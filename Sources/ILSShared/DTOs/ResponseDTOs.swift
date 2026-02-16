import Foundation

// MARK: - Stats Response

/// Dashboard statistics response.
public struct StatsResponse: Codable, Sendable {
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

/// Basic count statistic with optional active count.
public struct CountStat: Codable, Sendable {
    /// Total count.
    public let total: Int
    /// Active count.
    public let active: Int?

    public init(total: Int, active: Int? = nil) {
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

    public init(total: Int, active: Int) {
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

    public init(total: Int, healthy: Int) {
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

    public init(total: Int, enabled: Int) {
        self.total = total
        self.enabled = enabled
    }
}

// MARK: - Project Group Info

/// Summary of sessions grouped by project, for sidebar display.
public struct ProjectGroupInfo: Codable, Sendable, Identifiable {
    /// Project name (used as identifier).
    public var id: String { name }
    /// Project display name.
    public let name: String
    /// Number of sessions in this project.
    public let sessionCount: Int
    /// Most recent session activity date.
    public let latestDate: Date

    public init(name: String, sessionCount: Int, latestDate: Date) {
        self.name = name
        self.sessionCount = sessionCount
        self.latestDate = latestDate
    }
}

// MARK: - Simple Responses

/// Confirmation that a resource was deleted.
public struct DeletedResponse: Codable, Sendable {
    /// Whether deletion was successful.
    public let deleted: Bool

    public init(deleted: Bool = true) {
        self.deleted = deleted
    }
}

/// Acknowledgment of a request.
public struct AcknowledgedResponse: Codable, Sendable {
    /// Whether the request was acknowledged.
    public let acknowledged: Bool

    public init(acknowledged: Bool = true) {
        self.acknowledged = acknowledged
    }
}

/// Confirmation that an operation was cancelled.
public struct CancelledResponse: Codable, Sendable {
    /// Whether cancellation was successful.
    public let cancelled: Bool

    public init(cancelled: Bool = true) {
        self.cancelled = cancelled
    }
}

/// Response indicating enabled/disabled state.
public struct EnabledResponse: Codable, Sendable {
    /// Whether the resource is enabled.
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

/// Empty request/response body.
public struct EmptyBody: Codable, Sendable {
    public init() {}
}

// MARK: - MCP Health & Logs

/// Health check response for an MCP server.
public struct MCPHealthResponse: Codable, Sendable {
    /// Server name.
    public let name: String
    /// Current health status.
    public let status: MCPStatus
    /// Whether the server is in the enabled list.
    public let isEnabled: Bool
    /// Server command.
    public let command: String
    /// Timestamp of the health check.
    public let checkedAt: String

    public init(name: String, status: MCPStatus, isEnabled: Bool, command: String, checkedAt: String) {
        self.name = name
        self.status = status
        self.isEnabled = isEnabled
        self.command = command
        self.checkedAt = checkedAt
    }
}

/// Log entry for an MCP server.
public struct MCPLogEntry: Codable, Sendable {
    /// Log timestamp.
    public let timestamp: String
    /// Log level (info, warn, error).
    public let level: String
    /// Log message.
    public let message: String

    public init(timestamp: String, level: String, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

/// Response containing MCP server logs.
public struct MCPLogsResponse: Codable, Sendable {
    /// Server name.
    public let name: String
    /// Log entries.
    public let logs: [MCPLogEntry]
    /// Whether logs are available.
    public let available: Bool

    public init(name: String, logs: [MCPLogEntry], available: Bool = true) {
        self.name = name
        self.logs = logs
        self.available = available
    }
}

/// Response after restarting an MCP server.
public struct MCPRestartResponse: Codable, Sendable {
    /// Server name.
    public let name: String
    /// Whether the restart was initiated.
    public let restarted: Bool
    /// New status after restart.
    public let status: MCPStatus

    public init(name: String, restarted: Bool, status: MCPStatus) {
        self.name = name
        self.restarted = restarted
        self.status = status
    }
}

// MARK: - Config DTOs

/// Configuration profiles across all scopes
public struct ConfigProfiles: Codable, Sendable {
    /// User-level config from ~/.claude/settings.json
    public let user: ConfigInfo?
    /// Project-level config from .claude/settings.json
    public let project: ConfigInfo?
    /// Local override config from .claude/settings.local.json
    public let local: ConfigInfo?

    public init(user: ConfigInfo?, project: ConfigInfo?, local: ConfigInfo?) {
        self.user = user
        self.project = project
        self.local = local
    }
}

/// Per-key configuration override showing cascade
public struct ConfigOverride: Codable, Sendable {
    /// Configuration key
    public let key: String
    /// Which scope won the cascade
    public let winningScope: String
    /// The winning value
    public let winningValue: String
    /// Value from user scope
    public let userValue: String?
    /// Value from project scope
    public let projectValue: String?
    /// Value from local scope
    public let localValue: String?

    public init(
        key: String,
        winningScope: String,
        winningValue: String,
        userValue: String?,
        projectValue: String?,
        localValue: String?
    ) {
        self.key = key
        self.winningScope = winningScope
        self.winningValue = winningValue
        self.userValue = userValue
        self.projectValue = projectValue
        self.localValue = localValue
    }
}

// MARK: - Config Requests

/// Request to update Claude Code configuration.
public struct UpdateConfigRequest: Codable, Sendable {
    /// Configuration scope (e.g., "user", "project").
    public let scope: String
    /// Configuration content.
    public let content: ClaudeConfig

    public init(scope: String, content: ClaudeConfig) {
        self.scope = scope
        self.content = content
    }
}

/// Request to validate a configuration before saving.
public struct ValidateConfigRequest: Codable, Sendable {
    /// Configuration to validate.
    public let content: ClaudeConfig

    public init(content: ClaudeConfig) {
        self.content = content
    }
}

/// Result of configuration validation.
public struct ConfigValidationResult: Codable, Sendable {
    /// Whether the configuration is valid.
    public let isValid: Bool
    /// Validation error messages.
    public let errors: [String]

    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}
