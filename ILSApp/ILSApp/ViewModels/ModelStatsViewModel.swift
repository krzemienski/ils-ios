import Foundation
import Observation
import ILSShared

/// View model for the model usage statistics screen.
///
/// Fetches aggregated model usage data from `GET /sessions/model-stats` and
/// exposes it to `ModelStatsView` via the `@Observable` macro.
@MainActor
@Observable
class ModelStatsViewModel: BaseViewModel {

    /// Aggregated model usage statistics returned by the backend.
    var stats: ModelStatsResponse?

    /// Fetch model usage statistics from the backend.
    ///
    /// Sets `isLoading` while the request is in flight and stores the result in
    /// ``stats``. Any error is captured in `BaseViewModel.error`.
    func loadStats() async {
        guard let client else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<ModelStatsResponse> = try await client.get("/sessions/model-stats")
            stats = response.data
        } catch let fetchError {
            error = fetchError
            AppLogger.shared.error("Failed to load model stats: \(fetchError)", category: "ui")
        }
    }
}
