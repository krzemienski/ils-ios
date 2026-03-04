import Foundation

// MARK: - Activity Timeline

/// A single data point in a project activity timeline.
public struct ActivityDataPoint: Codable, Sendable, Identifiable {
    /// Unique identifier for this data point.
    public var id: String { date }
    /// ISO-8601 date string for this data point.
    public let date: String
    /// Number of sessions on this date.
    public let sessionCount: Int
    /// Number of messages exchanged on this date.
    public let messageCount: Int
    /// Total tokens used on this date.
    public let tokensUsed: Int

    public init(date: String, sessionCount: Int, messageCount: Int, tokensUsed: Int) {
        self.date = date
        self.sessionCount = sessionCount
        self.messageCount = messageCount
        self.tokensUsed = tokensUsed
    }
}

/// Activity timeline response for a project over a date range.
public struct ActivityTimelineResponse: Codable, Sendable {
    /// Project name the timeline belongs to.
    public let projectName: String
    /// Ordered list of activity data points.
    public let dataPoints: [ActivityDataPoint]
    /// Start of the date range (ISO-8601).
    public let startDate: String
    /// End of the date range (ISO-8601).
    public let endDate: String
    /// Granularity of data points (e.g., "day", "week", "month").
    public let granularity: String

    public init(
        projectName: String,
        dataPoints: [ActivityDataPoint],
        startDate: String,
        endDate: String,
        granularity: String
    ) {
        self.projectName = projectName
        self.dataPoints = dataPoints
        self.startDate = startDate
        self.endDate = endDate
        self.granularity = granularity
    }
}

// MARK: - Model Usage

/// Usage statistics for a single AI model.
public struct ModelUsageStat: Codable, Sendable, Identifiable {
    /// Model identifier (used as unique key).
    public var id: String { model }
    /// Model name (e.g., "claude-opus-4-5", "claude-sonnet-4-5").
    public let model: String
    /// Number of sessions that used this model.
    public let sessionCount: Int
    /// Total messages sent using this model.
    public let messageCount: Int
    /// Total tokens consumed by this model.
    public let tokensUsed: Int
    /// Percentage of total usage attributed to this model.
    public let usagePercentage: Double

    public init(
        model: String,
        sessionCount: Int,
        messageCount: Int,
        tokensUsed: Int,
        usagePercentage: Double
    ) {
        self.model = model
        self.sessionCount = sessionCount
        self.messageCount = messageCount
        self.tokensUsed = tokensUsed
        self.usagePercentage = usagePercentage
    }
}

// MARK: - Session Metrics

/// Aggregated session effectiveness metrics for a project.
public struct SessionMetricsResponse: Codable, Sendable {
    /// Project name these metrics belong to.
    public let projectName: String
    /// Total number of sessions analyzed.
    public let totalSessions: Int
    /// Average number of messages per session.
    public let avgMessagesPerSession: Double
    /// Average session duration in seconds.
    public let avgSessionDurationSeconds: Double
    /// Number of sessions that ended with a successful completion.
    public let completedSessions: Int
    /// Number of sessions that were abandoned or interrupted.
    public let abandonedSessions: Int
    /// Completion rate as a percentage (0–100).
    public let completionRate: Double
    /// Average number of iterations (edits/retries) per session.
    public let avgIterationsPerSession: Double
    /// Usage breakdown by model.
    public let modelUsage: [ModelUsageStat]

    public init(
        projectName: String,
        totalSessions: Int,
        avgMessagesPerSession: Double,
        avgSessionDurationSeconds: Double,
        completedSessions: Int,
        abandonedSessions: Int,
        completionRate: Double,
        avgIterationsPerSession: Double,
        modelUsage: [ModelUsageStat]
    ) {
        self.projectName = projectName
        self.totalSessions = totalSessions
        self.avgMessagesPerSession = avgMessagesPerSession
        self.avgSessionDurationSeconds = avgSessionDurationSeconds
        self.completedSessions = completedSessions
        self.abandonedSessions = abandonedSessions
        self.completionRate = completionRate
        self.avgIterationsPerSession = avgIterationsPerSession
        self.modelUsage = modelUsage
    }
}

// MARK: - Skill Analytics

/// Usage statistics for a single skill.
public struct SkillUsageStat: Codable, Sendable, Identifiable {
    /// Skill name (used as unique key).
    public var id: String { skillName }
    /// Display name of the skill.
    public let skillName: String
    /// Number of times this skill was invoked.
    public let invocationCount: Int
    /// Number of sessions that used this skill.
    public let sessionCount: Int
    /// Percentage of sessions that used this skill out of all sessions.
    public let usagePercentage: Double
    /// Average effectiveness rating (0–5), if available.
    public let avgEffectivenessRating: Double?

    public init(
        skillName: String,
        invocationCount: Int,
        sessionCount: Int,
        usagePercentage: Double,
        avgEffectivenessRating: Double? = nil
    ) {
        self.skillName = skillName
        self.invocationCount = invocationCount
        self.sessionCount = sessionCount
        self.usagePercentage = usagePercentage
        self.avgEffectivenessRating = avgEffectivenessRating
    }
}

/// Skill analytics response containing usage statistics across all skills.
public struct SkillAnalyticsResponse: Codable, Sendable {
    /// Project name these analytics belong to.
    public let projectName: String
    /// Total number of sessions analyzed.
    public let totalSessions: Int
    /// Skill usage stats ordered by invocation count descending.
    public let skillStats: [SkillUsageStat]
    /// Date range start (ISO-8601).
    public let startDate: String
    /// Date range end (ISO-8601).
    public let endDate: String

    public init(
        projectName: String,
        totalSessions: Int,
        skillStats: [SkillUsageStat],
        startDate: String,
        endDate: String
    ) {
        self.projectName = projectName
        self.totalSessions = totalSessions
        self.skillStats = skillStats
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Analytics Summary

/// High-level analytics summary for a project over a period.
public struct AnalyticsSummary: Codable, Sendable {
    /// Project name this summary belongs to.
    public let projectName: String
    /// Human-readable label for the report period (e.g., "Last 30 days").
    public let periodLabel: String
    /// Start of the period (ISO-8601).
    public let startDate: String
    /// End of the period (ISO-8601).
    public let endDate: String
    /// Total sessions in the period.
    public let totalSessions: Int
    /// Total messages exchanged in the period.
    public let totalMessages: Int
    /// Total tokens consumed in the period.
    public let totalTokensUsed: Int
    /// Session completion rate as a percentage (0–100).
    public let completionRate: Double
    /// Most-used model during the period.
    public let topModel: String?
    /// Most-used skill during the period.
    public let topSkill: String?
    /// Week-over-week change in session count as a percentage.
    public let weekOverWeekChange: Double?

    public init(
        projectName: String,
        periodLabel: String,
        startDate: String,
        endDate: String,
        totalSessions: Int,
        totalMessages: Int,
        totalTokensUsed: Int,
        completionRate: Double,
        topModel: String? = nil,
        topSkill: String? = nil,
        weekOverWeekChange: Double? = nil
    ) {
        self.projectName = projectName
        self.periodLabel = periodLabel
        self.startDate = startDate
        self.endDate = endDate
        self.totalSessions = totalSessions
        self.totalMessages = totalMessages
        self.totalTokensUsed = totalTokensUsed
        self.completionRate = completionRate
        self.topModel = topModel
        self.topSkill = topSkill
        self.weekOverWeekChange = weekOverWeekChange
    }
}

// MARK: - Analytics Export

/// Full analytics export payload for a project.
public struct AnalyticsExportData: Codable, Sendable {
    /// Project name this export belongs to.
    public let projectName: String
    /// Timestamp when the export was generated (ISO-8601).
    public let exportedAt: String
    /// High-level summary for the export period.
    public let summary: AnalyticsSummary
    /// Activity timeline data points.
    public let activityTimeline: [ActivityDataPoint]
    /// Session effectiveness metrics.
    public let sessionMetrics: SessionMetricsResponse
    /// Skill usage analytics.
    public let skillAnalytics: SkillAnalyticsResponse
    /// Schema version for forward-compatibility.
    public let schemaVersion: String

    public init(
        projectName: String,
        exportedAt: String,
        summary: AnalyticsSummary,
        activityTimeline: [ActivityDataPoint],
        sessionMetrics: SessionMetricsResponse,
        skillAnalytics: SkillAnalyticsResponse,
        schemaVersion: String = "1.0"
    ) {
        self.projectName = projectName
        self.exportedAt = exportedAt
        self.summary = summary
        self.activityTimeline = activityTimeline
        self.sessionMetrics = sessionMetrics
        self.skillAnalytics = skillAnalytics
        self.schemaVersion = schemaVersion
    }
}
