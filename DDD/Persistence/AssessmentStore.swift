import Foundation
import CoreData

/// Camada de acesso às avaliações persistidas.
/// Traduz entre o modelo de domínio (`RiskAssessment`) e o CoreData.
final class AssessmentStore {

    private let controller: PersistenceController

    init(controller: PersistenceController = .shared) {
        self.controller = controller
    }

    // MARK: - Escrita

    @discardableResult
    func save(_ assessment: RiskAssessment) -> Bool {
        let context = controller.viewContext
        let entity = AssessmentEntity(context: context)

        entity.id = assessment.id
        entity.date = assessment.date
        entity.riskLevel = Int16(assessment.level.rawValue)
        entity.confidence = assessment.confidence
        entity.provenance = assessment.provenance.rawValue
        entity.probLow = assessment.probabilities[.low] ?? 0
        entity.probMedium = assessment.probabilities[.medium] ?? 0
        entity.probHigh = assessment.probabilities[.high] ?? 0
        entity.daysMonitored = Int16(assessment.features.daysMonitored)
        entity.featuresJSON = encodeFeatures(assessment.features)

        controller.save()
        return true
    }

    // MARK: - Leitura

    func fetchAll(limit: Int = 100) -> [RiskAssessment] {
        let request = NSFetchRequest<AssessmentEntity>(entityName: "AssessmentEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit

        guard let entities = try? controller.viewContext.fetch(request) else { return [] }
        return entities.compactMap(toDomain)
    }

    func fetchLatest() -> RiskAssessment? {
        fetchAll(limit: 1).first
    }

    /// Série temporal do nível de risco — alimenta o gráfico de evolução.
    func riskTrend(lastDays days: Int = 30) -> [(date: Date, level: RiskLevel)] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        return fetchAll(limit: 500)
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map { ($0.date, $0.level) }
    }

    func deleteAll() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "AssessmentEntity")
        let delete = NSBatchDeleteRequest(fetchRequest: request)
        _ = try? controller.container.persistentStoreCoordinator.execute(
            delete, with: controller.viewContext
        )
        controller.viewContext.reset()
    }

    // MARK: - Conversão

    private func toDomain(_ entity: AssessmentEntity) -> RiskAssessment? {
        guard let level = RiskLevel(rawValue: Int(entity.riskLevel)),
              let provenance = DataProvenance(rawValue: entity.provenance),
              let features = decodeFeatures(entity.featuresJSON, days: Int(entity.daysMonitored))
        else { return nil }

        return RiskAssessment(
            id: entity.id,
            date: entity.date,
            level: level,
            probabilities: [
                .low: entity.probLow,
                .medium: entity.probMedium,
                .high: entity.probHigh
            ],
            features: features,
            provenance: provenance
        )
    }

    private func encodeFeatures(_ f: UserFeatures) -> String? {
        let dict: [String: Double] = [
            "avg_daily_sessions": f.avgDailySessions,
            "avg_daily_events": f.avgDailyEvents,
            "avg_unique_apps": f.avgUniqueApps,
            "avg_night_ratio": f.avgNightRatio,
            "avg_session_duration": f.avgSessionDuration,
            "avg_short_session_ratio": f.avgShortSessionRatio,
            "avg_top_app_ratio": f.avgTopAppRatio,
            "avg_entropy": f.avgEntropy,
            "avg_reopening_index": f.avgReopeningIndex,
            "avg_inter_session": f.avgInterSession,
            "std_daily_sessions": f.stdDailySessions,
            "max_daily_sessions": f.maxDailySessions,
            "escalation_rate": f.escalationRate
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeFeatures(_ json: String?, days: Int) -> UserFeatures? {
        guard let json,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Double]
        else { return nil }

        func value(_ key: String) -> Double { dict[key] ?? 0 }

        return UserFeatures(
            avgDailySessions: value("avg_daily_sessions"),
            avgDailyEvents: value("avg_daily_events"),
            avgUniqueApps: value("avg_unique_apps"),
            avgNightRatio: value("avg_night_ratio"),
            avgSessionDuration: value("avg_session_duration"),
            avgShortSessionRatio: value("avg_short_session_ratio"),
            avgTopAppRatio: value("avg_top_app_ratio"),
            avgEntropy: value("avg_entropy"),
            avgReopeningIndex: value("avg_reopening_index"),
            avgInterSession: value("avg_inter_session"),
            stdDailySessions: value("std_daily_sessions"),
            maxDailySessions: value("max_daily_sessions"),
            escalationRate: value("escalation_rate"),
            daysMonitored: days
        )
    }
}
