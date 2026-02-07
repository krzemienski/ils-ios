import SwiftUI
import ILSShared

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedSection: DashboardSection?
    @State private var lastRefreshed: Date?

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ILSTheme.spaceL) {
                // Greeting Header
                greetingHeader

                if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        await viewModel.retryLoad()
                    }
                    .padding()
                } else if viewModel.isLoading && viewModel.stats == nil {
                    skeletonContent
                } else if let stats = viewModel.stats {
                    // 2x2 Stat Cards Grid
                    statCardsGrid(stats)

                    // Quick Actions Section
                    quickActionsSection

                    // Recent Sessions Section
                    recentSessionsSection

                    // System Health Strip
                    systemHealthStrip(stats)

                    // Last Updated
                    if let lastRefreshed = lastRefreshed {
                        Text("Updated \(lastRefreshed, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.textTertiary)
                            .padding(.bottom, ILSTheme.spaceS)
                    }
                } else {
                    EmptyEntityState(
                        entityType: .sessions,
                        title: "No Data",
                        description: "Dashboard data is not available",
                        actionTitle: "Retry"
                    ) {
                        Task { await viewModel.loadAll() }
                    }
                    .padding()
                }
            }
            .padding(.horizontal, ILSTheme.spaceL)
        }
        .background(ILSTheme.bg0.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await viewModel.loadAll()
            lastRefreshed = Date()
            HapticManager.notification(.success)
        }
        .sheet(item: $selectedSection) { section in
            NavigationStack {
                section.destinationView
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadAll()
            lastRefreshed = Date()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.retryLoad() }
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.title2.weight(.bold))
                    .foregroundColor(ILSTheme.textPrimary)

                Text("ILS Dashboard")
                    .font(.subheadline)
                    .foregroundColor(ILSTheme.textSecondary)
            }

            Spacer()

            // Connection dot
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(appState.isConnected ? "Online" : "Offline")
                    .font(.caption.weight(.medium))
                    .foregroundColor(appState.isConnected ? .green : .red)
            }
            .padding(.horizontal, ILSTheme.spaceM)
            .padding(.vertical, ILSTheme.spaceXS)
            .background(ILSTheme.bg2)
            .clipShape(Capsule())
        }
        .padding(.top, ILSTheme.spaceS)
    }

    // MARK: - 2x2 Stat Cards Grid

    private func statCardsGrid(_ stats: StatsResponse) -> some View {
        VStack(spacing: ILSTheme.spaceM) {
            HStack(spacing: ILSTheme.spaceM) {
                StatCard(
                    title: "Sessions",
                    count: stats.sessions.total,
                    entityType: .sessions,
                    sparklineData: viewModel.sessionSparkline
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.impact(.light)
                    selectedSection = .sessions
                }

                StatCard(
                    title: "Projects",
                    count: stats.projects.total,
                    entityType: .projects,
                    sparklineData: viewModel.projectSparkline
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.impact(.light)
                    selectedSection = .projects
                }
            }

            HStack(spacing: ILSTheme.spaceM) {
                StatCard(
                    title: "Skills",
                    count: stats.skills.total,
                    entityType: .skills,
                    sparklineData: viewModel.skillSparkline
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.impact(.light)
                    selectedSection = .skills
                }

                StatCard(
                    title: "MCP Servers",
                    count: stats.mcpServers.total,
                    entityType: .mcp,
                    sparklineData: viewModel.mcpSparkline
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.impact(.light)
                    selectedSection = .mcpServers
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            Text("Quick Actions")
                .font(.headline.weight(.semibold))
                .foregroundColor(ILSTheme.textPrimary)

            HStack(spacing: ILSTheme.spaceM) {
                // New Session button
                Button {
                    appState.selectedTab = "sessions"
                } label: {
                    HStack(spacing: ILSTheme.spaceS) {
                        Image(systemName: "plus.bubble.fill")
                            .foregroundColor(EntityType.sessions.color)
                        Text("New Session")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(ILSTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ILSTheme.spaceM)
                    .background(ILSTheme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                    .overlay(
                        RoundedRectangle(cornerRadius: ILSTheme.radiusS)
                            .stroke(EntityType.sessions.color.opacity(0.15), lineWidth: 1)
                    )
                }

                // Total Cost card
                VStack(spacing: 4) {
                    Text("Total Cost")
                        .font(.caption)
                        .foregroundColor(ILSTheme.textTertiary)
                    Text(viewModel.formattedTotalCost)
                        .font(.title3.monospacedDigit().bold())
                        .foregroundColor(ILSTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(ILSTheme.spaceM)
                .background(ILSTheme.bg2)
                .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            Text("Recent Sessions")
                .font(.headline.weight(.semibold))
                .foregroundColor(ILSTheme.textPrimary)

            if viewModel.recentSessions.isEmpty {
                EmptyEntityState(
                    entityType: .sessions,
                    title: "No Recent Activity",
                    description: "Your recent sessions will appear here"
                )
            } else {
                VStack(spacing: ILSTheme.spaceXS) {
                    ForEach(viewModel.recentSessions.prefix(5)) { session in
                        NavigationLink(destination: ChatView(session: session)) {
                            HStack(spacing: ILSTheme.spaceM) {
                                // Blue entity dot
                                Circle()
                                    .fill(session.status == .active
                                          ? EntityType.sessions.color
                                          : EntityType.sessions.color.opacity(0.3))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.name ?? "Unnamed Session")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(ILSTheme.textPrimary)
                                        .lineLimit(1)

                                    HStack(spacing: ILSTheme.spaceS) {
                                        Text(session.model)
                                            .font(.caption2)
                                            .foregroundColor(ILSTheme.textTertiary)
                                        Text("\(session.messageCount) msgs")
                                            .font(.caption2)
                                            .foregroundColor(ILSTheme.textTertiary)
                                    }
                                }

                                Spacer()

                                Text(session.lastActiveAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.textTertiary)
                            }
                            .padding(ILSTheme.spaceM)
                            .background(ILSTheme.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - System Health Strip

    private func systemHealthStrip(_ stats: StatsResponse) -> some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            Text("System Health")
                .font(.headline.weight(.semibold))
                .foregroundColor(ILSTheme.textPrimary)

            HStack(spacing: ILSTheme.spaceM) {
                // Active sessions bar
                compactBar(
                    label: "Active",
                    value: Double(stats.sessions.active),
                    total: Double(max(stats.sessions.total, 1)),
                    color: EntityType.sessions.color
                )

                // Healthy MCP bar
                compactBar(
                    label: "MCP Health",
                    value: Double(stats.mcpServers.healthy),
                    total: Double(max(stats.mcpServers.total, 1)),
                    color: EntityType.mcp.color
                )

                // Enabled plugins bar
                compactBar(
                    label: "Plugins",
                    value: Double(stats.plugins.enabled),
                    total: Double(max(stats.plugins.total, 1)),
                    color: EntityType.plugins.color
                )
            }
            .padding(ILSTheme.spaceM)
            .background(ILSTheme.bg2)
            .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
        }
    }

    private func compactBar(label: String, value: Double, total: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))/\(Int(total))")
                .font(.caption.monospacedDigit().bold())
                .foregroundColor(color)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ILSTheme.bg3)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(value / total, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            Text(label)
                .font(.caption2)
                .foregroundColor(ILSTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Skeleton Content

    private var skeletonContent: some View {
        VStack(spacing: ILSTheme.spaceL) {
            VStack(spacing: ILSTheme.spaceM) {
                HStack(spacing: ILSTheme.spaceM) {
                    skeletonCard
                    skeletonCard
                }
                HStack(spacing: ILSTheme.spaceM) {
                    skeletonCard
                    skeletonCard
                }
            }

            VStack(spacing: ILSTheme.spaceXS) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRow()
                }
            }
        }
        .padding(.top)
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 24, height: 24)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 40, height: 20)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(ILSTheme.bg3)
                .frame(width: 80, height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(ILSTheme.bg3)
                .frame(height: 24)
        }
        .padding(ILSTheme.spaceM)
        .background(ILSTheme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
        .shimmer()
    }
}

// MARK: - Dashboard Section Navigation

enum DashboardSection: Identifiable {
    case projects
    case sessions
    case skills
    case mcpServers

    var id: String {
        switch self {
        case .projects: return "projects"
        case .sessions: return "sessions"
        case .skills: return "skills"
        case .mcpServers: return "mcpServers"
        }
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .projects:
            ProjectsListView()
        case .sessions:
            SessionsListView()
        case .skills:
            SkillsListView()
        case .mcpServers:
            MCPServerListView()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
