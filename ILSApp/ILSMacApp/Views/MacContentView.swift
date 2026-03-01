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
    case hostProfiles = "Host Profiles"
    case backends = "Backends"
    case themes = "Themes"
    case hooks = "Hooks"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .system: return "gauge.with.dots.needle.33percent"
        case .browser: return "square.grid.2x2.fill"
        case .teams: return "person.3.fill"
        case .hostProfiles: return "desktopcomputer"
        case .backends: return "server.rack"
        case .themes: return "paintpalette.fill"
        case .hooks: return "bolt.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var screen: ActiveScreen {
        switch self {
        case .home: return .home
        case .system: return .system
        case .browser: return .browser
        case .teams: return .teams
        case .hostProfiles: return .hostProfiles
        case .backends: return .backends
        case .themes: return .themes
        case .hooks: return .hooks
        case .settings: return .settings
        }
    }
}

// MARK: - Mac Content View
// NAV-MED-2: macOS uses NavigationSplitView (3-column) — platform-appropriate pattern.
// Sidebar + list + detail layout matches macOS HIG. ActiveScreen enum shared with iOS
// enables deep link handling across platforms via the same route definitions.
struct MacContentView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var sessionsViewModel = SessionsViewModel()
    @State private var activityFeedVM = ActivityFeedViewModel()
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    @State private var selectedSection: SidebarSection? = .home
    @State private var activeScreen: ActiveScreen = .home
    /// Initial segment selection forwarded to ``BrowserView`` when navigation is triggered via deep link.
    @State private var browserSegment: BrowserSegment = .mcp

    /// Comma-separated project names whose DisclosureGroups are expanded, persisted across app launches.
    @AppStorage("macExpandedProjects") private var expandedProjectsStorage: String = ""

    /// Computed Set<String> backed by @AppStorage for persistence across navigation and restarts.
    private var expandedProjects: Set<String> {
        get {
            guard !expandedProjectsStorage.isEmpty else { return [] }
            return Set(expandedProjectsStorage.components(separatedBy: ",").filter { !$0.isEmpty })
        }
        nonmutating set {
            expandedProjectsStorage = newValue.sorted().joined(separator: ",")
        }
    }

    @State private var sessionToRename: ChatSession?
    @State private var renameText: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var appState = appState
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
            NavigationStack {
                detailContent
            }
            .navigationSplitViewColumnWidth(min: 600, ideal: 800)
        }
        .task {
            sessionsViewModel.configure(client: appState.apiClient)
            activityFeedVM.configure(client: appState.apiClient)
            await sessionsViewModel.loadProjectGroups()

            // Load custom themes from backend on cold start (parity with iOS SidebarRootView)
            await themeManager.loadAndRegisterCustomThemes(client: appState.apiClient)

            // Index sessions in Spotlight after loading
            let allSessions = sessionsViewModel.projectSessions.values.flatMap { $0 }
            SpotlightIndexer.shared.indexSessions(Array(allSessions))
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let intent else { return }
            handleNavigationIntent(intent)
        }
        .onChange(of: appState.serverURL) { _, _ in
            sessionsViewModel.configure(client: appState.apiClient)
            activityFeedVM.configure(client: appState.apiClient)
            Task {
                await sessionsViewModel.loadProjectGroups()
                await themeManager.loadAndRegisterCustomThemes(client: appState.apiClient)
            }
        }
        .onChange(of: activeScreen) { _, newScreen in
            switch newScreen {
            case .home, .chat:
                columnVisibility = .all
            default:
                columnVisibility = .doubleColumn
            }
        }
        // Observe menu bar command notifications
        .onReceive(NotificationCenter.default.publisher(for: .ilsCreateNewSession)) { _ in
            let newSession = ChatSession(name: "New Session", model: AppConstants.defaultModel)
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
        // A4: Handle notification tap from NotificationManager — navigate to the session
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSessionFromNotification"))) { notification in
            guard let sessionId = notification.object as? UUID else { return }
            Task {
                do {
                    let response: APIResponse<ChatSession> = try await appState.apiClient.get("/sessions/\(sessionId.uuidString)")
                    if let session = response.data {
                        activeScreen = .chat(session)
                        selectedSection = .home
                    }
                } catch {
                    // Session not found or network error — ignore and let app stay on current screen
                }
            }
        }
        .onKeyPress(.init("/")) {
            isSearchFocused = true
            return .handled
        }
        .sheet(isPresented: $appState.showOnboarding) {
            ServerSetupSheet()
                .environment(appState)
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Connection status")
                    .accessibilityValue(appState.isConnected ? appState.serverURL : "Disconnected")

                    // Active host indicator
                    if let hostName = appState.activeHostName {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                            Text(hostName)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
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
        @Bindable var sessionsViewModel = sessionsViewModel
        return VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("SESSIONS")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                if !sessionsViewModel.debouncedSearchText.isEmpty {
                    Text("\(sessionsViewModel.filteredCount) of \(sessionsViewModel.totalCount)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    Text("\(sessionsViewModel.totalCount)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
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
                    .onChange(of: sessionsViewModel.searchText) { _, _ in
                        sessionsViewModel.scheduleSearchDebounce()
                    }
                if !sessionsViewModel.searchText.isEmpty {
                    Button {
                        sessionsViewModel.clearSearch()
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
                let newSession = ChatSession(name: "New Session", model: AppConstants.defaultModel)
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
                sessionsVM: sessionsViewModel,
                onSessionSelected: { session in
                    activeScreen = .chat(session)
                },
                onNavigate: { screen in
                    handleNavigationIntent(screen)
                }
            )
        case .chat(let session):
            MacChatView(session: session)
        case .system:
            SystemMonitorView()
        case .settings:
            MacSettingsView()
        case .browser:
            BrowserView(initialSegment: browserSegment)
                .id(browserSegment)
        case .teams:
            AgentTeamsListView(apiClient: appState.apiClient)
        case .hostProfiles:
            HostProfilesView()
        case .themes:
            ThemesListView()
        case .hooks:
            HooksManagementView()
        case .activityFeed:
            ActivityFeedView(viewModel: activityFeedVM) { sessionId in
                if let uuid = UUID(uuidString: sessionId) {
                    activeScreen = .chat(ChatSession(id: uuid, name: "Session"))
                }
            }
        case .backends:
            BackendConnectionsView()
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

    /// Sections filtered by feature flags. Only recalculates when
    /// `enableAgentTeams` changes (not on every body evaluation).
    private var filteredSections: [SidebarSection] {
        if enableAgentTeams {
            return SidebarSection.allCases
        }
        return SidebarSection.allCases.filter { $0 != .teams }
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
                do {
                    let data = try encoder.encode(session)
                    try data.write(to: url)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not save JSON: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
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
                do {
                    try md.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not save Markdown: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private func handleNavigationIntent(_ intent: ActiveScreen) {
        // Consume browser segment intent BEFORE setting activeScreen so that
        // BrowserView receives the correct initialSegment and a fresh .id().
        if intent == .browser, let segmentIntent = appState.browserSegmentIntent {
            browserSegment = segmentIntent
            appState.browserSegmentIntent = nil
        }

        // Sync sidebar selection for non-chat screens
        switch intent {
        case .home: selectedSection = .home
        case .system: selectedSection = .system
        case .settings: selectedSection = .settings
        case .browser: selectedSection = .browser
        case .teams: selectedSection = .teams
        case .hostProfiles: selectedSection = .hostProfiles
        case .backends: selectedSection = .backends
        case .themes: selectedSection = .themes
        case .hooks: selectedSection = .hooks
        case .chat: selectedSection = .home
        case .activityFeed: selectedSection = .home
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
        .environment(AppState())
        .environment(ThemeManager())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
