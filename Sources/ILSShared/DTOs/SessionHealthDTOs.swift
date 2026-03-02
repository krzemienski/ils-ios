import Foundation

// MARK: - Session Health Score

/// Computed health score for a session based on quality signals.
///
/// The score (0–100) is derived from error rate, token efficiency,
/// task completion rate, and retry count. Higher scores indicate
/// healthier sessions with fewer errors and better efficiency.
public struct SessionHealthScore: Codable, Sendable {
    /// Session identifier.
    public let sessionId: String
    /// Overall health score (0–100).
    public let score: Double
    /// Qualitative health level derived from the score.
    public let level: HealthScoreLevel
    /// Individual factors that contribute to the overall score.
    public let factors: [HealthScoreFactor]
    /// Actionable recommendations when health degrades.
    public let recommendations: [String]
    /// Timestamp when the score was computed.
    public let computedAt: Date

    /// Creates a new session health score.
    /// - Parameters:
    ///   - sessionId: Session identifier.
    ///   - score: Overall health score in the range 0–100.
    ///   - level: Qualitative health level.
    ///   - factors: Individual contributing factors.
    ///   - recommendations: Actionable improvement suggestions.
    ///   - computedAt: Timestamp of computation.
    public init(
        sessionId: String,
        score: Double,
        level: HealthScoreLevel,
        factors: [HealthScoreFactor],
        recommendations: [String],
        computedAt: Date
    ) {
        self.sessionId = sessionId
        self.score = score
        self.level = level
        self.factors = factors
        self.recommendations = recommendations
        self.computedAt = computedAt
    }
}

// MARK: - Health Score Factor

/// An individual factor contributing to the session health score.
///
/// Each factor represents one quality signal (e.g., error rate)
/// with its own sub-score, weight, and human-readable description.
public struct HealthScoreFactor: Codable, Sendable {
    /// Machine-readable factor identifier (e.g., `"error_rate"`).
    public let factorId: String
    /// Human-readable display name.
    public let name: String
    /// Factor sub-score (0–100).
    public let score: Double
    /// Weight of this factor in the overall score (0–1).
    public let weight: Double
    /// Human-readable description of the factor value.
    public let description: String
    /// Raw underlying value (e.g., error count, percentage).
    public let rawValue: Double

    /// Creates a new health score factor.
    /// - Parameters:
    ///   - factorId: Machine-readable identifier.
    ///   - name: Display name.
    ///   - score: Sub-score in the range 0–100.
    ///   - weight: Contribution weight in the range 0–1.
    ///   - description: Human-readable description.
    ///   - rawValue: Underlying raw metric value.
    public init(
        factorId: String,
        name: String,
        score: Double,
        weight: Double,
        description: String,
        rawValue: Double
    ) {
        self.factorId = factorId
        self.name = name
        self.score = score
        self.weight = weight
        self.description = description
        self.rawValue = rawValue
    }
}

// MARK: - Health Score Level

/// Qualitative health level derived from the numeric health score.
public enum HealthScoreLevel: String, Codable, Sendable, CaseIterable {
    /// Score ≥ 80 — session is operating well.
    case healthy
    /// Score 50–79 — session shows signs of degradation.
    case degrading
    /// Score < 50 — session has significant quality issues.
    case problematic
}

// MARK: - Project Health Summary

/// Aggregate health metrics for all sessions within a project.
///
/// Provides a rolled-up view of session health over a time period,
/// including trend data and distribution by health level.
public struct ProjectHealthSummary: Codable, Sendable {
    /// Project identifier.
    public let projectId: String
    /// Project display name.
    public let projectName: String
    /// Average health score across all sessions (0–100).
    public let averageScore: Double
    /// Total number of sessions included in the summary.
    public let totalSessions: Int
    /// Number of healthy sessions (score ≥ 80).
    public let healthySessions: Int
    /// Number of degrading sessions (score 50–79).
    public let degradingSessions: Int
    /// Number of problematic sessions (score < 50).
    public let problematicSessions: Int
    /// Health score trend over time (chronological).
    public let trend: [HealthScoreTrendPoint]
    /// Start of the reporting period.
    public let periodStart: Date
    /// End of the reporting period.
    public let periodEnd: Date

    /// Creates a new project health summary.
    /// - Parameters:
    ///   - projectId: Project identifier.
    ///   - projectName: Display name.
    ///   - averageScore: Average health score in the range 0–100.
    ///   - totalSessions: Total session count.
    ///   - healthySessions: Count of healthy sessions.
    ///   - degradingSessions: Count of degrading sessions.
    ///   - problematicSessions: Count of problematic sessions.
    ///   - trend: Chronological list of score trend points.
    ///   - periodStart: Start of reporting period.
    ///   - periodEnd: End of reporting period.
    public init(
        projectId: String,
        projectName: String,
        averageScore: Double,
        totalSessions: Int,
        healthySessions: Int,
        degradingSessions: Int,
        problematicSessions: Int,
        trend: [HealthScoreTrendPoint],
        periodStart: Date,
        periodEnd: Date
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.averageScore = averageScore
        self.totalSessions = totalSessions
        self.healthySessions = healthySessions
        self.degradingSessions = degradingSessions
        self.problematicSessions = problematicSessions
        self.trend = trend
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    /// A single data point in the health score trend series.
    public struct HealthScoreTrendPoint: Codable, Sendable {
        /// Timestamp of this data point.
        public let timestamp: Date
        /// Average health score at this point (0–100).
        public let score: Double
        /// Number of sessions included in this data point.
        public let sessionCount: Int

        /// Creates a new trend data point.
        /// - Parameters:
        ///   - timestamp: Timestamp of the data point.
        ///   - score: Average health score in the range 0–100.
        ///   - sessionCount: Number of sessions sampled.
        public init(timestamp: Date, score: Double, sessionCount: Int) {
            self.timestamp = timestamp
            self.score = score
            self.sessionCount = sessionCount
        }
    }
}
