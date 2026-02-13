import SwiftUI
import ILSShared

// MARK: - Active Screen (macOS)

enum MacActiveScreen: Hashable {
    case home
    case chat(ChatSession)
    case system
    case settings
    case browser
    case teams
    case fleet
}

// MARK: - Sidebar Section

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case system = "System Monitor"
    case browser = "Browse"
    case teams = "Agent Teams"
    case fleet = "Fleet"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .system: return "gauge.with.dots.needle.33percent"
        case .browser: return "square.grid.2x2.fill"
        case .teams: return "person.3.fill"
        case .fleet: return "server.rack"
        case .settings: return "gearshape.fill"
        }
    }

    var screen: MacActiveScreen {
        switch self {
        case .home: return .home
        case .system: return .system
        case .browser: return .browser
        case .teams: return .teams
        case .fleet: return .fleet
        case .settings: return .settings
        }
    }
}

// MARK: - Mac Content View

struct MacContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @StateObject private var sessionsViewModel = SessionsViewModel()
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    @State private var selectedSection: SidebarSection? = .home
    @State private var activeScreen: MacActiveScreen = .home
    @State private var searchText: String = ""
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
            await sessionsViewModel.loadSessions(refresh: true)
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let intent else { return }
            handleNavigationIntent(intent)
        }
        .onKeyPress(.init("/", modifiers: .command)) {
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
                    Task {
                        let _: APIResponse<ChatSession> = try await appState.apiClient.renameSession(id: session.id, name: renameText)
                        await sessionsViewModel.loadSessions(refresh: true)
                    }
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
                        .font(.system(size: theme.fontTitle1, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.accent)

                    HStack(spacing: theme.spacingXS) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? appState.serverURL : "Disconnected")
                            .font(.system(size: theme.fontCaption))
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
                        .font(.system(size: theme.fontBody))
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
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(sessionsViewModel.sessions.count)")
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Search bar
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textPrimary)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: theme.fontCaption))
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

            // Session list
            List {
                if sessionsViewModel.isLoading && sessionsViewModel.sessions.isEmpty {
                    loadingView
                } else if filteredSessions.isEmpty {
                    emptyView
                } else {
                    ForEach(groupedSessions, id: \.key) { project, sessions in
                        projectGroup(name: project, sessions: sessions)
                    }
                }
            }
            .listStyle(.sidebar)
            .refreshable {
                await sessionsViewModel.loadSessions(refresh: true)
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
                        .font(.system(size: theme.fontBody, weight: .semibold))
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
                    handleIOSNavigationIntent(screen)
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
        }
    }

    // MARK: - Project Group

    @ViewBuilder
    private func projectGroup(name: String, sessions: [ChatSession]) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProjects.contains(name) },
                set: { isExpanded in
                    if isExpanded {
                        expandedProjects.insert(name)
                    } else {
                        expandedProjects.remove(name)
                    }
                }
            )
        ) {
            ForEach(sessions) { session in
                Button {
                    activeScreen = .chat(session)
                } label: {
                    MacSessionRow(session: session)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        renameText = session.name ?? ""
                        sessionToRename = session
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        exportSession(session)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        Task {
                            await sessionsViewModel.deleteSession(session)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.entityProject)
                Text(name)
                    .font(.system(size: theme.fontCaption, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(sessions.count)")
                    .font(.system(size: theme.fontCaption, design: .monospaced))
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
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty ? "No sessions yet" : "No matching sessions")
                .font(.system(size: theme.fontCaption))
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

    private var filteredSessions: [ChatSession] {
        guard !searchText.isEmpty else { return sessionsViewModel.sessions }
        let query = searchText.lowercased()
        return sessionsViewModel.sessions.filter { session in
            (session.name?.lowercased().contains(query) ?? false) ||
            (session.projectName?.lowercased().contains(query) ?? false) ||
            (session.firstPrompt?.lowercased().contains(query) ?? false)
        }
    }

    private var groupedSessions: [(key: String, value: [ChatSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.projectName ?? "Ungrouped"
        }
        return grouped.sorted { group1, group2 in
            let latest1 = group1.value.map(\.lastActiveAt).max() ?? .distantPast
            let latest2 = group2.value.map(\.lastActiveAt).max() ?? .distantPast
            return latest1 > latest2
        }
    }

    private func exportSession(_ session: ChatSession) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let text = "Session: \(session.name ?? "Unnamed")\nModel: \(session.model)\nCreated: \(formatter.string(from: session.createdAt))\nMessages: \(session.messageCount)"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(session.name ?? "session").txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func handleNavigationIntent(_ intent: ActiveScreen) {
        switch intent {
        case .home:
            selectedSection = .home
            activeScreen = .home
        case .system:
            selectedSection = .system
            activeScreen = .system
        case .settings:
            selectedSection = .settings
            activeScreen = .settings
        case .browser:
            selectedSection = .browser
            activeScreen = .browser
        case .teams:
            selectedSection = .teams
            activeScreen = .teams
        case .fleet:
            selectedSection = .fleet
            activeScreen = .fleet
        case .chat(let session):
            selectedSection = .home
            activeScreen = .chat(session)
        }
        appState.navigationIntent = nil
    }

    private func handleIOSNavigationIntent(_ screen: ActiveScreen) {
        // Convert iOS ActiveScreen to macOS MacActiveScreen
        handleNavigationIntent(screen)
    }
}

// MARK: - Mac Session Row

struct MacSessionRow: View {
    let session: ChatSession
    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let firstPrompt = session.firstPrompt {
                    Text(firstPrompt)
                        .font(.system(size: theme.fontCaption - 1))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.messageCount > 0 ? "\(session.messageCount)" : "")
                .font(.system(size: theme.fontCaption - 1, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, theme.spacingXS)
    }
}

#Preview {
    MacContentView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environment(\.theme, ObsidianTheme())
}
