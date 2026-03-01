import Foundation
import Observation
import ILSShared

@Observable
@MainActor
final class UsageDashboardViewModel {

    // MARK: - State

    var metrics: UsageMetrics?
    var isLoading = false
    var error: Error?
    var isExporting = false
    /// Raw export bytes ready for sharing (set after a successful exportUsage() call).
    var exportData: Data?

    // MARK: - Persisted Preferences

    /// The time period used for loading and filtering usage data.
    var selectedPeriod: UsagePeriod = .daily

    /// Alert threshold as a percentage (0–100). Persisted to UserDefaults.
    var alertThreshold: Int {
        didSet {
            UserDefaults.standard.set(alertThreshold, forKey: "usageAlertThreshold")
        }
    }

    /// Whether usage alerts are enabled. Persisted to UserDefaults.
    var alertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(alertsEnabled, forKey: "usageAlertsEnabled")
        }
    }

    // MARK: - Private

    private var client: APIClient?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        // Default to 80% if the key has never been written (integer(forKey:) returns 0 for missing keys).
        alertThreshold = defaults.object(forKey: "usageAlertThreshold") != nil
            ? defaults.integer(forKey: "usageAlertThreshold")
            : 80
        alertsEnabled = defaults.bool(forKey: "usageAlertsEnabled")
    }

    // MARK: - Configuration

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed Properties

    /// Day-by-day usage data scoped to the selected period.
    /// Monthly returns the full daily breakdown; weekly returns the last 7 entries; daily returns the last 1.
    var filteredDailyData: [DailyUsage] {
        guard let metrics else { return [] }
        let breakdown = metrics.dailyBreakdown
        switch selectedPeriod {
        case .daily:
            return Array(breakdown.suffix(1))
        case .weekly:
            return Array(breakdown.suffix(7))
        case .monthly:
            return breakdown
        }
    }

    /// Rate limit consumption expressed as a percentage (0–100).
    var rateLimitPercentage: Double {
        guard let metrics else { return 0.0 }
        return metrics.rateLimitStatus.consumptionFraction * 100.0
    }

    /// True when alerts are enabled and consumption has reached or exceeded the threshold.
    var isNearingLimit: Bool {
        alertsEnabled && rateLimitPercentage >= Double(alertThreshold)
    }

    /// Human-readable summary of current rate limit usage (e.g. "32 / 45").
    var rateLimitSummary: String {
        guard let status = metrics?.rateLimitStatus else { return "—" }
        return "\(status.messagesUsed) / \(status.messagesLimit)"
    }

    // MARK: - Data Loading

    /// Fetch usage metrics for the currently selected period from the backend.
    func loadAll() async {
        guard let client else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<UsageMetrics> = try await client.get(
                "/usage?period=\(selectedPeriod.rawValue)"
            )
            if let data = response.data {
                metrics = data
                AppLogger.shared.info(
                    "Loaded usage metrics: \(data.totalMessages) messages, period=\(selectedPeriod.rawValue)",
                    category: "usage"
                )
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load usage metrics: \(error.localizedDescription)",
                category: "usage"
            )
        }
    }

    /// Retry loading after an error.
    func retryLoad() async {
        await loadAll()
    }

    // MARK: - Export

    /// Downloads a usage report from the export endpoint and stores raw bytes in `exportData`.
    /// The view is responsible for presenting a share sheet once `exportData` is set.
    func exportUsage(format: UsageExportFormat = .csv) async {
        guard let client else { return }
        isExporting = true
        exportData = nil
        defer { isExporting = false }

        do {
            let data = try await client.getRawData(
                "/usage/export?period=\(selectedPeriod.rawValue)&format=\(format.rawValue)"
            )
            exportData = data
            AppLogger.shared.info(
                "Exported \(data.count) bytes of usage data (period=\(selectedPeriod.rawValue), format=\(format.rawValue))",
                category: "usage"
            )
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to export usage: \(error.localizedDescription)",
                category: "usage"
            )
        }
    }
}
