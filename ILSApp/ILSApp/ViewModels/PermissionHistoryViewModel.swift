import Foundation
import Observation
import ILSShared

// MARK: - PermissionHistoryViewModel

/// ViewModel for the permission history screen.
///
/// Loads history entries and aggregated stats from PermissionHistoryService (local GRDB storage).
/// Also fetches permission policy names from the backend to annotate auto-resolved entries
/// with the rule name that matched them.
@MainActor
@Observable
class PermissionHistoryViewModel {
    var history: [PermissionHistoryEntry] = []
    var stats = PermissionStats(
        totalApproved: 0,
        totalDenied: 0,
        totalAutoApproved: 0,
        approvalRate: 0.0,
        topTools: [:]
    )
    var isLoading = false
    var error: Error?
    var showClearConfirmation = false

    /// Maps policy UUID to its display name, populated by `loadPolicyNames(apiClient:)`.
    var policyNames: [UUID: String] = [:]

    private let apiService = PermissionPolicyAPIService()

    init() {
        Task { await loadHistory() }
    }

    // MARK: - Load

    func loadHistory() async {
        isLoading = true
        error = nil

        async let fetchedHistory = PermissionHistoryService.shared.fetchHistory()
        async let fetchedStats = PermissionHistoryService.shared.fetchStats()

        history = await fetchedHistory
        stats = await fetchedStats

        isLoading = false
    }

    func refresh() async {
        await loadHistory()
    }

    // MARK: - Policy Names

    /// Fetches all permission policies and builds a `[UUID: String]` lookup of id → name.
    ///
    /// Called from the view once an API client is available. Silently no-ops on error
    /// so the history list still renders without policy names.
    func loadPolicyNames(apiClient: APIClient) async {
        do {
            let response = try await apiService.fetchPolicies(apiClient: apiClient)
            var names: [UUID: String] = [:]
            for policy in response.items {
                names[policy.id] = policy.name
            }
            policyNames = names
        } catch {
            AppLogger.shared.error(
                "Failed to load policy names for history: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Clear

    func clearHistory() async {
        do {
            try await PermissionHistoryService.shared.clearHistory()
            await loadHistory()
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to clear permission history: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }
}
