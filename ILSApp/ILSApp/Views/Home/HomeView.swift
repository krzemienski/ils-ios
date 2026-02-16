import SwiftUI
import ILSShared
import TipKit

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var dashboardVM = DashboardViewModel()
    @State private var sessionsVM = SessionsViewModel()

    private let createSessionTip = CreateSessionTip()

    var onSessionSelected: ((ChatSession) -> Void)?
    var onNavigate: ((ActiveScreen) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                connectionBanner

                TipView(createSessionTip)
                    .tipBackground(theme.bgSecondary)

                recentSessionsSection
                quickActionsGrid
                statsSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
        }
        .background(theme.bgPrimary)
        #if os(iOS)
        .inlineNavigationBarTitle()
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            dashboardVM.configure(client: appState.apiClient)
            sessionsVM.configure(client: appState.apiClient)
            await dashboardVM.loadAll()
            await sessionsVM.loadSessions(refresh: true)
        }
        .refreshable {
            await dashboardVM.loadAll()
            await sessionsVM.loadSessions(refresh: true)
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
        let recent = Array(sessionsVM.sessions.prefix(5))

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Recent Sessions")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Text("\(sessionsVM.totalCount)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
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
        } else if sessionsVM.isLoading {
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
    }

    @ViewBuilder
    private func recentSessionRow(_ session: ChatSession) -> some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name ?? "Unnamed Session")
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
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityLabel("\(session.name ?? "Unnamed"), \(session.model), \(session.messageCount) messages")
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
                    .font(.system(size: 24, design: theme.fontDesign))
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
            }
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
