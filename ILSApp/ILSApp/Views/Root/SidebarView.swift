import SwiftUI
import ILSShared

/// Navigation sidebar for the iOS app providing access to screens and chat sessions.
///
/// Displays the app header with connection status, a list of primary navigation destinations,
/// a searchable session list grouped by project, and a button to create new sessions.
/// Sessions are loaded via `SessionsViewModel` into project-based DisclosureGroups whose
/// expansion state is persisted via `@SceneStorage`. Sessions within each project are
/// loaded on-demand when the group is expanded.
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
/// - ``sessionsSection`` - Searchable, project-grouped session list with pull-to-refresh
/// - ``bottomActions`` - "New Session" button that creates and opens a fresh session
///
/// ### Session Management
/// - ``projectGroup(group:)`` - DisclosureGroup for sessions within a project
/// - ``loadingView`` - Skeleton placeholder shown while sessions are loading
/// - ``emptyView`` - Empty state shown when no sessions match the current search
///
/// Projects load on sidebar appear; sessions within each project load lazily on expand.
struct SidebarView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(MultiSessionViewModel.self) private var multiSessionVM
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    /// Shared sessions view model owned by SidebarRootView.
    @Bindable var sessionsViewModel: SessionsViewModel

    /// The currently active navigation destination.
    @Binding var activeScreen: ActiveScreen
    /// Whether the sidebar overlay is currently open.
    @Binding var isSidebarOpen: Bool
    /// Called when the user selects a session from the list.
    var onSessionSelected: (ChatSession) -> Void
    /// Number of unread activity events to display as a badge on the Activity Feed nav item.
    var activityFeedUnreadCount: Int = 0

    /// BackendManager singleton — observed for health dot updates when 2+ backends registered.
    private let backendManager = BackendManager.shared

    @FocusState private var isSearchFocused: Bool
    /// The session currently being renamed, if any.
    @State private var sessionToRename: ChatSession?
    @State private var showRenameAlert = false
    /// Editable text used in the rename alert.
    @State private var renameText: String = ""
    /// The session pending deletion confirmation, if any.
    @State private var sessionToDelete: ChatSession?
    @State private var showNewSessionSheet = false
    /// The session being saved as a template, if any.
    @State private var sessionToSaveAsTemplate: ChatSession?
    /// View model for template creation (lazy-configured on first appearance).
    @State private var templatesViewModel = TemplatesViewModel()
    /// Whether the "too many pinned sessions" limit alert is visible.
    @State private var showPinLimitAlert = false

    /// Comma-separated project names whose DisclosureGroups are expanded, persisted across scenes.
    @SceneStorage("sidebarExpandedProjects") private var expandedProjectsStorage: String = ""

    /// Computed Set<String> backed by @SceneStorage for persistence across scenes.
    private var expandedProjects: Set<String> {
        get {
            guard !expandedProjectsStorage.isEmpty else { return [] }
            return Set(expandedProjectsStorage.components(separatedBy: ",").filter { !$0.isEmpty })
        }
        nonmutating set {
            expandedProjectsStorage = newValue.sorted().joined(separator: ",")
        }
    }

    /// Shared bookmark manager for toggling session bookmarks.
    private var bookmarksManager: SessionBookmarksManager { SessionBookmarksManager.shared }

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
            await sessionsViewModel.loadProjectGroups()
        }
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionView { session in
                showNewSessionSheet = false
                onSessionSelected(session)
                isSidebarOpen = false
            }
            .environment(appState)
            .environment(\.theme, theme)
        }
        .sheet(item: $sessionToSaveAsTemplate) { session in
            NavigationStack {
                EditTemplateView(
                    template: nil,
                    prefillName: session.name ?? "New Template",
                    prefillModel: session.model,
                    prefillPermissionMode: session.permissionMode.rawValue,
                    viewModel: templatesViewModel
                )
            }
            .environment(appState)
            .environment(\.theme, theme)
        }
        .task {
            templatesViewModel.configure(client: appState.apiClient)
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
        .alert("Split View Full", isPresented: $showPinLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin at most 4 sessions to Split View. Unpin a session before adding another.")
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let intent else { return }
            activeScreen = intent
            appState.navigationIntent = nil
        }
        .onChange(of: appState.browserSegmentIntent) { _, segment in
            guard segment != nil else { return }
            // Consumed by SidebarRootView
        }
        .onAppear {
            if case .chat(let session) = activeScreen {
                appState.updateLastSessionId(session.id)
            }
        }
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            await sessionsViewModel.loadProjectGroups()
        }
        // Cmd+N keyboard shortcut: open new session sheet
        .onReceive(NotificationCenter.default.publisher(for: .ilsCreateNewSession)) { _ in
            showNewSessionSheet = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("ILS")
                .font(.system(size: theme.fontTitle1, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)

            if backendManager.backends.count >= 2 {
                // Multi-backend: show a tappable row of colored health dots
                Button {
                    HapticManager.selection()
                    activeScreen = .backends
                    isSidebarOpen = false
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        ForEach(backendManager.backends) { backend in
                            Circle()
                                .fill(healthColor(backend.healthStatus))
                                .frame(width: 10, height: 10)
                        }
                        Text("\(backendManager.backends.count) backends")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Backend connections")
                .accessibilityValue("\(backendManager.backends.count) backends configured")
                .accessibilityHint("Navigate to backend management")
            } else {
                // Single or no backend: original connection status indicator
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

            // iCloud sync status indicator
            iCloudSyncStatusIndicator
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingLG)
        .padding(.bottom, theme.spacingMD)
    }

    // MARK: - iCloud Sync Status

    /// Shows a compact iCloud sync status row inside the sidebar header.
    ///
    /// Hidden when sync is disabled. Reflects the current `ICloudSyncStatus`
    /// with an SF Symbol, color, and relative last-sync timestamp.
    @ViewBuilder
    private var iCloudSyncStatusIndicator: some View {
        let syncManager = ICloudSyncManager.shared
        if syncManager.isSyncEnabled {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: iCloudStatusIcon(for: syncManager.syncStatus))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(iCloudStatusColor(for: syncManager.syncStatus))
                Text(iCloudStatusLabel(status: syncManager.syncStatus, lastSyncDate: syncManager.lastSyncDate))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(syncManager.syncStatus == .error ? theme.error : theme.textTertiary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("iCloud sync status")
            .accessibilityValue(iCloudStatusLabel(status: syncManager.syncStatus, lastSyncDate: syncManager.lastSyncDate))
        }
    }

    private func iCloudStatusIcon(for status: ICloudSyncStatus) -> String {
        switch status {
        case .syncing: return "arrow.clockwise.icloud"
        case .error:   return "exclamationmark.icloud"
        default:       return "checkmark.icloud"
        }
    }

    private func iCloudStatusColor(for status: ICloudSyncStatus) -> Color {
        switch status {
        case .syncing: return theme.accent
        case .error:   return theme.error
        default:       return theme.success
        }
    }

    private func iCloudStatusLabel(status: ICloudSyncStatus, lastSyncDate: Date?) -> String {
        switch status {
        case .syncing:  return "Syncing..."
        case .error:    return "Sync error"
        case .idle:
            guard let date = lastSyncDate else { return "iCloud Sync" }
            return "Synced \(iCloudRelativeTime(from: date))"
        case .disabled: return "iCloud Sync"
        }
    }

    private func iCloudRelativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<5:    return "just now"
        case ..<60:   return "\(Int(interval))s ago"
        case ..<3600:
            let m = Int(interval / 60)
            return m == 1 ? "1 min ago" : "\(m) min ago"
        default:
            let h = Int(interval / 3600)
            return h == 1 ? "1 hr ago" : "\(h) hrs ago"
        }
    }

    // MARK: - Health Color

    private func healthColor(_ status: BackendConnection.HealthStatus) -> Color {
        switch status {
        case .healthy: return theme.success
        case .degraded: return theme.warning
        case .unreachable: return theme.error
        case .unknown: return theme.textTertiary
        }
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
                sidebarNavItem(icon: "terminal.fill", label: "Terminal", screen: .terminal)
                sidebarNavItem(icon: "list.bullet.rectangle", label: "All Sessions", screen: .unifiedSessions)
                sidebarNavItem(
                    icon: "list.bullet.rectangle.fill",
                    label: "Activity Feed",
                    screen: .activityFeed,
                    badge: activityFeedUnreadCount
                )
                sidebarNavItem(icon: "book.fill", label: "Documentation", screen: .documentation)
                sidebarNavItem(icon: "split.cells.horizontal", label: "Split View", screen: .splitView)
                if enableAgentTeams {
                    sidebarNavItem(icon: "person.3.fill", label: "Agent Teams", screen: .teams)
                }
            }

            Spacer().frame(height: theme.spacingMD)

            // Configuration screens group
            sidebarSectionHeader(title: "CONFIGURE")
            VStack(spacing: theme.spacingXS) {
                sidebarNavItem(icon: "desktopcomputer", label: "Host Profiles", screen: .hostProfiles)
                sidebarNavItem(icon: "server.rack", label: "Backends", screen: .backends)
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

            // Search bar with NL indicator
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    TextField("Search or ask in plain English...", text: $sessionsViewModel.searchText)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .accessibilityLabel("Search sessions")
                        .focused($isSearchFocused)
                        .onChange(of: sessionsViewModel.searchText) { _, _ in
                            sessionsViewModel.scheduleSearchDebounce()
                        }
                    if sessionsViewModel.parsedQuery != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                            .accessibilityLabel("Smart search active")
                    }
                    if !sessionsViewModel.searchText.isEmpty {
                        Button {
                            sessionsViewModel.clearSearch()
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

                if sessionsViewModel.parsedQuery != nil {
                    QueryExplanationView(
                        parsedQuery: $sessionsViewModel.parsedQuery,
                        clearAll: { sessionsViewModel.clearSearch() }
                    )
                    .padding(.top, theme.spacingXS)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)
            .animation(.easeInOut(duration: 0.2), value: sessionsViewModel.parsedQuery != nil)

            // Cache freshness indicator
            HStack {
                Spacer()
                CacheStatusView(lastUpdated: sessionsViewModel.lastUpdated)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Session list — List provides view recycling (UICollectionView-backed).
            // Project groups expand lazily: sessions load on first expand.
            List {
                if sessionsViewModel.isLoading && sessionsViewModel.projectGroups.isEmpty {
                    loadingView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else if sessionsViewModel.filteredProjectGroups.isEmpty {
                    emptyView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else {
                    ForEach(sessionsViewModel.filteredProjectGroups) { group in
                        projectGroup(group: group)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.bgSidebar)
            .refreshable {
                #if os(iOS)
                HapticManager.impact(.light)
                #endif
                await sessionsViewModel.loadProjectGroups()
            }
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
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
            } else {
                ForEach(sessions) { session in
                    SidebarSessionRow(
                        session: session,
                        isActive: isSessionActive(session),
                        searchText: sessionsViewModel.debouncedSearchText
                    ) {
                        QueryLearningService.shared.recordSessionSelected(
                            forQuery: sessionsViewModel.searchText,
                            session: session
                        )
                        onSessionSelected(session)
                        isSidebarOpen = false
                    }
                    .contextMenu {
                        Button {
                            Task { await bookmarksManager.toggleBookmark(session: session) }
                        } label: {
                            let isBookmarked = bookmarksManager.isBookmarked(sessionId: session.id)
                            Label(
                                isBookmarked ? "Remove Bookmark" : "Bookmark",
                                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                            )
                        }

                        let isPinned = multiSessionVM.isPinned(session)
                        Button {
                            if isPinned {
                                multiSessionVM.unpinSession(session)
                            } else if multiSessionVM.pinnedSessionIds.count >= 4 {
                                showPinLimitAlert = true
                            } else {
                                multiSessionVM.pinSession(session)
                            }
                        } label: {
                            Label(
                                isPinned ? "Unpin from Split View" : "Pin to Split View",
                                systemImage: isPinned ? "pin.slash" : "pin"
                            )
                        }

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
                        Button {
                            sessionToSaveAsTemplate = session
                        } label: {
                            Label("Save as Template", systemImage: "doc.badge.plus")
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
                            Task { await bookmarksManager.toggleBookmark(session: session) }
                        } label: {
                            let isBookmarked = bookmarksManager.isBookmarked(sessionId: session.id)
                            Label(
                                isBookmarked ? "Unbookmark" : "Bookmark",
                                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .tint(.orange)
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
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
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
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
            Text(sessionsViewModel.searchText.isEmpty ? "No projects yet" : "No matching projects")
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

    private func sidebarNavItem(icon: String, label: String, screen: ActiveScreen, badge: Int = 0) -> some View {
        let isActive = isScreenActive(screen)
        let clampedBadge = min(badge, 99)

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
                if clampedBadge > 0 {
                    Text("\(clampedBadge)")
                        .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM + 4)
            .frame(minHeight: 44)
            .background(isActive ? theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(clampedBadge > 0 ? "\(label), \(clampedBadge) unread" : label)
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
             (.themes, .themes), (.hooks, .hooks), (.activityFeed, .activityFeed),
             (.documentation, .documentation), (.terminal, .terminal),
             (.backends, .backends), (.unifiedSessions, .unifiedSessions),
             (.splitView, .splitView):
            return true
        case (.chat, .chat):
            return true
        default:
            return false
        }
    }

}
