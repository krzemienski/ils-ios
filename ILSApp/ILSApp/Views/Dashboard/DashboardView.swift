import SwiftUI
import ILSShared

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedSection: DashboardSection?

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
                                color: ILSTheme.info
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSection = .projects
                            }

                            StatCardView(
                                title: "Sessions",
                                count: stats.sessions.total,
                                subtitle: "\(stats.sessions.active) active",
                                icon: "bubble.left.and.bubble.right.fill",
                                color: ILSTheme.success
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSection = .sessions
                            }
                        }

                        // Row 2: Skills & MCP
                        HStack(spacing: ILSTheme.spacingM) {
                            StatCardView(
                                title: "Skills",
                                count: stats.skills.total,
                                subtitle: activeText(stats.skills.active),
                                icon: "wand.and.stars.fill",
                                color: Color(red: 175.0/255.0, green: 82.0/255.0, blue: 222.0/255.0)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSection = .skills
                            }

                            StatCardView(
                                title: "MCP Servers",
                                count: stats.mcpServers.total,
                                subtitle: "\(stats.mcpServers.healthy) healthy",
                                icon: "server.rack",
                                color: ILSTheme.accent
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSection = .mcpServers
                            }
                        }
                    }
                    .padding()

                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                        Text("Quick Actions")
                            .font(ILSTheme.titleFont)
                            .foregroundColor(ILSTheme.primaryText)
                            .padding(.horizontal)

                        VStack(spacing: ILSTheme.spacingXS) {
                            ForEach(viewModel.quickActions) { action in
                                Button {
                                    // Navigate to the corresponding tab
                                    appState.selectedTab = action.tab.rawValue.lowercased()
                                } label: {
                                    HStack(spacing: ILSTheme.spacingM) {
                                        Image(systemName: action.icon)
                                            .font(.title3)
                                            .foregroundColor(ILSTheme.accent)
                                            .frame(width: 32)

                                        Text(action.title)
                                            .font(ILSTheme.bodyFont)
                                            .foregroundColor(ILSTheme.primaryText)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(ILSTheme.tertiaryText)
                                    }
                                    .padding(ILSTheme.spacingM)
                                    .background(ILSTheme.secondaryBackground)
                                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

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
        .background(ILSTheme.background.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await viewModel.loadAll()
        }
        .sheet(item: $selectedSection) { section in
            NavigationStack {
                section.destinationView
            }
            .presentationBackground(Color.black)
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadAll()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.retryLoad() }
            }
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
    @State private var isPressed = false

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
                .foregroundColor(ILSTheme.accent)

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
        .cornerRadius(ILSTheme.cornerRadiusMedium)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count), \(subtitle)")
    }
}

// MARK: - Recent Activity Row Component

struct RecentActivityRowView: View {
    let session: ChatSession

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

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
                    .cornerRadius(ILSTheme.cornerRadiusXS)
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
        .cornerRadius(ILSTheme.cornerRadiusSmall)
    }

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
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
        .cornerRadius(ILSTheme.cornerRadiusMedium)
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
                    .cornerRadius(ILSTheme.cornerRadiusXS)
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
        .cornerRadius(ILSTheme.cornerRadiusSmall)
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
