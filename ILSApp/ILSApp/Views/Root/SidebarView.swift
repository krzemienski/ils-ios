import SwiftUI
import ILSShared

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @StateObject private var sessionsViewModel = SessionsViewModel()

    @Binding var activeScreen: ActiveScreen
    @Binding var isSidebarOpen: Bool
    var onSessionSelected: (ChatSession) -> Void

    @State private var searchText: String = ""
    @State private var expandedProjects: Set<String> = []

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
    }

    // MARK: - Header

    private var headerSection: some View {
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
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
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
                    } else if filteredSessions.isEmpty {
                        emptyView
                    } else {
                        ForEach(groupedSessions, id: \.key) { project, sessions in
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
                        // Rename — wired in Phase 3
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        // Export — wired in Phase 3
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

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        Button {
            // New session — wired in Phase 5
            isSidebarOpen = false
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
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingMD)
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
                    .font(.system(size: theme.fontBody))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: theme.fontBody))
                Spacer()
            }
            .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM + 4)
            .padding(.vertical, theme.spacingSM + 2)
            .background(isActive ? theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private func isScreenActive(_ screen: ActiveScreen) -> Bool {
        switch (activeScreen, screen) {
        case (.home, .home), (.system, .system), (.settings, .settings), (.browser, .browser):
            return true
        case (.chat, .chat):
            return true
        default:
            return false
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
        // Sort groups: most recently active first
        return grouped.sorted { group1, group2 in
            let latest1 = group1.value.map(\.lastActiveAt).max() ?? .distantPast
            let latest2 = group2.value.map(\.lastActiveAt).max() ?? .distantPast
            return latest1 > latest2
        }
    }
}
