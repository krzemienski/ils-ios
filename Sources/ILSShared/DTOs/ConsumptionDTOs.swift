import Foundation

// MARK: - Daily Consumption

/// Estimated consumption metrics for a single calendar day.
public struct DailyConsumption: Codable, Sendable, Identifiable {
    /// The calendar date for this record (ISO 8601 date string, e.g. "2026-03-20").
    public let date: String
    /// Estimated input tokens consumed on this day.
    public let estimatedInputTokens: Int
    /// Estimated output tokens consumed on this day.
    public let estimatedOutputTokens: Int
    /// Estimated cost in USD on this day.
    public let estimatedCostUSD: Double
    /// Total number of messages sent on this day.
    public let messageCount: Int
    /// Total number of sessions active on this day.
    public let sessionCount: Int

    /// Stable identifier using the date string.
    public var id: String { date }

    public init(
        date: String,
        estimatedInputTokens: Int,
        estimatedOutputTokens: Int,
        estimatedCostUSD: Double,
        messageCount: Int,
        sessionCount: Int
    ) {
        precondition(!date.isEmpty, "DailyConsumption date must not be empty")
        precondition(estimatedInputTokens >= 0, "DailyConsumption estimatedInputTokens must be non-negative")
        precondition(estimatedOutputTokens >= 0, "DailyConsumption estimatedOutputTokens must be non-negative")
        precondition(estimatedCostUSD >= 0, "DailyConsumption estimatedCostUSD must be non-negative")
        precondition(messageCount >= 0, "DailyConsumption messageCount must be non-negative")
        precondition(sessionCount >= 0, "DailyConsumption sessionCount must be non-negative")
        self.date = date
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.messageCount = messageCount
        self.sessionCount = sessionCount
    }
}

// MARK: - Model Consumption

/// Consumption statistics broken down by AI model.
public struct ModelConsumption: Codable, Sendable, Identifiable {
    /// Model name (e.g., "claude-opus-4-5", "claude-sonnet-4-5").
    public let model: String
    /// Estimated total tokens consumed by this model.
    public let tokenCount: Int
    /// Estimated cost in USD attributed to this model.
    public let costUSD: Double
    /// Total messages sent using this model.
    public let messageCount: Int
    /// Percentage of total consumption attributed to this model (0–100).
    public let percentageOfTotal: Double

    /// Stable identifier using the model name.
    public var id: String { model }

    public init(
        model: String,
        tokenCount: Int,
        costUSD: Double,
        messageCount: Int,
        percentageOfTotal: Double
    ) {
        precondition(!model.isEmpty, "ModelConsumption model must not be empty")
        precondition(tokenCount >= 0, "ModelConsumption tokenCount must be non-negative")
        precondition(costUSD >= 0, "ModelConsumption costUSD must be non-negative")
        precondition(messageCount >= 0, "ModelConsumption messageCount must be non-negative")
        precondition(
            (0.0...100.0).contains(percentageOfTotal),
            "ModelConsumption percentageOfTotal must be between 0 and 100"
        )
        self.model = model
        self.tokenCount = tokenCount
        self.costUSD = costUSD
        self.messageCount = messageCount
        self.percentageOfTotal = percentageOfTotal
    }
}

// MARK: - Session Consumption

/// Consumption statistics for a single session.
public struct SessionConsumption: Codable, Sendable, Identifiable {
    /// Unique session identifier.
    public let sessionId: String
    /// Human-readable session name or label.
    public let sessionName: String
    /// Model used in this session.
    public let model: String
    /// Estimated total tokens consumed in this session.
    public let estimatedTokens: Int
    /// Estimated cost in USD for this session.
    public let estimatedCostUSD: Double
    /// Total messages sent in this session.
    public let messageCount: Int

    /// Stable identifier using the session ID.
    public var id: String { sessionId }

    public init(
        sessionId: String,
        sessionName: String,
        model: String,
        estimatedTokens: Int,
        estimatedCostUSD: Double,
        messageCount: Int
    ) {
        precondition(!sessionId.isEmpty, "SessionConsumption sessionId must not be empty")
        precondition(!model.isEmpty, "SessionConsumption model must not be empty")
        precondition(estimatedTokens >= 0, "SessionConsumption estimatedTokens must be non-negative")
        precondition(estimatedCostUSD >= 0, "SessionConsumption estimatedCostUSD must be non-negative")
        precondition(messageCount >= 0, "SessionConsumption messageCount must be non-negative")
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.model = model
        self.estimatedTokens = estimatedTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.messageCount = messageCount
    }
}

// MARK: - Project Consumption

/// Consumption statistics broken down by project for a given period.
public struct ProjectConsumption: Codable, Sendable, Identifiable {
    /// Project name (used as identifier).
    public let projectName: String
    /// Estimated total tokens consumed by this project.
    public let estimatedTokens: Int
    /// Estimated cost in USD attributed to this project.
    public let estimatedCostUSD: Double
    /// Total messages sent in this project.
    public let messageCount: Int
    /// Total sessions in this project.
    public let sessionCount: Int
    /// Percentage of total consumption attributed to this project (0–100).
    public let percentageOfTotal: Double

    /// Stable identifier using the project name.
    public var id: String { projectName }

    public init(
        projectName: String,
        estimatedTokens: Int,
        estimatedCostUSD: Double,
        messageCount: Int,
        sessionCount: Int,
        percentageOfTotal: Double
    ) {
        precondition(!projectName.isEmpty, "ProjectConsumption projectName must not be empty")
        precondition(estimatedTokens >= 0, "ProjectConsumption estimatedTokens must be non-negative")
        precondition(estimatedCostUSD >= 0, "ProjectConsumption estimatedCostUSD must be non-negative")
        precondition(messageCount >= 0, "ProjectConsumption messageCount must be non-negative")
        precondition(sessionCount >= 0, "ProjectConsumption sessionCount must be non-negative")
        precondition(
            (0.0...100.0).contains(percentageOfTotal),
            "ProjectConsumption percentageOfTotal must be between 0 and 100"
        )
        self.projectName = projectName
        self.estimatedTokens = estimatedTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.percentageOfTotal = percentageOfTotal
    }
}

// MARK: - Burn Rate

/// Consumption burn rate information for projecting future usage.
public struct BurnRateInfo: Codable, Sendable {
    /// Average messages sent per hour within the analysis window.
    public let messagesPerHour: Double
    /// Estimated tokens consumed per hour within the analysis window.
    public let estimatedTokensPerHour: Double
    /// Estimated cost in USD per hour within the analysis window.
    public let estimatedCostPerHour: Double
    /// Projected date when the rate limit will be exhausted (ISO 8601), if applicable.
    public let projectedExhaustionDate: String?
    /// Projected hours remaining before the rate limit is exhausted, if applicable.
    public let projectedHoursRemaining: Double?
    /// Duration of the analysis window in hours.
    public let windowDurationHours: Double

    public init(
        messagesPerHour: Double,
        estimatedTokensPerHour: Double,
        estimatedCostPerHour: Double,
        projectedExhaustionDate: String? = nil,
        projectedHoursRemaining: Double? = nil,
        windowDurationHours: Double
    ) {
        precondition(messagesPerHour >= 0, "BurnRateInfo messagesPerHour must be non-negative")
        precondition(estimatedTokensPerHour >= 0, "BurnRateInfo estimatedTokensPerHour must be non-negative")
        precondition(estimatedCostPerHour >= 0, "BurnRateInfo estimatedCostPerHour must be non-negative")
        precondition(windowDurationHours > 0, "BurnRateInfo windowDurationHours must be positive")
        self.messagesPerHour = messagesPerHour
        self.estimatedTokensPerHour = estimatedTokensPerHour
        self.estimatedCostPerHour = estimatedCostPerHour
        self.projectedExhaustionDate = projectedExhaustionDate
        self.projectedHoursRemaining = projectedHoursRemaining
        self.windowDurationHours = windowDurationHours
    }
}

// MARK: - Anomaly Flag

/// Anomaly type classification for consumption patterns.
public enum AnomalyType: String, Codable, Sendable, CaseIterable {
    /// Sudden increase in consumption.
    case spike
    /// Sudden decrease in consumption.
    case drop
    /// Unexpected distribution of model usage.
    case unusualModelMix = "unusual_model_mix"
}

/// Severity level for consumption anomalies.
public enum AnomalySeverity: String, Codable, Sendable, CaseIterable {
    /// Notable but not urgent anomaly.
    case warning
    /// Significant anomaly requiring attention.
    case critical
}

/// A flagged anomaly in consumption patterns.
public struct AnomalyFlag: Codable, Sendable, Identifiable {
    /// Unique identifier for this anomaly.
    public let id: String
    /// Classification of the anomaly.
    public let type: AnomalyType
    /// Severity level of the anomaly.
    public let severity: AnomalySeverity
    /// The date affected by this anomaly (ISO 8601 date string).
    public let affectedDate: String
    /// Percentage change from the baseline that triggered this anomaly.
    public let percentageChange: Double
    /// Human-readable description of the anomaly.
    public let description: String
    /// Additional context or explanation for the anomaly.
    public let context: String?

    public init(
        id: String,
        type: AnomalyType,
        severity: AnomalySeverity,
        affectedDate: String,
        percentageChange: Double,
        description: String,
        context: String? = nil
    ) {
        precondition(!id.isEmpty, "AnomalyFlag id must not be empty")
        precondition(!affectedDate.isEmpty, "AnomalyFlag affectedDate must not be empty")
        precondition(!description.isEmpty, "AnomalyFlag description must not be empty")
        self.id = id
        self.type = type
        self.severity = severity
        self.affectedDate = affectedDate
        self.percentageChange = percentageChange
        self.description = description
        self.context = context
    }
}

// MARK: - Consumption Dashboard Response

/// Complete consumption dashboard response combining all consumption metrics.
///
/// Provides estimated token usage, cost projections, burn rate analysis,
/// anomaly detection, and breakdowns by model, project, and session.
public struct ConsumptionDashboardResponse: Codable, Sendable {
    /// The time period these metrics cover (reuses UsagePeriod).
    public let period: UsagePeriod
    /// ISO 8601 date string for the start of the reporting window.
    public let periodStart: String
    /// ISO 8601 date string for the end of the reporting window.
    public let periodEnd: String
    /// Total estimated tokens consumed within the reporting period.
    public let totalEstimatedTokens: Int
    /// Total estimated cost in USD within the reporting period.
    public let totalEstimatedCostUSD: Double
    /// Total messages sent within the reporting period.
    public let totalMessages: Int
    /// Total sessions within the reporting period.
    public let totalSessions: Int
    /// Day-by-day consumption breakdown for trend graphs.
    public let dailyConsumption: [DailyConsumption]
    /// Consumption breakdown by model, sorted by token count descending.
    public let modelBreakdown: [ModelConsumption]
    /// Consumption breakdown by project, sorted by estimated tokens descending.
    public let projectBreakdown: [ProjectConsumption]
    /// Top sessions sorted by consumption descending.
    public let topSessionsByConsumption: [SessionConsumption]
    /// Current burn rate analysis and projections.
    public let burnRate: BurnRateInfo
    /// Detected anomalies in consumption patterns.
    public let anomalies: [AnomalyFlag]
    /// Current rate-limit window status (reuses existing RateLimitStatus).
    public let rateLimitStatus: RateLimitStatus

    public init(
        period: UsagePeriod,
        periodStart: String,
        periodEnd: String,
        totalEstimatedTokens: Int,
        totalEstimatedCostUSD: Double,
        totalMessages: Int,
        totalSessions: Int,
        dailyConsumption: [DailyConsumption],
        modelBreakdown: [ModelConsumption],
        projectBreakdown: [ProjectConsumption],
        topSessionsByConsumption: [SessionConsumption],
        burnRate: BurnRateInfo,
        anomalies: [AnomalyFlag],
        rateLimitStatus: RateLimitStatus
    ) {
        precondition(!periodStart.isEmpty, "ConsumptionDashboardResponse periodStart must not be empty")
        precondition(!periodEnd.isEmpty, "ConsumptionDashboardResponse periodEnd must not be empty")
        precondition(totalEstimatedTokens >= 0, "ConsumptionDashboardResponse totalEstimatedTokens must be non-negative")
        precondition(totalEstimatedCostUSD >= 0, "ConsumptionDashboardResponse totalEstimatedCostUSD must be non-negative")
        precondition(totalMessages >= 0, "ConsumptionDashboardResponse totalMessages must be non-negative")
        precondition(totalSessions >= 0, "ConsumptionDashboardResponse totalSessions must be non-negative")
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalEstimatedTokens = totalEstimatedTokens
        self.totalEstimatedCostUSD = totalEstimatedCostUSD
        self.totalMessages = totalMessages
        self.totalSessions = totalSessions
        self.dailyConsumption = dailyConsumption
        self.modelBreakdown = modelBreakdown
        self.projectBreakdown = projectBreakdown
        self.topSessionsByConsumption = topSessionsByConsumption
        self.burnRate = burnRate
        self.anomalies = anomalies
        self.rateLimitStatus = rateLimitStatus
    }
}
