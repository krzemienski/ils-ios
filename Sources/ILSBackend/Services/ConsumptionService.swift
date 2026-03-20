import Foundation
import ILSShared

/// Actor that computes consumption metrics from session data.
///
/// Provides token estimation, daily/model/project breakdowns, burn rate
/// calculations, and anomaly detection for the consumption dashboard.
actor ConsumptionService {

    // MARK: - Token Estimation Constants

    /// Average input tokens per message by model family.
    private let avgInputTokensPerMessage: [String: Int] = [
        "haiku": 800,
        "sonnet": 1500,
        "opus": 2000
    ]

    /// Average output tokens per message by model family.
    private let avgOutputTokensPerMessage: [String: Int] = [
        "haiku": 1200,
        "sonnet": 2000,
        "opus": 3000
    ]

    /// Default input tokens per message for unknown models.
    private let defaultInputTokensPerMessage = 1500
    /// Default output tokens per message for unknown models.
    private let defaultOutputTokensPerMessage = 2000

    /// Rate limit: maximum messages allowed within the sliding window.
    private let rateLimitMessages = 45
    /// Rate limit: sliding window duration in hours.
    private let rateLimitWindowHours = 5.0

    // MARK: - Date Formatting

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Token Estimation

    /// Estimate input and output tokens for a given message count and model.
    ///
    /// Uses model-specific averages: haiku (~800 in/1200 out), sonnet (~1500 in/2000 out),
    /// opus (~2000 in/3000 out) per message. Unknown models default to sonnet-level estimates.
    ///
    /// - Parameters:
    ///   - messageCount: Number of messages to estimate for.
    ///   - model: The model string (e.g. "sonnet", "claude-opus-4-20250514").
    /// - Returns: A tuple of (estimatedInputTokens, estimatedOutputTokens).
    func estimateTokens(messageCount: Int, model: String) -> (input: Int, output: Int) {
        let modelKey = resolveModelFamily(model)
        let inputPerMsg = avgInputTokensPerMessage[modelKey] ?? defaultInputTokensPerMessage
        let outputPerMsg = avgOutputTokensPerMessage[modelKey] ?? defaultOutputTokensPerMessage
        return (messageCount * inputPerMsg, messageCount * outputPerMsg)
    }

    // MARK: - Daily Consumption

    /// Build a day-by-day consumption breakdown for the given date range.
    ///
    /// Pre-populates every day in `[start, end]` with zero values so charts
    /// always have complete coverage, then aggregates session data.
    ///
    /// - Parameters:
    ///   - sessions: Sessions to aggregate.
    ///   - start: Beginning of the reporting window.
    ///   - end: End of the reporting window.
    /// - Returns: Array of ``DailyConsumption`` sorted by date ascending.
    func buildDailyConsumption(
        sessions: [ChatSession],
        start: Date,
        end: Date
    ) -> [DailyConsumption] {
        let calendar = Calendar.current

        // Pre-fill all days in the range
        var dayMap: [String: (inputTokens: Int, outputTokens: Int, cost: Double, messages: Int, sessions: Int)] = [:]
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            dayMap[Self.dayFormatter.string(from: current)] = (0, 0, 0.0, 0, 0)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // Aggregate sessions into day buckets
        for session in sessions {
            let createdAt = session.createdAt
            guard createdAt >= start, createdAt <= end else { continue }
            let dateStr = Self.dayFormatter.string(from: createdAt)
            let tokens = estimateTokens(messageCount: session.messageCount, model: session.model)
            let cost = computeCost(inputTokens: tokens.input, outputTokens: tokens.output, model: session.model)

            var entry = dayMap[dateStr] ?? (0, 0, 0.0, 0, 0)
            entry.inputTokens += tokens.input
            entry.outputTokens += tokens.output
            entry.cost += cost
            entry.messages += session.messageCount
            entry.sessions += 1
            dayMap[dateStr] = entry
        }

        return dayMap
            .map { dateStr, stats in
                DailyConsumption(
                    date: dateStr,
                    estimatedInputTokens: stats.inputTokens,
                    estimatedOutputTokens: stats.outputTokens,
                    estimatedCostUSD: round(stats.cost * 100) / 100,
                    messageCount: stats.messages,
                    sessionCount: stats.sessions
                )
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Model Breakdown

    /// Group sessions by model and compute token/cost totals for each.
    ///
    /// - Parameter sessions: Sessions to aggregate.
    /// - Returns: Array of ``ModelConsumption`` sorted by token count descending.
    func buildModelBreakdown(sessions: [ChatSession]) -> [ModelConsumption] {
        var modelMap: [String: (tokens: Int, cost: Double, messages: Int)] = [:]

        for session in sessions {
            let modelKey = resolveModelFamily(session.model)
            let tokens = estimateTokens(messageCount: session.messageCount, model: session.model)
            let totalTokens = tokens.input + tokens.output
            let cost = computeCost(inputTokens: tokens.input, outputTokens: tokens.output, model: session.model)

            var entry = modelMap[modelKey] ?? (0, 0.0, 0)
            entry.tokens += totalTokens
            entry.cost += cost
            entry.messages += session.messageCount
            modelMap[modelKey] = entry
        }

        let grandTotalTokens = modelMap.values.reduce(0) { $0 + $1.tokens }

        return modelMap
            .map { model, stats in
                let pct: Double = grandTotalTokens > 0
                    ? min(100.0, Double(stats.tokens) / Double(grandTotalTokens) * 100.0)
                    : 0.0
                return ModelConsumption(
                    model: model,
                    tokenCount: stats.tokens,
                    costUSD: round(stats.cost * 100) / 100,
                    messageCount: stats.messages,
                    percentageOfTotal: round(pct * 10) / 10
                )
            }
            .sorted { $0.tokenCount > $1.tokenCount }
    }

    // MARK: - Project Breakdown

    /// Group sessions by project and compute consumption totals for each.
    ///
    /// - Parameter sessions: Sessions to aggregate.
    /// - Returns: Array of ``ProjectConsumption`` sorted by estimated tokens descending.
    func buildProjectBreakdown(sessions: [ChatSession]) -> [ProjectConsumption] {
        var projectMap: [String: (tokens: Int, cost: Double, messages: Int, sessions: Int)] = [:]

        for session in sessions {
            let projectName = session.projectName ?? "No Project"
            let tokens = estimateTokens(messageCount: session.messageCount, model: session.model)
            let totalTokens = tokens.input + tokens.output
            let cost = computeCost(inputTokens: tokens.input, outputTokens: tokens.output, model: session.model)

            var entry = projectMap[projectName] ?? (0, 0.0, 0, 0)
            entry.tokens += totalTokens
            entry.cost += cost
            entry.messages += session.messageCount
            entry.sessions += 1
            projectMap[projectName] = entry
        }

        let grandTotalTokens = projectMap.values.reduce(0) { $0 + $1.tokens }

        return projectMap
            .map { name, stats in
                let pct: Double = grandTotalTokens > 0
                    ? min(100.0, Double(stats.tokens) / Double(grandTotalTokens) * 100.0)
                    : 0.0
                return ProjectConsumption(
                    projectName: name,
                    estimatedTokens: stats.tokens,
                    estimatedCostUSD: round(stats.cost * 100) / 100,
                    messageCount: stats.messages,
                    sessionCount: stats.sessions,
                    percentageOfTotal: round(pct * 10) / 10
                )
            }
            .sorted { $0.estimatedTokens > $1.estimatedTokens }
    }

    // MARK: - Burn Rate

    /// Calculate the current consumption burn rate over a recent time window.
    ///
    /// Computes messages/hour and tokens/hour within the window, then projects
    /// when the 45-message/5-hour rate limit will be exhausted at the current pace.
    ///
    /// - Parameters:
    ///   - sessions: All available sessions (will be filtered to the window).
    ///   - windowHours: Number of recent hours to analyze (e.g. 5).
    /// - Returns: A ``BurnRateInfo`` with rates and optional exhaustion projection.
    func calculateBurnRate(
        sessions: [ChatSession],
        windowHours: Double = 5.0
    ) -> BurnRateInfo {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowHours * 3600)

        // Filter sessions active within the window
        let windowSessions = sessions.filter { session in
            session.createdAt >= windowStart || session.lastActiveAt >= windowStart
        }

        let totalMessages = windowSessions.reduce(0) { $0 + $1.messageCount }
        let messagesPerHour = windowHours > 0 ? Double(totalMessages) / windowHours : 0.0

        // Estimate tokens and cost in the window
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCost = 0.0

        for session in windowSessions {
            let tokens = estimateTokens(messageCount: session.messageCount, model: session.model)
            totalInputTokens += tokens.input
            totalOutputTokens += tokens.output
            totalCost += computeCost(inputTokens: tokens.input, outputTokens: tokens.output, model: session.model)
        }

        let totalTokens = totalInputTokens + totalOutputTokens
        let tokensPerHour = windowHours > 0 ? Double(totalTokens) / windowHours : 0.0
        let costPerHour = windowHours > 0 ? totalCost / windowHours : 0.0

        // Project exhaustion based on 45-message/5-hour rate limit
        var projectedExhaustionDate: String?
        var projectedHoursRemaining: Double?

        if messagesPerHour > 0 {
            let messagesRemaining = max(0, rateLimitMessages - totalMessages)
            if messagesRemaining > 0 {
                let hoursRemaining = Double(messagesRemaining) / messagesPerHour
                projectedHoursRemaining = round(hoursRemaining * 100) / 100
                let exhaustionDate = now.addingTimeInterval(hoursRemaining * 3600)
                projectedExhaustionDate = Self.isoFormatter.string(from: exhaustionDate)
            } else {
                // Already at or past the limit
                projectedHoursRemaining = 0
                projectedExhaustionDate = Self.isoFormatter.string(from: now)
            }
        }

        return BurnRateInfo(
            messagesPerHour: round(messagesPerHour * 100) / 100,
            estimatedTokensPerHour: round(tokensPerHour),
            estimatedCostPerHour: round(costPerHour * 100) / 100,
            projectedExhaustionDate: projectedExhaustionDate,
            projectedHoursRemaining: projectedHoursRemaining,
            windowDurationHours: windowHours
        )
    }

    // MARK: - Anomaly Detection

    /// Detect consumption anomalies by comparing each day to a rolling 7-day average.
    ///
    /// Flags days where message count deviates from the rolling average:
    /// - **Warning**: >50% deviation
    /// - **Critical**: >100% deviation
    ///
    /// - Parameter dailyData: Sorted daily consumption data (ascending by date).
    /// - Returns: Array of ``AnomalyFlag`` for detected anomalies.
    func detectAnomalies(dailyData: [DailyConsumption]) -> [AnomalyFlag] {
        guard dailyData.count > 1 else { return [] }

        var anomalies: [AnomalyFlag] = []
        let warningThreshold = 0.50
        let criticalThreshold = 1.00

        for i in 0..<dailyData.count {
            // Build the rolling 7-day window (up to 7 days before this day)
            let windowStart = max(0, i - 7)
            let windowEnd = i
            guard windowEnd > windowStart else { continue }

            let windowSlice = dailyData[windowStart..<windowEnd]
            let avgMessages = Double(windowSlice.reduce(0) { $0 + $1.messageCount }) / Double(windowSlice.count)

            guard avgMessages > 0 else { continue }

            let current = dailyData[i]
            let deviation = (Double(current.messageCount) - avgMessages) / avgMessages

            let absDeviation = abs(deviation)
            guard absDeviation > warningThreshold else { continue }

            let severity: AnomalySeverity = absDeviation > criticalThreshold ? .critical : .warning
            let type: AnomalyType = deviation > 0 ? .spike : .drop
            let pctChange = round(deviation * 1000) / 10 // e.g. 1.5 -> 150.0%

            let description: String
            let context: String
            switch (type, severity) {
            case (.spike, .critical):
                description = "Critical spike: \(current.messageCount) messages vs \(Int(avgMessages)) avg"
                context = "Message count on \(current.date) was \(Int(absDeviation * 100))% above the 7-day rolling average. This may indicate an intensive development session or automated usage."
            case (.spike, .warning):
                description = "Elevated usage: \(current.messageCount) messages vs \(Int(avgMessages)) avg"
                context = "Message count on \(current.date) was \(Int(absDeviation * 100))% above the 7-day rolling average. Consider monitoring if this trend continues."
            case (.drop, .critical):
                description = "Critical drop: \(current.messageCount) messages vs \(Int(avgMessages)) avg"
                context = "Message count on \(current.date) was \(Int(absDeviation * 100))% below the 7-day rolling average. This could indicate a service disruption or change in usage patterns."
            case (.drop, .warning):
                description = "Reduced usage: \(current.messageCount) messages vs \(Int(avgMessages)) avg"
                context = "Message count on \(current.date) was \(Int(absDeviation * 100))% below the 7-day rolling average."
            default:
                description = "Anomaly detected on \(current.date)"
                context = "Deviation of \(Int(absDeviation * 100))% from 7-day rolling average."
            }

            anomalies.append(AnomalyFlag(
                id: "\(type.rawValue)-\(current.date)",
                type: type,
                severity: severity,
                affectedDate: current.date,
                percentageChange: pctChange,
                description: description,
                context: context
            ))
        }

        return anomalies
    }

    // MARK: - Private Helpers

    /// Resolve a model string to its family key (haiku, sonnet, opus).
    ///
    /// Handles full model IDs like "claude-sonnet-4-20250514" as well as
    /// short names like "sonnet".
    private func resolveModelFamily(_ model: String) -> String {
        let lowercased = model.lowercased()
        if lowercased.contains("haiku") { return "haiku" }
        if lowercased.contains("opus") { return "opus" }
        if lowercased.contains("sonnet") { return "sonnet" }
        return "sonnet" // Default to sonnet for unknown models
    }

    /// Compute estimated cost in USD for a given token count and model.
    ///
    /// Resolves the model family (haiku/sonnet/opus) before looking up pricing,
    /// so full model IDs like "claude-sonnet-4-20250514" get correct costs.
    func computeCost(inputTokens: Int, outputTokens: Int, model: String) -> Double {
        let claudeModel = ClaudeModel(rawValue: resolveModelFamily(model))
        let inputCost = Double(inputTokens) / 1_000_000.0 * claudeModel.costPerMInputTokens
        let outputCost = Double(outputTokens) / 1_000_000.0 * claudeModel.costPerMOutputTokens
        return inputCost + outputCost
    }
}
