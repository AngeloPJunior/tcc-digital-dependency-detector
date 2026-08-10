import Foundation

/// Contrato entre a captura de dados e o resto do pipeline.
///
/// Este protocolo é o ponto de inversão de dependência do sistema: o
/// `AssessmentCoordinator` não sabe se os eventos vieram da Screen Time
/// ou de um gerador sintético. Isso permite:
///   1. Desenvolver e testar todo o pipeline sem o entitlement da Apple.
///   2. Demonstrar o fluxo completo no simulador.
///   3. Trocar a implementação real sem tocar em mais nada.
protocol UsageDataSource {
    /// De onde vêm os dados — propagado até a interface.
    var provenance: DataProvenance { get }

    /// Indica se a fonte está pronta (autorizada, com dados disponíveis).
    var isAvailable: Bool { get }

    /// Solicita autorização, quando a fonte precisar.
    func requestAuthorization() async throws

    /// Retorna os eventos dos últimos `days` dias, ordenados por timestamp.
    func fetchEvents(lastDays days: Int) async throws -> [UsageEvent]
}

enum UsageDataSourceError: LocalizedError {
    case notAuthorized
    case unavailableOnThisDevice
    case insufficientData(daysFound: Int, daysRequired: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Autorização de Tempo de Uso não concedida."
        case .unavailableOnThisDevice:
            return "Recurso indisponível neste dispositivo."
        case .insufficientData(let found, let required):
            return "Dados insuficientes: \(found) dia(s) disponível(is), \(required) necessário(s)."
        }
    }
}
