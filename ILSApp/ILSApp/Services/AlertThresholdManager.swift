import Foundation
import Observation
import UserNotifications

// MARK: - AlertThresholdManager

/// Manages configurable threshold-based alerts for system metrics.
///
/// Evaluates incoming system metrics against user-defined thresholds and fires
/// push notifications when conditions are met. Respects per-threshold cooldown
/// periods and snooze state. Persists both thresholds and alert history to
/// UserDefaults (JSON-encoded).
///
/// ## Usage
/// ```swift
/// // Evaluate metrics on each update
/// AlertThresholdManager.shared.evaluate(metrics: latestMetrics)
///
/// // Apply a preset
/// AlertThresholdManager.shared.applyPreset(.developmentMachine)
///
/// // Snooze a threshold
/// AlertThresholdManager.shared.snoozeThreshold(id: threshold.id, for: .oneHour)
/// ```
///
/// Uses @Observable for zero-overhead SwiftUI integration, matching the
/// NetworkMonitor/LowPowerModeMonitor singleton pattern.
@MainActor
@Observable
final class AlertThresholdManager {
    static let shared = AlertThresholdManager()

    // MARK: - Observable State

    private(set) var thresholds: [AlertThreshold] = []
    private(set) var alertHistory: [AlertRecord] = []

    // MARK: - Private State

    @ObservationIgnored private var lastAlertTimes: [UUID: Date] = [:]

    @ObservationIgnored private let thresholdsKey = "alertThresholds_v1"
    @ObservationIgnored private let historyKey = "alertHistory_v1"
    @ObservationIgnored private let maxHistoryCount = 200

    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    // MARK: - Init

    private init() {
        loadThresholds()
        loadAlertHistory()
        AppLogger.shared.info(
            "AlertThresholdManager started (\(thresholds.count) thresholds)",
            category: "alerts"
        )
    }

    // MARK: - Threshold Persistence

    /// Load thresholds from UserDefaults. Called on init and can be called to refresh.
    func loadThresholds() {
        guard
            let data = UserDefaults.standard.data(forKey: thresholdsKey),
            let decoded = try? decoder.decode([AlertThreshold].self, from: data)
        else {
            thresholds = []
            return
        }
        thresholds = decoded
    }

    private func saveThresholds() {
        guard let data = try? encoder.encode(thresholds) else {
            AppLogger.shared.warning("Failed to encode thresholds for persistence", category: "alerts")
            return
        }
        UserDefaults.standard.set(data, forKey: thresholdsKey)
    }

    // MARK: - History Persistence

    private func loadAlertHistory() {
        guard
            let data = UserDefaults.standard.data(forKey: historyKey),
            let decoded = try? decoder.decode([AlertRecord].self, from: data)
        else {
            alertHistory = []
            return
        }
        alertHistory = decoded
    }

    private func saveAlertHistory() {
        guard let data = try? encoder.encode(alertHistory) else {
            AppLogger.shared.warning("Failed to encode alert history for persistence", category: "alerts")
            return
        }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    // MARK: - Threshold Management

    /// Add a new threshold rule.
    func addThreshold(_ threshold: AlertThreshold) {
        thresholds.append(threshold)
        saveThresholds()
    }

    /// Update an existing threshold rule by ID.
    func updateThreshold(_ threshold: AlertThreshold) {
        guard let index = thresholds.firstIndex(where: { $0.id == threshold.id }) else { return }
        thresholds[index] = threshold
        saveThresholds()
    }

    /// Remove a threshold rule by ID.
    func removeThreshold(id: UUID) {
        thresholds.removeAll { $0.id == id }
        lastAlertTimes.removeValue(forKey: id)
        saveThresholds()
    }

    /// Replace all thresholds with those from a named preset.
    func applyPreset(_ preset: AlertPreset) {
        thresholds = preset.makeThresholds()
        lastAlertTimes.removeAll()
        saveThresholds()
        AppLogger.shared.info("Applied alert preset: \(preset.displayName)", category: "alerts")
    }

    /// Snooze a threshold for the given duration.
    func snoozeThreshold(id: UUID, for duration: SnoozeDuration) {
        guard let index = thresholds.firstIndex(where: { $0.id == id }) else { return }
        thresholds[index].snooze(for: duration)
        saveThresholds()
        AppLogger.shared.info(
            "Snoozed threshold \(id) for \(duration.displayName)",
            category: "alerts"
        )
    }

    /// Clear snooze for a threshold, allowing it to fire again.
    func clearSnooze(id: UUID) {
        guard let index = thresholds.firstIndex(where: { $0.id == id }) else { return }
        thresholds[index].clearSnooze()
        saveThresholds()
    }

    /// Remove all alert history records.
    func clearHistory() {
        alertHistory.removeAll()
        saveAlertHistory()
    }

    // MARK: - Evaluation

    /// Evaluate current system metrics against all active thresholds.
    ///
    /// For each enabled, non-snoozed threshold that passes cooldown, fires a
    /// push notification and appends an `AlertRecord` to `alertHistory`.
    ///
    /// - Parameter metrics: The latest `SystemMetricsResponse` snapshot.
    func evaluate(metrics: SystemMetricsResponse) {
        let now = Date()
        // Network connectivity represented as 1.0 (connected) or 0.0 (disconnected).
        // Preset uses condition `.equalTo` with threshold 0.0 to detect connectivity loss.
        let networkValue: Double = NetworkMonitor.shared.isConnected ? 1.0 : 0.0

        for threshold in thresholds {
            guard threshold.isActive else { continue }

            let currentValue: Double
            switch threshold.metricType {
            case .cpu:
                currentValue = metrics.cpu
            case .memory:
                currentValue = metrics.memory.percentage
            case .disk:
                currentValue = metrics.disk.percentage
            case .network:
                currentValue = networkValue
            }

            // Check condition
            guard threshold.condition.evaluate(currentValue, against: threshold.thresholdValue) else {
                continue
            }

            // Cooldown: skip if we've fired this alert recently
            if let lastFired = lastAlertTimes[threshold.id],
               now.timeIntervalSince(lastFired) < threshold.cooldownSeconds {
                continue
            }

            // Fire notification, record alert, update cooldown timestamp
            fireNotification(for: threshold, currentValue: currentValue)
            recordAlert(threshold: threshold, value: currentValue, at: now)
            lastAlertTimes[threshold.id] = now
        }
    }

    // MARK: - Notification

    private func fireNotification(for threshold: AlertThreshold, currentValue: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(threshold.metricType.displayName) Alert"
        content.body = notificationBody(for: threshold, currentValue: currentValue)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "alert.\(threshold.id.uuidString).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Task { @MainActor in
                    AppLogger.shared.error(
                        "Failed to schedule alert notification: \(error.localizedDescription)",
                        category: "alerts"
                    )
                }
            }
        }

        AppLogger.shared.info(
            "Alert fired: \(threshold.metricType.displayName) \(threshold.condition.symbol) \(threshold.thresholdValue)\(threshold.metricType.unit) (current: \(String(format: "%.1f", currentValue))\(threshold.metricType.unit))",
            category: "alerts"
        )
    }

    private func notificationBody(for threshold: AlertThreshold, currentValue: Double) -> String {
        if threshold.metricType == .network {
            return "Network connectivity has been lost."
        }
        let value = String(format: "%.1f", currentValue)
        let thresholdStr = String(format: "%.1f", threshold.thresholdValue)
        let unit = threshold.metricType.unit
        let conditionText = threshold.condition.displayName.lowercased()
        return "\(threshold.metricType.displayName) is at \(value)\(unit), \(conditionText) the \(thresholdStr)\(unit) threshold."
    }

    // MARK: - History

    private func recordAlert(threshold: AlertThreshold, value: Double, at date: Date) {
        let record = AlertRecord(
            thresholdID: threshold.id,
            metricType: threshold.metricType,
            triggeredValue: value,
            thresholdValue: threshold.thresholdValue,
            condition: threshold.condition,
            timestamp: date
        )

        // Prepend so newest is first; cap at maxHistoryCount to bound memory usage
        alertHistory.insert(record, at: 0)
        if alertHistory.count > maxHistoryCount {
            alertHistory = Array(alertHistory.prefix(maxHistoryCount))
        }

        saveAlertHistory()
    }
}
