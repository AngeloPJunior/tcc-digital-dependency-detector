import Foundation
import UserNotifications

/// Notificações locais de conscientização.
///
/// Princípio de design: o app informa, não pune. As mensagens descrevem o
/// padrão observado e sugerem reflexão — nunca culpabilizam nem alarmam.
/// Isso é uma decisão ética consciente, não apenas estética: um app sobre
/// dependência digital que gera ansiedade agrava o problema que pretende medir.
final class NotificationService {

    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Autorização

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Notificação de resultado

    /// Dispara após uma nova avaliação, apenas para MEDIUM e HIGH.
    /// LOW não gera notificação: reforçar comportamento saudável com alerta
    /// treina o usuário a ignorar as notificações que importam.
    func notifyAssessment(_ assessment: RiskAssessment) async {
        guard assessment.level != .low else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch assessment.level {
        case .medium:
            content.title = "Alguns sinais no seu uso"
            content.body = "Sua avaliação apontou nível moderado. Toque para ver quais padrões contribuíram."
        case .high:
            content.title = "Vale um momento de atenção"
            content.body = "Vários indicadores apareceram juntos nesta avaliação. Toque para entender o que foi observado."
        case .low:
            return
        }

        content.userInfo = ["assessmentId": assessment.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "assessment-\(assessment.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        try? await center.add(request)
    }

    // MARK: - Lembrete diário

    /// Agenda um lembrete diário para gerar nova avaliação.
    func scheduleDailyReminder(hour: Int = 21, minute: Int = 0) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])

        let content = UNMutableNotificationContent()
        content.title = "Resumo do dia"
        content.body = "Sua análise de uso está pronta para ser gerada."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])
    }

    private static let dailyReminderID = "daily-assessment-reminder"
}
