import Vapor
import Fluent
import ILSShared
import Foundation

/// Analytics controller providing project activity, session metrics, skill analytics,
/// summary reports, and data export endpoints.
///
/// All endpoints compute data from existing `SessionModel` DB queries and
/// `FileSystemService` calls — same data sources as `StatsController`.
struct AnalyticsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let analytics = routes.grouped("analytics")
        analytics.get("activity", use: self.activity)
        analytics.get("sessions", use: self.sessionMetrics)
        analytics.get("skills", use: self.skillAnalytics)
        analytics.get("summary", use: self.summary)
        analytics.get("export", use: self.exportData)
    }

    // MARK: - Route Handlers

    /// GET /analytics/activity?period=week|month
    ///
    /// Returns a daily activity timeline of session counts and message counts
    /// for the given period. Missing days are filled with zeros.
    @Sendable
    func activity(req: Request) async throws -> APIResponse<ActivityTimelineResponse> {
        let (start, end, days) = periodDates(from: req)
        let sessions = try await allSessions(req: req)
        let timeline = buildActivityTimeline(sessions: sessions, start: start, end: end, days: days)
        return APIResponse(success: true, data: timeline)
    }

    /// GET /analytics/sessions
    ///
    /// Returns aggregated session effectiveness metrics including model breakdown,
    /// completion rates, and average message counts across all sessions.
    @Sendable
    func sessionMetrics(req: Request) async throws -> APIResponse<SessionMetricsResponse> {
        let sessions = try await allSessions(req: req)
        let metrics = buildSessionMetrics(sessions: sessions)
        return APIResponse(success: true, data: metrics)
    }

    /// GET /analytics/skills?period=week|month
    ///
    /// Returns skill analytics listing all configured skills with active/inactive status.
    @Sendable
    func skillAnalytics(req: Request) async throws -> APIResponse<SkillAnalyticsResponse> {
        let (start, end, _) = periodDates(from: req)
        let skills = try await fileSystem.listSkills()
        let sessions = try await allSessions(req: req)
        let analytics = buildSkillAnalytics(
            skills: skills,
            totalSessions: sessions.count,
            start: start,
            end: end
        )
        return APIResponse(success: true, data: analytics)
    }

    /// GET /analytics/summary?period=week|month
    ///
    /// Returns a high-level summary of activity for the given period including
    /// session counts, message totals, completion rate, and top model/skill.
    @Sendable
    func summary(req: Request) async throws -> APIResponse<AnalyticsSummary> {
        let (start, end, days) = periodDates(from: req)
        let sessions = try await allSessions(req: req)
        let skills = try await fileSystem.listSkills()
        let summaryData = buildSummary(
            sessions: sessions,
            skills: skills,
            start: start,
            end: end,
            days: days
        )
        return APIResponse(success: true, data: summaryData)
    }

    /// GET /analytics/export
    ///
    /// Returns a full analytics export payload combining activity timeline,
    /// session metrics, skill analytics, and summary data.
    @Sendable
    func exportData(req: Request) async throws -> APIResponse<AnalyticsExportData> {
        let (start, end, days) = periodDates(from: req)

        // Load shared data once to avoid redundant DB/filesystem queries
        let sessions = try await allSessions(req: req)
        let skills = try await fileSystem.listSkills()

        let activityTimeline = buildActivityTimeline(
            sessions: sessions,
            start: start,
            end: end,
            days: days
        )
        let metrics = buildSessionMetrics(sessions: sessions)
        let skillsAnalytics = buildSkillAnalytics(
            skills: skills,
            totalSessions: sessions.count,
            start: start,
            end: end
        )
        let summaryData = buildSummary(
            sessions: sessions,
            skills: skills,
            start: start,
            end: end,
            days: days
        )

        let exportedAt = Self.exportFormatter.string(from: Date())

        return APIResponse(
            success: true,
            data: AnalyticsExportData(
                projectName: "All Projects",
                exportedAt: exportedAt,
                summary: summaryData,
                activityTimeline: activityTimeline.dataPoints,
                sessionMetrics: metrics,
                skillAnalytics: skillsAnalytics
            )
        )
    }

    // MARK: - Private Helpers

    /// Date formatters (static to avoid repeated allocation).
    private static let dayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let exportFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Resolves the `period` query parameter to (startDate, endDate, dayCount).
    /// Defaults to `week` (7 days). `month` yields 30 days.
    private func periodDates(from req: Request) -> (start: Date, end: Date, days: Int) {
        let periodStr = req.query[String.self, at: "period"] ?? "week"
        let days = periodStr == "month" ? 30 : 7
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return (start, end, days)
    }

    /// Loads all sessions from DB + external filesystem, deduplicating by claudeSessionId.
    /// Mirrors the merge strategy used in `StatsController.recentSessions`.
    private func allSessions(req: Request) async throws -> [ChatSession] {
        let dbModels = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .all()
        var merged: [ChatSession] = dbModels.map { $0.toShared(projectName: $0.project?.name) }

        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions()
        let dbClaudeIds = Set(dbModels.compactMap(\.claudeSessionId))
        let uniqueExternal = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIds.contains(claudeId)
        }
        merged.append(contentsOf: uniqueExternal)
        return merged
    }

    /// Builds an `ActivityTimelineResponse` from a pre-loaded session list.
    /// Pre-populates every day in the range with zero counts, then fills actuals.
    private func buildActivityTimeline(
        sessions: [ChatSession],
        start: Date,
        end: Date,
        days: Int
    ) -> ActivityTimelineResponse {
        // Pre-populate all days in range with zero values
        var dayMap: [String: (sessionCount: Int, messageCount: Int)] = [:]
        for offset in 0..<days {
            if let day = Calendar.current.date(byAdding: .day, value: offset, to: start) {
                let key = Self.dayFormatter.string(from: day)
                dayMap[key] = (0, 0)
            }
        }

        // Accumulate sessions that fall within the period
        let periodSessions = sessions.filter { $0.createdAt >= start && $0.createdAt <= end }
        for session in periodSessions {
            let key = Self.dayFormatter.string(from: session.createdAt)
            let current = dayMap[key] ?? (0, 0)
            dayMap[key] = (current.sessionCount + 1, current.messageCount + session.messageCount)
        }

        let dataPoints = dayMap.keys.sorted().map { key -> ActivityDataPoint in
            let counts = dayMap[key] ?? (0, 0)
            return ActivityDataPoint(
                date: key,
                sessionCount: counts.sessionCount,
                messageCount: counts.messageCount,
                tokensUsed: 0
            )
        }

        return ActivityTimelineResponse(
            projectName: "All Projects",
            dataPoints: dataPoints,
            startDate: Self.dayFormatter.string(from: start),
            endDate: Self.dayFormatter.string(from: end),
            granularity: "day"
        )
    }

    /// Builds `SessionMetricsResponse` from a pre-loaded session list (all-time).
    private func buildSessionMetrics(sessions: [ChatSession]) -> SessionMetricsResponse {
        let total = sessions.count
        guard total > 0 else {
            return SessionMetricsResponse(
                projectName: "All Projects",
                totalSessions: 0,
                avgMessagesPerSession: 0,
                avgSessionDurationSeconds: 0,
                completedSessions: 0,
                abandonedSessions: 0,
                completionRate: 0,
                avgIterationsPerSession: 0,
                modelUsage: []
            )
        }

        let totalMessages = sessions.reduce(0) { $0 + $1.messageCount }
        let avgMessages = Double(totalMessages) / Double(total)

        // Sessions with at least one message are considered completed
        let completed = sessions.filter { $0.messageCount > 0 }.count
        let abandoned = total - completed
        let completionRate = Double(completed) / Double(total) * 100.0

        // Group sessions by model
        var modelMap: [String: (sessionCount: Int, messageCount: Int)] = [:]
        for session in sessions {
            let model = session.model.isEmpty ? "unknown" : session.model
            let current = modelMap[model] ?? (0, 0)
            modelMap[model] = (current.sessionCount + 1, current.messageCount + session.messageCount)
        }

        let modelUsage = modelMap.map { (model, counts) -> ModelUsageStat in
            ModelUsageStat(
                model: model,
                sessionCount: counts.sessionCount,
                messageCount: counts.messageCount,
                tokensUsed: 0,
                usagePercentage: Double(counts.sessionCount) / Double(total) * 100.0
            )
        }.sorted { $0.sessionCount > $1.sessionCount }

        return SessionMetricsResponse(
            projectName: "All Projects",
            totalSessions: total,
            avgMessagesPerSession: avgMessages,
            avgSessionDurationSeconds: 0,
            completedSessions: completed,
            abandonedSessions: abandoned,
            completionRate: completionRate,
            avgIterationsPerSession: avgMessages,
            modelUsage: modelUsage
        )
    }

    /// Builds `SkillAnalyticsResponse` from the pre-loaded skill list.
    /// Since per-session skill invocation is not tracked, invocationCount reflects
    /// the active state (1 for active skills, 0 for inactive).
    private func buildSkillAnalytics(
        skills: [Skill],
        totalSessions: Int,
        start: Date,
        end: Date
    ) -> SkillAnalyticsResponse {
        let skillStats = skills.map { skill -> SkillUsageStat in
            SkillUsageStat(
                skillName: skill.name,
                invocationCount: skill.isActive ? 1 : 0,
                sessionCount: 0,
                usagePercentage: 0.0,
                avgEffectivenessRating: nil
            )
        }.sorted { $0.skillName < $1.skillName }

        return SkillAnalyticsResponse(
            projectName: "All Projects",
            totalSessions: totalSessions,
            skillStats: skillStats,
            startDate: Self.dayFormatter.string(from: start),
            endDate: Self.dayFormatter.string(from: end)
        )
    }

    /// Builds `AnalyticsSummary` for the given period from pre-loaded sessions and skills.
    private func buildSummary(
        sessions: [ChatSession],
        skills: [Skill],
        start: Date,
        end: Date,
        days: Int
    ) -> AnalyticsSummary {
        let periodLabel = days == 30 ? "Last 30 days" : "Last 7 days"
        let periodSessions = sessions.filter { $0.createdAt >= start && $0.createdAt <= end }
        let total = periodSessions.count
        let totalMessages = periodSessions.reduce(0) { $0 + $1.messageCount }
        let completed = periodSessions.filter { $0.messageCount > 0 }.count
        let completionRate = total > 0 ? Double(completed) / Double(total) * 100.0 : 0.0

        // Determine most-used model by session count
        var modelCounts: [String: Int] = [:]
        for session in periodSessions {
            let model = session.model.isEmpty ? "unknown" : session.model
            modelCounts[model, default: 0] += 1
        }
        let topModel = modelCounts.max(by: { $0.value < $1.value })?.key

        // Top skill: first active skill alphabetically (no per-session skill data available)
        let topSkill = skills
            .filter { $0.isActive }
            .sorted { $0.name < $1.name }
            .first?.name

        return AnalyticsSummary(
            projectName: "All Projects",
            periodLabel: periodLabel,
            startDate: Self.dayFormatter.string(from: start),
            endDate: Self.dayFormatter.string(from: end),
            totalSessions: total,
            totalMessages: totalMessages,
            totalTokensUsed: 0,
            completionRate: completionRate,
            topModel: topModel,
            topSkill: topSkill
        )
    }
}
