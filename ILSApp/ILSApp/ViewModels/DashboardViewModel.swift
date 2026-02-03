import Foundation
import ILSShared

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var recentSessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading dashboard..."
        }
        return stats == nil ? "No data available" : ""
    }

    /// Load all dashboard data (stats + recent activity)
    func loadAll() async {
        isLoading = true
        error = nil

        await loadStats()
        await loadRecentActivity()

        isLoading = false
    }

    /// Load dashboard stats
    func loadStats() async {
        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            if let data = response.data {
                stats = data
            }
        } catch {
            self.error = error
            print("❌ Failed to load stats: \(error.localizedDescription)")
        }
    }

    /// Load recent activity timeline
    func loadRecentActivity() async {
        do {
            let response: APIResponse<RecentSessionsResponse> = try await client.get("/stats/recent")
            if let data = response.data {
                recentSessions = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load recent activity: \(error.localizedDescription)")
        }
    }

    /// Retry loading dashboard data
    func retryLoad() async {
        await loadAll()
    }
}
