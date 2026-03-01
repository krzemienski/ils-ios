import Foundation

// MARK: - Alert Metric Type

/// The system metric being monitored by an alert threshold.
enum AlertMetricType: String, Codable, CaseIterable, Sendable {
    case cpu = "cpu"
    case memory = "memory"
    case disk = "disk"
    case network = "network"

    var displayName: String {
        switch self {
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .disk: return "Disk Usage"
        case .network: return "Network Loss"
        }
    }

    var unit: String {
        switch self {
        case .cpu: return "%"
        case .memory: return "%"
        case .disk: return "%"
        case .network: return ""
        }
    }

    var defaultThreshold: Double {
        switch self {
        case .cpu: return 90.0
        case .memory: return 85.0
        case .disk: return 90.0
        case .network: return 0.0
        }
    }
}

// MARK: - Alert Condition

/// The comparison condition used to evaluate a threshold.
enum AlertCondition: String, Codable, CaseIterable, Sendable {
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case equalTo = "equalTo"

    var displayName: String {
        switch self {
        case .greaterThan: return "Greater than"
        case .lessThan: return "Less than"
        case .equalTo: return "Equal to"
        }
    }

    var symbol: String {
        switch self {
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .equalTo: return "="
        }
    }

    func evaluate(_ current: Double, against threshold: Double) -> Bool {
        switch self {
        case .greaterThan: return current > threshold
        case .lessThan: return current < threshold
        case .equalTo: return current == threshold
        }
    }
}

// MARK: - Snooze Duration

/// Duration options for snoozing an alert.
enum SnoozeDuration: String, Codable, CaseIterable, Sendable {
    case oneHour = "oneHour"
    case fourHours = "fourHours"
    case twentyFourHours = "twentyFourHours"

    var displayName: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .fourHours: return "4 Hours"
        case .twentyFourHours: return "24 Hours"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .oneHour: return 3600
        case .fourHours: return 14400
        case .twentyFourHours: return 86400
        }
    }
}

// MARK: - Alert Threshold

/// A configurable threshold rule for a system metric.
struct AlertThreshold: Identifiable, Codable, Equatable {
    let id: UUID
    /// The metric being monitored.
    var metricType: AlertMetricType
    /// The threshold value to compare against.
    var thresholdValue: Double
    /// The comparison condition.
    var condition: AlertCondition
    /// Minimum seconds between repeated alert notifications.
    var cooldownSeconds: TimeInterval
    /// Whether this alert is active.
    var isEnabled: Bool
    /// If non-nil, the date until which this alert is snoozed.
    var snoozedUntil: Date?

    /// Returns true if the alert is currently snoozed.
    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > Date()
    }

    /// Returns true if the alert is active (enabled and not snoozed).
    var isActive: Bool {
        isEnabled && !isSnoozed
    }

    init(
        id: UUID = UUID(),
        metricType: AlertMetricType,
        thresholdValue: Double,
        condition: AlertCondition = .greaterThan,
        cooldownSeconds: TimeInterval = 300,
        isEnabled: Bool = true,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.metricType = metricType
        self.thresholdValue = thresholdValue
        self.condition = condition
        self.cooldownSeconds = cooldownSeconds
        self.isEnabled = isEnabled
        self.snoozedUntil = snoozedUntil
    }

    /// Snooze this alert for the given duration.
    mutating func snooze(for duration: SnoozeDuration) {
        snoozedUntil = Date().addingTimeInterval(duration.seconds)
    }

    /// Clear any active snooze.
    mutating func clearSnooze() {
        snoozedUntil = nil
    }

    /// Check whether the given metric value triggers this threshold.
    func isTriggered(by value: Double) -> Bool {
        guard isActive else { return false }
        return condition.evaluate(value, against: thresholdValue)
    }

    static func == (lhs: AlertThreshold, rhs: AlertThreshold) -> Bool {
        lhs.id == rhs.id &&
        lhs.metricType == rhs.metricType &&
        lhs.thresholdValue == rhs.thresholdValue &&
        lhs.condition == rhs.condition &&
        lhs.cooldownSeconds == rhs.cooldownSeconds &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.snoozedUntil == rhs.snoozedUntil
    }
}

// MARK: - Alert Record

/// A historical record of a triggered alert.
struct AlertRecord: Identifiable, Codable, Equatable {
    let id: UUID
    /// The threshold that was triggered.
    let thresholdID: UUID
    /// The metric type at time of trigger.
    let metricType: AlertMetricType
    /// The metric value that triggered the alert.
    let triggeredValue: Double
    /// The threshold value at time of trigger.
    let thresholdValue: Double
    /// The condition that was met.
    let condition: AlertCondition
    /// When the alert was triggered.
    let timestamp: Date

    init(
        id: UUID = UUID(),
        thresholdID: UUID,
        metricType: AlertMetricType,
        triggeredValue: Double,
        thresholdValue: Double,
        condition: AlertCondition,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.thresholdID = thresholdID
        self.metricType = metricType
        self.triggeredValue = triggeredValue
        self.thresholdValue = thresholdValue
        self.condition = condition
        self.timestamp = timestamp
    }

    static func == (lhs: AlertRecord, rhs: AlertRecord) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Alert Preset

/// Named preset collections of alert thresholds for common use cases.
enum AlertPreset: String, CaseIterable {
    case developmentMachine = "Development Machine"
    case ciServer = "CI Server"
    case productionHost = "Production Host"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .developmentMachine:
            return "Balanced alerts for day-to-day development work"
        case .ciServer:
            return "High-utilization tolerant alerts for CI/CD pipelines"
        case .productionHost:
            return "Strict alerts for production reliability"
        }
    }

    /// Generates the default set of alert thresholds for this preset.
    func makeThresholds() -> [AlertThreshold] {
        switch self {
        case .developmentMachine:
            return [
                AlertThreshold(
                    metricType: .cpu,
                    thresholdValue: 90.0,
                    condition: .greaterThan,
                    cooldownSeconds: 300
                ),
                AlertThreshold(
                    metricType: .memory,
                    thresholdValue: 85.0,
                    condition: .greaterThan,
                    cooldownSeconds: 300
                ),
                AlertThreshold(
                    metricType: .disk,
                    thresholdValue: 90.0,
                    condition: .greaterThan,
                    cooldownSeconds: 3600
                ),
                AlertThreshold(
                    metricType: .network,
                    thresholdValue: 0.0,
                    condition: .equalTo,
                    cooldownSeconds: 60
                )
            ]

        case .ciServer:
            return [
                AlertThreshold(
                    metricType: .cpu,
                    thresholdValue: 95.0,
                    condition: .greaterThan,
                    cooldownSeconds: 600
                ),
                AlertThreshold(
                    metricType: .memory,
                    thresholdValue: 90.0,
                    condition: .greaterThan,
                    cooldownSeconds: 600
                ),
                AlertThreshold(
                    metricType: .disk,
                    thresholdValue: 85.0,
                    condition: .greaterThan,
                    cooldownSeconds: 1800
                ),
                AlertThreshold(
                    metricType: .network,
                    thresholdValue: 0.0,
                    condition: .equalTo,
                    cooldownSeconds: 120
                )
            ]

        case .productionHost:
            return [
                AlertThreshold(
                    metricType: .cpu,
                    thresholdValue: 80.0,
                    condition: .greaterThan,
                    cooldownSeconds: 120
                ),
                AlertThreshold(
                    metricType: .memory,
                    thresholdValue: 75.0,
                    condition: .greaterThan,
                    cooldownSeconds: 120
                ),
                AlertThreshold(
                    metricType: .disk,
                    thresholdValue: 80.0,
                    condition: .greaterThan,
                    cooldownSeconds: 900
                ),
                AlertThreshold(
                    metricType: .network,
                    thresholdValue: 0.0,
                    condition: .equalTo,
                    cooldownSeconds: 30
                )
            ]
        }
    }
}
