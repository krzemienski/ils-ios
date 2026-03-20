import Foundation
import ILSShared

// MARK: - Conflict Types

/// The result of comparing local and server versions of a session.
enum ConflictResult: Sendable {
    /// No conflict detected — versions match or no local changes exist.
    case noConflict

    /// Conflict was automatically resolved using last-write-wins strategy.
    /// The associated session is the merged result.
    case autoResolved(ChatSession)

    /// Conflict requires manual resolution.
    /// Provides both versions and the list of fields that differ.
    case manualRequired(local: ChatSession, server: ChatSession, fields: [ConflictField])
}

/// A field that differs between local and server versions of a session.
enum ConflictField: String, Codable, Sendable {
    case name
    case status
    case messageCount
}

/// How the user (or system) chose to resolve a conflict.
enum ConflictResolution: Sendable {
    /// Discard server changes and keep the local version.
    case keepLocal

    /// Discard local changes and accept the server version.
    case keepServer

    /// Use a manually merged session that combines fields from both.
    case merge(ChatSession)
}

// MARK: - ConflictResolver

/// Detects and resolves conflicts between locally cached sessions and their
/// server counterparts using version comparison and last-write-wins strategy.
///
/// Follows the actor-based singleton pattern established by `CacheService`
/// and `SyncCoordinator`. Conflict state is persisted via `LocalDatabase`
/// sync metadata so it survives app restarts.
actor ConflictResolver {
    static let shared = ConflictResolver()

    private let db = LocalDatabase.shared

    private init() {}

    // MARK: - Conflict Detection

    /// Compare a locally cached session against the server version to detect conflicts.
    ///
    /// Detection logic:
    /// 1. If no local changes exist (`localVersion == serverVersion`), there is no conflict.
    /// 2. If the server version advanced while the local session has pending changes,
    ///    a conflict exists.
    /// 3. For auto-resolution, last-write-wins based on `lastActiveAt` is applied when
    ///    no field-level differences are found beyond timestamps.
    /// 4. If specific fields (name, status, messageCount) differ, manual resolution
    ///    may be required.
    ///
    /// - Parameters:
    ///   - localSession: The locally cached version of the session.
    ///   - serverSession: The latest version from the server.
    /// - Returns: A `ConflictResult` indicating whether a conflict exists and how it was handled.
    func detectConflict(localSession: ChatSession, serverSession: ChatSession) -> ConflictResult {
        // Fetch sync metadata to compare versions
        let metadata: SyncMetadata?
        do {
            metadata = try db.getSessionSyncMetadata(sessionId: localSession.id.uuidString)
        } catch {
            AppLogger.shared.warning(
                "Failed to read sync metadata for session \(localSession.id): \(error.localizedDescription)",
                category: "sync"
            )
            return .noConflict
        }

        // If no metadata exists or no local changes are pending, no conflict
        guard let metadata, metadata.hasLocalChanges else {
            return .noConflict
        }

        // Identify which fields differ between local and server
        let conflictingFields = detectFieldDifferences(local: localSession, server: serverSession)

        // If no meaningful fields differ, the server just has newer metadata — no conflict
        if conflictingFields.isEmpty {
            return .noConflict
        }

        // Attempt auto-resolution via last-write-wins on lastActiveAt
        if shouldAutoResolve(conflictingFields: conflictingFields) {
            let winner = lastWriteWins(local: localSession, server: serverSession)

            AppLogger.shared.info(
                "Auto-resolved conflict for session \(localSession.id) using last-write-wins "
                + "(winner: \(winner.id == localSession.id ? "local" : "server"))",
                category: "sync"
            )

            return .autoResolved(winner)
        }

        // Multiple important fields differ — require manual resolution
        AppLogger.shared.info(
            "Manual resolution required for session \(localSession.id) — "
            + "conflicting fields: \(conflictingFields.map(\.rawValue).joined(separator: ", "))",
            category: "sync"
        )

        return .manualRequired(local: localSession, server: serverSession, fields: conflictingFields)
    }

    // MARK: - Conflict Resolution

    /// Apply a chosen resolution for a conflicted session.
    ///
    /// Updates the local database with the resolved session data and resets
    /// sync metadata to clear the conflict state.
    ///
    /// - Parameters:
    ///   - sessionId: The ID of the session being resolved.
    ///   - resolution: The chosen resolution strategy.
    func resolveConflict(sessionId: UUID, resolution: ConflictResolution) async {
        let resolvedSession: ChatSession

        switch resolution {
        case .keepLocal:
            // Local version stays — just clear the conflict state
            AppLogger.shared.info(
                "Resolving conflict for \(sessionId): keeping local version",
                category: "sync"
            )
            clearConflictState(sessionId: sessionId)
            return

        case .keepServer:
            // Accept the server version — retrieve from conflict data
            guard let serverSession = loadConflictData(sessionId: sessionId) else {
                AppLogger.shared.error(
                    "Cannot resolve conflict for \(sessionId): no stored server data",
                    category: "sync"
                )
                return
            }
            resolvedSession = serverSession

        case .merge(let merged):
            resolvedSession = merged
        }

        // Persist the resolved session to the cache
        do {
            try db.saveSessions([resolvedSession])
            AppLogger.shared.info(
                "Resolved conflict for \(sessionId): saved merged/server version",
                category: "sync"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to save resolved session \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
        }

        clearConflictState(sessionId: sessionId)
    }

    // MARK: - Private Helpers

    /// Detect which high-level fields differ between local and server sessions.
    private func detectFieldDifferences(local: ChatSession, server: ChatSession) -> [ConflictField] {
        var fields: [ConflictField] = []

        if local.name != server.name {
            fields.append(.name)
        }
        if local.status != server.status {
            fields.append(.status)
        }
        if local.messageCount != server.messageCount {
            fields.append(.messageCount)
        }

        return fields
    }

    /// Determine whether the conflict can be auto-resolved.
    ///
    /// Auto-resolution is applied when only a single field differs,
    /// keeping the process simple and predictable. Multiple differing
    /// fields warrant user attention.
    private func shouldAutoResolve(conflictingFields: [ConflictField]) -> Bool {
        return conflictingFields.count <= 1
    }

    /// Apply last-write-wins strategy based on `lastActiveAt` timestamps.
    private func lastWriteWins(local: ChatSession, server: ChatSession) -> ChatSession {
        return local.lastActiveAt >= server.lastActiveAt ? local : server
    }

    /// Store the server session snapshot as conflict data in sync metadata.
    ///
    /// Called when a conflict is detected so the server version is available
    /// for later resolution without re-fetching from the network.
    func storeConflictData(sessionId: UUID, serverSession: ChatSession) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(serverSession)

            // Retrieve current metadata to get the server version
            guard var metadata = try db.getSessionSyncMetadata(sessionId: sessionId.uuidString) else {
                AppLogger.shared.warning(
                    "No sync metadata found for session \(sessionId) — cannot store conflict data",
                    category: "sync"
                )
                return
            }

            metadata.markConflict(
                serverVersion: metadata.serverVersion,
                data: data
            )

            // Persist the conflict status
            try db.updateSessionSyncStatus(
                sessionId: sessionId.uuidString,
                status: .conflict,
                failureReason: nil
            )
        } catch {
            AppLogger.shared.error(
                "Failed to store conflict data for \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
        }
    }

    /// Load the stored server session from conflict metadata.
    private func loadConflictData(sessionId: UUID) -> ChatSession? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            guard let metadata = try db.getSessionSyncMetadata(sessionId: sessionId.uuidString),
                  let data = metadata.conflictData else { return nil }
            return try decoder.decode(ChatSession.self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to load conflict data for \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
            return nil
        }
    }

    /// Clear conflict state and mark the session as synced.
    private func clearConflictState(sessionId: UUID) {
        do {
            try db.updateSessionSyncStatus(
                sessionId: sessionId.uuidString,
                status: .synced,
                failureReason: nil
            )

            AppLogger.shared.info(
                "Cleared conflict state for session \(sessionId)",
                category: "sync"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to clear conflict state for \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
        }
    }
}
