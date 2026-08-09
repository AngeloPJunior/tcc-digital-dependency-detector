import SwiftUI

@main
struct DigitalDependencyApp: App {

    @StateObject private var coordinator = AssessmentCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Avaliação", systemImage: "waveform.path.ecg") }

            HistoryView()
                .tabItem { Label("Histórico", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}
