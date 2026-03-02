import Foundation
import ILSShared

/// Actor that computes health scores for Claude Code sessions based on quality signals.
///
/// Health scores (0–100) are derived from four weighted factors:
/// - **Error rate** (30%): Was the session error-free?
/// - **Completion rate** (25%): Did the session complete successfully?
/// - **Cost efficiency** (25%): How much did each message cost?
/// - **Turn efficiency** (20%): Was the conversation concise?
///
/// Level thresholds: healthy (≥ 70), degrading (40–69), problematic (< 40).
actor SessionHealthService {

    // MARK: - Factor Weights

    private let errorWeight: Double = 0.30
    private let completionWeight: Double = 0.25
    private let costWeight: Double = 0.25
    private let turnWeight: Double = 0.20

    // MARK: - Public API

    /// Compute a health score for a single session.
    /// - Parameter session: The session to evaluate.
    /// - Returns: A fully-populated ``SessionHealthScore``.
    func computeHealthScore(session: ChatSession) -> SessionHealthScore {
        let errorFactor = computeErrorFactor(session: session)
        let completionFactor = computeCompletionFactor(session: session)
        let costFactor = computeCostFactor(session: session)
        let turnFactor = computeTurnFactor(session: session)

        let score = (errorFactor.score * errorWeight)
            + (completionFactor.score * completionWeight)
            + (costFactor.score * costWeight)
            + (turnFactor.score * turnWeight)

        let roundedScore = (score * 10).rounded() / 10
        let level = determineLevel(score: roundedScore)
        let recommendations = buildRecommendations(
            session: session,
            level: level,
            costFactor: costFactor
        )

        return SessionHealthScore(
            sessionId: session.id.uuidString.lowercased(),
            score: roundedScore,
            level: level,
            factors: [errorFactor, completionFactor, costFactor, turnFactor],
            recommendations: recommendations,
            computedAt: Date()
        )
    }

    /// Compute aggregate health for all sessions in a project.
    /// - Parameters:
    ///   - projectName: Name of the project to summarize.
    ///   - sessions: All sessions belonging to the project.
    /// - Returns: A ``ProjectHealthSummary`` with trend data.
    func computeProjectHealth(
        projectName: String,
        sessions: [ChatSession]
    ) -> ProjectHealthSummary {
        guard !sessions.isEmpty else {
            let now = Date()
            return ProjectHealthSummary(
                projectId: projectName,
                projectName: projectName,
                averageScore: 0,
                totalSessions: 0,
                healthySessions: 0,
                degradingSessions: 0,
                problematicSessions: 0,
                trend: [],
                periodStart: now,
                periodEnd: now
            )
        }

        let healthScores = sessions.map { computeHealthScore(session: $0) }

        let totalSessions = healthScores.count
        let healthySessions = healthScores.filter { $0.level == .healthy }.count
        let degradingSessions = healthScores.filter { $0.level == .degrading }.count
        let problematicSessions = healthScores.filter { $0.level == .problematic }.count

        let averageScore = healthScores.reduce(0.0) { $0 + $1.score } / Double(totalSessions)
        let roundedAverage = (averageScore * 10).rounded() / 10

        let dates = sessions.map { $0.lastActiveAt }
        let periodStart = dates.min() ?? Date()
        let periodEnd = dates.max() ?? Date()

        let trend = buildTrend(sessions: sessions, healthScores: healthScores)

        return ProjectHealthSummary(
            projectId: projectName,
            projectName: projectName,
            averageScore: roundedAverage,
            totalSessions: totalSessions,
            healthySessions: healthySessions,
            degradingSessions: degradingSessions,
            problematicSessions: problematicSessions,
            trend: trend,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }

    // MARK: - Private Helpers - Factor Computation

    /// Error factor: 100 if the session did not end in error, 0 if it did.
    private func computeErrorFactor(session: ChatSession) -> HealthScoreFactor {
        let score: Double = session.status == .error ? 0 : 100
        let description: String
        if session.status == .error {
            description = "Session terminated with an error"
        } else {
            description = "No errors detected"
        }

        return HealthScoreFactor(
            factorId: "error_rate",
            name: "Error Rate",
            score: score,
            weight: errorWeight,
            description: description,
            rawValue: session.status == .error ? 1 : 0
        )
    }

    /// Completion factor: scores session status on a 0–100 scale.
    ///
    /// - completed → 100 (task finished)
    /// - active → 60 (session still running, neutral)
    /// - cancelled → 20 (user stopped early)
    /// - error → 0 (aborted unexpectedly)
    private func computeCompletionFactor(session: ChatSession) -> HealthScoreFactor {
        let score: Double
        let description: String

        switch session.status {
        case .completed:
            score = 100
            description = "Session completed successfully"
        case .active:
            score = 60
            description = "Session is still active"
        case .cancelled:
            score = 20
            description = "Session was cancelled"
        case .error:
            score = 0
            description = "Session ended in error"
        }

        return HealthScoreFactor(
            factorId: "completion_rate",
            name: "Completion Rate",
            score: score,
            weight: completionWeight,
            description: description,
            rawValue: score
        )
    }

    /// Cost efficiency factor: scores cost-per-message on a 0–100 scale.
    ///
    /// If cost data is unavailable, a neutral score of 60 is assumed.
    private func computeCostFactor(session: ChatSession) -> HealthScoreFactor {
        guard let totalCost = session.totalCostUSD, session.messageCount > 0 else {
            return HealthScoreFactor(
                factorId: "cost_efficiency",
                name: "Cost Efficiency",
                score: 60,
                weight: costWeight,
                description: "Cost data unavailable — neutral score assumed",
                rawValue: 0
            )
        }

        let costPerMessage = totalCost / Double(session.messageCount)

        let score: Double
        let description: String

        if totalCost == 0 {
            score = 100
            description = "Zero cost — extremely efficient"
        } else if costPerMessage < 0.005 {
            score = 90
            description = String(format: "$%.4f per message — very efficient", costPerMessage)
        } else if costPerMessage < 0.02 {
            score = 70
            description = String(format: "$%.4f per message — efficient", costPerMessage)
        } else if costPerMessage < 0.05 {
            score = 50
            description = String(format: "$%.4f per message — moderate cost", costPerMessage)
        } else if costPerMessage < 0.10 {
            score = 30
            description = String(format: "$%.4f per message — high cost", costPerMessage)
        } else {
            score = 10
            description = String(format: "$%.4f per message — very high cost", costPerMessage)
        }

        return HealthScoreFactor(
            factorId: "cost_efficiency",
            name: "Cost Efficiency",
            score: score,
            weight: costWeight,
            description: description,
            rawValue: costPerMessage
        )
    }

    /// Turn efficiency factor: scores message count on a 0–100 scale.
    ///
    /// Fewer messages indicate a more focused, efficient conversation.
    private func computeTurnFactor(session: ChatSession) -> HealthScoreFactor {
        let count = session.messageCount
        let score: Double
        let description: String

        switch count {
        case 1...5:
            score = 100
            description = "\(count) messages — very concise"
        case 6...15:
            score = 80
            description = "\(count) messages — concise"
        case 16...30:
            score = 60
            description = "\(count) messages — moderate"
        case 31...50:
            score = 40
            description = "\(count) messages — verbose"
        case 51...100:
            score = 20
            description = "\(count) messages — very verbose"
        default:
            score = 10
            description = "\(count) messages — extremely verbose"
        }

        return HealthScoreFactor(
            factorId: "turn_efficiency",
            name: "Turn Efficiency",
            score: score,
            weight: turnWeight,
            description: description,
            rawValue: Double(count)
        )
    }

    // MARK: - Private Helpers - Level & Recommendations

    private func determineLevel(score: Double) -> HealthScoreLevel {
        if score >= 70 {
            return .healthy
        } else if score >= 40 {
            return .degrading
        } else {
            return .problematic
        }
    }

    private func buildRecommendations(
        session: ChatSession,
        level: HealthScoreLevel,
        costFactor: HealthScoreFactor
    ) -> [String] {
        var recommendations: [String] = []

        if session.status == .error {
            recommendations.append(
                "Session ended in error. Consider starting a fresh session or checking Claude CLI logs."
            )
        }

        if costFactor.score <= 30 {
            recommendations.append(
                "High token cost detected. Consider breaking this task into smaller sessions."
            )
        }

        if session.status == .cancelled {
            recommendations.append(
                "Session was cancelled. Consider resuming or forking from a checkpoint."
            )
        }

        return recommendations
    }

    // MARK: - Private Helpers - Trend

    /// Group sessions by calendar day and compute average scores for each day.
    private func buildTrend(
        sessions: [ChatSession],
        healthScores: [SessionHealthScore]
    ) -> [ProjectHealthSummary.HealthScoreTrendPoint] {
        let calendar = Calendar.current

        // Pair sessions with their computed scores
        let pairs = zip(sessions, healthScores)

        // Group by day component of lastActiveAt
        var dayGroups: [DateComponents: [(ChatSession, SessionHealthScore)]] = [:]
        for (session, score) in pairs {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: session.lastActiveAt)
            dayGroups[dayComponents, default: []].append((session, score))
        }

        // Build sorted trend points
        let trendPoints = dayGroups.compactMap { (components, group) -> ProjectHealthSummary.HealthScoreTrendPoint? in
            guard let date = calendar.date(from: components) else { return nil }
            let avgScore = group.reduce(0.0) { $0 + $1.1.score } / Double(group.count)
            let roundedAvg = (avgScore * 10).rounded() / 10
            return ProjectHealthSummary.HealthScoreTrendPoint(
                timestamp: date,
                score: roundedAvg,
                sessionCount: group.count
            )
        }

        return trendPoints.sorted { $0.timestamp < $1.timestamp }
    }
}
