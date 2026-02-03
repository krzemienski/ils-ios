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

                    // Recent Activity Section
                    VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                        Text("Recent Activity")
                            .font(ILSTheme.titleFont)
                            .foregroundColor(ILSTheme.primaryText)
                            .padding(.horizontal)

                        if viewModel.recentSessions.isEmpty {
                            EmptyStateView(
                                title: "No Recent Activity",
                                systemImage: "clock",
                                description: "Your recent sessions will appear here"
                            )
                            .padding()
                        } else {
                            VStack(spacing: ILSTheme.spacingXS) {
                                ForEach(viewModel.recentSessions.prefix(10)) { session in
                                    RecentActivityRowView(session: session)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if viewModel.isLoading {
                    SkeletonDashboardView()
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

// MARK: - Recent Activity Row Component

struct RecentActivityRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name ?? "Unnamed Session")
                    .font(ILSTheme.headlineFont)
                    .foregroundColor(ILSTheme.primaryText)

                Spacer()

                Text(session.model)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }

            if let projectName = session.projectName {
                Text(projectName)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(1)
            }

            HStack {
                Label("\(session.messageCount) messages", systemImage: "bubble.left.and.bubble.right")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)

                Spacer()

                Text(formattedDate(session.lastActiveAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding(ILSTheme.spacingM)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusM)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Skeleton Loading Views

struct SkeletonDashboardView: View {
    var body: some View {
        VStack(spacing: ILSTheme.spacingL) {
            // Stats Grid Skeleton
            VStack(spacing: ILSTheme.spacingM) {
                // Row 1
                HStack(spacing: ILSTheme.spacingM) {
                    SkeletonStatCardView()
                    SkeletonStatCardView()
                }

                // Row 2
                HStack(spacing: ILSTheme.spacingM) {
                    SkeletonStatCardView()
                    SkeletonStatCardView()
                }
            }

            // Recent Activity Section Skeleton
            VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                Text("Recent Activity")
                    .font(ILSTheme.titleFont)
                    .foregroundColor(ILSTheme.primaryText)

                VStack(spacing: ILSTheme.spacingXS) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonActivityRowView()
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct SkeletonStatCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            HStack {
                Image(systemName: "square.fill")
                    .font(.title2)

                Spacer()
            }

            Text("000")
                .font(ILSTheme.titleFont)

            Text("Loading")
                .font(ILSTheme.headlineFont)

            Text("Please wait")
                .font(ILSTheme.captionFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ILSTheme.spacingM)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

struct SkeletonActivityRowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Loading Session Name")
                    .font(ILSTheme.headlineFont)

                Spacer()

                Text("model")
                    .font(ILSTheme.captionFont)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }

            Text("Project Name")
                .font(ILSTheme.captionFont)
                .lineLimit(1)

            HStack {
                Label("0 messages", systemImage: "bubble.left.and.bubble.right")
                    .font(ILSTheme.captionFont)

                Spacer()

                Text("Just now")
                    .font(ILSTheme.captionFont)
            }
        }
        .padding(ILSTheme.spacingM)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusM)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
