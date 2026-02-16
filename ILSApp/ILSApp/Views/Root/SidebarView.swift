import SwiftUI
import ILSShared

struct SidebarView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var sessionsViewModel = SessionsViewModel()
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    @Binding var activeScreen: ActiveScreen
    @Binding var isSidebarOpen: Bool
    var onSessionSelected: (ChatSession) -> Void

    @State private var expandedProjects: Set<String> = []
    @State private var sessionToRename: ChatSession?
    @State private var renameText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider().overlay(theme.divider)

            // Navigation items
            navigationItems

            Divider().overlay(theme.divider)
                .padding(.top, theme.spacingSM)

            // Sessions section
            sessionsSection

            Spacer(minLength: 0)

            Divider().overlay(theme.divider)

            // Bottom actions
            bottomActions
        }
        .background(theme.bgSidebar)
        .task {
            sessionsViewModel.configure(client: appState.apiClient)
            await sessionsViewModel.loadSessions(refresh: true)
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

    // MARK: - Header

    private var headerSection: some View {
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
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingLG)
        .padding(.bottom, theme.spacingMD)
    }

    // MARK: - Navigation Items

    private var navigationItems: some View {
        VStack(spacing: theme.spacingXS) {
            sidebarNavItem(icon: "house.fill", label: "Home", screen: .home)
            sidebarNavItem(icon: "gauge.with.dots.needle.33percent", label: "System Monitor", screen: .system)
            sidebarNavItem(icon: "square.grid.2x2.fill", label: "Browse", screen: .browser)
            if enableAgentTeams {
                sidebarNavItem(icon: "person.3.fill", label: "Agent Teams", screen: .teams)
            }
            #if DEBUG
            sidebarNavItem(icon: "server.rack", label: "Fleet", screen: .fleet)
            #endif
            sidebarNavItem(icon: "gearshape.fill", label: "Settings", screen: .settings)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.top, theme.spacingMD)
    }

    // MARK: - Sessions Section

    private var sessionsSection: some View {
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
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .accessibilityLabel("Search sessions")
                if !sessionsViewModel.searchText.isEmpty {
                    Button {
                        sessionsViewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Session list
            ScrollView {
                LazyVStack(spacing: 2) {
                    if sessionsViewModel.isLoading && sessionsViewModel.sessions.isEmpty {
                        loadingView
                    } else if sessionsViewModel.filteredSessions.isEmpty {
                        emptyView
                    } else {
                        ForEach(sessionsViewModel.groupedSessions, id: \.key) { project, sessions in
                            projectGroup(name: project, sessions: sessions)
                        }
                    }
                }
                .padding(.horizontal, theme.spacingSM)
            }
            .refreshable {
                await sessionsViewModel.loadSessions(refresh: true)
            }
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
                SidebarSessionRow(session: session) {
                    onSessionSelected(session)
                    isSidebarOpen = false
                }
                .contextMenu {
                    Button {
                        renameText = session.name ?? ""
                        sessionToRename = session
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        SessionExporter.share(session)
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
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.entityProject)
                Text(name)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(sessions.count)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, theme.spacingXS)
        }
        .tint(theme.textSecondary)
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

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        Button {
            let newSession = ChatSession(name: "New Session", model: "sonnet")
            onSessionSelected(newSession)
            isSidebarOpen = false
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
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingMD)
        .accessibilityLabel("Create new chat session")
        .accessibilityHint("Opens a new conversation with Claude")
    }

    // MARK: - Navigation Item

    private func sidebarNavItem(icon: String, label: String, screen: ActiveScreen) -> some View {
        let isActive = isScreenActive(screen)

        return Button {
            activeScreen = screen
            isSidebarOpen = false
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                Spacer()
            }
            .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM + 4)
            .frame(minHeight: 44)
            .background(isActive ? theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(label)
        .accessibilityHint("Navigate to \(label)")
    }

    // MARK: - Helpers

    private func isScreenActive(_ screen: ActiveScreen) -> Bool {
        switch (activeScreen, screen) {
        case (.home, .home), (.system, .system), (.settings, .settings), (.browser, .browser), (.teams, .teams), (.fleet, .fleet):
            return true
        case (.chat, .chat):
            return true
        default:
            return false
        }
    }

}
