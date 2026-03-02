import SwiftUI
import ILSShared
import TipKit

/// The primary home dashboard displayed when the app launches or no session is active.
///
/// Renders six stacked sections — Welcome, Refreshing Banner, Connection Banner, Quick Actions,
/// Recent Sessions, and Overview Stats — inside a vertically scrolling container. Quick-action
/// cards are laid out with a two-column ``LazyVGrid``. While the sessions list is loading, the
/// Recent Sessions section shows skeleton rows animated with a shimmer effect. A ``TipKit``
/// tip guides new users toward creating their first session. Pull-to-refresh triggers a
/// simultaneous reload of ``DashboardViewModel`` and the shared ``SessionsViewModel``,
/// which is owned by the parent `SidebarRootView` so that sidebar and home stay in sync.
/// Sparkline data for each entity type is sourced from ``DashboardViewModel`` and passed to
/// individual ``StatCard`` views in the Overview section.
///
/// ## Topics
/// ### Sections
/// - ``welcomeSection`` - Greeting header showing the connected server URL
/// - ``refreshingBanner`` - Transient animated banner shown during pull-to-refresh
/// - ``connectionBanner`` - Warning banner with a Setup CTA when the server is unreachable
/// - ``quickActionsGrid`` - Two-column ``LazyVGrid`` of tappable shortcut cards
/// - ``recentSessionsSection`` - Up to five most-recent sessions with skeleton loading fallback
/// - ``statsSection`` - Overview stat cards with sparklines and secondary health indicators
///
/// ### Actions
/// - ``onSessionSelected`` - Callback invoked when the user taps a recent session row
/// - ``onNavigate`` - Callback to push a named ``ActiveScreen`` onto the navigation stack
/// - ``onNavigateToBrowser`` - Callback to deep-link to a specific ``BrowserSegment``
///
/// ### Loading
/// - ``skeletonSessionRow`` - Placeholder row rendered with shimmer while sessions load
/// - ``isRefreshing`` - Drives the refreshing banner visibility and shimmer on stat cards
struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// View model that loads dashboard statistics, sparkline data, and entity counts.
    @State private var dashboardVM = DashboardViewModel()
    /// Whether a pull-to-refresh reload is currently in flight.
    @State private var isRefreshing = false
    /// Controls presentation of the New Session sheet.
    @State private var showNewSessionSheet = false
    /// Text entered in the sessions search bar.
    @State private var sessionSearchText: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let createSessionTip = CreateSessionTip()
    private let commandPaletteTip = CommandPaletteTip()

    /// Shared sessions view model owned by SidebarRootView.
    var sessionsVM: SessionsViewModel
    /// Called when the user selects a recent session row; passes the chosen ``ChatSession``.
    var onSessionSelected: ((ChatSession) -> Void)?
    /// Called to navigate to a top-level ``ActiveScreen`` from a quick-action card.
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

                quickActionsGrid
                recentSessionsSection
                statsSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
            .animation(.easeInOut(duration: 0.3), value: isRefreshing)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Home")
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionView { session in
                showNewSessionSheet = false
                onSessionSelected?(session)
            }
            .environment(appState)
            .environment(\.theme, theme)
        }
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            dashboardVM.configure(client: appState.apiClient)
            await dashboardVM.loadAll()
            // Sessions are loaded by SidebarRootView (shared VM)
        }
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            isRefreshing = true
            await dashboardVM.loadAll()
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
        .onChange(of: appState.serverURL) { _, _ in
            dashboardVM.configure(client: appState.apiClient)
            Task { await dashboardVM.loadAll() }
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
            // Empty state handled by connection banner
            EmptyView()
        } else if sessionsVM.isLoading {
            ForEach(0..<3, id: \.self) { _ in
                skeletonSessionRow
            }
        }
    }

    @ViewBuilder
    private func recentSessionRow(_ session: ChatSession) -> some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacingXS) {
                    Text(session.model.capitalized)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.entitySession)

                    Text("·")
                        .foregroundStyle(theme.textTertiary)

                    Text("\(session.messageCount) msgs")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingSM)
        .frame(minHeight: 44)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityLabel("\(session.displayName), \(session.model), \(session.messageCount) messages")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
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

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Quick Actions")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: theme.spacingSM),
                GridItem(.flexible(), spacing: theme.spacingSM)
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
            }
            .shimmerIfActive(isRefreshing)
        }
    }


    private func statsSubtitle(_ count: Int?) -> String? {
        guard let count else { return nil }
        return "\(count)"
    }

    /// Returns a health-aware subtitle for the Configure MCP quick action card.
    /// Shows "X/Y healthy" with a warning color when servers are unhealthy,
    /// or the plain total count when all servers are healthy.
    private func mcpHealthSubtitle() -> String? {
        guard let mcpStats = dashboardVM.stats?.mcpServers else { return nil }
        if mcpStats.healthy < mcpStats.total {
            return "\(mcpStats.healthy)/\(mcpStats.total) healthy"
        }
        return "\(mcpStats.total)"
    }

    /// Returns `theme.warning` when any MCP server is unhealthy, otherwise `nil`
    /// so the card falls back to the default `theme.textTertiary` subtitle color.
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
                    GridItem(.flexible(), spacing: theme.spacingSM),
                    GridItem(.flexible(), spacing: theme.spacingSM)
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

                // Secondary stats row: plugins + active counts
                HStack(spacing: theme.spacingSM) {
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
            }
        }
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
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
