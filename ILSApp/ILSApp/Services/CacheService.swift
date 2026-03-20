import Foundation
import ILSShared

/// High-level caching API that wraps LocalDatabase.
///
/// Provides cache-first data loading with configurable expiry times.
/// TTL and capacity limits are driven by `OfflineCacheSettings`.
actor CacheService {
    static let shared = CacheService()

    private let db = LocalDatabase.shared
    private let settings = OfflineCacheSettings.shared

    private init() {}

    /// Initialize the underlying database. Call once at app launch.
    func initialize() async {
        do {
            try await db.initialize()
            try await db.cleanupExpired(olderThan: settings.cacheTTL)
            AppLogger.shared.info("CacheService initialized", category: "cache")
        } catch {
            AppLogger.shared.error(
                "CacheService initialization failed: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    private let syncCoordinator = SyncCoordinator.shared
    private let conflictResolver = ConflictResolver.shared

    // MARK: - Sessions

    /// Cache a list of sessions from the network, respecting the configured session count limit.
    ///
    /// When `OfflineCacheSettings.maxSessions` is non-zero, the list is sorted by
    /// `lastActiveAt` descending and trimmed to the limit before saving, so the most
    /// recently active sessions are always retained. Sessions not in the top-N are discarded
    /// to keep cache size bounded.
    ///
    /// Before saving, compares incoming server sessions against locally cached sessions
    /// to detect version changes. For sessions with pending local changes and differing
    /// server data, runs conflict detection via ``ConflictResolver``. Updates sync metadata
    /// after caching to reflect the latest server state.
    ///
    /// - Parameter sessions: Array of ChatSession objects from the backend API.
    /// - Note: No-ops silently if caching is disabled for the session type.
    func cacheSessions(_ sessions: [ChatSession]) async {
        guard settings.isCachingEnabled(for: .sessions) else { return }
        do {
            let toCache = applySessionLimit(sessions)

            // Detect conflicts for sessions with pending local changes.
            // Returns IDs that should NOT be overwritten (conflicted or auto-resolved).
            let conflictedIds = await detectConflictsForIncomingSessions(toCache)

            // Only save sessions that are not conflicted, preventing overwrite of
            // conflict metadata or auto-resolved merge results.
            let sessionsToSave = toCache.filter { !conflictedIds.contains($0.id) }
            if !sessionsToSave.isEmpty {
                try await db.saveSessions(sessionsToSave)
            }

            // Update sync metadata for freshly cached sessions
            await updateSyncMetadataAfterCache(sessionsToSave)

            // MEM-005: Proactively enforce the hard size limit after every write so
            // the cache never silently grows beyond the 500 MB bound between cleanup cycles.
            await enforceHardSizeLimitIfNeeded()
        } catch {
            AppLogger.shared.error(
                "Failed to cache sessions: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached sessions.
    ///
    /// - Parameter isOffline: When `true`, bypasses the TTL filter so stale cached
    ///   sessions are still returned when the server is unreachable.
    func getCachedSessions(isOffline: Bool = false) async -> [ChatSession] {
        guard settings.isCachingEnabled(for: .sessions) else { return [] }
        do {
            let ttl = isOffline ? nil : settings.cacheTTL
            return try await db.fetchSessions(newerThan: ttl, isOffline: isOffline)
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached sessions: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Private Helpers

    /// Applies the configured session count limit, keeping the most-recently-active sessions.
    ///
    /// PERF-003: Sort is required here because input comes from the network API
    /// with no guaranteed order. The database fetch path sorts via SQL ORDER BY,
    /// but this write path must sort to correctly select the top-N sessions.
    private func applySessionLimit(_ sessions: [ChatSession]) -> [ChatSession] {
        let limit = settings.maxSessions
        guard limit > 0, sessions.count > limit else { return sessions }
        return Array(sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }.prefix(limit))
    }

    // MARK: - Messages

    /// Cache messages for a session.
    func cacheMessages(_ messages: [Message], forSession sessionId: UUID) async {
        guard settings.isCachingEnabled(for: .messages) else { return }
        do {
            // Replace existing cached messages for this session
            try await db.deleteMessages(forSession: sessionId)
            try await db.saveMessages(messages)
        } catch {
            AppLogger.shared.error(
                "Failed to cache messages: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached messages for a session.
    func getCachedMessages(forSession sessionId: UUID) async -> [Message] {
        guard settings.isCachingEnabled(for: .messages) else { return [] }
        do {
            return try await db.fetchMessages(forSession: sessionId)
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached messages: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Projects

    /// Cache a list of projects.
    func cacheProjects(_ projects: [Project]) async {
        guard settings.isCachingEnabled(for: .projects) else { return }
        do {
            try await db.saveProjects(projects)
        } catch {
            AppLogger.shared.error(
                "Failed to cache projects: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached projects.
    func getCachedProjects() async -> [Project] {
        guard settings.isCachingEnabled(for: .projects) else { return [] }
        do {
            return try await db.fetchProjects()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached projects: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Skills

    /// Cache a list of skills.
    func cacheSkills(_ skills: [Skill]) async {
        guard settings.isCachingEnabled(for: .skills) else { return }
        do {
            try await db.saveSkills(skills)
        } catch {
            AppLogger.shared.error(
                "Failed to cache skills: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached skills.
    func getCachedSkills() async -> [Skill] {
        guard settings.isCachingEnabled(for: .skills) else { return [] }
        do {
            return try await db.fetchSkills()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached skills: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - MCP Servers

    /// Cache a list of MCP servers.
    func cacheMCPServers(_ servers: [MCPServer]) async {
        guard settings.isCachingEnabled(for: .mcpServers) else { return }
        do {
            try await db.saveMCPServers(servers)
        } catch {
            AppLogger.shared.error(
                "Failed to cache MCP servers: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached MCP servers.
    func getCachedMCPServers() async -> [MCPServer] {
        guard settings.isCachingEnabled(for: .mcpServers) else { return [] }
        do {
            return try await db.fetchMCPServers()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached MCP servers: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Plugins

    /// Cache a list of plugins.
    func cachePlugins(_ plugins: [Plugin]) async {
        guard settings.isCachingEnabled(for: .plugins) else { return }
        do {
            try await db.savePlugins(plugins)
        } catch {
            AppLogger.shared.error(
                "Failed to cache plugins: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached plugins.
    func getCachedPlugins() async -> [Plugin] {
        guard settings.isCachingEnabled(for: .plugins) else { return [] }
        do {
            return try await db.fetchPlugins()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached plugins: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Teams

    /// Cache a list of teams.
    func cacheTeams(_ teams: [AgentTeam]) async {
        do {
            try await db.saveTeams(teams)
        } catch {
            AppLogger.shared.error(
                "Failed to cache teams: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached teams.
    func getCachedTeams() async -> [AgentTeam] {
        do {
            return try await db.fetchTeams()
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached teams: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Sync Integration

    /// Record a local mutation for a session, tracking it as a pending change
    /// via ``SyncCoordinator`` so it can be synced when connectivity returns.
    ///
    /// Also increments the session's local version in sync metadata to enable
    /// conflict detection on the next server fetch.
    ///
    /// - Parameters:
    ///   - sessionId: The ID of the session being modified.
    ///   - changeType: The kind of mutation: "create", "update", or "delete".
    ///   - changeData: Optional JSON-encoded payload describing the change.
    func markSessionDirty(sessionId: UUID, changeType: String, changeData: Data?) async {
        let sessionIdString = sessionId.uuidString

        // Track the change in the pending_changes table
        await syncCoordinator.trackChange(
            entityType: "session",
            entityId: sessionIdString,
            changeType: changeType,
            changeData: changeData
        )

        // Increment the local version to flag that local data has diverged
        do {
            if var metadata = try await db.getSessionSyncMetadata(sessionId: sessionIdString) {
                metadata.markPending()
                try await db.updateSessionVersions(
                    sessionId: sessionIdString,
                    localVersion: metadata.localVersion,
                    serverVersion: metadata.serverVersion
                )
                try await db.updateSessionSyncStatus(
                    sessionId: sessionIdString,
                    status: .pending,
                    failureReason: nil
                )
            }
        } catch {
            AppLogger.shared.error(
                "Failed to mark session \(sessionIdString) as dirty: \(error.localizedDescription)",
                category: "cache"
            )
        }

        AppLogger.shared.info(
            "Marked session \(sessionIdString) dirty (\(changeType))",
            category: "cache"
        )
    }

    /// Retrieve the sync status for all cached sessions.
    ///
    /// Combines the database-level sync metadata with the ``SyncCoordinator``
    /// in-memory status map. Returns a dictionary keyed by session UUID so
    /// the UI can annotate session rows with their current sync state.
    ///
    /// - Returns: A mapping of session UUID to its current ``SyncStatus``.
    func getSessionSyncStatuses() async -> [UUID: SyncStatus] {
        var result: [UUID: SyncStatus] = [:]

        // Pull sync metadata from the database
        do {
            let sessionsWithMeta = try await db.fetchSessionsWithSyncStatus()
            for entry in sessionsWithMeta {
                result[entry.session.id] = entry.syncMetadata.syncStatus
            }
        } catch {
            AppLogger.shared.error(
                "Failed to fetch session sync statuses: \(error.localizedDescription)",
                category: "cache"
            )
        }

        // Overlay in-memory status from SyncCoordinator (queue-based status
        // may be more current than persisted metadata)
        let coordinatorStatuses = await syncCoordinator.syncStatusMap
        for (sessionIdString, status) in coordinatorStatuses {
            if let uuid = UUID(uuidString: sessionIdString) {
                // SyncCoordinator status takes precedence when it indicates
                // pending or failed — these reflect active queue state.
                if status == .pending || status == .failed {
                    result[uuid] = status
                }
            }
        }

        return result
    }

    /// Reconcile local cache with the server after reconnecting.
    ///
    /// Fetches fresh session data from the server, runs conflict detection for
    /// all sessions that have pending local changes, and updates sync statuses
    /// accordingly. Auto-resolved conflicts are applied immediately; manual
    /// conflicts are stored for later user resolution.
    func reconcileOnReconnect() async {
        AppLogger.shared.info("Starting reconnect reconciliation", category: "cache")

        // Fetch fresh session list from server
        let serverSessions: [ChatSession]
        do {
            let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? ConnectionDefaults.defaultURL
            let apiClient = APIClient(baseURL: baseURL)
            serverSessions = try await apiClient.get("/sessions")
        } catch {
            AppLogger.shared.warning(
                "Reconcile on reconnect failed — could not fetch server sessions: \(error.localizedDescription)",
                category: "cache"
            )
            return
        }

        // Build a lookup of server sessions by ID
        let serverSessionMap = Dictionary(uniqueKeysWithValues: serverSessions.map { ($0.id, $0) })

        // Check all locally cached sessions with pending changes
        let sessionsWithMeta: [(session: ChatSession, syncMetadata: SyncMetadata)]
        do {
            sessionsWithMeta = try await db.fetchSessionsWithSyncStatus()
        } catch {
            AppLogger.shared.error(
                "Reconcile on reconnect failed — could not fetch local sessions: \(error.localizedDescription)",
                category: "cache"
            )
            return
        }

        var conflictsDetected = 0
        var autoResolved = 0

        for entry in sessionsWithMeta where entry.syncMetadata.hasLocalChanges {
            guard let serverSession = serverSessionMap[entry.session.id] else {
                // Session no longer exists on server — keep local version as pending
                continue
            }

            let conflictResult = await conflictResolver.detectConflict(
                localSession: entry.session,
                serverSession: serverSession
            )

            switch conflictResult {
            case .noConflict:
                // Server version is compatible — update sync metadata to synced
                do {
                    try await db.updateSessionSyncStatus(
                        sessionId: entry.session.id.uuidString,
                        status: .synced,
                        failureReason: nil
                    )
                } catch {
                    AppLogger.shared.error(
                        "Failed to update sync status for \(entry.session.id): \(error.localizedDescription)",
                        category: "cache"
                    )
                }

            case .autoResolved(let resolved):
                // Apply the auto-resolved version
                autoResolved += 1
                do {
                    try await db.saveSessions([resolved])
                    try await db.updateSessionSyncStatus(
                        sessionId: entry.session.id.uuidString,
                        status: .synced,
                        failureReason: nil
                    )
                } catch {
                    AppLogger.shared.error(
                        "Failed to apply auto-resolved session \(entry.session.id): \(error.localizedDescription)",
                        category: "cache"
                    )
                }

            case .manualRequired(_, let server, _):
                // Store conflict for manual resolution
                conflictsDetected += 1
                await conflictResolver.storeConflictData(
                    sessionId: entry.session.id,
                    serverSession: server
                )
            }
        }

        // Cache non-conflicting server sessions to keep local data fresh
        let conflictedIds = Set(
            sessionsWithMeta
                .filter { $0.syncMetadata.hasLocalChanges }
                .map { $0.session.id }
        )
        let nonConflictingSessions = serverSessions.filter { !conflictedIds.contains($0.id) }
        if !nonConflictingSessions.isEmpty {
            do {
                let limited = applySessionLimit(nonConflictingSessions)
                try await db.saveSessions(limited)
            } catch {
                AppLogger.shared.error(
                    "Failed to cache non-conflicting sessions during reconcile: \(error.localizedDescription)",
                    category: "cache"
                )
            }
        }

        AppLogger.shared.info(
            "Reconnect reconciliation complete — \(autoResolved) auto-resolved, \(conflictsDetected) conflicts pending",
            category: "cache"
        )
    }

    // MARK: - Sync Private Helpers

    /// Compare incoming server sessions against locally cached sessions to detect conflicts.
    ///
    /// Only checks sessions that have pending local changes (localVersion > serverVersion).
    /// For each conflict, stores the server data for later resolution.
    ///
    /// - Returns: Set of session IDs that have active conflicts and should not be overwritten
    ///   by the incoming server data.
    @discardableResult
    private func detectConflictsForIncomingSessions(_ serverSessions: [ChatSession]) async -> Set<UUID> {
        var conflictedIds = Set<UUID>()

        // Fetch all local sessions once before the loop for O(1) lookups
        let allLocalSessions: [ChatSession]
        do {
            allLocalSessions = try await db.fetchSessions(newerThan: nil, isOffline: true)
        } catch {
            return conflictedIds
        }
        let localSessionMap = Dictionary(uniqueKeysWithValues: allLocalSessions.map { ($0.id, $0) })

        for serverSession in serverSessions {
            let sessionId = serverSession.id.uuidString

            // Check if this session has pending local changes
            let metadata: SyncMetadata?
            do {
                metadata = try await db.getSessionSyncMetadata(sessionId: sessionId)
            } catch {
                continue
            }

            guard let metadata, metadata.hasLocalChanges else { continue }

            // Look up the locally cached version from the pre-fetched map
            guard let localSession = localSessionMap[serverSession.id] else {
                continue
            }

            let conflictResult = await conflictResolver.detectConflict(
                localSession: localSession,
                serverSession: serverSession
            )

            switch conflictResult {
            case .noConflict:
                break
            case .autoResolved(let resolved):
                // Apply auto-resolved version directly
                do {
                    try await db.saveSessions([resolved])
                    try await db.updateSessionSyncStatus(
                        sessionId: sessionId,
                        status: .synced,
                        failureReason: nil
                    )
                } catch {
                    AppLogger.shared.error(
                        "Failed to apply auto-resolved session \(sessionId): \(error.localizedDescription)",
                        category: "cache"
                    )
                }
                // Auto-resolved sessions were already saved with the merged version;
                // exclude from the bulk save to avoid overwriting the merge result.
                conflictedIds.insert(serverSession.id)
            case .manualRequired(_, let server, _):
                await conflictResolver.storeConflictData(
                    sessionId: serverSession.id,
                    serverSession: server
                )
                conflictedIds.insert(serverSession.id)
            }
        }

        return conflictedIds
    }

    /// Update sync metadata for sessions that were successfully cached from the server.
    ///
    /// For sessions without pending local changes, marks them as synced with
    /// the current timestamp. Sessions with pending changes are left untouched
    /// to preserve their dirty state.
    private func updateSyncMetadataAfterCache(_ sessions: [ChatSession]) async {
        for session in sessions {
            let sessionId = session.id.uuidString
            do {
                let metadata = try await db.getSessionSyncMetadata(sessionId: sessionId)
                // Only update metadata for sessions that don't have pending local changes
                if metadata == nil || !metadata!.hasLocalChanges {
                    try await db.updateSessionSyncStatus(
                        sessionId: sessionId,
                        status: .synced,
                        failureReason: nil
                    )
                }
            } catch {
                AppLogger.shared.error(
                    "Failed to update sync metadata for session \(sessionId): \(error.localizedDescription)",
                    category: "cache"
                )
            }
        }
    }

    // MARK: - Cache Management

    /// Clear all cached data and log the storage freed.
    func clearAll() async {
        let bytesBefore = await db.cacheStorageBytes()
        do {
            try await db.clearAll()
            AppLogger.shared.info(
                "Cache cleared — freed \(bytesBefore / 1024) KB",
                category: "cache"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to clear cache: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// MEM-005: Checkpoint SQLite WAL on memory warning to reduce memory footprint.
    func handleMemoryWarning() async {
        do {
            try await db.checkpointWAL()
        } catch {
            AppLogger.shared.error(
                "WAL checkpoint on memory warning failed: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// STOR-004: Hard maximum cache size in bytes (500 MB).
    /// If the SQLite cache exceeds this limit, aggressively prune oldest entries
    /// even if they haven't expired by TTL yet.
    private static let hardMaxCacheBytes: Int64 = 500 * 1024 * 1024

    /// MEM-005: Proactively check the hard size limit and prune if exceeded.
    /// Called after every session write so the cache never silently grows beyond
    /// the 500 MB bound between scheduled cleanup cycles.
    /// Uses a lightweight byte check first to avoid unnecessary work on most writes.
    private func enforceHardSizeLimitIfNeeded() async {
        let currentSize = await db.cacheStorageBytes()
        guard currentSize > Self.hardMaxCacheBytes else { return }
        AppLogger.shared.warning(
            "Cache size \(currentSize / (1024 * 1024)) MB exceeds \(Self.hardMaxCacheBytes / (1024 * 1024)) MB hard limit — running proactive cleanup",
            category: "cache"
        )
        await cleanupExpired()
    }

    /// Remove expired cache entries using the configured TTL.
    /// Also enforces the hard maximum cache size (STOR-004).
    func cleanupExpired() async {
        // Read @MainActor-isolated setting once before entering actor-isolated work.
        let ttl = await settings.cacheTTL
        do {
            try await db.cleanupExpired(olderThan: ttl)

            // STOR-004: If cache still exceeds hard limit after TTL cleanup,
            // aggressively prune by halving the TTL until under limit.
            var currentSize = await db.cacheStorageBytes()
            var aggressiveTTL = ttl / 2
            while currentSize > Self.hardMaxCacheBytes, aggressiveTTL > 60 {
                AppLogger.shared.warning(
                    "Cache size \(currentSize / (1024 * 1024)) MB exceeds \(Self.hardMaxCacheBytes / (1024 * 1024)) MB limit — pruning with TTL \(Int(aggressiveTTL))s",
                    category: "cache"
                )
                try await db.cleanupExpired(olderThan: aggressiveTTL)
                currentSize = await db.cacheStorageBytes()
                aggressiveTTL /= 2
            }
            // If still over limit after aggressive TTL pruning, clear everything
            if currentSize > Self.hardMaxCacheBytes {
                AppLogger.shared.warning(
                    "Cache still \(currentSize / (1024 * 1024)) MB after aggressive prune — clearing all",
                    category: "cache"
                )
                try await db.clearAll()
            }

            // MEM-005: Checkpoint WAL after cleanup to reclaim disk space freed by deletions.
            try? await db.checkpointWAL()
        } catch {
            AppLogger.shared.error(
                "Failed to cleanup expired cache: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Returns the total disk space used by the SQLite cache in bytes.
    func cacheStorageBytes() async -> Int64 {
        await db.cacheStorageBytes()
    }
}
