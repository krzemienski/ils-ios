import Foundation

/// High-level service for recording and querying permission decisions.
///
/// Wraps LocalDatabase to provide a permission-specific API with stats aggregation.
/// All read operations return empty/default values on error; write/clear operations rethrow.
actor PermissionHistoryService {
    static let shared = PermissionHistoryService()

    private let db = LocalDatabase.shared

    private init() {}

    // MARK: - Record

    /// Record a permission decision to local storage.
    ///
    /// - Throws: Any GRDB error encountered during the write.
    func record(_ entry: PermissionHistoryEntry) async throws {
        do {
            try await db.savePermissionEntry(entry)
        } catch {
            AppLogger.shared.error(
                "Failed to record permission entry: \(error.localizedDescription)",
                category: "permissions"
            )
            throw error
        }
    }

    // MARK: - Fetch

    /// Retrieve permission history ordered by most recent first.
    ///
    /// - Parameter limit: Maximum number of entries to return (default 200).
    /// - Returns: Array of history entries, or empty array on error.
    func fetchHistory(limit: Int = 200) async -> [PermissionHistoryEntry] {
        do {
            return try await db.fetchPermissionHistory(limit: limit)
        } catch {
            AppLogger.shared.error(
                "Failed to fetch permission history: \(error.localizedDescription)",
                category: "permissions"
            )
            return []
        }
    }

    /// Aggregate permission statistics via SQL GROUP BY queries.
    ///
    /// - Returns: Aggregated stats, or zeroed stats on error.
    func fetchStats() async -> PermissionStats {
        do {
            return try await db.fetchPermissionStats()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch permission stats: \(error.localizedDescription)",
                category: "permissions"
            )
            return PermissionStats(
                totalApproved: 0,
                totalDenied: 0,
                totalAutoApproved: 0,
                approvalRate: 0.0,
                topTools: [:]
            )
        }
    }

    // MARK: - Clear

    /// Delete all permission history records.
    ///
    /// - Throws: Any GRDB error encountered during the delete.
    func clearHistory() async throws {
        do {
            try await db.clearPermissionHistory()
        } catch {
            AppLogger.shared.error(
                "Failed to clear permission history: \(error.localizedDescription)",
                category: "permissions"
            )
            throw error
        }
    }
}
