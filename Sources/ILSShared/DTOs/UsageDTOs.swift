import Foundation

// MARK: - Usage Period

/// Time period for aggregating usage statistics.
public enum UsagePeriod: String, Codable, Sendable, CaseIterable {
    /// Daily aggregation (last 24 hours or current calendar day).
    case daily
    /// Weekly aggregation (last 7 days or current calendar week).
    case weekly
    /// Monthly aggregation (last 30 days or current calendar month).
    case monthly
}

// MARK: - Usage Export Format

/// Export format for usage reports.
public enum UsageExportFormat: String, Codable, Sendable, CaseIterable {
    /// Comma-separated values format.
    case csv
    /// JSON format.
    case json
}

// MARK: - Daily Usage

/// Usage statistics aggregated for a single calendar day.
public struct DailyUsage: Codable, Sendable, Identifiable {
    /// The calendar date for this usage record (ISO 8601 date string, e.g. "2026-03-01").
    public let date: String
    /// Total number of messages sent on this day.
    public let messageCount: Int
    /// Total number of sessions active on this day.
    public let sessionCount: Int
    /// Total duration of all sessions in seconds.
    public let totalDurationSeconds: Int

    /// Stable identifier using the date string.
    public var id: String { date }

    public init(
        date: String,
        messageCount: Int,
        sessionCount: Int,
        totalDurationSeconds: Int
    ) {
        precondition(!date.isEmpty, "DailyUsage date must not be empty")
        precondition(messageCount >= 0, "DailyUsage messageCount must be non-negative")
        precondition(sessionCount >= 0, "DailyUsage sessionCount must be non-negative")
        precondition(totalDurationSeconds >= 0, "DailyUsage totalDurationSeconds must be non-negative")
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.totalDurationSeconds = totalDurationSeconds
    }
}

// MARK: - Project Usage

/// Usage statistics broken down by project for a given period.
public struct ProjectUsage: Codable, Sendable, Identifiable {
    /// Project name (used as identifier).
    public let projectName: String
    /// Total number of messages sent in this project.
    public let messageCount: Int
    /// Total number of sessions in this project.
    public let sessionCount: Int
    /// Total duration of all sessions in seconds.
    public let totalDurationSeconds: Int
    /// Percentage of total usage attributed to this project (0–100).
    public let percentageOfTotal: Double

    /// Stable identifier using project name.
    public var id: String { projectName }

    public init(
        projectName: String,
        messageCount: Int,
        sessionCount: Int,
        totalDurationSeconds: Int,
        percentageOfTotal: Double
    ) {
        precondition(!projectName.isEmpty, "ProjectUsage projectName must not be empty")
        precondition(messageCount >= 0, "ProjectUsage messageCount must be non-negative")
        precondition(sessionCount >= 0, "ProjectUsage sessionCount must be non-negative")
        precondition(totalDurationSeconds >= 0, "ProjectUsage totalDurationSeconds must be non-negative")
        precondition(
            (0.0...100.0).contains(percentageOfTotal),
            "ProjectUsage percentageOfTotal must be between 0 and 100"
        )
        self.projectName = projectName
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.totalDurationSeconds = totalDurationSeconds
        self.percentageOfTotal = percentageOfTotal
    }
}

// MARK: - Rate Limit Status

/// Current rate limit consumption for the Claude Code rate limiting window.
///
/// Claude Pro accounts have a shared rate limit (approximately 45 messages per
/// 5-hour window). This struct surfaces how much of that budget has been consumed
/// so the user can plan accordingly.
public struct RateLimitStatus: Codable, Sendable {
    /// Number of messages sent in the current rate-limit window.
    public let messagesUsed: Int
    /// Maximum messages allowed in the current rate-limit window.
    public let messagesLimit: Int
    /// Number of messages remaining before the rate limit is hit.
    public var messagesRemaining: Int { max(0, messagesLimit - messagesUsed) }
    /// Fraction of the rate limit consumed (0.0–1.0).
    public var consumptionFraction: Double {
        guard messagesLimit > 0 else { return 0.0 }
        return min(1.0, Double(messagesUsed) / Double(messagesLimit))
    }
    /// ISO 8601 timestamp when the current rate-limit window resets.
    public let windowResetsAt: String?
    /// Duration of the rate-limit window in seconds (e.g. 18000 for 5 hours).
    public let windowDurationSeconds: Int

    public init(
        messagesUsed: Int,
        messagesLimit: Int,
        windowResetsAt: String? = nil,
        windowDurationSeconds: Int = 18_000
    ) {
        precondition(messagesUsed >= 0, "RateLimitStatus messagesUsed must be non-negative")
        precondition(messagesLimit > 0, "RateLimitStatus messagesLimit must be positive")
        precondition(windowDurationSeconds > 0, "RateLimitStatus windowDurationSeconds must be positive")
        self.messagesUsed = messagesUsed
        self.messagesLimit = messagesLimit
        self.windowResetsAt = windowResetsAt
        self.windowDurationSeconds = windowDurationSeconds
    }
}

// MARK: - Usage Metrics Response

/// Aggregated usage metrics response returned by the usage dashboard endpoint.
///
/// Combines period totals, daily trend data, per-project breakdown, and current
/// rate-limit status into a single response optimised for the dashboard view.
public struct UsageMetrics: Codable, Sendable {
    /// The time period these metrics cover.
    public let period: UsagePeriod
    /// ISO 8601 date string for the start of the reporting window.
    public let periodStart: String
    /// ISO 8601 date string for the end of the reporting window.
    public let periodEnd: String
    /// Total messages sent within the reporting period.
    public let totalMessages: Int
    /// Total sessions within the reporting period.
    public let totalSessions: Int
    /// Average messages per session within the reporting period.
    public let averageMessagesPerSession: Double
    /// Total session duration in seconds within the reporting period.
    public let totalDurationSeconds: Int
    /// Day-by-day usage breakdown for trend graphs.
    public let dailyBreakdown: [DailyUsage]
    /// Per-project usage breakdown, sorted by message count descending.
    public let projectBreakdown: [ProjectUsage]
    /// Current rate-limit window status.
    public let rateLimitStatus: RateLimitStatus

    public init(
        period: UsagePeriod,
        periodStart: String,
        periodEnd: String,
        totalMessages: Int,
        totalSessions: Int,
        averageMessagesPerSession: Double,
        totalDurationSeconds: Int,
        dailyBreakdown: [DailyUsage],
        projectBreakdown: [ProjectUsage],
        rateLimitStatus: RateLimitStatus
    ) {
        precondition(!periodStart.isEmpty, "UsageMetrics periodStart must not be empty")
        precondition(!periodEnd.isEmpty, "UsageMetrics periodEnd must not be empty")
        precondition(totalMessages >= 0, "UsageMetrics totalMessages must be non-negative")
        precondition(totalSessions >= 0, "UsageMetrics totalSessions must be non-negative")
        precondition(averageMessagesPerSession >= 0, "UsageMetrics averageMessagesPerSession must be non-negative")
        precondition(totalDurationSeconds >= 0, "UsageMetrics totalDurationSeconds must be non-negative")
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalMessages = totalMessages
        self.totalSessions = totalSessions
        self.averageMessagesPerSession = averageMessagesPerSession
        self.totalDurationSeconds = totalDurationSeconds
        self.dailyBreakdown = dailyBreakdown
        self.projectBreakdown = projectBreakdown
        self.rateLimitStatus = rateLimitStatus
    }
}
