import SwiftUI
import ILSShared
import Observation

// MARK: - SystemMetricsWidgetViewModel

/// View model for the System Metrics dashboard widget.
///
/// Supplies CPU, memory, and disk utilisation percentages along with a recent
/// history window for sparklines. Data is sourced from a shared
/// ``SystemMetricsViewModel`` when available (which owns the live WebSocket
/// connection), and falls back to a one-shot REST fetch from
/// `/api/v1/system/metrics` when the widget runs standalone or via a direct
/// ``APIClient``.
///
/// ## Topics
/// ### Configuration
/// - ``configure(metricsVM:)`` - Bind to the shared system-metrics view model
/// - ``configure(client:)`` - Bind to a direct API client for standalone REST use
///
/// ### Data
/// - ``cpuPercentage`` - Current CPU utilisation (0–100)
/// - ``memoryPercentage`` - Current memory utilisation (0–100)
/// - ``diskPercentage`` - Current disk utilisation (0–100)
/// - ``cpuHistory`` - Recent CPU % values for the sparkline
/// - ``memoryHistory`` - Recent memory % values for the sparkline
/// - ``diskHistory`` - Recent disk % values for the sparkline
@Observable
@MainActor
final class SystemMetricsWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while fetching the initial metrics snapshot.
    private(set) var isLoading = true
    /// True when the backend returned an error or is unreachable.
    private(set) var isOffline = false

    // MARK: Data

    /// Current CPU utilisation percentage (0–100).
    private(set) var cpuPercentage: Double = 0
    /// Current memory utilisation percentage (0–100).
    private(set) var memoryPercentage: Double = 0
    /// Current disk utilisation percentage (0–100).
    private(set) var diskPercentage: Double = 0

    /// Used memory in gigabytes.
    private(set) var memoryUsedGB: Double = 0
    /// Total physical memory in gigabytes.
    private(set) var memoryTotalGB: Double = 0
    /// Used disk space in gigabytes.
    private(set) var diskUsedGB: Double = 0
    /// Total disk space in gigabytes.
    private(set) var diskTotalGB: Double = 0

    /// Sliding window of recent CPU % values (up to 60 points).
    private(set) var cpuHistory: [Double] = []
    /// Sliding window of recent memory % values (up to 60 points).
    private(set) var memoryHistory: [Double] = []
    /// Sliding window of recent disk % values (up to 60 points).
    private(set) var diskHistory: [Double] = []

    // MARK: Private

    /// Shared metrics VM — preferred data source (owns the WebSocket connection).
    private weak var metricsVM: SystemMetricsViewModel?
    /// Direct API client — used for standalone REST-only operation.
    private var client: APIClient?

    /// URLSession used for the direct REST fallback when no APIClient is set.
    private let session: URLSession
    /// Decoder for the REST fallback response.
    nonisolated private let decoder: JSONDecoder
    /// Base server URL for the direct REST fallback.
    private let baseURL: String

    // MARK: Init

    init(baseURL: String = "http://localhost:9999") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        self.decoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }()
    }

    // MARK: Configuration

    /// Bind this view model to the shared system-metrics view model.
    /// - Parameter metricsVM: The ``SystemMetricsViewModel`` owned by the app root.
    func configure(metricsVM: SystemMetricsViewModel) {
        self.metricsVM = metricsVM
    }

    /// Bind this view model to a direct API client for standalone use.
    /// - Parameter client: The ``APIClient`` for fetching metrics independently.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: DashboardWidgetViewModel

    /// Fetches a system metrics snapshot from the shared VM, API client, or REST fallback.
    func loadContent() async {
        isLoading = true
        isOffline = false

        if let vm = metricsVM {
            updateFromSharedVM(vm)
        } else if let client {
            await fetchFromAPIClient(client)
        } else {
            await fetchFromURL()
        }

        isLoading = false
    }

    // MARK: Private Helpers

    /// Sync metrics from an already-connected shared view model.
    private func updateFromSharedVM(_ vm: SystemMetricsViewModel) {
        cpuPercentage = vm.cpuPercentage
        memoryPercentage = vm.memoryPercentage
        diskPercentage = vm.diskPercentage
        memoryUsedGB = vm.memoryUsedGB
        memoryTotalGB = vm.memoryTotalGB
        diskUsedGB = vm.diskUsedGB
        diskTotalGB = vm.diskTotalGB
        cpuHistory = vm.metricsClient.cpuHistory.map(\.value)
        memoryHistory = vm.metricsClient.memoryHistory.map(\.value)
        diskHistory = vm.metricsClient.diskHistory.map(\.value)
        isOffline = !vm.isConnected && vm.metricsClient.latestMetrics == nil
    }

    /// Fetch a single metrics snapshot from the API client.
    private func fetchFromAPIClient(_ client: APIClient) async {
        do {
            let response: APIResponse<SystemMetricsResponse> = try await client.get("/system/metrics")
            if let metrics = response.data {
                applyMetrics(metrics)
                isOffline = false
            } else {
                isOffline = true
            }
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "SystemMetricsWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
    }

    /// Fetch a single metrics snapshot directly from the server REST endpoint.
    private func fetchFromURL() async {
        guard let url = URL(string: "\(baseURL)/api/v1/system/metrics") else {
            isOffline = true
            return
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                isOffline = true
                return
            }
            let metrics = try decoder.decode(SystemMetricsResponse.self, from: data)
            applyMetrics(metrics)
            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "SystemMetricsWidget REST fallback failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
    }

    /// Apply a decoded `SystemMetricsResponse` to all published properties.
    private func applyMetrics(_ metrics: SystemMetricsResponse) {
        cpuPercentage = metrics.cpu
        memoryPercentage = metrics.memory.percentage
        diskPercentage = metrics.disk.percentage
        memoryUsedGB = Double(metrics.memory.used) / 1_073_741_824
        memoryTotalGB = Double(metrics.memory.total) / 1_073_741_824
        diskUsedGB = Double(metrics.disk.used) / 1_073_741_824
        diskTotalGB = Double(metrics.disk.total) / 1_073_741_824
    }
}

// MARK: - SystemMetricsWidget

/// Dashboard widget that shows a real-time snapshot of CPU, memory, and disk usage.
///
/// Each metric is displayed as a row containing a coloured icon, a label, a thin
/// ``ProgressView`` bar, and a percentage value.  When history is available in
/// the view model (populated via the shared WebSocket client), a compact
/// ``SparklineChart`` is rendered below each metric bar.
///
/// Data is sourced from a shared ``SystemMetricsViewModel`` when provided, and
/// falls back to a one-shot REST fetch when the widget runs standalone.
///
/// ## Usage
/// ```swift
/// SystemMetricsWidget(viewModel: vm)
/// ```
struct SystemMetricsWidget: View {

    // MARK: - Properties

    /// View model supplying metrics data and loading state.
    let viewModel: SystemMetricsWidgetViewModel

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Colors

    private var cpuColor: Color { theme.accent }
    private var memoryColor: Color { theme.success }
    private var diskColor: Color { theme.warning }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else {
                metricsContent
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.systemMetrics.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            Text("System Metrics")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Metrics Content

    private var metricsContent: some View {
        VStack(spacing: theme.spacingSM) {
            metricRow(
                icon: "cpu",
                label: "CPU",
                value: viewModel.cpuPercentage,
                detail: nil,
                history: viewModel.cpuHistory,
                color: cpuColor
            )

            metricRow(
                icon: "memorychip",
                label: "Memory",
                value: viewModel.memoryPercentage,
                detail: memoryDetail,
                history: viewModel.memoryHistory,
                color: memoryColor
            )

            metricRow(
                icon: "internaldrive",
                label: "Disk",
                value: viewModel.diskPercentage,
                detail: diskDetail,
                history: viewModel.diskHistory,
                color: diskColor
            )
        }
        .padding(.top, theme.spacingSM)
    }

    /// "X.X / Y.Y GB" detail string for memory.
    private var memoryDetail: String? {
        guard viewModel.memoryTotalGB > 0 else { return nil }
        return String(format: "%.1f / %.1fGB", viewModel.memoryUsedGB, viewModel.memoryTotalGB)
    }

    /// "X.X / Y.Y GB" detail string for disk.
    private var diskDetail: String? {
        guard viewModel.diskTotalGB > 0 else { return nil }
        return String(format: "%.1f / %.1fGB", viewModel.diskUsedGB, viewModel.diskTotalGB)
    }

    // MARK: - Metric Row

    /// A single metric row: icon, label, progress bar, percentage, and optional sparkline.
    @ViewBuilder
    private func metricRow(
        icon: String,
        label: String,
        value: Double,
        detail: String?,
        history: [Double],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(color)
                    .frame(width: 14)
                    .accessibilityHidden(true)

                Text(label)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                if let detail {
                    Text(detail)
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }

                Text(String(format: "%.0f%%", value))
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(color)
                    .frame(minWidth: 32, alignment: .trailing)
                    .monospacedDigit()
            }

            ProgressView(value: min(value / 100, 1.0))
                .tint(color)
                .scaleEffect(y: 0.7, anchor: .center)
                .accessibilityLabel("\(label) usage \(Int(value)) percent")

            if history.count >= 2 {
                SparklineChart(data: history, color: color)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Int(value)) percent")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonRow
            }
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacingSM) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 14, height: 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 55, height: 12)

                Spacer()

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 34, height: 12)
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(theme.bgTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 6)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    SystemMetricsWidget(viewModel: SystemMetricsWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 220)
        .glassCard()
        .padding()
}
