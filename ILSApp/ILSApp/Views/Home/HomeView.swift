import SwiftUI
import ILSShared
import TipKit

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var dashboardVM = DashboardViewModel()

    private let createSessionTip = CreateSessionTip()

    var onSessionSelected: ((ChatSession) -> Void)?
    var onNavigate: ((ActiveScreen) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                connectionBanner

                if appState.isConnected {
                    TipView(createSessionTip)
                        .tipBackground(theme.bgSecondary)
                }

                quickActionsGrid
                recentSessionsSection
                statsSection
                errorBanner
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Home")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            dashboardVM.configure(client: appState.apiClient)
            await dashboardVM.loadAll()
        }
        .refreshable {
            await dashboardVM.loadAll()
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
        let recent = Array(dashboardVM.recentSessions.prefix(5))

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Recent Sessions")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if let stats = dashboardVM.stats {
                        Text("\(stats.sessions.total) total")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                ForEach(recent, id: \.id) { session in
                    Button {
                        onSessionSelected?(session)
                    } label: {
                        recentSessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if !appState.isConnected {
            // Empty state handled by connection banner
            EmptyView()
        } else if !dashboardVM.isLoading {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Recent Sessions")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                VStack(spacing: theme.spacingSM) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text("No sessions yet")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Text("Create a new session to get started")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
            }
        } else if dashboardVM.isLoading {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Recent Sessions")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                ForEach(0..<3, id: \.self) { _ in
                    skeletonSessionRow
                }
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
                Text((session.name ?? "Unnamed Session").cleanedSessionTitle())
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

                    if let projectName = session.projectName {
                        Text("·")
                            .foregroundStyle(theme.textTertiary)

                        Text(projectName)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(relativeTime(session.lastActiveAt))
                    .font(.system(size: 10, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingSM)
        .frame(minHeight: 44)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityLabel("\((session.name ?? "Unnamed Session").cleanedSessionTitle()), \(session.model), \(session.messageCount) messages")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    /// Relative time string (e.g. "2h ago", "3d ago").
    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 30 { return "\(days)d ago" }
        let months = days / 30
        return "\(months)mo ago"
    }

    @ViewBuilder
    private var skeletonSessionRow: some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(theme.bgTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
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
                quickActionCard(
                    icon: "plus.bubble.fill",
                    title: "New Session",
                    color: theme.entitySession
                ) {
                    let newSession = ChatSession(name: "New Session", model: "sonnet")
                    onSessionSelected?(newSession)
                }

                quickActionCard(
                    icon: "sparkles",
                    title: "Skills",
                    subtitle: statsSubtitle(dashboardVM.stats?.skills.total),
                    color: theme.entitySkill
                ) {
                    onNavigate?(.browser)
                }

                quickActionCard(
                    icon: "server.rack",
                    title: "MCP Servers",
                    subtitle: statsSubtitle(dashboardVM.stats?.mcpServers.total),
                    color: theme.entityMCP
                ) {
                    onNavigate?(.browser)
                }

                quickActionCard(
                    icon: "puzzlepiece.extension.fill",
                    title: "Plugins",
                    subtitle: statsSubtitle(dashboardVM.stats?.plugins.total),
                    color: theme.entityPlugin
                ) {
                    onNavigate?(.browser)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String? = nil,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(.title3, design: theme.fontDesign))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(subtitle.map { ", \($0)" } ?? "")")
        .accessibilityHint("Double tap to open \(title)")
    }

    private func statsSubtitle(_ count: Int?) -> String? {
        guard let count else { return nil }
        return "\(count)"
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        if let stats = dashboardVM.stats {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Overview")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if dashboardVM.totalCost > 0 {
                        Text(dashboardVM.formattedTotalCost)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }

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
            }
        }
    }

    @ViewBuilder
    private func secondaryStat(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 12, design: theme.fontDesign))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(.system(size: 10, design: theme.fontDesign))
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

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = dashboardVM.error, dashboardVM.stats == nil {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 28, design: theme.fontDesign))
                    .foregroundStyle(theme.error)

                Text("Failed to load dashboard")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(error.localizedDescription)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await dashboardVM.retryLoad()
                    }
                } label: {
                    Text("Retry")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Retry loading dashboard")
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingLG)
            .background(theme.error.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.error.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
