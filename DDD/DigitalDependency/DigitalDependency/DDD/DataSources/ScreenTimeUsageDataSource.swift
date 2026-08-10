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
/// configurado é atingido. Registrando limiares finos por aplicativo,
/// obtém-se uma série de marcos temporais da qual eventos são *estimados*.
///
/// SEGUNDA RESTRIÇÃO: ANONIMATO DOS TOKENS
/// ---------------------------------------
/// `ApplicationToken` é opaco. Não há API para obter nome ou bundle ID.
/// Os apps são portanto identificados por índice posicional (`app0`, `app1`),
/// estável enquanto a seleção não mudar.
///
/// Isso é suficiente para as features do modelo, que medem *distribuição* e
/// *repetição* de uso, não identidade: `unique_apps`, `top_app_ratio`,
/// `app_entropy` e `reopening_index` operam sobre identificadores arbitrários.
///
/// Consequência metodológica a declarar: os eventos aqui produzidos são
/// reconstruções a partir de limiares, não observações diretas.
@available(iOS 16.0, *)
final class ScreenTimeUsageDataSource: UsageDataSource {

    let provenance: DataProvenance = .screenTime

    private let center = AuthorizationCenter.shared
    private let store = ThresholdEventStore.shared

    /// Limiares registrados por aplicativo, em minutos.
    /// Mais limiares ⇒ estimativa mais fina, ao custo de mais acionamentos.
    private let limiares = [1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120]

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
        guard !events.isEmpty else {
            throw UsageDataSourceError.insufficientData(daysFound: 0, daysRequired: 1)
        }
        return events
    }

    // MARK: - Monitoramento

    /// Registra um evento de limiar por aplicativo selecionado.
    ///
    /// O nome do evento codifica índice e limiar, porque o callback da
    /// extension recebe apenas o nome — não o token nem metadados.
    func startMonitoring(selection: FamilyActivitySelection) throws {
        let deviceActivityCenter = DeviceActivityCenter()

        // Encerra monitoramento anterior para evitar acúmulo de agendamentos.
        deviceActivityCenter.stopMonitoring([.init("dailyUsage")])

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for (indice, token) in selection.applicationTokens.enumerated() {
            for minutos in limiares {
                let nome = DeviceActivityEvent.Name("app\(indice)_threshold_\(minutos)min")
                events[nome] = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(minute: minutos)
                )
            }
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

    var isMonitoring: Bool {
        !DeviceActivityCenter().activities.isEmpty
    }
}
#endif

/// Lê os marcos gravados pela extension e os converte em eventos de uso.
final class ThresholdEventStore {

    static let shared = ThresholdEventStore()

    /// Precisa ser idêntico ao App Group dos dois targets e ao valor em
    /// `SharedThresholdWriter.appGroupID` dentro da extension.
    static let appGroupID = "group.com.angelojunior.DigitalDependency"

    private let key = "threshold_marks"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    private struct Mark: Codable {
        let appLabel: String
        let timestamp: Date
        let thresholdMinutes: Int
    }

    /// Converte marcos de limiar em eventos de uso estimados.
    ///
    /// Cada marco vira um par Opened/Closed. A duração atribuída é a diferença
    /// entre o limiar atual e o anterior do mesmo app — uma estimativa, e
    /// documentada como tal.
    func events(lastDays days: Int) -> [UsageEvent] {
        guard let corte = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }

        let marks = carregar()
            .filter { $0.timestamp >= corte && $0.thresholdMinutes > 0 }
            .sorted { $0.timestamp < $1.timestamp }

        var events: [UsageEvent] = []
        var ultimoLimiar: [String: Int] = [:]
        let calendar = Calendar.current

        for mark in marks {
            // O limiar reinicia a cada dia, porque o schedule é diário.
            let chave = "\(mark.appLabel)_\(calendar.startOfDay(for: mark.timestamp).timeIntervalSince1970)"
            let anterior = ultimoLimiar[chave] ?? 0
            let segundosEstimados = Double(max(mark.thresholdMinutes - anterior, 1) * 60)
            ultimoLimiar[chave] = mark.thresholdMinutes

            let inicio = mark.timestamp.addingTimeInterval(-segundosEstimados)
            events.append(UsageEvent(appName: mark.appLabel, timestamp: inicio, eventType: .opened))
            events.append(UsageEvent(appName: mark.appLabel, timestamp: mark.timestamp, eventType: .closed))
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }

    /// Diagnóstico: quantos marcos foram capturados até agora.
    func totalMarcos() -> Int {
        carregar().filter { $0.thresholdMinutes > 0 }.count
    }

    func clear() { defaults.removeObject(forKey: key) }

    private func carregar() -> [Mark] {
        guard let data = defaults.data(forKey: key),
              let marks = try? JSONDecoder().decode([Mark].self, from: data)
        else { return [] }
        return marks
    }
}
