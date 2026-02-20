import AppKit
import Combine
import ILSShared
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar Section

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case system = "System Monitor"
    case browser = "Browse"
    case teams = "Agent Teams"
    case fleet = "Fleet"
    case themes = "Themes"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .system: return "gauge.with.dots.needle.33percent"
        case .browser: return "square.grid.2x2.fill"
        case .teams: return "person.3.fill"
        case .fleet: return "server.rack"
        case .themes: return "paintpalette.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var screen: ActiveScreen {
        switch self {
        case .home: return .home
        case .system: return .system
        case .browser: return .browser
        case .teams: return .teams
        case .fleet: return .fleet
        case .themes: return .themes
        case .settings: return .settings
        }
    }
}

// MARK: - Mac Content View

struct MacContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @StateObject private var sessionsViewModel = SessionsViewModel()
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    @State private var selectedSection: SidebarSection? = .home
    @State private var activeScreen: ActiveScreen = .home
    @State private var expandedProjects: Set<String> = []
    @State private var sessionToRename: ChatSession?
    @State private var renameText: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar (left column)
            sidebarContent
                .navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 400)
        } content: {
            // Middle column (sessions list or secondary content)
            middleContent
                .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 500)
        } detail: {
            // Detail view (main content)
            detailContent
                .navigationSplitViewColumnWidth(min: 600, ideal: 800)
        }
        .task {
            sessionsViewModel.configure(client: appState.apiClient)
            await sessionsViewModel.loadProjectGroups()

            // Index sessions in Spotlight after loading
            let allSessions = sessionsViewModel.projectSessions.values.flatMap { $0 }
            SpotlightIndexer.shared.indexSessions(Array(allSessions))
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let intent else { return }
            handleNavigationIntent(intent)
        }
        // Observe menu bar command notifications
        .onReceive(NotificationCenter.default.publisher(for: .ilsCreateNewSession)) { _ in
            let newSession = ChatSession(name: "New Session", model: "sonnet")
            activeScreen = .chat(newSession)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ilsNavigateTo)) { notification in
            guard let target = notification.object as? String else { return }
            switch target {
            case "home": handleNavigationIntent(.home)
            case "sessions": handleNavigationIntent(.home)
            case "browser": handleNavigationIntent(.browser)
            case "system": handleNavigationIntent(.system)
            case "settings": handleNavigationIntent(.settings)
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ilsRenameSession)) { _ in
            if case .chat(let session) = activeScreen {
                renameText = session.name ?? ""
                sessionToRename = session
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ilsForkSession)) { _ in
            if case .chat(let session) = activeScreen {
                Task {
                    if let forked = await sessionsViewModel.forkSession(session) {
                        activeScreen = .chat(forked)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ilsExportSession)) { _ in
            if case .chat(let session) = activeScreen {
                exportSessionAsJSON(session)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ilsDeleteSession)) { _ in
            if case .chat(let session) = activeScreen {
                Task {
                    await sessionsViewModel.deleteSession(session)
                    activeScreen = .home
                }
            }
        }
        .onKeyPress(.init("/")) {
            isSearchFocused = true
            return .handled
        }
        .sheet(isPresented: $appState.showOnboarding) {
            ServerSetupSheet()
                .environmentObject(appState)
                .environment(\.theme, theme)
        }
        .alert("Rename Session", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("Session name", text: $renameText)
            Button("Cancel", role: .cancel) { sessionToRename = nil }
            Button("Rename") {
                if let session = sessionToRename {
                    Task { await sessionsViewModel.renameSession(session, to: renameText) }
                }
                sessionToRename = nil
            }
        } message: {
            Text("Enter a new name for this session")
        }
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            // Header
            Section {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("ILS")
                        .font(.system(size: theme.fontTitle1, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)

                    HStack(spacing: theme.spacingXS) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? appState.serverURL : "Disconnected")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, theme.spacingSM)
                .listRowBackground(theme.bgSidebar)
            }

            // Navigation sections
            Section {
                ForEach(filteredSections) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
            }
            .listRowBackground(theme.bgSidebar)
        }
        .listStyle(.sidebar)
        .background(theme.bgSidebar)
        .onChange(of: selectedSection) { _, newSection in
            if let section = newSection {
                activeScreen = section.screen
            }
        }
    }

    // MARK: - Middle Content (Sessions List)

    private var middleContent: some View {
        Group {
            if case .home = activeScreen {
                sessionsListView
            } else if case .chat = activeScreen {
                sessionsListView
            } else {
                // Empty middle column for other sections
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.bgPrimary)
            }
        }
    }

    private var sessionsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("SESSIONS")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(sessionsViewModel.totalCount)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Search bar
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                TextField("Search sessions...", text: $sessionsViewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .focused($isSearchFocused)
                if !sessionsViewModel.searchText.isEmpty {
                    Button {
                        sessionsViewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Session list (project groups loaded from backend)
            List {
                if sessionsViewModel.isLoading && sessionsViewModel.projectGroups.isEmpty {
                    loadingView
                } else if sessionsViewModel.filteredProjectGroups.isEmpty {
                    emptyView
                } else {
                    ForEach(sessionsViewModel.filteredProjectGroups) { group in
                        projectGroup(group: group)
                    }
                }
            }
            .listStyle(.sidebar)
            .refreshable {
                await sessionsViewModel.loadProjectGroups()
            }

            Divider()

            // New Session button
            Button {
                let newSession = ChatSession(name: "New Session", model: "sonnet")
                activeScreen = .chat(newSession)
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Session")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
        }
        .background(theme.bgPrimary)
    }

    // MARK: - Detail Content (Main View)

    @ViewBuilder
    private var detailContent: some View {
        switch activeScreen {
        case .home:
            HomeView(
                onSessionSelected: { session in
                    activeScreen = .chat(session)
                },
                onNavigate: { screen in
                    handleNavigationIntent(screen)
                }
            )
        case .chat(let session):
            ChatView(session: session)
        case .system:
            SystemMonitorView()
        case .settings:
            SettingsView()
        case .browser:
            BrowserView()
        case .teams:
            AgentTeamsListView(apiClient: appState.apiClient)
        case .fleet:
            FleetManagementView()
        case .themes:
            ThemesListView()
        }
    }

    // MARK: - Project Group

    @ViewBuilder
    private func projectGroup(group: ProjectGroupInfo) -> some View {
        let name = group.name
        let sessions = sessionsViewModel.projectSessions[name] ?? []
        let isLoadingSessions = sessionsViewModel.loadingProjects.contains(name)

        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProjects.contains(name) },
                set: { isExpanded in
                    if isExpanded {
                        expandedProjects.insert(name)
                        // Lazy-load sessions when first expanded
                        if sessionsViewModel.projectSessions[name] == nil {
                            Task { await sessionsViewModel.loadSessionsForProject(name) }
                        }
                    } else {
                        expandedProjects.remove(name)
                    }
                }
            )
        ) {
            if isLoadingSessions && sessions.isEmpty {
                HStack(spacing: theme.spacingSM) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.accent)
                    Text("Loading...")
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.vertical, theme.spacingXS)
            } else {
                ForEach(sessions) { session in
                    Button {
                        activeScreen = .chat(session)
                    } label: {
                        MacSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            activeScreen = .chat(session)
                        } label: {
                            Label("Open Session", systemImage: "bubble.left.and.bubble.right")
                        }

                        Button {
                            WindowManager.shared.openSessionWindow(session)
                        } label: {
                            Label("Open in New Window", systemImage: "macwindow.badge.plus")
                        }

                        Divider()

                        Button {
                            renameText = session.name ?? ""
                            sessionToRename = session
                        } label: {
                            Label("Rename...", systemImage: "pencil")
                        }

                        Button {
                            Task {
                                if let forked = await sessionsViewModel.forkSession(session) {
                                    activeScreen = .chat(forked)
                                }
                            }
                        } label: {
                            Label("Fork Session", systemImage: "arrow.branch")
                        }

                        Divider()

                        Button {
                            exportSessionAsJSON(session)
                        } label: {
                            Label("Export as JSON...", systemImage: "curlybraces")
                        }

                        Button {
                            exportSessionAsMarkdown(session)
                        } label: {
                            Label("Export as Markdown...", systemImage: "doc.text")
                        }

                        Divider()

                        Button(role: .destructive) {
                            Task {
                                await sessionsViewModel.deleteSession(session)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Load more button if there are more sessions
                if sessionsViewModel.projectHasMore[name] == true {
                    Button {
                        Task { await sessionsViewModel.loadMoreForProject(name) }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            Text("Load more...")
                                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.vertical, theme.spacingXS)
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.entityProject)
                Text(name)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(group.sessionCount)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading sessions...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(sessionsViewModel.searchText.isEmpty ? "No sessions yet" : "No matching sessions")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    // MARK: - Helpers

    private var filteredSections: [SidebarSection] {
        SidebarSection.allCases.filter { section in
            if section == .teams {
                return enableAgentTeams
            }
            return true
        }
    }


    private func exportSessionAsJSON(_ session: ChatSession) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(session.name ?? "session").json"
        panel.canCreateDirectories = true
        panel.title = "Export Session as JSON"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(session) {
                    try? data.write(to: url)
                }
            }
        }
    }

    private func exportSessionAsMarkdown(_ session: ChatSession) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(session.name ?? "session").md"
        panel.canCreateDirectories = true
        panel.title = "Export Session as Markdown"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                var md = "# Session: \(session.name ?? "Unnamed")\n\n"
                md += "- **Model:** \(session.model)\n"
                md += "- **Status:** \(session.status.rawValue)\n"
                md += "- **Created:** \(session.createdAt.formatted())\n"
                md += "- **Last Active:** \(session.lastActiveAt.formatted())\n"
                md += "- **Messages:** \(session.messageCount)\n"
                if let cost = session.totalCostUSD {
                    md += "- **Cost:** $\(String(format: "%.4f", cost))\n"
                }
                if let projectName = session.projectName {
                    md += "- **Project:** \(projectName)\n"
                }
                md += "\n---\n"
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func handleNavigationIntent(_ intent: ActiveScreen) {
        // Sync sidebar selection for non-chat screens
        switch intent {
        case .home: selectedSection = .home
        case .system: selectedSection = .system
        case .settings: selectedSection = .settings
        case .browser: selectedSection = .browser
        case .teams: selectedSection = .teams
        case .fleet: selectedSection = .fleet
        case .themes: selectedSection = .themes
        case .chat: selectedSection = .home
        }
        activeScreen = intent
        appState.navigationIntent = nil
    }
}

// MARK: - Mac Session Row

struct MacSessionRow: View {
    let session: ChatSession
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let firstPrompt = session.firstPrompt {
                    Text(firstPrompt)
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.messageCount > 0 ? "\(session.messageCount)" : "")
                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, theme.spacingXS)
    }
}

#Preview {
    MacContentView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
