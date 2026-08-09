import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var coordinator: AssessmentCoordinator

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if coordinator.history.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            trendCard
                            ForEach(coordinator.history) { assessment in
                                row(assessment)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Histórico")
            .toolbar {
                if !coordinator.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Limpar", role: .destructive) {
                            coordinator.clearHistory()
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundStyle(Theme.secondaryText)
            Text("Nenhuma avaliação registrada")
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
            Text("As avaliações geradas ficam salvas aqui e persistem entre execuções.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
        }
    }

    /// Gráfico de barras simples da evolução do nível de risco.
    /// Implementado sem dependências para funcionar em qualquer versão de iOS.
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Evolução")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            let recent = Array(coordinator.history.prefix(14).reversed())

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(recent) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: item.level))
                            .frame(height: barHeight(for: item.level))
                        Text(shortDate(item.date))
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .frame(height: 100, alignment: .bottom)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ assessment: RiskAssessment) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color(for: assessment.level))
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(assessment.level.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color(for: assessment.level))
                Text(assessment.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f%%", assessment.confidence * 100))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                Text(assessment.provenance.rotulo)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func barHeight(for level: RiskLevel) -> CGFloat {
        switch level {
        case .low: return 30
        case .medium: return 60
        case .high: return 90
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }

    private func color(for level: RiskLevel) -> Color {
        switch level {
        case .low: return Theme.low
        case .medium: return Theme.medium
        case .high: return Theme.high
        }
    }
}
