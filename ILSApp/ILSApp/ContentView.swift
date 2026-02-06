import SwiftUI
import ILSShared

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSidebar = false

    private var selectedTab: SidebarItem {
        switch appState.selectedTab.lowercased() {
        case "dashboard":
            return .dashboard
        case "sessions":
            return .sessions
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
            return .dashboard
        }
    }

    var body: some View {
        NavigationStack {
            detailView
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showingSidebar = true }) {
                            Image(systemName: "sidebar.left")
                                .imageScale(.large)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("sidebarButton")
                        .accessibilityLabel("Open Sidebar")
                    }
                }
                .overlay(alignment: .topLeading) {
                    Button(action: { showingSidebar = true }) {
                        Color.clear
                            .frame(width: 60, height: 60)
                    }
                    .accessibilityIdentifier("sidebarTapTarget")
                    .accessibilityLabel("Open Sidebar")
                    .offset(x: 4, y: -8)
                }
                .safeAreaInset(edge: .top) {
                    if !appState.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                            Text("No connection to backend")
                                .font(ILSTheme.captionFont)
                            Spacer()
                            if UserDefaults.standard.bool(forKey: "hasConnectedBefore") {
                                Button("Retry") {
                                    Task {
                                        try? await appState.apiClient.healthCheck()
                                    }
                                }
                                .font(ILSTheme.captionFont.weight(.semibold))
                                .foregroundColor(ILSTheme.accent)
                            } else {
                                Button("Configure") {
                                    appState.showOnboarding = true
                                }
                                .font(ILSTheme.captionFont.weight(.semibold))
                                .foregroundColor(ILSTheme.accent)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, ILSTheme.spacingM)
                        .padding(.vertical, ILSTheme.spacingS)
                        .background(ILSTheme.error.opacity(0.9))
                    }
                }
                .sheet(isPresented: $showingSidebar) {
                    NavigationStack {
                        SidebarView(selectedItem: Binding(
                            get: { selectedTab },
                            set: { newItem in
                                switch newItem {
                                case .dashboard:
                                    appState.selectedTab = "dashboard"
                                case .sessions:
                                    appState.selectedTab = "sessions"
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
                                showingSidebar = false
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
                            .overlay(alignment: .topTrailing) {
                                Button(action: { showingSidebar = false }) {
                                    Color.clear
                                        .frame(width: 80, height: 44)
                                }
                                .accessibilityIdentifier("doneTapTarget")
                                .accessibilityLabel("Done")
                                .offset(x: -16, y: 12)
                            }
                    }
                    .presentationBackground(Color.black)
                }
        }
        .background(ILSTheme.background)
        .tint(ILSTheme.accent)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
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
