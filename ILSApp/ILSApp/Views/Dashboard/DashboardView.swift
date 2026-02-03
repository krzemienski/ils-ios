import SwiftUI
import ILSShared

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: ILSTheme.spacingL) {
                if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        await viewModel.retryLoad()
                    }
                    .padding()
                } else if let stats = viewModel.stats {
                    // Stats Grid
                    VStack(spacing: ILSTheme.spacingM) {
                        // Row 1: Projects & Sessions
                        HStack(spacing: ILSTheme.spacingM) {
                            StatCardView(
                                title: "Projects",
                                count: stats.projects.total,
                                subtitle: activeText(stats.projects.active),
                                icon: "folder.fill",
                                color: .blue
                            )

                            StatCardView(
                                title: "Sessions",
                                count: stats.sessions.total,
                                subtitle: "\(stats.sessions.active) active",
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .green
                            )
                        }

                        // Row 2: Skills & MCP
                        HStack(spacing: ILSTheme.spacingM) {
                            StatCardView(
                                title: "Skills",
                                count: stats.skills.total,
                                subtitle: activeText(stats.skills.active),
                                icon: "wand.and.stars.fill",
                                color: .purple
                            )

                            StatCardView(
                                title: "MCP Servers",
                                count: stats.mcpServers.total,
                                subtitle: "\(stats.mcpServers.healthy) healthy",
                                icon: "server.rack",
                                color: ILSTheme.accent
                            )
                        }
                    }
                    .padding()
                } else if viewModel.isLoading {
                    ProgressView("Loading dashboard...")
                        .padding()
                } else {
                    EmptyStateView(
                        title: "No Data",
                        systemImage: "chart.bar",
                        description: "Dashboard data is not available"
                    ) {
                        Task {
                            await viewModel.loadAll()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Dashboard")
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            await viewModel.loadAll()
        }
    }

    private func activeText(_ active: Int?) -> String {
        if let active = active {
            return "\(active) active"
        }
        return "No activity"
    }
}

// MARK: - Stat Card Component

struct StatCardView: View {
    let title: String
    let count: Int
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)

                Spacer()
            }

            Text("\(count)")
                .font(ILSTheme.titleFont)
                .foregroundColor(ILSTheme.primaryText)

            Text(title)
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.secondaryText)

            Text(subtitle)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ILSTheme.spacingM)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
