import SwiftUI
import ILSShared
import Observation

// MARK: - UsageStatsWidgetViewModel

/// View model for the Usage Stats dashboard widget.
///
/// Supplies total session counts, active session counts, and total cost
/// derived from recent sessions, along with synthetic sparkline data for
/// visual interest.  Data is sourced from a shared ``DashboardViewModel``
/// when available, and falls back to direct ``APIClient`` fetches from
/// `/stats` and `/stats/recent` when the widget runs standalone.
///
/// ## Topics
/// ### Configuration
/// - ``configure(dashboardVM:)`` - Bind to the shared dashboard view model
/// - ``configure(client:)`` - Bind to a direct API client for standalone use
///
/// ### Data
/// - ``totalSessions`` - Lifetime session count
/// - ``activeSessions`` - Currently active session count
/// - ``formattedTotalCost`` - Total cost across recent sessions as "$X.XX"
/// - ``sessionSparkline`` - Synthetic sparkline derived from total session count
/// - ``costSparkline`` - Per-session cost sparkline from recent session history
@Observable
@MainActor
final class UsageStatsWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while the widget is fetching its initial or refreshed data.
    private(set) var isLoading = true
    /// True when the backend is unreachable or returned an error.
    private(set) var isOffline = false

    // MARK: Data

    /// Total lifetime session count.
    private(set) var totalSessions: Int = 0
    /// Number of currently active sessions.
    private(set) var activeSessions: Int = 0
    /// Cumulative cost across recent sessions.
    private(set) var totalCost: Double = 0

    /// Synthetic sparkline values derived from `totalSessions`.
    private(set) var sessionSparkline: [Double] = []
    /// Cost-per-session sparkline derived from recent session history.
    private(set) var costSparkline: [Double] = []

    // MARK: Computed

    /// Total cost formatted as "$X.XX".
    var formattedTotalCost: String {
        String(format: "$%.2f", totalCost)
    }

    // MARK: Private

    /// Shared dashboard VM — preferred data source.
    private weak var dashboardVM: DashboardViewModel?
    /// Direct API client — fallback when `dashboardVM` is `nil`.
    private var client: APIClient?

    // MARK: Init

    init() {}

    // MARK: Configuration

    /// Bind this view model to the shared dashboard view model.
    /// - Parameter dashboardVM: The ``DashboardViewModel`` owned by the root view.
    func configure(dashboardVM: DashboardViewModel) {
        self.dashboardVM = dashboardVM
    }

    /// Bind this view model to a direct API client for standalone use.
    /// - Parameter client: The ``APIClient`` for fetching stats independently.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: DashboardWidgetViewModel

    /// Fetches usage statistics from the shared view model or the API.
    func loadContent() async {
        isLoading = true
        isOffline = false

        if let vm = dashboardVM {
            // Ensure the shared VM has loaded before we read from it
            if vm.isLoading && vm.stats == nil {
                await vm.loadAll()
            }
            updateFromDashboardVM(vm)
        } else if let client {
            await fetchFromAPI(client: client)
        } else {
            isLoading = false
            return
        }

        isLoading = false
    }

    // MARK: Private Helpers

    /// Derive usage stats from an already-loaded dashboard view model.
    private func updateFromDashboardVM(_ vm: DashboardViewModel) {
        if let stats = vm.stats {
            totalSessions = stats.sessions.total
            activeSessions = stats.sessions.active
        }
        totalCost = vm.totalCost
        sessionSparkline = vm.sessionSparkline
        costSparkline = makeCostSparkline(from: vm.recentSessions)
        isOffline = false
    }

    /// Fetch stats and recent sessions independently via the API client.
    private func fetchFromAPI(client: APIClient) async {
        do {
            async let statsResult: APIResponse<StatsResponse> = client.get("/stats")
            async let recentResult: APIResponse<RecentSessionsResponse> = client.get("/stats/recent")
            let (statsResponse, recentResponse) = try await (statsResult, recentResult)

            if let stats = statsResponse.data {
                totalSessions = stats.sessions.total
                activeSessions = stats.sessions.active
                sessionSparkline = makeSessionSparkline(total: totalSessions)
            }

            if let recent = recentResponse.data {
                let sessions = recent.items
                totalCost = sessions.reduce(0.0) { $0 + ($1.totalCostUSD ?? 0.0) }
                costSparkline = makeCostSparkline(from: sessions)
            }

            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "UsageStatsWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
    }

    /// Build a cost sparkline from the most recent 8 sessions.
    private func makeCostSparkline(from sessions: [ChatSession]) -> [Double] {
        sessions
            .sorted { $0.lastActiveAt < $1.lastActiveAt }
            .suffix(8)
            .map { $0.totalCostUSD ?? 0.0 }
    }

    /// Build a synthetic sparkline from a session count seed (matches DashboardViewModel).
    private func makeSessionSparkline(total: Int) -> [Double] {
        guard total > 0 else { return [] }
        let base = Double(total)
        return (0..<8).map { i in
            let variance = sin(Double(i) * 0.8 + Double(total % 7)) * base * 0.3
            return max(0, base + variance)
        }
    }
}

// MARK: - UsageStatsWidget

/// Dashboard widget that shows lifetime session counts and cumulative cost with sparklines.
///
/// Renders two ``StatCard``-style panels stacked vertically:
/// - **Sessions** — total count with an active-session badge and a synthetic sparkline.
/// - **Cost** — formatted total cost string and a per-session cost sparkline.
///
/// While data loads, skeleton cards shimmer as placeholders.  If neither a shared
/// ``DashboardViewModel`` nor an ``APIClient`` has been configured, the widget
/// shows a centred empty-state prompt.
///
/// ## Usage
/// ```swift
/// UsageStatsWidget(viewModel: vm)
/// ```
struct UsageStatsWidget: View {

    // MARK: - Properties

    /// View model supplying stats data and loading state.
    let viewModel: UsageStatsWidgetViewModel

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Colors

    private var sessionsColor: Color { theme.entitySession }
    private var costColor: Color { theme.success }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else if viewModel.totalSessions == 0 && viewModel.totalCost == 0 {
                emptyState
            } else {
                statsContent
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.usageStats.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(sessionsColor)
                .accessibilityHidden(true)

            Text("Usage Stats")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: theme.spacingSM) {
            sessionsStatCard
            costStatCard
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Sessions Stat Card

    private var sessionsStatCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: theme.fontTitle3, design: theme.fontDesign))
                    .foregroundStyle(sessionsColor)
                    .accessibilityHidden(true)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.totalSessions)")
                        .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(sessionsColor)
                        .monospacedDigit()

                    if viewModel.activeSessions > 0 {
                        Text("\(viewModel.activeSessions) active")
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                    }
                }
            }

            Text("Total Sessions")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            SparklineChart(data: viewModel.sessionSparkline, color: sessionsColor)
        }
        .padding(theme.spacingSM)
        .background(theme.bgTertiary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(sessionsColor.opacity(0.15), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total sessions, \(viewModel.totalSessions)")
    }

    // MARK: - Cost Stat Card

    private var costStatCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: theme.fontTitle3, design: theme.fontDesign))
                    .foregroundStyle(costColor)
                    .accessibilityHidden(true)

                Spacer()

                Text(viewModel.formattedTotalCost)
                    .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(costColor)
                    .monospacedDigit()
            }

            Text("Total Cost")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            SparklineChart(data: viewModel.costSparkline, color: costColor)
        }
        .padding(theme.spacingSM)
        .background(theme.bgTertiary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(costColor.opacity(0.15), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total cost, \(viewModel.formattedTotalCost)")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Usage Data")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("No usage data available")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingSM) {
            skeletonStatCard
            skeletonStatCard
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonStatCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.bgTertiary)
                    .frame(width: 22, height: 22)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.bgTertiary)
                    .frame(width: 60, height: 22)
            }

            RoundedRectangle(cornerRadius: 3)
                .fill(theme.bgTertiary)
                .frame(width: 80, height: 12)

            RoundedRectangle(cornerRadius: 3)
                .fill(theme.bgTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
        }
        .padding(theme.spacingSM)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    UsageStatsWidget(viewModel: UsageStatsWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 220)
        .glassCard()
        .padding()
}
