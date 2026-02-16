import Foundation
import ILSShared

/// High-level caching API that wraps LocalDatabase.
///
/// Provides cache-first data loading with configurable expiry times.
/// Sessions expire after 1 hour; skills, plugins, and MCP servers expire after 24 hours.
actor CacheService {
    static let shared = CacheService()

    /// Cache TTL for sessions (1 hour).
    private let sessionTTL: TimeInterval = 3600
    /// Cache TTL for reference data like skills, plugins, MCP (24 hours).
    private let referenceTTL: TimeInterval = 86400

    private let db = LocalDatabase.shared

    private init() {}

    /// Initialize the underlying database. Call once at app launch.
    func initialize() async {
        do {
            try await db.initialize()
            try await db.cleanupExpired(olderThan: referenceTTL)
            AppLogger.shared.info("CacheService initialized", category: "cache")
        } catch {
            AppLogger.shared.error(
                "CacheService initialization failed: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    // MARK: - Sessions

    /// Cache a list of sessions.
    func cacheSessions(_ sessions: [ChatSession]) async {
        do {
            try await db.saveSessions(sessions)
        } catch {
            AppLogger.shared.error(
                "Failed to cache sessions: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Retrieve cached sessions, filtering out expired entries.
    func getCachedSessions() async -> [ChatSession] {
        do {
            return try await db.fetchSessions(olderThan: sessionTTL)
        } catch {
            AppLogger.shared.error(
                "Failed to fetch cached sessions: \(error.localizedDescription)",
                category: "cache"
            )
            return []
        }
    }

    // MARK: - Messages

    /// Cache messages for a session.
    func cacheMessages(_ messages: [Message], forSession sessionId: UUID) async {
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

    // MARK: - Cache Management

    /// Clear all cached data.
    func clearAll() async {
        do {
            try await db.clearAll()
        } catch {
            AppLogger.shared.error(
                "Failed to clear cache: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }

    /// Remove expired cache entries.
    func cleanupExpired() async {
        do {
            try await db.cleanupExpired(olderThan: referenceTTL)
        } catch {
            AppLogger.shared.error(
                "Failed to cleanup expired cache: \(error.localizedDescription)",
                category: "cache"
            )
        }
    }
}
