import Vapor
import Fluent
import ILSShared
import Foundation

struct UsageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usage = routes.grouped("usage")
        usage.get(use: self.usage)
    }

    /// GET /usage?period=monthly - Aggregate usage metrics for dashboard
    @Sendable
    func usage(req: Request) async throws -> APIResponse<UsageMetrics> {
        let periodParam = try? req.query.get(String.self, at: "period")
        let period: UsagePeriod = UsagePeriod(rawValue: periodParam ?? "") ?? .monthly

        let now = Date()
        let calendar = Calendar.current

        // Determine reporting window
        let daysBack: Int
        let periodStart: Date
        switch period {
        case .daily:
            daysBack = 1
            periodStart = calendar.startOfDay(for: now)
        case .weekly:
            daysBack = 7
            periodStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .monthly:
            daysBack = 30
            periodStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current

        let periodStartStr = dateFormatter.string(from: periodStart)
        let periodEndStr = dateFormatter.string(from: now)

        // Fetch sessions in the reporting window (with project relationship)
        let sessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$createdAt >= periodStart)
            .all()

        // --- Daily breakdown ---
        // Pre-fill all days so the chart always has data points
        var dailyMap: [String: (messageCount: Int, sessionCount: Int, durationSeconds: Int)] = [:]
        for dayOffset in 0..<max(daysBack, 1) {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)) {
                dailyMap[dateFormatter.string(from: date)] = (0, 0, 0)
            }
        }

        for session in sessions {
            guard let createdAt = session.createdAt else { continue }
            let dateStr = dateFormatter.string(from: createdAt)
            var entry = dailyMap[dateStr] ?? (0, 0, 0)
            entry.messageCount += session.messageCount
            entry.sessionCount += 1
            if let lastActiveAt = session.lastActiveAt {
                entry.durationSeconds += max(0, Int(lastActiveAt.timeIntervalSince(createdAt)))
            }
            dailyMap[dateStr] = entry
        }

        let dailyBreakdown = dailyMap
            .map { dateStr, stats in
                DailyUsage(
                    date: dateStr,
                    messageCount: stats.messageCount,
                    sessionCount: stats.sessionCount,
                    totalDurationSeconds: stats.durationSeconds
                )
            }
            .sorted { $0.date < $1.date }

        // --- Period totals ---
        let totalMessages = sessions.reduce(0) { $0 + $1.messageCount }
        let totalSessions = sessions.count
        let totalDurationSeconds = sessions.reduce(0) { sum, session in
            guard let createdAt = session.createdAt,
                  let lastActiveAt = session.lastActiveAt else { return sum }
            return sum + max(0, Int(lastActiveAt.timeIntervalSince(createdAt)))
        }
        let averageMessagesPerSession: Double = totalSessions > 0
            ? Double(totalMessages) / Double(totalSessions)
            : 0.0

        // --- Per-project breakdown ---
        var projectMap: [String: (messageCount: Int, sessionCount: Int, durationSeconds: Int)] = [:]
        for session in sessions {
            let projectName = session.project?.name ?? "No Project"
            var entry = projectMap[projectName] ?? (0, 0, 0)
            entry.messageCount += session.messageCount
            entry.sessionCount += 1
            if let createdAt = session.createdAt, let lastActiveAt = session.lastActiveAt {
                entry.durationSeconds += max(0, Int(lastActiveAt.timeIntervalSince(createdAt)))
            }
            projectMap[projectName] = entry
        }

        let projectBreakdown = projectMap
            .map { projectName, stats in
                let pct: Double = totalMessages > 0
                    ? min(100.0, Double(stats.messageCount) / Double(totalMessages) * 100.0)
                    : 0.0
                return ProjectUsage(
                    projectName: projectName,
                    messageCount: stats.messageCount,
                    sessionCount: stats.sessionCount,
                    totalDurationSeconds: stats.durationSeconds,
                    percentageOfTotal: pct
                )
            }
            .sorted { $0.messageCount > $1.messageCount }

        // --- Rate limit status (5-hour window) ---
        let windowDurationSeconds = 18_000 // 5 hours × 3600
        let windowStart = Date(timeIntervalSinceNow: -Double(windowDurationSeconds))

        let messagesUsed = try await MessageModel.query(on: req.db)
            .filter(\.$role == "user")
            .filter(\.$createdAt >= windowStart)
            .count()

        // Window resets when the oldest message in the window ages out
        var windowResetsAt: String?
        let oldestWindowMessage = try await MessageModel.query(on: req.db)
            .filter(\.$role == "user")
            .filter(\.$createdAt >= windowStart)
            .sort(\.$createdAt, .ascending)
            .first()

        if let oldest = oldestWindowMessage, let oldestCreatedAt = oldest.createdAt {
            let resetDate = oldestCreatedAt.addingTimeInterval(Double(windowDurationSeconds))
            windowResetsAt = ISO8601DateFormatter().string(from: resetDate)
        }

        let rateLimitStatus = RateLimitStatus(
            messagesUsed: messagesUsed,
            messagesLimit: 45,
            windowResetsAt: windowResetsAt,
            windowDurationSeconds: windowDurationSeconds
        )

        return APIResponse(
            success: true,
            data: UsageMetrics(
                period: period,
                periodStart: periodStartStr,
                periodEnd: periodEndStr,
                totalMessages: totalMessages,
                totalSessions: totalSessions,
                averageMessagesPerSession: averageMessagesPerSession,
                totalDurationSeconds: totalDurationSeconds,
                dailyBreakdown: dailyBreakdown,
                projectBreakdown: projectBreakdown,
                rateLimitStatus: rateLimitStatus
            )
        )
    }
}
