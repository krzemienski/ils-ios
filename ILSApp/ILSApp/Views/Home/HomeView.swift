import SwiftUI
import ILSShared
import TipKit

/// The primary home dashboard displayed when the app launches or no session is active.
///
/// Hosts a configurable ``DashboardGridView`` which renders the user's chosen
/// ``DashboardLayout`` as a grid of widget tiles. A toolbar slider button opens
/// ``DashboardLayoutPickerView`` to switch or customise layouts. The ``DashboardLayoutStore``
/// is owned here as `@State` and injected into the layout-picker sheet via the environment.
/// Pull-to-refresh triggers a reload of the shared ``SessionsViewModel`` and the
/// refreshing banner is shown while the operation is in flight.
///
/// ## Topics
/// ### Sections
/// - ``welcomeSection`` - Greeting header showing the connected server URL
/// - ``refreshingBanner`` - Transient animated banner shown during pull-to-refresh
/// - ``connectionBanner`` - Warning banner with a Setup CTA when the server is unreachable
/// - ``quickActionsGrid`` - Two-column ``LazyVGrid`` of tappable shortcut cards
/// - ``suggestionsWidget`` - Collapsible widget surfacing abandoned sessions worth resuming
/// - ``recentSessionsSection`` - Up to five most-recent sessions with skeleton loading fallback
/// - ``statsSection`` - Overview stat cards with sparklines and secondary health indicators
///
/// ### Actions
/// - ``onSessionSelected`` - Callback invoked when the user taps a session row in a widget
/// - ``onNavigate`` - Callback to push a named ``ActiveScreen`` onto the navigation stack
/// - ``onNavigateToBrowser`` - Callback to deep-link to a specific ``BrowserSegment``
///
/// ### Widget Operations
/// - ``removeWidget(_:)`` - Removes a widget from the active layout and persists the change
/// - ``reorderWidget(fromID:toID:)`` - Moves a dragged widget before the drop-target widget
struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(MultiSessionViewModel.self) private var multiSessionVM

    /// View model that loads dashboard statistics, sparkline data, and entity counts.
    @State private var dashboardVM = DashboardViewModel()
    /// View model for the tunnel status card shown on the dashboard.
    @State private var tunnelVM = TunnelSettingsViewModel()
    /// Persists and manages all dashboard layouts, including the active layout selection.
    /// Injected from the app-level environment so a single store instance is shared app-wide.
    @Environment(DashboardLayoutStore.self) private var layoutStore
    /// Whether the dashboard grid is in edit mode (shows remove / reorder controls).
    @State private var isEditMode = false
    /// Whether a pull-to-refresh reload is currently in flight.
    @State private var isRefreshing = false
    /// Controls presentation of the ``DashboardLayoutPickerView`` sheet.
    @State private var showLayoutPicker = false
    /// Controls presentation of the new-session sheet from the Quick Actions card.
    @State private var showNewSessionSheet = false
    /// Text binding for the searchable modifier on recent sessions.
    @State private var sessionSearchText = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let createSessionTip = CreateSessionTip()
    private let commandPaletteTip = CommandPaletteTip()

    /// Shared sessions view model owned by SidebarRootView.
    var sessionsVM: SessionsViewModel
    /// Called when the user selects a session row inside a widget.
    var onSessionSelected: ((ChatSession) -> Void)?
    /// Called to navigate to a top-level ``ActiveScreen`` from a widget action.
    var onNavigate: ((ActiveScreen) -> Void)?
    /// Called to navigate directly to a specific ``BrowserSegment`` (Skills, MCP, Plugins).
    var onNavigateToBrowser: ((BrowserSegment) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                refreshingBanner
                connectionBanner

                TipView(createSessionTip)
                    .tipBackground(theme.bgSecondary)

                TipView(commandPaletteTip)
                    .tipBackground(theme.bgSecondary)

                if let layout = layoutStore.activeLayout {
                    DashboardGridView(
                        layout: layout,
                        isEditMode: $isEditMode,
                        sessionsVM: sessionsVM,
                        apiClient: appState.apiClient,
                        onRemoveWidget: { widget in
                            removeWidget(widget)
                        },
                        onReorderWidget: { fromID, toID in
                            reorderWidget(fromID: fromID, toID: toID)
                        },
                        onSessionSelected: onSessionSelected,
                        onNavigate: onNavigate,
                        onNavigateToBrowser: onNavigateToBrowser
                    )
                } else {
                    // Fallback: static dashboard when no layout is configured
                    if appState.isConnected {
                        tunnelStatusSection
                    }

                    quickActionsGrid
                    suggestionsWidget
                    recentSessionsSection
                    statsSection
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
            .animation(.easeInOut(duration: 0.3), value: isRefreshing)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Home")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLayoutPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Dashboard Layout")
                .accessibilityHint("Opens the layout picker to customise your dashboard")
            }
            #else
            ToolbarItem {
                Button {
                    showLayoutPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Dashboard Layout")
                .accessibilityHint("Opens the layout picker to customise your dashboard")
            }
            #endif
        }
        .sheet(isPresented: $showLayoutPicker) {
            NavigationStack {
                DashboardLayoutPickerView()
            }
            .environment(layoutStore)
            .environment(\.theme, theme)
        }
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            dashboardVM.configure(client: appState.apiClient)
            await dashboardVM.loadAll()
            tunnelVM.configure(client: appState.apiClient)
            await tunnelVM.fetchStatus()
        }
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            isRefreshing = true
            await sessionsVM.loadSessions(refresh: true)  // Shared VM — updates both Home and Sidebar
            isRefreshing = false
        }
        .searchable(text: $sessionSearchText, prompt: "Search sessions")
        .onChange(of: sessionSearchText) { _, newValue in
            sessionsVM.searchText = newValue
            sessionsVM.scheduleSearchDebounce()
        }
        .onChange(of: appState.isConnected) { _, connected in
            CreateSessionTip.isConnected = connected
        }
    }

    // MARK: - Welcome Section

    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Welcome back")
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if appState.isConnected {
                Text(appState.serverURL)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Refreshing Banner

    @ViewBuilder
    private var refreshingBanner: some View {
        if isRefreshing {
            HStack(spacing: theme.spacingSM) {
                if !reduceMotion {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(theme.textSecondary)
                }

                Text("Refreshing…")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
            .accessibilityLabel("Refreshing content")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !appState.isConnected {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Not Connected")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure your server to get started")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    appState.showOnboarding = true
                } label: {
                    Text("Setup")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Setup server connection")
                .accessibilityHint("Opens the server configuration wizard")
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Widget Operations

    /// Removes a widget from the active layout and persists the updated layout.
    private func removeWidget(_ widget: DashboardWidget) {
        guard var layout = layoutStore.activeLayout else { return }
        layout.widgets.removeAll { $0.id == widget.id }
        renumberRows(&layout.widgets)
        layoutStore.save(layout)
        layoutStore.setActiveLayout(layout)
    }

    // MARK: - Suggestions Widget

    @ViewBuilder
    private var suggestionsWidget: some View {
        SessionSuggestionsWidget(apiClient: appState.apiClient) { session in
            onSessionSelected?(session)
        }
    }

    // MARK: - Recent Sessions

    @ViewBuilder
    private var recentSessionsSection: some View {
        let isSearching = !sessionSearchText.isEmpty
        let parsedQuery = sessionsVM.parsedQuery
        let isNLParsed = parsedQuery != nil
            && !(parsedQuery!.isFullTextOnly)
            && parsedQuery!.confidence >= 0.4
        let displaySessions: [ChatSession] = {
            if isSearching {
                if isNLParsed {
                    return sessionsVM.filteredSessions
                } else {
                    return sessionsVM.sessions.filter {
                        $0.displayName.localizedCaseInsensitiveContains(sessionSearchText)
                    }
                }
            } else {
                return Array(sessionsVM.sessions.prefix(5))
            }
        }()

        if !displaySessions.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text(isSearching ? "Results" : "Recent Sessions")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if isSearching {
                        Text("\(displaySessions.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        Button {
                            onNavigate?(.browser)
                        } label: {
                            HStack(spacing: theme.spacingXS) {
                                Text("View All")
                                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                                Text("(\(sessionsVM.totalCount))")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption - 2, weight: .semibold))
                            }
                            .foregroundStyle(theme.accent)
                        }
                    }
                }

                if isNLParsed, let pq = parsedQuery, !pq.explanation.isEmpty {
                    Text(pq.explanation)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityLabel("Filter: \(pq.explanation)")
                }

                ForEach(displaySessions, id: \.id) { session in
                    Button {
                        onSessionSelected?(session)
                    } label: {
                        recentSessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .shimmerIfActive(isRefreshing)
                }
            }
        } else if isSearching {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text("No sessions matching \"\(sessionSearchText)\"")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMD)
        } else if !appState.isConnected {
            EmptyView()
        } else if sessionsVM.isLoading {
            ForEach(0..<3, id: \.self) { _ in
                skeletonSessionRow
            }
        }
    }

    /// Moves the dragged widget (`fromID`) to the position occupied by the
    /// drop-target widget (`toID`) and persists the updated layout.
    ///
    /// The dragged widget is removed from its original position and inserted
    /// immediately before (or after) the drop target, matching the visual
    /// expectation set by ``DashboardGridView``'s drag-and-drop handler.
    /// Row indices are renumbered after the move.
    ///
    /// - Parameters:
    ///   - fromID: Stable identity of the widget being dragged.
    ///   - toID: Stable identity of the widget acting as the drop target.
    private func reorderWidget(fromID: UUID, toID: UUID) {
        guard var layout = layoutStore.activeLayout,
              let fromIndex = layout.widgets.firstIndex(where: { $0.id == fromID }),
              let toIndex = layout.widgets.firstIndex(where: { $0.id == toID }) else { return }
        let widget = layout.widgets.remove(at: fromIndex)
        let insertIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        layout.widgets.insert(widget, at: insertIndex)
        renumberRows(&layout.widgets)
        layoutStore.save(layout)
        layoutStore.setActiveLayout(layout)
    }

    /// Rewrites each widget's `position.row` to its array index, keeping
    /// `position.col` at zero. Called after every structural mutation.
    private func renumberRows(_ widgets: inout [DashboardWidget]) {
        for idx in widgets.indices {
            widgets[idx].position.row = idx
            widgets[idx].position.col = 0
        }
    }

    @ViewBuilder
    private var skeletonSessionRow: some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(theme.bgTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 140, height: 14)
                HStack(spacing: theme.spacingXS) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 50, height: 10)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 40, height: 10)
                }
            }

            Spacer()
        }
        .padding(theme.spacingSM)
        .frame(minHeight: 44)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
    }

    /// A compact row displaying a session's name, model badge, message count, and relative timestamp.
    private func recentSessionRow(_ session: ChatSession) -> some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(session.status == .active ? theme.success : theme.textTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(session.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacingXS) {
                    Text(session.model.isEmpty ? "default" : session.model)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text("·")
                        .foregroundStyle(theme.textTertiary)

                    Text("\(session.messageCount) msgs")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            Text(DateFormatters.relativeDateTime.localizedString(for: session.lastActiveAt, relativeTo: Date()))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingSM)
        .frame(minHeight: 44)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.displayName), \(session.messageCount) messages")
    }

    // MARK: - Tunnel Status

    @ViewBuilder
    private var tunnelStatusSection: some View {
        TunnelStatusCard()
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Quick Actions")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 220), spacing: theme.spacingSM)
            ], spacing: theme.spacingSM) {
                QuickActionCard(
                    icon: "plus.bubble.fill",
                    title: "New Session",
                    color: theme.entitySession
                ) {
                    showNewSessionSheet = true
                }

                QuickActionCard(
                    icon: "sparkles",
                    title: "Discover Skills",
                    subtitle: statsSubtitle(dashboardVM.stats?.skills.total),
                    color: theme.entitySkill
                ) {
                    onNavigateToBrowser?(.skills)
                }

                QuickActionCard(
                    icon: "server.rack",
                    title: "Configure MCP",
                    subtitle: mcpHealthSubtitle(),
                    subtitleColor: mcpHealthSubtitleColor(),
                    color: theme.entityMCP
                ) {
                    onNavigateToBrowser?(.mcp)
                }

                QuickActionCard(
                    icon: "puzzlepiece.extension.fill",
                    title: "Browse Plugins",
                    subtitle: statsSubtitle(dashboardVM.stats?.plugins.total),
                    color: theme.entityPlugin
                ) {
                    onNavigateToBrowser?(.plugins)
                }

                QuickActionCard(
                    icon: "gearshape.fill",
                    title: "Edit Settings",
                    color: theme.textSecondary
                ) {
                    onNavigate?(.settings)
                }

                QuickActionCard(
                    icon: "gauge.with.dots.needle.33percent",
                    title: "System Monitor",
                    color: theme.entityMCP
                ) {
                    onNavigate?(.system)
                }

                if sessionsVM.totalCount >= 2 {
                    QuickActionCard(
                        icon: "rectangle.split.2x2.fill",
                        title: "Monitor Sessions",
                        subtitle: "\(sessionsVM.totalCount) sessions",
                        color: theme.accent
                    ) {
                        onNavigate?(.splitView)
                    }
                }

                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "Usage",
                    color: theme.accent
                ) {
                    onNavigate?(.usage)
                }
            }
            .shimmerIfActive(isRefreshing)
        }
    }


    private func statsSubtitle(_ count: Int?) -> String? {
        guard let count else { return nil }
        return "\(count)"
    }

    private func mcpHealthSubtitle() -> String? {
        guard let mcpStats = dashboardVM.stats?.mcpServers else { return nil }
        if mcpStats.healthy < mcpStats.total {
            return "\(mcpStats.healthy)/\(mcpStats.total) healthy"
        }
        return "\(mcpStats.total)"
    }

    private func mcpHealthSubtitleColor() -> Color? {
        guard let mcpStats = dashboardVM.stats?.mcpServers,
              mcpStats.healthy < mcpStats.total else { return nil }
        return theme.warning
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        if let stats = dashboardVM.stats {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Overview")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 140, maximum: .infinity), spacing: theme.spacingSM)
                ], spacing: theme.spacingSM) {
                    StatCard(
                        title: "Sessions",
                        count: stats.sessions.total,
                        entityType: .sessions,
                        sparklineData: dashboardVM.sessionSparkline
                    )

                    StatCard(
                        title: "Projects",
                        count: stats.projects.total,
                        entityType: .projects,
                        sparklineData: dashboardVM.projectSparkline
                    )

                    StatCard(
                        title: "Skills",
                        count: stats.skills.total,
                        entityType: .skills,
                        sparklineData: dashboardVM.skillSparkline
                    )

                    StatCard(
                        title: "MCP Servers",
                        count: stats.mcpServers.total,
                        entityType: .mcp,
                        sparklineData: dashboardVM.mcpSparkline
                    )
                }
                .shimmerIfActive(isRefreshing)

                HStack {
                    Spacer()
                    CacheStatusView(lastUpdated: dashboardVM.lastUpdated)
                }

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: .infinity), spacing: theme.spacingSM)
                ], spacing: theme.spacingSM) {
                    secondaryStat(
                        icon: "puzzlepiece.extension.fill",
                        label: "Plugins",
                        value: "\(stats.plugins.enabled)/\(stats.plugins.total) enabled",
                        color: theme.entityPlugin
                    )

                    secondaryStat(
                        icon: "heart.fill",
                        label: "MCP Health",
                        value: "\(stats.mcpServers.healthy)/\(stats.mcpServers.total) healthy",
                        color: stats.mcpServers.healthy == stats.mcpServers.total ? theme.success : theme.warning
                    )
                }
                .shimmerIfActive(isRefreshing)

                if let health = stats.healthSummary, health.totalScored > 0 {
                    sessionHealthCard(health)
                        .shimmerIfActive(isRefreshing)
                }

                // Rate limit mini-card
                if let rateLimit = dashboardVM.rateLimitStatus {
                    rateLimitMiniCard(rateLimit)
                        .shimmerIfActive(isRefreshing)
                }
            }
        }
    }

    @ViewBuilder
    private func rateLimitMiniCard(_ status: RateLimitStatus) -> some View {
        let fraction = status.consumptionFraction
        let color: Color = fraction >= 0.8 ? theme.error : (fraction >= 0.6 ? theme.warning : theme.success)
        let summary = "\(status.messagesUsed) / \(status.messagesLimit)"

        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text("Rate Limit")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(summary)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(color)
            }
            ProgressView(value: fraction, total: 1.0)
                .progressViewStyle(.linear)
                .tint(color)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rate limit: \(summary) messages, \(Int(fraction * 100)) percent consumed")
    }

    @ViewBuilder
    private func secondaryStat(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Session Health Card

    @ViewBuilder
    private func sessionHealthCard(_ health: HealthSummary) -> some View {
        let avgScore = health.averageScore
        let scoreColor: Color = {
            if avgScore >= 70 { return theme.success }
            if avgScore >= 40 { return theme.warning }
            return theme.error
        }()

        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(scoreColor)
                        .accessibilityHidden(true)

                    Text("Session Health")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(avgScore))")
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                    Text("avg")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            HStack(spacing: theme.spacingSM) {
                healthLevelPill(count: health.healthyCount, label: "Healthy", color: theme.success)
                healthLevelPill(count: health.degradingCount, label: "Degrading", color: theme.warning)
                healthLevelPill(count: health.problematicCount, label: "Critical", color: theme.error)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Session Health, average score \(Int(avgScore)), " +
            "\(health.healthyCount) healthy, \(health.degradingCount) degrading, " +
            "\(health.problematicCount) critical, out of \(health.totalScored) scored sessions"
        )
    }

    @ViewBuilder
    private func healthLevelPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text("\(count) \(label)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let subtitleColor: Color?
    let color: Color
    let action: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var isPressed = false

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color? = nil,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: 24, design: theme.fontDesign))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(subtitleColor ?? theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(title)\(subtitle.map { ", \($0)" } ?? "")")
        .accessibilityHint("Double tap to open \(title)")
        // ACC-002: The DragGesture for press animation can interfere with VoiceOver activation.
        // Explicitly mark as a button and add a named action so VoiceOver users can activate
        // the card reliably via the accessibility action rotor.
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }
}

// MARK: - Conditional Shimmer Helper

private extension View {
    @ViewBuilder
    func shimmerIfActive(_ active: Bool) -> some View {
        if active {
            shimmer()
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(sessionsVM: SessionsViewModel())
            .environment(AppState())
            .environment(DashboardLayoutStore())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
