import Foundation
import ILSShared

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    /// Load dashboard stats from backend
    func loadStats() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            if let data = response.data {
                stats = data
            }
        } catch {
            self.error = error
            print("❌ Failed to load dashboard stats: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadStats() async {
        await loadStats()
    }
}
