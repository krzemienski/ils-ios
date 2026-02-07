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

// Keep SidebarItem for backward compatibility (used by SidebarView)
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case sessions = "Sessions"
    case projects = "Projects"
    case plugins = "Plugins"
    case mcp = "MCP Servers"
    case skills = "Skills"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .sessions: return "bubble.left.and.bubble.right"
        case .projects: return "folder"
        case .plugins: return "puzzlepiece.extension"
        case .mcp: return "server.rack"
        case .skills: return "star"
        case .settings: return "gear"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
