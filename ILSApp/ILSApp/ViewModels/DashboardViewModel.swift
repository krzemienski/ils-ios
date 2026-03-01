import Foundation
import Observation
import ILSShared

@Observable
@MainActor
class DashboardViewModel: BaseViewModel {
    var stats: StatsResponse?
    var recentSessions: [ChatSession] = []
    var totalCost: Double = 0.0
    var lastUpdated: Date?

    // Sparkline data (synthetic from recent sessions for visual interest)
    var sessionSparkline: [Double] { generateSparkline(count: 8, seed: stats?.sessions.total ?? 0) }
    var projectSparkline: [Double] { generateSparkline(count: 8, seed: stats?.projects.total ?? 0) }
    var skillSparkline: [Double] { generateSparkline(count: 8, seed: stats?.skills.total ?? 0) }
    var mcpSparkline: [Double] { generateSparkline(count: 8, seed: stats?.mcpServers.total ?? 0) }

    /// Formatted total cost as "$X.XX"
    var formattedTotalCost: String {
        String(format: "$%.2f", totalCost)
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading dashboard..."
        }
        return stats == nil ? "No data available" : ""
    }

    /// Load all dashboard data (stats + recent activity)
    func loadAll() async {
        guard client != nil else { return }
        isLoading = true
        error = nil

        // Cache-first: show cached sessions as recent activity while loading
        if recentSessions.isEmpty {
            let cached = await CacheService.shared.getCachedSessions()
            if !cached.isEmpty {
                // Use the most recent cached sessions as placeholder
                recentSessions = Array(cached.prefix(10))
                computeTotalCost()
                AppLogger.shared.info("Loaded \(cached.count) cached sessions for dashboard", category: "dashboard")
            }
        }

        // SPERF-04: Run loadStats and loadRecentActivity in parallel.
        // Both write to different @Observable properties (stats vs recentSessions).
        // The actual network calls run on the APIClient actor, so async let allows
        // both requests to be in-flight simultaneously rather than waiting sequentially.
        async let statsResult: Void = loadStats()
        async let recentResult: Void = loadRecentActivity()
        _ = await (statsResult, recentResult)
        computeTotalCost()

        // Cache the fresh recent sessions
        if !recentSessions.isEmpty {
            // C-MED-5: Use Task instead of Task.detached — only calls CacheService actor,
            // no need to escape @MainActor isolation.
            let sessions = self.recentSessions
            Task { await CacheService.shared.cacheSessions(sessions) }
        }

        isLoading = false
    }

    /// Load dashboard stats
    func loadStats() async {
        guard let client else { return }
        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            if let data = response.data {
                stats = data
                lastUpdated = Date()
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load stats: \(error.localizedDescription)", category: "dashboard")
        }
    }

    /// Load recent activity timeline
    func loadRecentActivity() async {
        guard let client else { return }
        do {
            let response: APIResponse<RecentSessionsResponse> = try await client.get("/stats/recent")
            if let data = response.data {
                recentSessions = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load recent activity: \(error.localizedDescription)", category: "dashboard")
        }
    }

    /// Compute total cost from all recent sessions
    private func computeTotalCost() {
        totalCost = recentSessions.reduce(0.0) { sum, session in
            sum + (session.totalCostUSD ?? 0.0)
        }
    }

    /// Retry loading dashboard data
    func retryLoad() async {
        await loadAll()
    }

    /// Synthetic sample data for dashboard sparkline visualization.
    /// Generates deterministic pseudo-random values from a seed for visual variety.
    private func generateSparkline(count: Int, seed: Int) -> [Double] {
        guard seed > 0 else { return [] }
        let base = Double(seed)
        return (0..<count).map { i in
            let variance = sin(Double(i) * 0.8 + Double(seed % 7)) * base * 0.3
            return max(0, base + variance)
        }
    }
}
