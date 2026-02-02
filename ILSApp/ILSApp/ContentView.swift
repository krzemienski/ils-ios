import SwiftUI
import ILSShared

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarItem = .sessions
    @State private var showingSidebar = false

    var body: some View {
        NavigationStack {
            detailView
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingSidebar = true }) {
                            Image(systemName: "sidebar.left")
                        }
                    }
                }
                .sheet(isPresented: $showingSidebar) {
                    NavigationStack {
                        SidebarView(selectedItem: $selectedTab)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingSidebar = false
                                    }
                                }
                            }
                    }
                }
        }
        .tint(ILSTheme.accent)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .sessions:
            SessionsListView()
        case .projects:
            ProjectsListView()
        case .plugins:
            PluginsListView()
        case .mcp:
            MCPServerListView()
        case .skills:
            SkillsListView()
        case .settings:
            SettingsView()
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case projects = "Projects"
    case plugins = "Plugins"
    case mcp = "MCP Servers"
    case skills = "Skills"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
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
