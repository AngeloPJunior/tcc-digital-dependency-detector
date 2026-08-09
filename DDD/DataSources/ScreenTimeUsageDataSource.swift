import Foundation

#if canImport(FamilyControls)
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Fonte de dados baseada na Screen Time API.
///
/// RESTRIÇÃO CENTRAL DA PLATAFORMA
/// -------------------------------
/// A Apple não expõe eventos individuais de abertura de app ao processo
/// principal. O detalhamento existe apenas dentro da `DeviceActivityReport`
/// Extension, cuja saída é uma SwiftUI View — o dado não atravessa de volta.
///
/// O que É acessível: callbacks do `DeviceActivityMonitor` quando um limiar
/// (threshold) configurado é atingido. Registrando limiares finos, obtém-se
/// uma série de marcos temporais por app, da qual eventos são *estimados*.
///
/// Consequência metodológica: os eventos aqui produzidos são reconstruções,
/// não medições diretas. `provenance` permanece `.screenTime` porque a
/// origem é o dispositivo, mas a monografia deve declarar que a granularidade
/// é inferida a partir de limiares, não observada evento a evento.
///
/// PRÉ-REQUISITOS
///   - Apple Developer Program pago (capability Family Controls)
///   - Dispositivo físico: limiares NÃO disparam no simulador
@available(iOS 16.0, *)
final class ScreenTimeUsageDataSource: UsageDataSource {

    let provenance: DataProvenance = .screenTime

    private let center = AuthorizationCenter.shared
    private let store = ThresholdEventStore.shared

    var isAvailable: Bool {
        center.authorizationStatus == .approved
    }

    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            throw UsageDataSourceError.notAuthorized
        }
    }

    func fetchEvents(lastDays days: Int) async throws -> [UsageEvent] {
        guard isAvailable else { throw UsageDataSourceError.notAuthorized }

        let events = store.events(lastDays: days)
        let distinctDays = Set(events.map { Calendar.current.startOfDay(for: $0.timestamp) }).count

        guard distinctDays >= 1 else {
            throw UsageDataSourceError.insufficientData(daysFound: distinctDays, daysRequired: 1)
        }
        return events
    }

    // MARK: - Monitoramento

    /// Inicia o monitoramento com limiares finos.
    ///
    /// Cada limiar atingido gera um callback na extension, que grava um marco
    /// temporal. Limiares menores ⇒ mais marcos ⇒ estimativa mais fina, ao
    /// custo de mais acionamentos do sistema.
    func startMonitoring(selection: FamilyActivitySelection) throws {
        let deviceActivityCenter = DeviceActivityCenter()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Limiares progressivos: 1, 2, 5, 10, 15, 30, 45, 60, 90, 120 minutos.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in [1, 2, 5, 10, 15, 30, 45, 60, 90, 120] {
            let name = DeviceActivityEvent.Name("threshold_\(minutes)min")
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: minutes)
            )
        }

        try deviceActivityCenter.startMonitoring(
            .init("dailyUsage"),
            during: schedule,
            events: events
        )
    }

    func stopMonitoring() {
        DeviceActivityCenter().stopMonitoring([.init("dailyUsage")])
    }
}
#endif

/// Armazena os marcos gravados pela extension.
///
/// A `DeviceActivityMonitor` Extension roda em processo separado; a
/// comunicação com o app principal é feita por App Group compartilhado.
/// Configure o App Group em ambos os targets antes de usar.
final class ThresholdEventStore {

    static let shared = ThresholdEventStore()

    /// Substitua pelo identificador do seu App Group.
    static let appGroupID = "group.com.seudominio.digitaldependency"

    private let key = "threshold_marks"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    private struct Mark: Codable {
        let appLabel: String
        let timestamp: Date
        let thresholdMinutes: Int
    }

    /// Chamado pela extension a cada limiar atingido.
    func record(appLabel: String, thresholdMinutes: Int, at date: Date = Date()) {
        var marks = loadMarks()
        marks.append(Mark(appLabel: appLabel, timestamp: date, thresholdMinutes: thresholdMinutes))
        // Retém 30 dias.
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        marks = marks.filter { $0.timestamp >= cutoff }
        if let data = try? JSONEncoder().encode(marks) {
            defaults.set(data, forKey: key)
        }
    }

    /// Converte marcos de limiar em eventos de uso estimados.
    ///
    /// Cada marco vira um par Opened/Closed. A duração atribuída é a
    /// diferença entre limiares consecutivos do mesmo app — é uma estimativa,
    /// e está documentada como tal.
    func events(lastDays days: Int) -> [UsageEvent] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let marks = loadMarks().filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }

        var events: [UsageEvent] = []
        var lastThreshold: [String: Int] = [:]

        for mark in marks {
            let previous = lastThreshold[mark.appLabel] ?? 0
            let estimatedSeconds = Double(max(mark.thresholdMinutes - previous, 1) * 60)
            lastThreshold[mark.appLabel] = mark.thresholdMinutes

            let start = mark.timestamp.addingTimeInterval(-estimatedSeconds)
            events.append(UsageEvent(appName: mark.appLabel, timestamp: start, eventType: .opened))
            events.append(UsageEvent(appName: mark.appLabel, timestamp: mark.timestamp, eventType: .closed))
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    func clear() { defaults.removeObject(forKey: key) }

    private func loadMarks() -> [Mark] {
        guard let data = defaults.data(forKey: key),
              let marks = try? JSONDecoder().decode([Mark].self, from: data)
        else { return [] }
        return marks
    }
}
