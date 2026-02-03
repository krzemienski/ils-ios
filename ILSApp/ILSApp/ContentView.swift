import SwiftUI
import ILSShared

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSidebar = false

    private var selectedTab: SidebarItem {
        switch appState.selectedTab.lowercased() {
        case "sessions":
            return .sessions
        case "templates":
            return .templates
        case "projects":
            return .projects
        case "plugins":
            return .plugins
        case "mcp":
            return .mcp
        case "skills":
            return .skills
        case "settings":
            return .settings
        default:
            return .sessions
        }
    }

    var body: some View {
        NavigationStack {
            detailView
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingSidebar = true }) {
                            Image(systemName: "sidebar.left")
                        }
                        .accessibilityIdentifier("sidebarButton")
                    }
                }
                .sheet(isPresented: $showingSidebar) {
                    NavigationStack {
                        SidebarView(selectedItem: Binding(
                            get: { selectedTab },
                            set: { newItem in
                                switch newItem {
                                case .sessions:
                                    appState.selectedTab = "sessions"
                                case .templates:
                                    appState.selectedTab = "templates"
                                case .projects:
                                    appState.selectedTab = "projects"
                                case .plugins:
                                    appState.selectedTab = "plugins"
                                case .mcp:
                                    appState.selectedTab = "mcp"
                                case .skills:
                                    appState.selectedTab = "skills"
                                case .settings:
                                    appState.selectedTab = "settings"
                                }
                            }
                        ))
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingSidebar = false
                                    }
                                    .accessibilityIdentifier("sidebarDoneButton")
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
        case .templates:
            TemplatesListView()
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
    case templates = "Templates"
    case projects = "Projects"
    case plugins = "Plugins"
    case mcp = "MCP Servers"
    case skills = "Skills"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .templates: return "doc.text.magnifyingglass"
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
