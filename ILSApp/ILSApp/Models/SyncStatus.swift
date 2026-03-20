import Foundation

// MARK: - SyncStatus

/// Synchronization state for a locally cached session or entity.
///
/// Tracks whether local data is in sync with the server, awaiting upload,
/// in conflict, or has encountered an unrecoverable error. Used by
/// ``SyncMetadata`` and the sync UI to communicate per-session sync health.
enum SyncStatus: String, Codable, Sendable, CaseIterable {
    /// Local data matches the server version — no action needed.
    case synced

    /// Local changes exist that have not yet been pushed to the server.
    case pending

    /// Local and server versions have diverged and require manual resolution.
    case conflict

    /// The last sync attempt failed (see ``SyncMetadata/failureReason``).
    case failed

    /// Human-readable label suitable for display in the UI.
    var displayName: String {
        switch self {
        case .synced:   return "Synced"
        case .pending:  return "Pending"
        case .conflict: return "Conflict"
        case .failed:   return "Failed"
        }
    }

    /// Whether this status indicates the session needs attention.
    var needsAttention: Bool {
        switch self {
        case .synced, .pending: return false
        case .conflict, .failed: return true
        }
    }
}

// MARK: - SyncMetadata

/// Per-entity metadata tracking synchronization state between
/// the local cache and the remote server.
///
/// Stored alongside cached sessions to enable offline-first editing
/// with conflict detection. The ``localVersion`` and ``serverVersion``
/// fields use monotonic counters so that stale writes can be detected
/// without requiring timestamps alone.
struct SyncMetadata: Codable, Sendable, Equatable {
    /// Monotonically increasing version counter for local edits.
    /// Incremented each time the user modifies the cached entity.
    var localVersion: Int

    /// Last known server version at the time of the most recent
    /// successful sync. Used to detect conflicts when pushing local changes.
    var serverVersion: Int

    /// Timestamp of the last successful synchronization with the server.
    /// `nil` if the entity has never been synced.
    var lastSyncedAt: Date?

    /// Current synchronization status for this entity.
    var syncStatus: SyncStatus

    /// Human-readable description of the failure when ``syncStatus`` is
    /// ``SyncStatus/failed``. `nil` otherwise.
    var failureReason: String?

    /// JSON-encoded snapshot of the server's version of the entity,
    /// populated when ``syncStatus`` is ``SyncStatus/conflict``.
    /// Used to present a diff or merge UI to the user.
    var conflictData: Data?

    /// Creates metadata for a freshly cached entity that is in sync
    /// with the server.
    static func synced(version: Int = 0) -> SyncMetadata {
        SyncMetadata(
            localVersion: version,
            serverVersion: version,
            lastSyncedAt: Date(),
            syncStatus: .synced,
            failureReason: nil,
            conflictData: nil
        )
    }

    /// Whether local changes exist that haven't been pushed to the server.
    var hasLocalChanges: Bool {
        localVersion > serverVersion
    }

    /// Whether a conflict exists between local and server versions.
    var hasConflict: Bool {
        syncStatus == .conflict
    }

    /// Marks the metadata as having a pending local change by
    /// incrementing ``localVersion`` and setting status to ``SyncStatus/pending``.
    mutating func markPending() {
        localVersion += 1
        syncStatus = .pending
        failureReason = nil
        conflictData = nil
    }

    /// Marks the metadata as successfully synced at the given server version.
    /// - Parameter version: The server version after a successful push/pull.
    mutating func markSynced(version: Int) {
        serverVersion = version
        localVersion = version
        lastSyncedAt = Date()
        syncStatus = .synced
        failureReason = nil
        conflictData = nil
    }

    /// Marks the metadata as failed with the given reason.
    /// - Parameter reason: A human-readable description of the failure.
    mutating func markFailed(reason: String) {
        syncStatus = .failed
        failureReason = reason
        conflictData = nil
    }

    /// Marks the metadata as conflicted, storing the server's version data.
    /// - Parameters:
    ///   - serverVersion: The server's current version number.
    ///   - data: JSON-encoded snapshot of the server's entity.
    mutating func markConflict(serverVersion: Int, data: Data) {
        self.serverVersion = serverVersion
        syncStatus = .conflict
        failureReason = nil
        conflictData = data
    }
}
