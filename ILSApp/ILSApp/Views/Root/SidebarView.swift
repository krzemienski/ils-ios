import SwiftUI
import ILSShared

/// Navigation sidebar for the iOS app providing access to screens and chat sessions.
///
/// Displays the app header with connection status, a list of primary navigation destinations,
/// a searchable session list grouped by recency, and a button to create new sessions.
/// Sessions are loaded via `SessionsViewModel` and can be renamed or deleted via context menus.
///
/// ## Topics
/// ### Bindings
/// - ``activeScreen`` - Currently active navigation destination
/// - ``isSidebarOpen`` - Whether the sidebar is currently visible
/// - ``onSessionSelected`` - Callback invoked when a session is tapped
///
/// ### View Sections
/// - ``headerSection`` - App logo and backend connection status indicator
/// - ``navigationItems`` - Primary navigation links (Home, System Monitor, Browse, Settings)
/// - ``sessionsSection`` - Searchable, time-grouped session list with pull-to-refresh
/// - ``bottomActions`` - "New Session" button that creates and opens a fresh session
///
/// ### Session Management
/// - ``timeGroup(label:sessions:)`` - Section header and rows for sessions in a time period
/// - ``loadingView`` - Skeleton placeholder shown while sessions are loading
/// - ``emptyView`` - Empty state shown when no sessions match the current search
///
/// Time groups are ordered: Today → Yesterday → This Week → Earlier.
struct SidebarView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    /// Shared sessions view model owned by SidebarRootView.
    @Bindable var sessionsViewModel: SessionsViewModel

    /// The currently active navigation destination.
    @Binding var activeScreen: ActiveScreen
    /// Whether the sidebar overlay is currently open.
    @Binding var isSidebarOpen: Bool
    /// Called when the user selects a session from the list.
    var onSessionSelected: (ChatSession) -> Void

    @FocusState private var isSearchFocused: Bool
    /// The session currently being renamed, if any.
    @State private var sessionToRename: ChatSession?
    @State private var showRenameAlert = false
    /// Editable text used in the rename alert.
    @State private var renameText: String = ""
    /// The session pending deletion confirmation, if any.
    @State private var sessionToDelete: ChatSession?
    @State private var showNewSessionSheet = false

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
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionView { session in
                showNewSessionSheet = false
                onSessionSelected(session)
                isSidebarOpen = false
            }
            .environment(appState)
            .environment(\.theme, theme)
        }
        // Sessions are loaded by SidebarRootView (shared VM)
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
        .alert("Delete Session", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task { await sessionsViewModel.deleteSession(session) }
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This will permanently delete this session and all its messages.")
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
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Active host")
                .accessibilityValue(hostName)
            } else if appState.isConnected {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text("Local")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Active host")
                .accessibilityValue("Local")
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingLG)
        .padding(.bottom, theme.spacingMD)
    }

    // MARK: - Navigation Items

    private var navigationItems: some View {
        VStack(spacing: 0) {
            // Primary screens group
            sidebarSectionHeader(title: "NAVIGATE")
            VStack(spacing: theme.spacingXS) {
                sidebarNavItem(icon: "house.fill", label: "Home", screen: .home)
                sidebarNavItem(icon: "gauge.with.dots.needle.33percent", label: "System Monitor", screen: .system)
                sidebarNavItem(icon: "square.grid.2x2.fill", label: "Browse", screen: .browser)
                if enableAgentTeams {
                    sidebarNavItem(icon: "person.3.fill", label: "Agent Teams", screen: .teams)
                }
            }

            Spacer().frame(height: theme.spacingMD)

            // Configuration screens group
            sidebarSectionHeader(title: "CONFIGURE")
            VStack(spacing: theme.spacingXS) {
                sidebarNavItem(icon: "desktopcomputer", label: "Host Profiles", screen: .hostProfiles)
                sidebarNavItem(icon: "arrow.triangle.branch", label: "Hooks", screen: .hooks)
                sidebarNavItem(icon: "paintpalette.fill", label: "Themes", screen: .themes)
                sidebarNavItem(icon: "gearshape.fill", label: "Settings", screen: .settings)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.top, theme.spacingMD)
    }

    // MARK: - Section Header

    private func sidebarSectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.spacingSM + 4)
            .padding(.bottom, theme.spacingXS)
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
                    .focused($isSearchFocused)
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
            .focusRing(isFocused: isSearchFocused, cornerRadius: theme.cornerRadiusSmall)
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Cache freshness indicator
            HStack {
                Spacer()
                CacheStatusView(lastUpdated: sessionsViewModel.lastUpdated)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Session list — List provides view recycling (UICollectionView-backed)
            // Section headers inside List are automatically pinned (sticky).
            List {
                if sessionsViewModel.isLoading && sessionsViewModel.sessions.isEmpty {
                    loadingView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else if sessionsViewModel.filteredSessions.isEmpty {
                    emptyView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else {
                    ForEach(sessionsViewModel.groupedSessionsByTime, id: \.key) { label, sessions in
                        timeGroup(label: label, sessions: sessions)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.bgSidebar)
            .refreshable {
                HapticManager.impact(.medium)
                await sessionsViewModel.loadSessions(refresh: true)
            }
        }
    }

    // MARK: - Time Group

    @ViewBuilder
    private func timeGroup(label: String, sessions: [ChatSession]) -> some View {
        Section {
            ForEach(sessions) { session in
                SidebarSessionRow(
                    session: session,
                    isActive: isSessionActive(session)
                ) {
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
                        sessionToDelete = session
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await sessionsViewModel.deleteSession(session)
                            HapticManager.notification(.success)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        renameText = session.name ?? ""
                        sessionToRename = session
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
            }
        } header: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "calendar")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text(label.uppercased())
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSidebar)
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(theme.bgTertiary)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 100, height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 60, height: 9)
                    }
                    Spacer()
                }
                .padding(.vertical, theme.spacingXS)
                .padding(.horizontal, theme.spacingSM)
            }
            .shimmer()
        }
        .padding(.vertical, theme.spacingSM)
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
            HapticManager.impact(.medium)
            showNewSessionSheet = true
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
            HapticManager.selection()
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

    private func isSessionActive(_ session: ChatSession) -> Bool {
        if case .chat(let activeSession) = activeScreen {
            return activeSession.id == session.id
        }
        return false
    }

    private func isScreenActive(_ screen: ActiveScreen) -> Bool {
        switch (activeScreen, screen) {
        case (.home, .home), (.system, .system), (.settings, .settings),
             (.browser, .browser), (.teams, .teams), (.hostProfiles, .hostProfiles),
             (.themes, .themes), (.hooks, .hooks):
            return true
        case (.chat, .chat):
            return true
        default:
            return false
        }
    }

}
