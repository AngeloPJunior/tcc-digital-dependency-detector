import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings

/// Tela de seleção dos aplicativos a monitorar.
///
/// Usa o `FamilyActivityPicker` da Apple, que é obrigatório: não existe API
/// para listar os apps instalados. O usuário escolhe, e o app recebe apenas
/// tokens opacos — nunca nomes ou bundle IDs.
@available(iOS 16.0, *)
struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: AssessmentCoordinator

    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false
    @State private var mensagem: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    explicacao

                    Button {
                        isPickerPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "apps.iphone")
                            Text(selection.applicationTokens.isEmpty
                                 ? "Escolher aplicativos"
                                 : "\(selection.applicationTokens.count) app(s) selecionado(s)")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.primaryText)
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !selection.applicationTokens.isEmpty {
                        Button {
                            iniciarMonitoramento()
                        } label: {
                            Text("Iniciar monitoramento")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                    }

                    if let mensagem {
                        Text(mensagem)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Monitoramento")
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { selection = SelectionStore.shared.load() }
        }
    }

    private var explicacao: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Como funciona")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            Text("Escolha os aplicativos que deseja acompanhar. O sistema avisa este app quando o uso atinge determinados limiares de tempo, e a partir desses marcos os padrões de comportamento são estimados.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            Text("O app recebe apenas identificadores anônimos — nomes e conteúdos dos aplicativos nunca são acessados.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func iniciarMonitoramento() {
        SelectionStore.shared.save(selection)
        let source = ScreenTimeUsageDataSource()
        do {
            try source.startMonitoring(selection: selection)
            coordinator.setDataSource(source)
            mensagem = "Monitoramento ativo. Os dados começam a ser coletados conforme você usa os aplicativos."
        } catch {
            mensagem = "Não foi possível iniciar: \(error.localizedDescription)"
        }
    }
}

/// Persiste a seleção de apps no App Group, para que a extension também
/// consiga associar tokens a índices estáveis.
@available(iOS 16.0, *)
final class SelectionStore {
    static let shared = SelectionStore()

    private let key = "family_activity_selection"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: ThresholdEventStore.appGroupID) ?? .standard
    }

    func save(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: key)
        }
    }

    func load() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }
}
#endif
