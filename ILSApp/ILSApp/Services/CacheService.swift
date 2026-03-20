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

    // MARK: - Sessions

    /// Cache a list of sessions, respecting the configured session count limit.
    ///
    /// When `OfflineCacheSettings.maxSessions` is non-zero, the list is sorted by
    /// `lastActiveAt` descending and trimmed to the limit before saving, so the most
    /// recently active sessions are always retained. Sessions not in the top-N are discarded
    /// to keep cache size bounded.
    ///
    /// - Parameter sessions: Array of ChatSession objects from the backend API.
    /// - Note: No-ops silently if caching is disabled for the session type.
    func cacheSessions(_ sessions: [ChatSession]) async {
        guard settings.isCachingEnabled(for: .sessions) else { return }
        do {
            let toCache = applySessionLimit(sessions)
            try await db.saveSessions(toCache)
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
