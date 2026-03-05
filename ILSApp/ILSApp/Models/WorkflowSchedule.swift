import Foundation

/// A schedule for automated workflow execution with cron-based triggers.
struct WorkflowSchedule: Codable, Identifiable {
    let id: UUID
    /// Associated workflow ID.
    let workflowId: UUID
    /// Cron expression for schedule (e.g., "0 0 * * *" for daily at midnight).
    var cron: String
    /// Whether the schedule is enabled.
    var enabled: Bool
    /// Optional timezone for schedule (defaults to UTC).
    var timezone: String?
    /// When the schedule was created.
    var createdAt: Date?
    /// When the schedule was last triggered.
    var lastTriggeredAt: Date?
    /// When the schedule will next trigger.
    var nextTriggerAt: Date?

    init(
        id: UUID = UUID(),
        workflowId: UUID,
        cron: String,
        enabled: Bool = true,
        timezone: String? = nil,
        createdAt: Date? = nil,
        lastTriggeredAt: Date? = nil,
        nextTriggerAt: Date? = nil
    ) {
        self.id = id
        self.workflowId = workflowId
        self.cron = cron
        self.enabled = enabled
        self.timezone = timezone
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
        self.nextTriggerAt = nextTriggerAt
    }

    /// User-friendly description of the schedule frequency.
    var frequencyDescription: String {
        // Parse common cron expressions
        let components = cron.split(separator: " ")
        guard components.count == 5 else {
            return "Custom schedule"
        }

        // Daily at midnight
        if cron == "0 0 * * *" {
            return "Daily at midnight"
        }
        // Hourly
        if cron == "0 * * * *" {
            return "Every hour"
        }
        // Weekly
        if cron == "0 0 * * 0" {
            return "Weekly on Sunday"
        }
        // Monthly
        if cron == "0 0 1 * *" {
            return "Monthly on the 1st"
        }

        return "Custom: \(cron)"
    }

    /// Whether this schedule is due to run soon (within 1 hour).
    var isDueSoon: Bool {
        guard enabled, let nextTriggerAt = nextTriggerAt else {
            return false
        }
        return nextTriggerAt.timeIntervalSinceNow < 3600 // 1 hour
    }

    /// Common cron presets for easy schedule creation.
    enum Preset: String, CaseIterable {
        case hourly = "0 * * * *"
        case daily = "0 0 * * *"
        case weekly = "0 0 * * 0"
        case monthly = "0 0 1 * *"

        var description: String {
            switch self {
            case .hourly: return "Every hour"
            case .daily: return "Daily at midnight"
            case .weekly: return "Weekly on Sunday"
            case .monthly: return "Monthly on the 1st"
            }
        }
    }
}
