import Vapor
import Fluent
import ILSShared
import Foundation

struct ConsumptionController: RouteCollection {
    private let consumptionService = ConsumptionService()

    func boot(routes: RoutesBuilder) throws {
        let consumption = routes.grouped("consumption")
        consumption.get(use: self.dashboard)
        consumption.get("burn-rate", use: self.burnRate)
        consumption.get("anomalies", use: self.anomalies)
    }

    /// GET /consumption?period=daily|weekly|monthly - Full consumption dashboard
    @Sendable
    func dashboard(req: Request) async throws -> APIResponse<ConsumptionDashboardResponse> {
        let periodParam = try? req.query.get(String.self, at: "period")
        let period: UsagePeriod = UsagePeriod(rawValue: periodParam ?? "") ?? .monthly

        let now = Date()
        let calendar = Calendar.current

        // Determine reporting window
        let periodStart: Date
        switch period {
        case .daily:
            periodStart = calendar.startOfDay(for: now)
        case .weekly:
            periodStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .monthly:
            periodStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current

        let periodStartStr = dateFormatter.string(from: periodStart)
        let periodEndStr = dateFormatter.string(from: now)

        // Fetch sessions and convert to ChatSession
        let sessions = try await fetchChatSessions(on: req.db, since: periodStart)

        // Build all breakdowns via ConsumptionService
        let dailyConsumption = await consumptionService.buildDailyConsumption(
            sessions: sessions, start: periodStart, end: now
        )
        let modelBreakdown = await consumptionService.buildModelBreakdown(sessions: sessions)
        let projectBreakdown = await consumptionService.buildProjectBreakdown(sessions: sessions)
        let burnRate = await consumptionService.calculateBurnRate(sessions: sessions)
        let anomalies = await consumptionService.detectAnomalies(dailyData: dailyConsumption)

        // Compute totals
        let totalMessages = sessions.reduce(0) { $0 + $1.messageCount }
        let totalSessions = sessions.count
        let totalTokens = dailyConsumption.reduce(0) { $0 + $1.estimatedInputTokens + $1.estimatedOutputTokens }
        let totalCost = dailyConsumption.reduce(0.0) { $0 + $1.estimatedCostUSD }

        // Build top sessions by consumption
        let topSessions = await buildTopSessions(sessions: sessions, limit: 10)

        // Rate limit status (5-hour window)
        let rateLimitStatus = try await buildRateLimitStatus(on: req.db)

        return APIResponse(
            success: true,
            data: ConsumptionDashboardResponse(
                period: period,
                periodStart: periodStartStr,
                periodEnd: periodEndStr,
                totalEstimatedTokens: totalTokens,
                totalEstimatedCostUSD: round(totalCost * 100) / 100,
                totalMessages: totalMessages,
                totalSessions: totalSessions,
                dailyConsumption: dailyConsumption,
                modelBreakdown: modelBreakdown,
                projectBreakdown: projectBreakdown,
                topSessionsByConsumption: topSessions,
                burnRate: burnRate,
                anomalies: anomalies,
                rateLimitStatus: rateLimitStatus
            )
        )
    }

    /// GET /consumption/burn-rate - Lightweight burn rate polling endpoint
    @Sendable
    func burnRate(req: Request) async throws -> APIResponse<BurnRateInfo> {
        // Fetch all sessions (burn rate uses its own 5-hour window internally)
        let allSessions = try await fetchChatSessions(on: req.db, since: Date.distantPast)
        let burnRate = await consumptionService.calculateBurnRate(sessions: allSessions)

        return APIResponse(success: true, data: burnRate)
    }

    /// GET /consumption/anomalies?period=weekly|monthly - Anomaly flags only
    @Sendable
    func anomalies(req: Request) async throws -> APIResponse<[AnomalyFlag]> {
        let periodParam = try? req.query.get(String.self, at: "period")
        let period: UsagePeriod = UsagePeriod(rawValue: periodParam ?? "") ?? .weekly

        let now = Date()
        let calendar = Calendar.current

        let periodStart: Date
        switch period {
        case .daily:
            periodStart = calendar.startOfDay(for: now)
        case .weekly:
            periodStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .monthly:
            periodStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }

        let sessions = try await fetchChatSessions(on: req.db, since: periodStart)
        let dailyConsumption = await consumptionService.buildDailyConsumption(
            sessions: sessions, start: periodStart, end: now
        )
        let anomalies = await consumptionService.detectAnomalies(dailyData: dailyConsumption)

        return APIResponse(success: true, data: anomalies)
    }

    // MARK: - Private Helpers

    /// Fetch sessions from DB and convert to ChatSession DTOs
    private func fetchChatSessions(on db: Database, since startDate: Date) async throws -> [ChatSession] {
        let sessionModels = try await SessionModel.query(on: db)
            .with(\.$project)
            .filter(\.$createdAt >= startDate)
            .all()

        return sessionModels.map { session in
            session.toShared(projectName: session.project?.name)
        }
    }

    /// Build top sessions sorted by estimated token consumption
    private func buildTopSessions(sessions: [ChatSession], limit: Int) async -> [SessionConsumption] {
        // Compute token estimates for all sessions first
        var sessionEstimates: [(session: ChatSession, totalTokens: Int, inputTokens: Int, outputTokens: Int, cost: Double)] = []
        for session in sessions {
            let tokens = await consumptionService.estimateTokens(
                messageCount: session.messageCount, model: session.model
            )
            let totalTokens = tokens.input + tokens.output
            let cost = await consumptionService.computeCost(
                inputTokens: tokens.input, outputTokens: tokens.output, model: session.model
            )
            sessionEstimates.append((session, totalTokens, tokens.input, tokens.output, cost))
        }

        // Sort by estimated token consumption (descending)
        let sorted = sessionEstimates.sorted { $0.totalTokens > $1.totalTokens }
        let top = sorted.prefix(limit)

        return top.map { entry in
            SessionConsumption(
                sessionId: entry.session.id.uuidString,
                sessionName: entry.session.name ?? "Session \(entry.session.id.uuidString.prefix(8))",
                model: entry.session.model,
                estimatedTokens: entry.totalTokens,
                estimatedCostUSD: round(entry.cost * 100) / 100,
                messageCount: entry.session.messageCount
            )
        }
    }

    /// Build rate limit status from message history
    private func buildRateLimitStatus(on db: Database) async throws -> RateLimitStatus {
        let windowDurationSeconds = 18_000 // 5 hours
        let windowStart = Date(timeIntervalSinceNow: -Double(windowDurationSeconds))

        let messagesUsed = try await MessageModel.query(on: db)
            .filter(\.$role == "user")
            .filter(\.$createdAt >= windowStart)
            .count()

        var windowResetsAt: String?
        let oldestWindowMessage = try await MessageModel.query(on: db)
            .filter(\.$role == "user")
            .filter(\.$createdAt >= windowStart)
            .sort(\.$createdAt, .ascending)
            .first()

        if let oldest = oldestWindowMessage, let oldestCreatedAt = oldest.createdAt {
            let resetDate = oldestCreatedAt.addingTimeInterval(Double(windowDurationSeconds))
            windowResetsAt = ISO8601DateFormatter().string(from: resetDate)
        }

        return RateLimitStatus(
            messagesUsed: messagesUsed,
            messagesLimit: 45,
            windowResetsAt: windowResetsAt,
            windowDurationSeconds: windowDurationSeconds
        )
    }
}
