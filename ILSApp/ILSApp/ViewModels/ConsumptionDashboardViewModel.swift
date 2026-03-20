import Foundation
import Observation
import UserNotifications
import ILSShared

/// Burn-rate severity classification used by the consumption dashboard.
enum BurnRateSeverity: String, Sendable {
    case low
    case medium
    case high
}

@Observable
@MainActor
final class ConsumptionDashboardViewModel {

    // MARK: - State

    var consumptionData: ConsumptionDashboardResponse?
    var isLoading = false
    var error: Error?

    // MARK: - Persisted Preferences

    /// The time period used for loading and filtering consumption data.
    var selectedPeriod: UsagePeriod = .daily

    /// Whether consumption alerts are enabled. Persisted to UserDefaults.
    var consumptionAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(consumptionAlertsEnabled, forKey: "consumptionAlertsEnabled")
        }
    }

    /// Burn-rate warning threshold in messages per hour. Persisted to UserDefaults.
    var burnRateWarningThreshold: Double {
        didSet {
            UserDefaults.standard.set(burnRateWarningThreshold, forKey: "consumptionBurnRateWarningThreshold")
        }
    }

    /// Daily consumption limit in messages per day. Persisted to UserDefaults.
    var dailyConsumptionLimit: Int {
        didSet {
            UserDefaults.standard.set(dailyConsumptionLimit, forKey: "consumptionDailyLimit")
        }
    }

    /// Alert when fewer than N hours remain before rate-limit exhaustion. Persisted to UserDefaults.
    var exhaustionWarningHours: Int {
        didSet {
            UserDefaults.standard.set(exhaustionWarningHours, forKey: "consumptionExhaustionWarningHours")
        }
    }

    // MARK: - Private

    private var client: APIClient?
    /// Prevents duplicate notifications for the same threshold crossing.
    private var hasNotifiedBurnRate = false
    /// Prevents duplicate notifications for the same exhaustion crossing.
    private var hasNotifiedExhaustion = false

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        consumptionAlertsEnabled = defaults.bool(forKey: "consumptionAlertsEnabled")
        burnRateWarningThreshold = defaults.object(forKey: "consumptionBurnRateWarningThreshold") != nil
            ? defaults.double(forKey: "consumptionBurnRateWarningThreshold")
            : 10.0
        dailyConsumptionLimit = defaults.object(forKey: "consumptionDailyLimit") != nil
            ? defaults.integer(forKey: "consumptionDailyLimit")
            : 200
        exhaustionWarningHours = defaults.object(forKey: "consumptionExhaustionWarningHours") != nil
            ? defaults.integer(forKey: "consumptionExhaustionWarningHours")
            : 2
    }

    // MARK: - Configuration

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed Properties

    /// Day-by-day consumption data scoped to the selected period.
    /// Monthly returns the full daily breakdown; weekly returns the last 7 entries; daily returns the last 1.
    var filteredDailyConsumption: [DailyConsumption] {
        guard let consumptionData else { return [] }
        let breakdown = consumptionData.dailyConsumption
        switch selectedPeriod {
        case .daily:
            return Array(breakdown.suffix(1))
        case .weekly:
            return Array(breakdown.suffix(7))
        case .monthly:
            return breakdown
        }
    }

    /// Total estimated cost formatted as a currency string (e.g. "$12.34").
    var totalEstimatedCostFormatted: String {
        guard let consumptionData else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: consumptionData.totalEstimatedCostUSD)) ?? "$0.00"
    }

    /// Burn-rate severity classification based on the configured threshold.
    var burnRateSeverity: BurnRateSeverity {
        guard let burnRate = consumptionData?.burnRate else { return .low }
        let rate = burnRate.messagesPerHour
        if rate >= burnRateWarningThreshold * 1.5 {
            return .high
        } else if rate >= burnRateWarningThreshold {
            return .medium
        }
        return .low
    }

    /// Human-readable string for projected exhaustion (e.g. "~3.2 hours remaining" or "No exhaustion projected").
    var projectedExhaustionFormatted: String {
        guard let hours = consumptionData?.burnRate.projectedHoursRemaining else {
            return "No exhaustion projected"
        }
        if hours < 1.0 {
            let minutes = Int(hours * 60)
            return "~\(minutes) min remaining"
        }
        return String(format: "~%.1f hours remaining", hours)
    }

    /// Active anomalies sorted by severity (critical first, then warning).
    var activeAnomalies: [AnomalyFlag] {
        guard let consumptionData else { return [] }
        return consumptionData.anomalies.sorted { lhs, rhs in
            let lhsOrder = lhs.severity == .critical ? 0 : 1
            let rhsOrder = rhs.severity == .critical ? 0 : 1
            return lhsOrder < rhsOrder
        }
    }

    // MARK: - Data Loading

    /// Fetch full consumption dashboard data for the currently selected period from the backend.
    func loadAll() async {
        guard let client else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<ConsumptionDashboardResponse> = try await client.get(
                "/consumption?period=\(selectedPeriod.rawValue)"
            )
            if let data = response.data {
                consumptionData = data
                AppLogger.shared.info(
                    "Loaded consumption data: \(data.totalMessages) messages, \(data.totalEstimatedTokens) tokens, period=\(selectedPeriod.rawValue)",
                    category: "consumption"
                )
                checkAndScheduleConsumptionAlert()
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load consumption data: \(error.localizedDescription)",
                category: "consumption"
            )
        }
    }

    /// Lightweight poll for burn-rate data only.
    func loadBurnRate() async {
        guard let client else { return }

        do {
            let response: APIResponse<BurnRateInfo> = try await client.get(
                "/consumption/burn-rate"
            )
            if let data = response.data, consumptionData != nil {
                // Update just the burn rate within the existing response by rebuilding
                let existing = consumptionData!
                consumptionData = ConsumptionDashboardResponse(
                    period: existing.period,
                    periodStart: existing.periodStart,
                    periodEnd: existing.periodEnd,
                    totalEstimatedTokens: existing.totalEstimatedTokens,
                    totalEstimatedCostUSD: existing.totalEstimatedCostUSD,
                    totalMessages: existing.totalMessages,
                    totalSessions: existing.totalSessions,
                    dailyConsumption: existing.dailyConsumption,
                    modelBreakdown: existing.modelBreakdown,
                    projectBreakdown: existing.projectBreakdown,
                    topSessionsByConsumption: existing.topSessionsByConsumption,
                    burnRate: data,
                    anomalies: existing.anomalies,
                    rateLimitStatus: existing.rateLimitStatus
                )
                AppLogger.shared.info(
                    "Updated burn rate: \(String(format: "%.1f", data.messagesPerHour)) msgs/hr",
                    category: "consumption"
                )
                checkAndScheduleConsumptionAlert()
            }
        } catch {
            AppLogger.shared.error(
                "Failed to load burn rate: \(error.localizedDescription)",
                category: "consumption"
            )
        }
    }

    /// Retry loading after an error.
    func retryLoad() async {
        await loadAll()
    }

    // MARK: - Alert Notifications

    /// Evaluates whether a consumption notification should be sent based on burn rate
    /// and projected exhaustion thresholds. Fires at most one notification per crossing.
    private func checkAndScheduleConsumptionAlert() {
        guard consumptionAlertsEnabled else {
            hasNotifiedBurnRate = false
            hasNotifiedExhaustion = false
            return
        }

        guard let burnRate = consumptionData?.burnRate else { return }

        // Check burn rate threshold
        if burnRate.messagesPerHour >= burnRateWarningThreshold {
            if !hasNotifiedBurnRate {
                hasNotifiedBurnRate = true
                scheduleConsumptionNotification(
                    title: "High Burn Rate",
                    body: String(
                        format: "Your consumption rate is %.1f msgs/hr, exceeding your %.1f msgs/hr threshold. Consider slowing down.",
                        burnRate.messagesPerHour,
                        burnRateWarningThreshold
                    ),
                    identifier: "consumption.burnRate.threshold"
                )
            }
        } else {
            hasNotifiedBurnRate = false
        }

        // Check exhaustion warning
        if let hoursRemaining = burnRate.projectedHoursRemaining,
           hoursRemaining <= Double(exhaustionWarningHours) {
            if !hasNotifiedExhaustion {
                hasNotifiedExhaustion = true
                let timeDesc = hoursRemaining < 1.0
                    ? "\(Int(hoursRemaining * 60)) minutes"
                    : String(format: "%.1f hours", hoursRemaining)
                scheduleConsumptionNotification(
                    title: "Rate Limit Exhaustion Warning",
                    body: "Projected ~\(timeDesc) remaining before rate limit exhaustion at current pace.",
                    identifier: "consumption.exhaustion.threshold"
                )
            }
        } else {
            hasNotifiedExhaustion = false
        }
    }

    /// Requests notification permission (if not yet granted) and fires an immediate local notification.
    private func scheduleConsumptionNotification(title: String, body: String, identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil // deliver immediately
            )
            center.add(request) { error in
                if let error {
                    AppLogger.shared.error(
                        "Failed to deliver consumption notification: \(error.localizedDescription)",
                        category: "consumption"
                    )
                }
            }
        }
    }
}
