import Foundation

/// Porte fiel de `02_engenharia_features.py` para Swift.
///
/// Cada método referencia a função Python correspondente. Qualquer alteração
/// aqui quebra a correspondência com o treino e invalida o modelo — por isso
/// as definições estão anotadas linha a linha.
enum FeatureEngineer {

    // MARK: - Nível diário (espelha `calculate_daily_features`)

    static func dailyFeatures(from events: [UsageEvent], on date: Date) -> DailyFeatures? {
        guard !events.isEmpty else { return nil }

        let calendar = Calendar.current
        let sessions = SessionBuilder.buildSessions(from: events)

        // 1. total_sessions
        let totalSessions = sessions.count

        // 2. total_events
        let totalEvents = events.count

        // 3. unique_apps
        let uniqueApps = Set(events.map(\.appName)).count

        // 4. night_usage_ratio — eventos entre 00h e 04h (inclusive), sobre o total.
        //    Python: group['hour'].between(0, 4)
        let nightEvents = events.filter { event in
            let hour = calendar.component(.hour, from: event.timestamp)
            return hour >= 0 && hour <= 4
        }
        let nightUsageRatio = Double(nightEvents.count) / Double(totalEvents)

        // 5. avg_session_duration — média das durações.
        //    Python considera APENAS sessões com 2+ eventos.
        let durations = sessions.compactMap(\.duration)
        let avgSessionDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // 6. short_session_ratio — sessões com menos de 10s.
        //    ATENÇÃO: o denominador é `durations.count`, não `sessions.count`.
        //    Isso reproduz o Python, onde a razão usa len(session_durations).
        let shortSessions = durations.filter { $0 < 10 }.count
        let shortSessionRatio = durations.isEmpty ? 0 : Double(shortSessions) / Double(durations.count)

        // 7. top_app_ratio — concentração no app mais frequente.
        var appCounts: [String: Int] = [:]
        for event in events { appCounts[event.appName, default: 0] += 1 }
        let topAppCount = appCounts.values.max() ?? 0
        let topAppRatio = Double(topAppCount) / Double(totalEvents)

        // 8. app_entropy — entropia de Shannon em log natural (padrão do scipy).
        //    Python retorna 0 quando há apenas 1 app distinto.
        let appEntropy = shannonEntropy(counts: Array(appCounts.values))

        // 9. reopening_index — eventos "Opened" consecutivos do mesmo app.
        let openedEvents = events
            .filter { $0.eventType == .opened }
            .sorted { $0.timestamp < $1.timestamp }
        var reopeningIndex = 0.0
        if openedEvents.count > 1 {
            var consecutiveSame = 0
            for i in 1..<openedEvents.count where openedEvents[i].appName == openedEvents[i - 1].appName {
                consecutiveSame += 1
            }
            reopeningIndex = Double(consecutiveSame) / Double(openedEvents.count - 1)
        }

        // 10. avg_inter_session — intervalo médio entre INÍCIOS de sessão, em minutos.
        var avgInterSession = 0.0
        let sessionStarts = sessions.map(\.start).sorted()
        if sessionStarts.count > 1 {
            var gaps: [Double] = []
            for i in 1..<sessionStarts.count {
                gaps.append(sessionStarts[i].timeIntervalSince(sessionStarts[i - 1]) / 60.0)
            }
            avgInterSession = gaps.reduce(0, +) / Double(gaps.count)
        }

        return DailyFeatures(
            date: calendar.startOfDay(for: date),
            totalSessions: totalSessions,
            totalEvents: totalEvents,
            uniqueApps: uniqueApps,
            nightUsageRatio: nightUsageRatio,
            avgSessionDuration: avgSessionDuration,
            shortSessionRatio: shortSessionRatio,
            topAppRatio: topAppRatio,
            appEntropy: appEntropy,
            reopeningIndex: reopeningIndex,
            avgInterSession: avgInterSession
        )
    }

    /// Entropia de Shannon em base e.
    /// Espelha `scipy.stats.entropy`, cujo padrão é logaritmo natural.
    /// Retorna 0 quando há um único app (mesma convenção do Python).
    private static func shannonEntropy(counts: [Int]) -> Double {
        guard counts.count > 1 else { return 0 }
        let total = Double(counts.reduce(0, +))
        guard total > 0 else { return 0 }

        return counts.reduce(0.0) { acc, count in
            let p = Double(count) / total
            guard p > 0 else { return acc }
            return acc - p * log(p)
        }
    }

    // MARK: - Agregação por usuário (espelha a seção 3 e 4 do Python)

    static func aggregate(dailyFeatures daily: [DailyFeatures]) -> UserFeatures? {
        guard !daily.isEmpty else { return nil }

        let sorted = daily.sorted { $0.date < $1.date }
        let sessionsPerDay = sorted.map { Double($0.totalSessions) }

        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }

        // std com ddof=1 (padrão do pandas). Com 1 dia, pandas gera NaN → preenchido com 0.
        func sampleStd(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0 }
            let m = mean(values)
            let sumSq = values.reduce(0.0) { $0 + pow($1 - m, 2) }
            return sqrt(sumSq / Double(values.count - 1))
        }

        return UserFeatures(
            avgDailySessions: mean(sessionsPerDay),
            avgDailyEvents: mean(sorted.map { Double($0.totalEvents) }),
            avgUniqueApps: mean(sorted.map { Double($0.uniqueApps) }),
            avgNightRatio: mean(sorted.map(\.nightUsageRatio)),
            avgSessionDuration: mean(sorted.map(\.avgSessionDuration)),
            avgShortSessionRatio: mean(sorted.map(\.shortSessionRatio)),
            avgTopAppRatio: mean(sorted.map(\.topAppRatio)),
            avgEntropy: mean(sorted.map(\.appEntropy)),
            avgReopeningIndex: mean(sorted.map(\.reopeningIndex)),
            avgInterSession: mean(sorted.map(\.avgInterSession)),
            stdDailySessions: sampleStd(sessionsPerDay),
            maxDailySessions: sessionsPerDay.max() ?? 0,
            escalationRate: escalationRate(sessionsPerDay: sessionsPerDay),
            daysMonitored: sorted.count
        )
    }

    /// Espelha `calculate_escalation`.
    /// Compara a média de sessões da primeira metade contra a segunda metade.
    /// Menos de 4 dias ⇒ 1.0 (neutro), exatamente como no Python.
    private static func escalationRate(sessionsPerDay: [Double]) -> Double {
        guard sessionsPerDay.count >= 4 else { return 1.0 }

        let mid = sessionsPerDay.count / 2
        let firstHalf = Array(sessionsPerDay[..<mid])
        let secondHalf = Array(sessionsPerDay[mid...])

        let firstMean = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondMean = secondHalf.reduce(0, +) / Double(secondHalf.count)

        guard firstMean > 0 else { return 1.0 }
        return secondMean / firstMean
    }

    // MARK: - Pipeline completo

    /// Agrupa eventos por dia, calcula features diárias e agrega por usuário.
    static func buildUserFeatures(from events: [UsageEvent]) -> UserFeatures? {
        guard !events.isEmpty else { return nil }
        let calendar = Calendar.current

        let byDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        let daily = byDay.compactMap { date, dayEvents in
            dailyFeatures(from: dayEvents, on: date)
        }
        return aggregate(dailyFeatures: daily)
    }
}
