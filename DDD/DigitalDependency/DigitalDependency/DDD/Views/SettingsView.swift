import SwiftUI

struct SettingsView: View {
    @State private var marcosCapturados = 0
    @EnvironmentObject private var coordinator: AssessmentCoordinator

    @State private var selectedProfile: SimulatedUsageDataSource.Profile = .moderate
    @State private var notificationsEnabled = false
    @State private var reminderHour = 21

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        dataSourceSection
                        diagnosticoSection
                        notificationSection
                        aboutSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Configurações")
        }
        .task {
            marcosCapturados = ThresholdEventStore.shared.totalMarcos()
            notificationsEnabled = await NotificationService.shared.authorizationStatus() == .authorized
        }
        .sheet(isPresented: $mostrandoSelecao) {
                    if #available(iOS 16.0, *) {
                        AppSelectionView().environmentObject(coordinator)
                    }
                }
    }

    // MARK: - Fonte de dados

    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Fonte de dados")

            Text("Modo de demonstração usa dados sintéticos reprodutíveis. O modo dispositivo requer autorização de Tempo de Uso.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            Picker("Perfil simulado", selection: $selectedProfile) {
                Text("Equilibrado").tag(SimulatedUsageDataSource.Profile.balanced)
                Text("Moderado").tag(SimulatedUsageDataSource.Profile.moderate)
                Text("Compulsivo").tag(SimulatedUsageDataSource.Profile.compulsive)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedProfile) { _, newValue in
                coordinator.setDataSource(SimulatedUsageDataSource(profile: newValue))
            }

            Button {
                Task { await activateScreenTime() }
            } label: {
                HStack {
                    Image(systemName: "iphone.gen3")
                    Text("Usar dados do dispositivo")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .padding(14)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    @State private var mostrandoSelecao = false

        private func activateScreenTime() async {
            #if canImport(FamilyControls)
            if #available(iOS 16.0, *) {
                let source = ScreenTimeUsageDataSource()
                do {
                    try await source.requestAuthorization()
                    mostrandoSelecao = true
                } catch {
                    // Autorização negada: mantém a fonte atual.
                }
            }
            #endif
        }

    // MARK: - Notificações

    private var diagnosticoSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Diagnóstico")

                HStack {
                    Text("Marcos capturados")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(marcosCapturados)")
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(marcosCapturados > 0 ? Theme.low : Theme.secondaryText)
                }

                Button("Atualizar") {
                    marcosCapturados = ThresholdEventStore.shared.totalMarcos()
                }
                .font(.caption)
                .foregroundStyle(Theme.accent)

                Text("Cada marco é um limiar de tempo atingido em um app monitorado. Zero significa que nenhum callback chegou ainda.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Notificações")

            Toggle("Lembrete diário", isOn: $notificationsEnabled)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.accent)
                .onChange(of: notificationsEnabled) { _, enabled in
                    Task {
                        if enabled {
                            let granted = await NotificationService.shared.requestAuthorization()
                            if granted {
                                await NotificationService.shared.scheduleDailyReminder(hour: reminderHour)
                            } else {
                                notificationsEnabled = false
                            }
                        } else {
                            NotificationService.shared.cancelDailyReminder()
                        }
                    }
                }

            if notificationsEnabled {
                Stepper("Horário: \(reminderHour)h", value: $reminderHour, in: 6...23)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .onChange(of: reminderHour) { _, hour in
                        Task { await NotificationService.shared.scheduleDailyReminder(hour: hour) }
                    }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sobre

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Sobre")

            Text("Todo o processamento é feito no dispositivo. Nenhum dado de uso é transmitido a servidores externos.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            Divider().background(Theme.secondaryText.opacity(0.2))

            Text("A classificação é orientativa e não constitui diagnóstico clínico. Os critérios de risco derivam de limiares comportamentais definidos na literatura, não de instrumento validado.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.primaryText)
    }
}
