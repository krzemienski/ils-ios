import SwiftUI
import ILSShared

struct TeamMetricsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel: TeamsViewModel
    let teamName: String
    @State private var pollingTask: Task<Void, Never>?

    init(teamName: String, apiClient: APIClient) {
        self.teamName = teamName
        _viewModel = State(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                headerSection
                performanceMetricsSection
                agentComparisonSection
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Performance Analytics")
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

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Performance Analytics")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if let metrics = viewModel.metrics {
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(healthColor(for: metrics.performance.efficiencyScore))
                        .frame(width: 8, height: 8)
                    Text("Team: \(metrics.teamName)")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    Spacer()

                    Text("Updated \(formatTimestamp(metrics.timestamp))")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Performance Metrics Section

    @ViewBuilder
    private var performanceMetricsSection: some View {
        if let metrics = viewModel.metrics {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("Performance Metrics")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD)
                    ],
                    spacing: theme.spacingMD
                ) {
                    performanceCard(
                        title: "Efficiency Score",
                        value: String(format: "%.0f%%", metrics.performance.efficiencyScore),
                        subtitle: "team efficiency",
                        systemImage: "gauge.with.dots.needle.67percent",
                        color: healthColor(for: metrics.performance.efficiencyScore)
                    )

                    performanceCard(
                        title: "Collaboration Score",
                        value: String(format: "%.0f%%", metrics.performance.collaborationScore),
                        subtitle: "agent synergy",
                        systemImage: "person.3.fill",
                        color: healthColor(for: metrics.performance.collaborationScore)
                    )

                    performanceCard(
                        title: "Throughput",
                        value: String(format: "%.1f", metrics.performance.throughput),
                        subtitle: "tasks/hour",
                        systemImage: "bolt.fill",
                        color: theme.accent
                    )

                    performanceCard(
                        title: "Avg Completion",
                        value: formatDuration(metrics.performance.averageCompletionTime),
                        subtitle: "per task",
                        systemImage: "clock.fill",
                        color: theme.info
                    )

                    performanceCard(
                        title: "Avg Response",
                        value: String(format: "%.0fms", metrics.performance.averageResponseTime),
                        subtitle: "response time",
                        systemImage: "timer",
                        color: responseTimeColor(metrics.performance.averageResponseTime)
                    )

                    performanceCard(
                        title: "Success Rate",
                        value: String(format: "%.0f%%", metrics.tasks.successRate),
                        subtitle: "\(metrics.tasks.completed)/\(metrics.tasks.total) completed",
                        systemImage: "checkmark.circle.fill",
                        color: successRateColor(metrics.tasks.successRate)
                    )
                }
            }
        } else if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.error {
            errorView(error)
        }
    }

    // MARK: - Agent Comparison Section

    @ViewBuilder
    private var agentComparisonSection: some View {
        if let metrics = viewModel.metrics, !metrics.workloadDistribution.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                HStack {
                    Text("Agent Performance Comparison")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Text("\(metrics.agents.active)/\(metrics.agents.total) active")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                ForEach(metrics.workloadDistribution, id: \.agentId) { workload in
                    agentPerformanceCard(workload)
                }
            }
        }
    }

    // MARK: - Performance Card

    private func performanceCard(
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

    // MARK: - Agent Performance Card

    private func agentPerformanceCard(_ workload: TeamMetricsResponse.WorkloadDistribution) -> some View {
        VStack(spacing: theme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workload.agentName)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    HStack(spacing: theme.spacingXS) {
                        Label {
                            Text("\(workload.completedTasks)/\(workload.assignedTasks)")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                        Text("•")
                            .foregroundStyle(theme.textTertiary)

                        Label {
                            Text(String(format: "%.0f%% workload", workload.workloadPercentage))
                        } icon: {
                            Image(systemName: "briefcase")
                        }
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(healthColor(for: workload.utilization))
                            .frame(width: 6, height: 6)

                        Text(String(format: "%.0f%%", workload.utilization))
                            .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                            .foregroundStyle(healthColor(for: workload.utilization))
                    }

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

            // Completion rate bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.bgTertiary)
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    if workload.assignedTasks > 0 {
                        let completionRate = Double(workload.completedTasks) / Double(workload.assignedTasks)
                        Rectangle()
                            .fill(theme.success.opacity(0.7))
                            .frame(width: geometry.size.width * completionRate, height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading performance metrics...")
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

            Text("Failed to load performance metrics")
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
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await loadData()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
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

    private func responseTimeColor(_ timeMs: Double) -> Color {
        if timeMs < 200 {
            return theme.success
        } else if timeMs < 500 {
            return theme.warning
        } else {
            return theme.error
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
