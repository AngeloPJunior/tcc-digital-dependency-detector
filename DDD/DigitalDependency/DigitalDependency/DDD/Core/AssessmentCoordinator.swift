import Foundation
import SwiftUI
import Combine

/// Orquestra o pipeline completo:
/// fonte de dados → features → inferência → persistência → notificação.
///
/// É o único ponto do app que conhece todos os módulos. As views observam
/// este objeto e não falam com nenhuma camada inferior diretamente.
@MainActor
final class AssessmentCoordinator: ObservableObject {

    // MARK: - Estado publicado

    @Published private(set) var latest: RiskAssessment?
    @Published private(set) var history: [RiskAssessment] = []
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    /// Fonte atualmente ativa — exibida na interface para transparência.
    @Published private(set) var activeProvenance: DataProvenance = .simulated

    // MARK: - Dependências

    private var dataSource: UsageDataSource
    private let modelManager: MLModelManager
    private let store: AssessmentStore
    private let notifications: NotificationService

    /// Janela de análise. 7 dias é o mínimo para que `escalation_rate`
    /// seja informativo (o Python exige 4+ dias, abaixo disso retorna 1.0).
    private let analysisWindowDays = 7

    init(dataSource: UsageDataSource = SimulatedUsageDataSource(profile: .moderate),
         modelManager: MLModelManager = MLModelManager(),
         store: AssessmentStore = AssessmentStore(),
         notifications: NotificationService = .shared) {
        self.dataSource = dataSource
        self.modelManager = modelManager
        self.store = store
        self.notifications = notifications
        self.activeProvenance = dataSource.provenance
        loadHistory()
    }

    // MARK: - Configuração

    /// Troca a fonte de dados em tempo de execução.
    /// É isto que permite migrar para a Screen Time sem tocar em mais nada.
    func setDataSource(_ source: UsageDataSource) {
        self.dataSource = source
        self.activeProvenance = source.provenance
    }

    // MARK: - Fluxo principal

    func runAssessment() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            // 1. Captura
            let events = try await dataSource.fetchEvents(lastDays: analysisWindowDays)
            guard !events.isEmpty else {
                errorMessage = "Nenhum evento de uso disponível no período."
                return
            }

            // 2. Engenharia de features
            guard let features = FeatureEngineer.buildUserFeatures(from: events) else {
                errorMessage = "Não foi possível calcular as features."
                return
            }

            // 3. Inferência
            let level: RiskLevel
            let probabilities: [RiskLevel: Double]

            if modelManager.isModelLoaded {
                let result = try modelManager.predict(features: features)
                level = result.level
                probabilities = result.probabilities
            } else {
                // Fallback declarado: modelo indisponível ⇒ regra de limiares.
                level = RuleBasedClassifier.classify(features)
                probabilities = [level: 1.0]
                errorMessage = "Modelo CoreML indisponível — resultado obtido pela regra de limiares."
            }

            let assessment = RiskAssessment(
                level: level,
                probabilities: probabilities,
                features: features,
                provenance: dataSource.provenance
            )

            // 4. Persistência
            store.save(assessment)

            // 5. Notificação
            await notifications.notifyAssessment(assessment)

            latest = assessment
            loadHistory()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Histórico

    func loadHistory() {
        history = store.fetchAll()
        latest = history.first
    }

    func clearHistory() {
        store.deleteAll()
        loadHistory()
        latest = nil
    }
}
