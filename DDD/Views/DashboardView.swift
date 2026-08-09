import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var coordinator: AssessmentCoordinator
    @State private var showingFeatures = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        provenanceBanner
                        riskCard
                        if let latest = coordinator.latest {
                            probabilityBreakdown(latest)
                            featuresToggle(latest)
                        }
                        actionButton
                        if let error = coordinator.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Avaliação")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Componentes

    /// Transparência sobre a origem dos dados.
    /// Nunca deve ser removido: é o que impede que estimativa pareça medição.
    private var provenanceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: coordinator.activeProvenance == .screenTime
                  ? "iphone.gen3" : "flask")
                .foregroundStyle(Theme.accent)
            Text(coordinator.activeProvenance.rotulo)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private var riskCard: some View {
        VStack(spacing: 16) {
            Text("Nível de risco")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            ZStack {
                Circle()
                    .stroke(Theme.card, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: coordinator.latest?.confidence ?? 0)
                    .stroke(color(for: coordinator.latest?.level),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: coordinator.latest?.confidence)

                VStack(spacing: 4) {
                    Text(coordinator.latest?.level.label ?? "—")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(color(for: coordinator.latest?.level))

                    if let latest = coordinator.latest {
                        Text(String(format: "%.0f%% de confiança", latest.confidence * 100))
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .frame(width: 190, height: 190)

            if let latest = coordinator.latest {
                Text(latest.level.descricao)
                    .font(.callout)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Baseado em \(latest.features.daysMonitored) dia(s) de dados")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("Nenhuma avaliação ainda")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func probabilityBreakdown(_ assessment: RiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribuição de probabilidade")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            ForEach(RiskLevel.allCases, id: \.rawValue) { level in
                            HStack(spacing: 10) {
                                Text(level.label)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(width: 60, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.background)
                                        Capsule()
                                            .fill(color(for: level))
                                            .frame(width: geo.size.width * min(1, assessment.probabilities[level] ?? 0))
                                    }
                                }
                                .frame(height: 8)

                                Text(String(format: "%.0f%%", (assessment.probabilities[level] ?? 0) * 100))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featuresToggle(_ assessment: RiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showingFeatures.toggle() }
            } label: {
                HStack {
                    Text("Features calculadas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Image(systemName: showingFeatures ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if showingFeatures {
                VStack(spacing: 8) {
                    featureRow("Sessões/dia", assessment.features.avgDailySessions, "%.1f")
                    featureRow("Eventos/dia", assessment.features.avgDailyEvents, "%.0f")
                    featureRow("Apps distintos", assessment.features.avgUniqueApps, "%.1f")
                    featureRow("Uso noturno", assessment.features.avgNightRatio * 100, "%.1f%%")
                    featureRow("Duração média (s)", assessment.features.avgSessionDuration, "%.0f")
                    featureRow("Sessões curtas", assessment.features.avgShortSessionRatio * 100, "%.1f%%")
                    featureRow("Concentração no top app", assessment.features.avgTopAppRatio * 100, "%.1f%%")
                    featureRow("Entropia", assessment.features.avgEntropy, "%.2f")
                    featureRow("Índice de reabertura", assessment.features.avgReopeningIndex, "%.2f")
                    featureRow("Intervalo entre sessões (min)", assessment.features.avgInterSession, "%.1f")
                    featureRow("Desvio padrão sessões", assessment.features.stdDailySessions, "%.2f")
                    featureRow("Máx. sessões/dia", assessment.features.maxDailySessions, "%.0f")
                    featureRow("Escalonamento", assessment.features.escalationRate, "%.2f")
                }
            }
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(_ name: String, _ value: Double, _ format: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(String(format: format, value))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(Theme.primaryText)
        }
    }

    private var actionButton: some View {
        Button {
            Task { await coordinator.runAssessment() }
        } label: {
            HStack(spacing: 8) {
                if coordinator.isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "waveform.path.ecg")
                }
                Text(coordinator.isProcessing ? "Analisando…" : "Gerar avaliação")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(coordinator.isProcessing)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private func color(for level: RiskLevel?) -> Color {
        switch level {
        case .low: return Theme.low
        case .medium: return Theme.medium
        case .high: return Theme.high
        case nil: return Theme.secondaryText
        }
    }
}

// MARK: - Tema

enum Theme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.11)
    static let card = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let accent = Color(red: 0.29, green: 0.53, blue: 0.91)
    static let primaryText = Color.white
    static let secondaryText = Color(white: 0.62)
    static let low = Color(red: 0.30, green: 0.78, blue: 0.55)
    static let medium = Color(red: 0.95, green: 0.70, blue: 0.25)
    static let high = Color(red: 0.91, green: 0.36, blue: 0.36)
}
