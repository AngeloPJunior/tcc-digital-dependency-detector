import Foundation

/// Reconstrói sessões de uso a partir de eventos brutos.
///
/// ADAPTAÇÃO METODOLÓGICA DECLARADA
/// --------------------------------
/// O dataset LSApp fornecia `session_id` já atribuído pelos autores.
/// O iOS não expõe nada equivalente: a Screen Time entrega eventos e
/// contagens, não sessões. Portanto, aqui a sessão é *inferida*.
///
/// Critério: eventos consecutivos pertencem à mesma sessão enquanto o
/// intervalo entre eles for menor que `inactivityThreshold`.
///
/// Consequência: `total_sessions`, `avg_session_duration`,
/// `short_session_ratio` e `avg_inter_session` passam a depender deste
/// parâmetro. Ele é a principal fonte de divergência possível entre
/// treino e inferência, e por isso está isolado numa constante única,
/// documentada e citável na monografia.
enum SessionBuilder {

    /// Janela de inatividade que encerra uma sessão.
    /// 5 minutos é o valor mais comum na literatura de analytics de uso móvel.
    static let inactivityThreshold: TimeInterval = 5 * 60

    static func buildSessions(from events: [UsageEvent]) -> [UsageSession] {
        guard !events.isEmpty else { return [] }

        let ordered = events.sorted { $0.timestamp < $1.timestamp }
        var sessions: [UsageSession] = []
        var current: [UsageEvent] = [ordered[0]]

        for event in ordered.dropFirst() {
            let gap = event.timestamp.timeIntervalSince(current[current.count - 1].timestamp)
            if gap > inactivityThreshold {
                sessions.append(UsageSession(events: current))
                current = [event]
            } else {
                current.append(event)
            }
        }
        sessions.append(UsageSession(events: current))
        return sessions
    }
}
