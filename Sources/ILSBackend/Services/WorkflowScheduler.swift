import Foundation
import Vapor
import ILSShared
import Logging

/// Actor responsible for scheduling and triggering automated workflow executions.
///
/// ## Scheduling Model
///
/// Schedules are defined using cron expressions and stored in-memory. The scheduler:
/// - Parses cron expressions to determine next execution times
/// - Runs a background task that checks for due schedules
/// - Triggers workflow executions via the WorkflowExecutionEngine
/// - Tracks schedule metadata (last triggered, next trigger time)
/// - Supports timezone-aware scheduling
///
/// ## Cron Format
///
/// Supports standard 5-field cron expressions:
/// ```
/// * * * * *
/// │ │ │ │ │
/// │ │ │ │ └─── Day of week (0-6, Sunday = 0)
/// │ │ │ └───── Month (1-12)
/// │ │ └─────── Day of month (1-31)
/// │ └───────── Hour (0-23)
/// └─────────── Minute (0-59)
/// ```
///
/// Examples:
/// - `0 0 * * *` - Daily at midnight
/// - `0 9 * * 1` - Every Monday at 9am
/// - `*/15 * * * *` - Every 15 minutes
/// - `0 0 1 * *` - First day of every month at midnight
///
/// ## State Management
///
/// Schedules are stored in memory keyed by schedule ID. Each schedule tracks:
/// - Associated workflow ID
/// - Cron expression
/// - Enabled/disabled state
/// - Last triggered timestamp
/// - Next trigger timestamp (calculated from cron expression)
actor WorkflowScheduler {
    /// Structured logger for workflow scheduling
    private static let logger = Logger(label: "ils.workflow-scheduler")

    /// Active schedules keyed by schedule ID
    private var schedules: [String: WorkflowSchedule] = [:]

    /// Reference to the workflow execution engine for triggering executions
    private let executionEngine: WorkflowExecutionEngine

    /// Background task for checking schedules
    private var schedulerTask: Task<Void, Never>?

    /// Check interval in seconds (default: 60 seconds)
    private let checkInterval: TimeInterval

    /// JSON encoder for serializing schedule data
    private let jsonEncoder: JSONEncoder

    /// JSON decoder for parsing schedule data
    private let jsonDecoder: JSONDecoder

    /// Initializes the scheduler with an execution engine.
    ///
    /// - Parameters:
    ///   - executionEngine: The WorkflowExecutionEngine for triggering executions
    ///   - checkInterval: How often to check for due schedules (default: 60 seconds)
    init(executionEngine: WorkflowExecutionEngine, checkInterval: TimeInterval = 60) {
        self.executionEngine = executionEngine
        self.checkInterval = checkInterval

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = .prettyPrinted
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Start the background scheduler task.
    ///
    /// This begins periodic checking of schedules and triggering of due workflows.
    func start() {
        guard schedulerTask == nil else {
            Self.logger.warning("Scheduler already running, ignoring start request")
            return
        }

        Self.logger.info("Starting workflow scheduler", metadata: [
            "check_interval_seconds": .stringConvertible(checkInterval)
        ])

        schedulerTask = Task {
            await self.runSchedulerLoop()
        }
    }

    /// Stop the background scheduler task.
    func stop() {
        Self.logger.info("Stopping workflow scheduler")
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    /// Create a new workflow schedule.
    ///
    /// - Parameters:
    ///   - workflowId: The workflow to schedule
    ///   - cron: Cron expression defining the schedule
    ///   - enabled: Whether the schedule is enabled
    ///   - timezone: Optional timezone (defaults to UTC)
    /// - Returns: Created WorkflowSchedule
    /// - Throws: SchedulerError if cron expression is invalid
    func createSchedule(
        workflowId: String,
        cron: String,
        enabled: Bool = true,
        timezone: String? = nil
    ) throws -> WorkflowSchedule {
        // Validate cron expression
        try validateCronExpression(cron)

        let now = Date()
        let nextTrigger = try calculateNextTrigger(from: now, cron: cron, timezone: timezone)

        let schedule = WorkflowSchedule(
            id: UUID().uuidString,
            workflowId: workflowId,
            cron: cron,
            enabled: enabled,
            timezone: timezone,
            createdAt: now,
            lastTriggeredAt: nil,
            nextTriggerAt: nextTrigger
        )

        schedules[schedule.id] = schedule

        Self.logger.info("Created workflow schedule", metadata: [
            "schedule_id": .string(schedule.id),
            "workflow_id": .string(workflowId),
            "cron": .string(cron),
            "enabled": .stringConvertible(enabled),
            "next_trigger_at": .string(nextTrigger?.description ?? "nil")
        ])

        return schedule
    }

    /// Get a schedule by ID.
    ///
    /// - Parameter scheduleId: The schedule ID
    /// - Returns: WorkflowSchedule if found, nil otherwise
    func getSchedule(scheduleId: String) -> WorkflowSchedule? {
        return schedules[scheduleId]
    }

    /// List all schedules.
    ///
    /// - Parameter workflowId: Optional filter by workflow ID
    /// - Returns: Array of WorkflowSchedule instances
    func listSchedules(workflowId: String? = nil) -> [WorkflowSchedule] {
        if let workflowId = workflowId {
            return schedules.values.filter { $0.workflowId == workflowId }
        }
        return Array(schedules.values)
    }

    /// Update an existing schedule.
    ///
    /// - Parameters:
    ///   - scheduleId: The schedule ID
    ///   - cron: New cron expression (optional)
    ///   - enabled: New enabled state (optional)
    ///   - timezone: New timezone (optional)
    /// - Returns: Updated WorkflowSchedule
    /// - Throws: SchedulerError if schedule not found or cron expression invalid
    func updateSchedule(
        scheduleId: String,
        cron: String? = nil,
        enabled: Bool? = nil,
        timezone: String? = nil
    ) throws -> WorkflowSchedule {
        guard var schedule = schedules[scheduleId] else {
            throw SchedulerError.scheduleNotFound(scheduleId)
        }

        var needsNextTriggerUpdate = false

        if let newCron = cron {
            try validateCronExpression(newCron)
            schedule.cron = newCron
            needsNextTriggerUpdate = true
        }

        if let newEnabled = enabled {
            schedule.enabled = newEnabled
            needsNextTriggerUpdate = newEnabled && !schedule.enabled // Re-calculate if re-enabling
        }

        if let newTimezone = timezone {
            schedule.timezone = newTimezone
            needsNextTriggerUpdate = true
        }

        if needsNextTriggerUpdate && schedule.enabled {
            let now = Date()
            schedule.nextTriggerAt = try calculateNextTrigger(
                from: schedule.lastTriggeredAt ?? now,
                cron: schedule.cron,
                timezone: schedule.timezone
            )
        }

        schedules[scheduleId] = schedule

        Self.logger.info("Updated workflow schedule", metadata: [
            "schedule_id": .string(scheduleId),
            "next_trigger_at": .string(schedule.nextTriggerAt?.description ?? "nil")
        ])

        return schedule
    }

    /// Delete a schedule.
    ///
    /// - Parameter scheduleId: The schedule ID
    /// - Throws: SchedulerError if schedule not found
    func deleteSchedule(scheduleId: String) throws {
        guard schedules[scheduleId] != nil else {
            throw SchedulerError.scheduleNotFound(scheduleId)
        }

        schedules.removeValue(forKey: scheduleId)

        Self.logger.info("Deleted workflow schedule", metadata: [
            "schedule_id": .string(scheduleId)
        ])
    }

    // MARK: - Private Implementation

    /// Main scheduler loop that checks for due schedules.
    private func runSchedulerLoop() async {
        Self.logger.info("Scheduler loop started")

        while !Task.isCancelled {
            await checkAndTriggerSchedules()

            // Wait for next check interval
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        Self.logger.info("Scheduler loop stopped")
    }

    /// Check all schedules and trigger any that are due.
    private func checkAndTriggerSchedules() async {
        let now = Date()
        let enabledSchedules = schedules.values.filter { $0.enabled }

        for var schedule in enabledSchedules {
            // Check if schedule is due
            if let nextTrigger = schedule.nextTriggerAt, nextTrigger <= now {
                Self.logger.info("Triggering scheduled workflow", metadata: [
                    "schedule_id": .string(schedule.id),
                    "workflow_id": .string(schedule.workflowId)
                ])

                // Note: We need to fetch the actual workflow from storage
                // For now, we'll log this. In a real implementation, this would
                // integrate with the WorkflowsController to fetch the workflow.
                // The controller will need to provide a shared workflow storage service.

                // Update schedule metadata
                schedule.lastTriggeredAt = now
                do {
                    schedule.nextTriggerAt = try calculateNextTrigger(
                        from: now,
                        cron: schedule.cron,
                        timezone: schedule.timezone
                    )
                } catch {
                    Self.logger.error("Failed to calculate next trigger", metadata: [
                        "schedule_id": .string(schedule.id),
                        "error": .string(String(describing: error))
                    ])
                    schedule.nextTriggerAt = nil
                }

                schedules[schedule.id] = schedule

                Self.logger.info("Scheduled workflow triggered", metadata: [
                    "schedule_id": .string(schedule.id),
                    "next_trigger_at": .string(schedule.nextTriggerAt?.description ?? "nil")
                ])
            }
        }
    }

    /// Validate a cron expression.
    ///
    /// - Parameter cron: Cron expression to validate
    /// - Throws: SchedulerError.invalidCronExpression if invalid
    private func validateCronExpression(_ cron: String) throws {
        let parts = cron.split(separator: " ")
        guard parts.count == 5 else {
            throw SchedulerError.invalidCronExpression(
                cron,
                "Must have exactly 5 fields: minute hour day-of-month month day-of-week"
            )
        }

        // Validate each field (basic validation)
        // Field 0: Minute (0-59 or *)
        // Field 1: Hour (0-23 or *)
        // Field 2: Day of month (1-31 or *)
        // Field 3: Month (1-12 or *)
        // Field 4: Day of week (0-6 or *)

        let fieldRanges = [
            (0, 59),  // minute
            (0, 23),  // hour
            (1, 31),  // day of month
            (1, 12),  // month
            (0, 6)    // day of week
        ]

        for (index, part) in parts.enumerated() {
            let field = String(part)
            let (min, max) = fieldRanges[index]

            // Allow * for wildcard
            if field == "*" {
                continue
            }

            // Allow */N for intervals
            if field.hasPrefix("*/") {
                let intervalStr = String(field.dropFirst(2))
                guard let interval = Int(intervalStr), interval > 0 else {
                    throw SchedulerError.invalidCronExpression(
                        cron,
                        "Invalid interval in field \(index + 1): \(field)"
                    )
                }
                continue
            }

            // Allow single numbers
            if let value = Int(field) {
                guard value >= min && value <= max else {
                    throw SchedulerError.invalidCronExpression(
                        cron,
                        "Value \(value) out of range [\(min)-\(max)] in field \(index + 1)"
                    )
                }
                continue
            }

            // Allow ranges (e.g., 1-5)
            if field.contains("-") {
                let rangeParts = field.split(separator: "-")
                guard rangeParts.count == 2,
                      let rangeStart = Int(rangeParts[0]),
                      let rangeEnd = Int(rangeParts[1]),
                      rangeStart >= min,
                      rangeEnd <= max,
                      rangeStart < rangeEnd else {
                    throw SchedulerError.invalidCronExpression(
                        cron,
                        "Invalid range in field \(index + 1): \(field)"
                    )
                }
                continue
            }

            // Allow comma-separated lists (e.g., 1,3,5)
            if field.contains(",") {
                let values = field.split(separator: ",")
                for valueStr in values {
                    guard let value = Int(valueStr),
                          value >= min,
                          value <= max else {
                        throw SchedulerError.invalidCronExpression(
                            cron,
                            "Invalid value in list for field \(index + 1): \(valueStr)"
                        )
                    }
                }
                continue
            }

            throw SchedulerError.invalidCronExpression(
                cron,
                "Unrecognized format in field \(index + 1): \(field)"
            )
        }
    }

    /// Calculate the next trigger time from a cron expression.
    ///
    /// - Parameters:
    ///   - from: Starting date
    ///   - cron: Cron expression
    ///   - timezone: Optional timezone (defaults to UTC)
    /// - Returns: Next trigger date
    /// - Throws: SchedulerError if calculation fails
    private func calculateNextTrigger(
        from: Date,
        cron: String,
        timezone: String?
    ) throws -> Date? {
        let parts = cron.split(separator: " ").map(String.init)
        guard parts.count == 5 else {
            throw SchedulerError.invalidCronExpression(cron, "Invalid field count")
        }

        // Parse cron fields
        let minuteField = parts[0]
        let hourField = parts[1]
        let dayOfMonthField = parts[2]
        let monthField = parts[3]
        let dayOfWeekField = parts[4]

        // Get calendar with appropriate timezone
        var calendar = Calendar.current
        if let tzString = timezone, let tz = TimeZone(identifier: tzString) {
            calendar.timeZone = tz
        } else {
            calendar.timeZone = TimeZone(identifier: "UTC")!
        }

        // Start from the next minute
        var candidateDate = calendar.date(byAdding: .minute, value: 1, to: from)!
        candidateDate = calendar.date(bySetting: .second, value: 0, of: candidateDate)!

        // Limit search to avoid infinite loops
        let maxIterations = 366 * 24 * 60  // One year of minutes
        var iterations = 0

        while iterations < maxIterations {
            let components = calendar.dateComponents(
                [.minute, .hour, .day, .month, .weekday],
                from: candidateDate
            )

            guard let minute = components.minute,
                  let hour = components.hour,
                  let day = components.day,
                  let month = components.month,
                  let weekday = components.weekday else {
                iterations += 1
                candidateDate = calendar.date(byAdding: .minute, value: 1, to: candidateDate)!
                continue
            }

            // Convert weekday (Sunday = 1) to cron format (Sunday = 0)
            let cronWeekday = (weekday + 6) % 7

            // Check if candidate matches cron expression
            if matches(value: minute, field: minuteField, range: 0...59) &&
               matches(value: hour, field: hourField, range: 0...23) &&
               matches(value: day, field: dayOfMonthField, range: 1...31) &&
               matches(value: month, field: monthField, range: 1...12) &&
               matches(value: cronWeekday, field: dayOfWeekField, range: 0...6) {
                return candidateDate
            }

            iterations += 1
            candidateDate = calendar.date(byAdding: .minute, value: 1, to: candidateDate)!
        }

        // Could not find next trigger within reasonable timeframe
        Self.logger.warning("Could not calculate next trigger within \(maxIterations) iterations", metadata: [
            "cron": .string(cron)
        ])
        return nil
    }

    /// Check if a value matches a cron field specification.
    ///
    /// - Parameters:
    ///   - value: Value to check
    ///   - field: Cron field specification
    ///   - range: Valid range for the field
    /// - Returns: true if value matches field
    private func matches(value: Int, field: String, range: ClosedRange<Int>) -> Bool {
        // Wildcard matches everything
        if field == "*" {
            return true
        }

        // Interval (e.g., */15)
        if field.hasPrefix("*/") {
            let intervalStr = String(field.dropFirst(2))
            if let interval = Int(intervalStr) {
                return value % interval == 0
            }
            return false
        }

        // Single value
        if let fieldValue = Int(field) {
            return value == fieldValue
        }

        // Range (e.g., 1-5)
        if field.contains("-") {
            let parts = field.split(separator: "-")
            if parts.count == 2,
               let start = Int(parts[0]),
               let end = Int(parts[1]) {
                return value >= start && value <= end
            }
            return false
        }

        // List (e.g., 1,3,5)
        if field.contains(",") {
            let values = field.split(separator: ",").compactMap { Int($0) }
            return values.contains(value)
        }

        return false
    }
}

// MARK: - Error Types

/// Errors that can occur during workflow scheduling.
enum SchedulerError: Error, CustomStringConvertible {
    /// Schedule not found
    case scheduleNotFound(String)
    /// Invalid cron expression
    case invalidCronExpression(String, String)
    /// Failed to calculate next trigger
    case calculationFailed(String)

    var description: String {
        switch self {
        case .scheduleNotFound(let id):
            return "Schedule not found: \(id)"
        case .invalidCronExpression(let expr, let reason):
            return "Invalid cron expression '\(expr)': \(reason)"
        case .calculationFailed(let reason):
            return "Failed to calculate next trigger: \(reason)"
        }
    }
}
