import Foundation
import CoreML

/// Encapsula o modelo CoreML e converte `UserFeatures` no formato de entrada.
///
/// A ordem e os nomes dos campos correspondem a `feature_columns` do
/// script `03_treinar_modelo.py`. Divergência aqui produz predição
/// silenciosamente errada — o CoreML não avisa se você trocar duas features
/// de mesmo tipo.
final class MLModelManager {

    enum ModelError: LocalizedError {
        case modelUnavailable
        case predictionFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Modelo CoreML não pôde ser carregado."
            case .predictionFailed(let detail):
                return "Falha na inferência: \(detail)"
            }
        }
    }

    private var model: RiskClassifier?

    init() {
        self.model = try? RiskClassifier(configuration: MLModelConfiguration())
    }

    var isModelLoaded: Bool { model != nil }

    /// Executa a inferência on-device.
        func predict(features: UserFeatures) throws -> (level: RiskLevel, probabilities: [RiskLevel: Double]) {
            guard let model else { throw ModelError.modelUnavailable }

            let input = RiskClassifierInput(
                avg_daily_sessions:      features.avgDailySessions,
                avg_daily_events:        features.avgDailyEvents,
                avg_unique_apps:         features.avgUniqueApps,
                avg_night_ratio:         features.avgNightRatio,
                avg_session_duration:    features.avgSessionDuration,
                avg_short_session_ratio: features.avgShortSessionRatio,
                avg_top_app_ratio:       features.avgTopAppRatio,
                avg_entropy:             features.avgEntropy,
                avg_reopening_index:     features.avgReopeningIndex,
                avg_inter_session:       features.avgInterSession,
                std_daily_sessions:      features.stdDailySessions,
                max_daily_sessions:      features.maxDailySessions,
                escalation_rate:         features.escalationRate
            )

            do {
                // Usa a API bruta do MLModel: os nomes das saídas variam conforme
                // a versão do coremltools que gerou o .mlmodel, então são
                // descobertos em tempo de execução em vez de fixados no código.
                let output = try model.model.prediction(from: input)

                var level: RiskLevel?
                var probabilities: [RiskLevel: Double] = [:]

                for name in output.featureNames {
                    guard let value = output.featureValue(for: name) else { continue }
                    // Normaliza para 0–1. Dependendo de como o .mlmodel foi gerado,
                                // as probabilidades podem vir em escala percentual (0–100).
                                let soma = probabilities.values.reduce(0, +)
                                if soma > 0 {
                                    for (chave, valor) in probabilities {
                                        probabilities[chave] = valor / soma
                                    }
                                }

                    switch value.type {
                    case .dictionary:
                                        for (key, prob) in value.dictionaryValue {
                                            // A chave pode vir como NSNumber, Int ou String
                                            // dependendo de como o modelo foi convertido.
                                            let raw: Int?
                                            if let number = key as? NSNumber {
                                                raw = number.intValue
                                            } else if let int = key as? Int {
                                                raw = int
                                            } else if let string = key as? String {
                                                raw = Int(string)
                                            } else {
                                                raw = nil
                                            }

                                            if let raw, let risk = RiskLevel(rawValue: raw) {
                                                probabilities[risk] = prob.doubleValue
                                            }
                                        }
                    case .int64:
                        level = RiskLevel(rawValue: Int(value.int64Value))
                    case .double:
                        if level == nil { level = RiskLevel(rawValue: Int(value.doubleValue)) }
                    default:
                        break
                    }
                }

                // Sem saída de classe explícita: usa a de maior probabilidade.
                if level == nil {
                    level = probabilities.max(by: { $0.value < $1.value })?.key
                }

                guard let finalLevel = level else {
                    throw ModelError.predictionFailed("modelo não retornou classe reconhecível")
                }

                // Modelo sem vetor de probabilidades: confiança total na classe predita.
                if probabilities.isEmpty {
                    probabilities[finalLevel] = 1.0
                }

                return (finalLevel, probabilities)
            } catch let error as ModelError {
                throw error
            } catch {
                throw ModelError.predictionFailed(error.localizedDescription)
            }
        }
}

/// Regra de limiares idêntica à função `classify_risk` do script 02.
///
/// Existe por dois motivos:
///   1. Rede de segurança caso o `.mlmodel` não carregue na demonstração.
///   2. Referência explícita: como os rótulos de treino foram gerados por
///      esta regra, ela é o "ground truth" do modelo. Deixá-la visível no
///      código é mais honesto do que escondê-la no notebook.
enum RuleBasedClassifier {

    static func classify(_ f: UserFeatures) -> RiskLevel {
        var highFactors = 0
        if f.avgNightRatio > 0.15 { highFactors += 1 }
        if f.avgShortSessionRatio > 0.50 { highFactors += 1 }
        if f.avgReopeningIndex > 0.40 { highFactors += 1 }
        if f.escalationRate > 1.30 { highFactors += 1 }
        if f.avgDailySessions > 30 { highFactors += 1 }
        if f.avgEntropy < 1.0 { highFactors += 1 }
        if highFactors >= 3 { return .high }

        var mediumFactors = 0
        if f.avgNightRatio > 0.08 { mediumFactors += 1 }
        if f.avgShortSessionRatio > 0.35 { mediumFactors += 1 }
        if f.avgReopeningIndex > 0.25 { mediumFactors += 1 }
        if f.escalationRate > 1.15 { mediumFactors += 1 }
        if f.avgDailySessions > 20 { mediumFactors += 1 }
        if mediumFactors >= 2 { return .medium }

        return .low
    }
}
