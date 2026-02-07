import SwiftUI
import ILSShared

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            .tag("dashboard")

            NavigationStack {
                SessionsListView()
            }
            .tabItem {
                Label("Sessions", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag("sessions")

            NavigationStack {
                ProjectsListView()
            }
            .tabItem {
                Label("Projects", systemImage: "folder.fill")
            }
            .tag("projects")

            NavigationStack {
                SystemMonitorView()
            }
            .tabItem {
                Label("System", systemImage: "gauge.with.dots.needle.33percent")
            }
            .tag("system")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag("settings")
        }
        .tint(.white)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .connectionBanner(isConnected: appState.isConnected)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
