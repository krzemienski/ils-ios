import Foundation
import Observation

// MARK: - PermissionHistoryViewModel

/// ViewModel for the permission history screen.
///
/// Loads history entries and aggregated stats from PermissionHistoryService (local GRDB storage).
/// No API client needed — all data is stored on-device.
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
