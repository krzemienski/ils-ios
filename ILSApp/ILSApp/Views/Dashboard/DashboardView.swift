import SwiftUI
import ILSShared

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: ILSTheme.spacingL) {
                if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        await viewModel.retryLoadStats()
                    }
                } else if let stats = viewModel.stats {
                    // Connection status
                    ConnectionStatusView()

                    // Stats cards grid
                    statsGrid(stats: stats)

                    // Quick navigation section
                    quickNavigationSection
                } else if !viewModel.isLoading {
                    EmptyStateView(
                        title: "No Stats Available",
                        systemImage: "chart.bar.xaxis",
                        description: "Unable to load dashboard statistics"
                    )
                }
            }
            .padding(ILSTheme.spacingM)
        }
        .navigationTitle("Dashboard")
        .refreshable {
            await viewModel.loadStats()
        }
        .overlay {
            if viewModel.isLoading && viewModel.stats == nil {
                ProgressView("Loading dashboard...")
            }
        }
        .task {
            await viewModel.loadStats()
        }
    }

    @ViewBuilder
    private func statsGrid(stats: StatsResponse) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: ILSTheme.spacingM),
                GridItem(.flexible(), spacing: ILSTheme.spacingM)
            ],
            spacing: ILSTheme.spacingM
        ) {
            StatCard(
                title: "Projects",
                count: stats.projects.total,
                systemImage: "folder",
                color: ILSTheme.accent
            )

            StatCard(
                title: "Sessions",
                count: stats.sessions.total,
                badge: "\(stats.sessions.active) active",
                badgeColor: ILSTheme.success,
                systemImage: "bubble.left.and.bubble.right",
                color: ILSTheme.info
            )

            StatCard(
                title: "Skills",
                count: stats.skills.total,
                badge: stats.skills.active.map { "\($0) active" },
                badgeColor: ILSTheme.success,
                systemImage: "star",
                color: .purple
            )

            StatCard(
                title: "MCP Servers",
                count: stats.mcpServers.total,
                badge: "\(stats.mcpServers.healthy)/\(stats.mcpServers.total) healthy",
                badgeColor: stats.mcpServers.healthy == stats.mcpServers.total ? ILSTheme.success : ILSTheme.warning,
                systemImage: "server.rack",
                color: .green
            )

            StatCard(
                title: "Plugins",
                count: stats.plugins.total,
                badge: "\(stats.plugins.enabled) enabled",
                badgeColor: ILSTheme.info,
                systemImage: "puzzlepiece.extension",
                color: .orange
            )
        }
    }

    private var quickNavigationSection: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
            Text("Quick Navigation")
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.primaryText)

            VStack(spacing: ILSTheme.spacingS) {
                QuickNavButton(
                    title: "Projects",
                    systemImage: "folder",
                    color: ILSTheme.accent
                )

                QuickNavButton(
                    title: "Sessions",
                    systemImage: "bubble.left.and.bubble.right",
                    color: ILSTheme.info
                )

                QuickNavButton(
                    title: "Skills",
                    systemImage: "star",
                    color: .purple
                )

                QuickNavButton(
                    title: "MCP Servers",
                    systemImage: "server.rack",
                    color: .green
                )

                QuickNavButton(
                    title: "Plugins",
                    systemImage: "puzzlepiece.extension",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let count: Int
    let badge: String?
    let badgeColor: Color
    let systemImage: String
    let color: Color

    init(
        title: String,
        count: Int,
        badge: String? = nil,
        badgeColor: Color = ILSTheme.success,
        systemImage: String,
        color: Color
    ) {
        self.title = title
        self.count = count
        self.badge = badge
        self.badgeColor = badgeColor
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, ILSTheme.spacingS)
                        .padding(.vertical, ILSTheme.spacingXS)
                        .background(badgeColor.opacity(0.15))
                        .foregroundColor(badgeColor)
                        .cornerRadius(ILSTheme.cornerRadiusS)
                }
            }

            VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
                Text("\(count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ILSTheme.primaryText)

                Text(title)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }
        }
        .padding(ILSTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    var body: some View {
        HStack(spacing: ILSTheme.spacingS) {
            Circle()
                .fill(ILSTheme.success)
                .frame(width: 8, height: 8)

            Text("Connected to Backend")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)

            Spacer()
        }
        .padding(.horizontal, ILSTheme.spacingM)
        .padding(.vertical, ILSTheme.spacingS)
        .background(ILSTheme.success.opacity(0.1))
        .cornerRadius(ILSTheme.cornerRadiusM)
    }
}

// MARK: - Quick Navigation Button

struct QuickNavButton: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Button {
            // Navigation will be handled in phase 3
        } label: {
            HStack(spacing: ILSTheme.spacingM) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)

                Text(title)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
            .padding(ILSTheme.spacingM)
            .background(ILSTheme.secondaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusM)
        }
    }
}
