import Foundation
import ILSShared

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tab: SidebarItem
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var recentSessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    var quickActions: [QuickAction] {
        [
            QuickAction(title: "Discover Skills", icon: "wand.and.stars", tab: .skills),
            QuickAction(title: "Browse Plugins", icon: "puzzlepiece.extension", tab: .plugins),
            QuickAction(title: "Configure MCP", icon: "server.rack", tab: .mcp),
            QuickAction(title: "Edit Settings", icon: "gear", tab: .settings),
        ]
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
        guard let client else { return }
        isLoading = true
        error = nil

        await loadStats()
        await loadRecentActivity()

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
            print("❌ Failed to load stats: \(error.localizedDescription)")
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
            print("❌ Failed to load recent activity: \(error.localizedDescription)")
        }
    }

    /// Retry loading dashboard data
    func retryLoad() async {
        await loadAll()
    }
}
