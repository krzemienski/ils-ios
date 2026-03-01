import Foundation

// MARK: - Dashboard Statistics

/// Dashboard statistics response aggregating counts across all entities.
///
/// Provides a type-safe snapshot of project, session, skill, MCP server,
/// and plugin counts for the home dashboard display.
public struct DashboardStats: Codable, Sendable {
    /// Project statistics.
    public let projects: CountStat
    /// Session statistics.
    public let sessions: SessionStat
    /// Skill statistics.
    public let skills: CountStat
    /// MCP server statistics.
    public let mcpServers: MCPStat
    /// Plugin statistics.
    public let plugins: PluginStat

    /// Creates a new dashboard statistics snapshot.
    /// - Parameters:
    ///   - projects: Project count statistics.
    ///   - sessions: Session count statistics.
    ///   - skills: Skill count statistics.
    ///   - mcpServers: MCP server health statistics.
    ///   - plugins: Plugin installation statistics.
    public init(
        projects: CountStat,
        sessions: SessionStat,
        skills: CountStat,
        mcpServers: MCPStat,
        plugins: PluginStat
    ) {
        self.projects = projects
        self.sessions = sessions
        self.skills = skills
        self.mcpServers = mcpServers
        self.plugins = plugins
    }
}

// MARK: - Stat Types

/// Basic count statistic with optional active count.
public struct CountStat: Codable, Sendable {
    /// Total count.
    public let total: Int
    /// Active count.
    public let active: Int?

    /// Creates a new count statistic.
    /// - Parameters:
    ///   - total: Total number of items. Must be non-negative.
    ///   - active: Number of currently active items, if applicable. Must be non-negative.
    public init(total: Int, active: Int? = nil) {
        precondition(total >= 0, "CountStat total must be non-negative")
        if let active { precondition(active >= 0, "CountStat active must be non-negative") }
        self.total = total
        self.active = active
    }
}

/// Session count statistics.
public struct SessionStat: Codable, Sendable {
    /// Total sessions.
    public let total: Int
    /// Currently active sessions.
    public let active: Int

    /// Creates a new session count statistic.
    /// - Parameters:
    ///   - total: Total number of sessions. Must be non-negative.
    ///   - active: Number of currently active sessions. Must be non-negative.
    public init(total: Int, active: Int) {
        precondition(total >= 0, "SessionStat total must be non-negative")
        precondition(active >= 0, "SessionStat active must be non-negative")
        self.total = total
        self.active = active
    }
}

/// MCP server health statistics.
public struct MCPStat: Codable, Sendable {
    /// Total MCP servers.
    public let total: Int
    /// Healthy MCP servers.
    public let healthy: Int

    /// Creates a new MCP server health statistic.
    /// - Parameters:
    ///   - total: Total number of MCP servers. Must be non-negative.
    ///   - healthy: Number of healthy MCP servers. Must be non-negative and not exceed `total`.
    public init(total: Int, healthy: Int) {
        precondition(total >= 0, "MCPStat total must be non-negative")
        precondition(healthy >= 0, "MCPStat healthy must be non-negative")
        precondition(healthy <= total, "MCPStat healthy must not exceed total")
        self.total = total
        self.healthy = healthy
    }
}

/// Plugin installation statistics.
public struct PluginStat: Codable, Sendable {
    /// Total plugins.
    public let total: Int
    /// Enabled plugins.
    public let enabled: Int

    /// Creates a new plugin installation statistic.
    /// - Parameters:
    ///   - total: Total number of installed plugins. Must be non-negative.
    ///   - enabled: Number of enabled plugins. Must be non-negative and not exceed `total`.
    public init(total: Int, enabled: Int) {
        precondition(total >= 0, "PluginStat total must be non-negative")
        precondition(enabled >= 0, "PluginStat enabled must be non-negative")
        precondition(enabled <= total, "PluginStat enabled must not exceed total")
        self.total = total
        self.enabled = enabled
    }
}
