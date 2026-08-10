import Foundation

/// Gera eventos sintéticos com padrões comportamentais controlados.
///
/// Serve a dois propósitos legítimos:
///   - Desenvolver o pipeline sem depender do entitlement da Apple.
///   - Demonstrar os três níveis de risco de forma reprodutível.
///
/// Os dados são SEMPRE marcados como `.simulated` e a interface exibe esse
/// rótulo. Em nenhum momento uma estimativa é apresentada como medição.
final class SimulatedUsageDataSource: UsageDataSource {

    /// Perfil comportamental a ser sintetizado.
    enum Profile {
        case balanced      // tende a LOW
        case moderate      // tende a MEDIUM
        case compulsive    // tende a HIGH
    }

    let provenance: DataProvenance = .simulated
    var isAvailable: Bool { true }

    private let profile: Profile
    private var generator: SeededGenerator

    /// - Parameter seed: fixa a sequência pseudoaleatória, tornando a
    ///   demonstração reprodutível (importante para apresentação em banca).
    init(profile: Profile, seed: UInt64 = 42) {
        self.profile = profile
        self.generator = SeededGenerator(seed: seed)
    }

    func requestAuthorization() async throws { /* fonte sintética não exige */ }

    func fetchEvents(lastDays days: Int) async throws -> [UsageEvent] {
        var events: [UsageEvent] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            // Fator de escalonamento: uso cresce ao longo do período no perfil compulsivo.
            let progress = days > 1 ? Double(days - 1 - dayOffset) / Double(days - 1) : 0
            events.append(contentsOf: generateDay(day, progress: progress, calendar: calendar))
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Geração

    private var apps: [String] {
        switch profile {
        case .balanced:
            return ["Mensagens", "Navegador", "Música", "Mapas", "E-mail",
                    "Notas", "Câmera", "Podcasts", "Calendário", "Livros"]
        case .moderate:
            return ["Rede Social", "Mensagens", "Vídeos", "Navegador",
                    "E-mail", "Música", "Jogo", "Notícias"]
        case .compulsive:
            return ["Rede Social", "Vídeos Curtos", "Mensagens", "Jogo"]
        }
    }

    private func generateDay(_ day: Date, progress: Double, calendar: Calendar) -> [UsageEvent] {
        let sessionCount = sessionsForDay(progress: progress)
        var events: [UsageEvent] = []

        for _ in 0..<sessionCount {
            let hour = drawHour()
            let minute = Int(generator.nextDouble() * 60)
            guard let sessionStart = calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) else { continue }

            events.append(contentsOf: generateSession(startingAt: sessionStart))
        }
        return events
    }

    private func sessionsForDay(progress: Double) -> Int {
        switch profile {
        case .balanced:
            return 6 + Int(generator.nextDouble() * 5)              // 6–10
        case .moderate:
            return 20 + Int(generator.nextDouble() * 8)             // 20–27
        case .compulsive:
            // Cresce ~40% do início ao fim → escalation_rate alto.
            let base = 32.0 + progress * 14.0
            return Int(base + generator.nextDouble() * 6)           // ~32–52
        }
    }

    /// Sorteia a hora de início respeitando a proporção de uso noturno (00h–04h)
    /// característica de cada perfil.
    private func drawHour() -> Int {
        let nightProbability: Double
        switch profile {
        case .balanced:   nightProbability = 0.02
        case .moderate:   nightProbability = 0.11
        case .compulsive: nightProbability = 0.24
        }

        if generator.nextDouble() < nightProbability {
            return Int(generator.nextDouble() * 5)          // 0–4h
        }
        return 7 + Int(generator.nextDouble() * 17)         // 7–23h
    }

    /// Gera os eventos internos de uma sessão.
    /// Sessões curtas (<10s) e reaberturas do mesmo app são os marcadores
    /// comportamentais que distinguem os perfis.
    private func generateSession(startingAt start: Date) -> [UsageEvent] {
        let isShort: Bool
        let reopenProbability: Double

        switch profile {
        case .balanced:
            isShort = generator.nextDouble() < 0.08
            reopenProbability = 0.15
        case .moderate:
            isShort = generator.nextDouble() < 0.38
            reopenProbability = 0.30
        case .compulsive:
            isShort = generator.nextDouble() < 0.62
            reopenProbability = 0.55
        }

        let eventCount = isShort ? 2 : 2 + Int(generator.nextDouble() * 7)
        var events: [UsageEvent] = []
        var cursor = start
        var lastApp = apps[Int(generator.nextDouble() * Double(apps.count))]

        for i in 0..<eventCount {
            // Reabertura: repete o app anterior com probabilidade do perfil.
            if i > 0 && generator.nextDouble() >= reopenProbability {
                lastApp = apps[Int(generator.nextDouble() * Double(apps.count))]
            }

            events.append(UsageEvent(appName: lastApp, timestamp: cursor, eventType: .opened))

            // Avanço dentro da sessão: curto ⇒ poucos segundos.
            let step = isShort
                ? 1.0 + generator.nextDouble() * 3.0
                : 20.0 + generator.nextDouble() * 120.0
            cursor = cursor.addingTimeInterval(step)

            events.append(UsageEvent(appName: lastApp, timestamp: cursor, eventType: .closed))
            cursor = cursor.addingTimeInterval(1.0 + generator.nextDouble() * 4.0)
        }
        return events
    }
}

/// Gerador congruente linear com semente fixa.
/// Necessário porque `Double.random` não é reprodutível entre execuções.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
