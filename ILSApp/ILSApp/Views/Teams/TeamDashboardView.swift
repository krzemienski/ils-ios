import SwiftUI
import ILSShared

struct TeamDashboardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel: TeamsViewModel
    let teamName: String
    @State private var refreshTimer: Timer?

    init(teamName: String, apiClient: APIClient) {
        self.teamName = teamName
        _viewModel = State(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                statsGrid
                workloadSection
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Dashboard")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            await loadData()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Welcome Section

    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Team Dashboard")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if let metrics = viewModel.metrics {
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(healthColor(for: metrics.performance.efficiencyScore))
                        .frame(width: 8, height: 8)
                    Text("Last updated: \(formatTimestamp(metrics.timestamp))")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private var statsGrid: some View {
        if let metrics = viewModel.metrics {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("Overview")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD)
                    ],
                    spacing: theme.spacingMD
                ) {
                    statCard(
                        title: "Active Agents",
                        value: "\(metrics.agents.active)",
                        subtitle: "of \(metrics.agents.total) total",
                        systemImage: "person.3.fill",
                        color: theme.accent
                    )

                    statCard(
                        title: "Tasks",
                        value: "\(metrics.tasks.completed)",
                        subtitle: "of \(metrics.tasks.total) completed",
                        systemImage: "checkmark.circle.fill",
                        color: theme.success
                    )

                    statCard(
                        title: "Success Rate",
                        value: String(format: "%.0f%%", metrics.tasks.successRate),
                        subtitle: "\(metrics.tasks.failed) failed",
                        systemImage: "chart.line.uptrend.xyaxis",
                        color: successRateColor(metrics.tasks.successRate)
                    )

                    statCard(
                        title: "Efficiency",
                        value: String(format: "%.0f%%", metrics.performance.efficiencyScore),
                        subtitle: "team score",
                        systemImage: "gauge.with.dots.needle.67percent",
                        color: healthColor(for: metrics.performance.efficiencyScore)
                    )
                }
            }
        } else if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.error {
            errorView(error)
        }
    }

    // MARK: - Workload Section

    @ViewBuilder
    private var workloadSection: some View {
        if let metrics = viewModel.metrics, !metrics.workloadDistribution.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("Workload Distribution")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                ForEach(metrics.workloadDistribution, id: \.agentId) { workload in
                    workloadCard(workload)
                }
            }
        }
    }

    // MARK: - Stat Card

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text(subtitle)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Workload Card

    private func workloadCard(_ workload: TeamMetricsResponse.WorkloadDistribution) -> some View {
        VStack(spacing: theme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workload.agentName)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("\(workload.completedTasks) of \(workload.assignedTasks) tasks")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", workload.utilization))
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(healthColor(for: workload.utilization))

                    Text("utilization")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.bgTertiary)
                        .frame(height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Rectangle()
                        .fill(healthColor(for: workload.utilization))
                        .frame(width: geometry.size.width * (workload.utilization / 100), height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(height: 8)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading team metrics...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, design: theme.fontDesign))
                .foregroundStyle(theme.warning)

            Text("Failed to load metrics")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(error)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadData() }
            } label: {
                Text("Retry")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingLG)
        .modifier(GlassCard())
    }

    // MARK: - Data Loading

    private func loadData() async {
        await viewModel.loadMetrics(teamName: teamName)
    }

    private func startPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await loadData()
            }
        }
    }

    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Helpers

    private func healthColor(for score: Double) -> Color {
        if score >= 70 {
            return theme.success
        } else if score >= 40 {
            return theme.warning
        } else {
            return theme.error
        }
    }

    private func successRateColor(_ rate: Double) -> Color {
        if rate >= 80 {
            return theme.success
        } else if rate >= 60 {
            return theme.warning
        } else {
            return theme.error
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
