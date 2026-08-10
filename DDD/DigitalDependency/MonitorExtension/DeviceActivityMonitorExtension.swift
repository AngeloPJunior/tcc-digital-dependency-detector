import DeviceActivity
import Foundation

/// Extension que roda em processo separado e recebe os callbacks do sistema
/// quando os limiares de uso configurados são atingidos.
///
/// Esta é a única via pela qual o iOS entrega informação temporal de uso a um
/// app de terceiros. O detalhamento evento a evento existe apenas dentro da
/// DeviceActivityReport Extension, cuja saída é uma View e não atravessa de
/// volta para o app.
///
/// A comunicação com o app principal é feita por UserDefaults compartilhado
/// via App Group — processos separados não compartilham memória.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        SharedThresholdWriter.registrar(evento: "interval_start", minutos: 0)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        SharedThresholdWriter.registrar(evento: "interval_end", minutos: 0)
    }

    /// Chamado quando um limiar é atingido.
    ///
    /// O nome do evento carrega a informação, já que o callback não recebe
    /// o token do app: o formato é "app<índice>_threshold_<minutos>min".
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        let nome = event.rawValue
        let partes = nome.components(separatedBy: "_")

        // Extrai o índice do app e o limiar em minutos do nome do evento.
        var appLabel = "app_desconhecido"
        var minutos = 0

        if let primeira = partes.first, primeira.hasPrefix("app") {
            appLabel = primeira
        }
        if let ultima = partes.last {
            minutos = Int(ultima.replacingOccurrences(of: "min", with: "")) ?? 0
        }

        SharedThresholdWriter.registrar(evento: appLabel, minutos: minutos)
    }
}

/// Escrita no App Group.
///
/// Duplicado aqui de propósito: a extension é um target separado e não
/// compartilha código com o app principal a menos que o arquivo seja
/// adicionado a ambos os targets. Manter uma cópia mínima e independente
/// evita arrastar todo o modelo de domínio para dentro da extension.
enum SharedThresholdWriter {

    /// Precisa ser idêntico ao App Group configurado nos dois targets.
    static let appGroupID = "group.com.angelojunior.DigitalDependency"

    private static let key = "threshold_marks"

    struct Mark: Codable {
        let appLabel: String
        let timestamp: Date
        let thresholdMinutes: Int
    }

    static func registrar(evento appLabel: String, minutos: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        var marks: [Mark] = []
        if let data = defaults.data(forKey: key),
           let existentes = try? JSONDecoder().decode([Mark].self, from: data) {
            marks = existentes
        }

        marks.append(Mark(appLabel: appLabel, timestamp: Date(), thresholdMinutes: minutos))

        // Retém 30 dias.
        let corte = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        marks = marks.filter { $0.timestamp >= corte }

        if let data = try? JSONEncoder().encode(marks) {
            defaults.set(data, forKey: key)
        }
    }
}

