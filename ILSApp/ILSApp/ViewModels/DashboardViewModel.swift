import Foundation
import ILSShared

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var recentSessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var totalCost: Double = 0.0

    private var client: APIClient?

    // Sparkline data (synthetic from recent sessions for visual interest)
    var sessionSparkline: [Double] { generateSparkline(count: 8, seed: stats?.sessions.total ?? 0) }
    var projectSparkline: [Double] { generateSparkline(count: 8, seed: stats?.projects.total ?? 0) }
    var skillSparkline: [Double] { generateSparkline(count: 8, seed: stats?.skills.total ?? 0) }
    var mcpSparkline: [Double] { generateSparkline(count: 8, seed: stats?.mcpServers.total ?? 0) }

    /// Formatted total cost as "$X.XX"
    var formattedTotalCost: String {
        String(format: "$%.2f", totalCost)
    }

    init() {}

    func configure(client: APIClient) {
        self.client = client
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

        await loadStats()
        await loadRecentActivity()
        computeTotalCost()

        isLoading = false
    }

    /// Load dashboard stats
    func loadStats() async {
        guard let client else { return }
        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            if let data = response.data {
                stats = data
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
