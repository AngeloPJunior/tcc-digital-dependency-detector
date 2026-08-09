import Foundation

// MARK: - Evento bruto de uso

/// Tipo de evento capturado. Espelha a coluna `event_type` do LSApp.
enum UsageEventType: String, Codable {
    case opened = "Opened"
    case closed = "Closed"
}

/// Um evento individual de uso de aplicativo.
/// É a unidade mínima do pipeline: tudo é derivado daqui.
struct UsageEvent: Codable, Identifiable {
    let id: UUID
    let appName: String
    let timestamp: Date
    let eventType: UsageEventType

    init(id: UUID = UUID(), appName: String, timestamp: Date, eventType: UsageEventType) {
        self.id = id
        self.appName = appName
        self.timestamp = timestamp
        self.eventType = eventType
    }
}

/// Sessão de uso reconstruída a partir de eventos.
///
/// IMPORTANTE (limitação metodológica declarada):
/// No dataset LSApp o `session_id` vinha pronto. No iOS não existe equivalente,
/// então a sessão é *inferida* por segmentação temporal (ver `SessionBuilder`).
struct UsageSession {
    let events: [UsageEvent]

    var start: Date { events.first?.timestamp ?? Date() }
    var end: Date { events.last?.timestamp ?? Date() }

    /// Duração em segundos. Espelha o Python: só é calculada para sessões
    /// com 2+ eventos (diferença entre primeiro e último timestamp).
    var duration: TimeInterval? {
        guard events.count >= 2 else { return nil }
        return end.timeIntervalSince(start)
    }
}

// MARK: - Features

/// As 10 features diárias, idênticas às do script `02_engenharia_features.py`.
struct DailyFeatures {
    let date: Date
    let totalSessions: Int
    let totalEvents: Int
    let uniqueApps: Int
    let nightUsageRatio: Double
    let avgSessionDuration: Double
    let shortSessionRatio: Double
    let topAppRatio: Double
    let appEntropy: Double
    let reopeningIndex: Double
    let avgInterSession: Double
}

/// As 13 features agregadas por usuário — exatamente o vetor de entrada do modelo.
/// A ORDEM E OS NOMES devem casar com `feature_columns` do script 03.
struct UserFeatures {
    let avgDailySessions: Double
    let avgDailyEvents: Double
    let avgUniqueApps: Double
    let avgNightRatio: Double
    let avgSessionDuration: Double
    let avgShortSessionRatio: Double
    let avgTopAppRatio: Double
    let avgEntropy: Double
    let avgReopeningIndex: Double
    let avgInterSession: Double
    let stdDailySessions: Double
    let maxDailySessions: Double
    let escalationRate: Double

    /// Número de dias que originaram estas features.
    /// Não é feature do modelo — serve para avaliar confiabilidade.
    let daysMonitored: Int
}

// MARK: - Resultado

enum RiskLevel: Int, CaseIterable, Codable {
    case low = 0
    case medium = 1
    case high = 2

    var label: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        }
    }

    var descricao: String {
        switch self {
        case .low: return "Padrão de uso equilibrado"
        case .medium: return "Alguns sinais de uso problemático"
        case .high: return "Múltiplos indicadores de risco"
        }
    }
}

/// Origem dos dados que geraram a avaliação.
/// Existe para que a interface NUNCA apresente estimativa como medição.
enum DataProvenance: String, Codable {
    case screenTime   // DeviceActivityMonitor, dados reais do dispositivo
    case simulated    // Dados sintéticos, para demonstração

    var rotulo: String {
        switch self {
        case .screenTime: return "Dados do dispositivo"
        case .simulated: return "Dados simulados"
        }
    }
}

struct RiskAssessment: Identifiable {
    let id: UUID
    let date: Date
    let level: RiskLevel
    let probabilities: [RiskLevel: Double]
    let features: UserFeatures
    let provenance: DataProvenance
    
    /// Confiança = probabilidade da classe predita.
    var confidence: Double { probabilities[level] ?? 0 }
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         level: RiskLevel,
         probabilities: [RiskLevel: Double],
         features: UserFeatures,
         provenance: DataProvenance) {
        self.id = id
        self.date = date
        self.level = level
        self.features = features
        self.provenance = provenance
        
        // Normaliza para 0–1 na entrada. Protege contra duas origens de
        // escala percentual: o .mlmodel (dependendo de como foi convertido)
        // e registros antigos gravados antes desta correção.
        let soma = probabilities.values.reduce(0, +)
        if soma > 0 {
            self.probabilities = probabilities.mapValues { $0 / soma }
        } else {
            self.probabilities = probabilities
        }
    }
}
