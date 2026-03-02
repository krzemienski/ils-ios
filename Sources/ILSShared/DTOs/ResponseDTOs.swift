import Foundation

/// Backward-compatible alias. Prefer `DashboardStats` in new code.
public typealias StatsResponse = DashboardStats

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
    /// Managed config from system-wide managed settings
    public let managed: ConfigInfo?

    public init(user: ConfigInfo?, project: ConfigInfo?, local: ConfigInfo?, managed: ConfigInfo? = nil) {
        self.user = user
        self.project = project
        self.local = local
        self.managed = managed
    }
}

/// Per-key configuration override showing cascade
public struct ConfigOverride: Codable, Sendable {
    /// Configuration key
    public let key: String
    /// Which scope won the cascade
    public let winningScope: ConfigScope
    /// The winning value
    public let winningValue: String
    /// Value from user scope
    public let userValue: String?
    /// Value from project scope
    public let projectValue: String?
    /// Value from local scope
    public let localValue: String?
    /// Value from managed scope
    public let managedValue: String?

    public init(
        key: String,
        winningScope: ConfigScope,
        winningValue: String,
        userValue: String?,
        projectValue: String?,
        localValue: String?,
        managedValue: String? = nil
    ) {
        precondition(!key.isEmpty, "ConfigOverride key must not be empty")
        self.key = key
        self.winningScope = winningScope
        self.winningValue = winningValue
        self.userValue = userValue
        self.projectValue = projectValue
        self.localValue = localValue
        self.managedValue = managedValue
    }
}

/// Effective configuration with per-key scope annotations.
///
/// Returned by GET /config/effective. Contains the merged config
/// (highest-precedence non-nil value for each key), per-key override
/// annotations showing which scope won, and the raw profiles for debugging.
public struct EffectiveConfig: Codable, Sendable {
    /// Merged config values (highest-precedence non-nil for each key)
    public let config: ClaudeConfig
    /// Per-key annotations showing which scope won
    public let overrides: [ConfigOverride]
    /// All scope configs that were read (for debugging / UI display)
    public let profiles: ConfigProfiles

    public init(config: ClaudeConfig, overrides: [ConfigOverride], profiles: ConfigProfiles) {
        self.config = config
        self.overrides = overrides
        self.profiles = profiles
    }
}

// MARK: - Config Requests

/// Request to update Claude Code configuration.
public struct UpdateConfigRequest: Codable, Sendable {
    /// Configuration scope (user, project, or local).
    public let scope: ConfigScope
    /// Configuration content.
    public let content: ClaudeConfig

    public init(scope: ConfigScope, content: ClaudeConfig) {
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

// MARK: - Plugin Update Info

/// Response for plugin update availability check.
public struct PluginUpdateInfo: Codable, Sendable {
    /// Plugin name that was checked.
    public let pluginName: String
    /// Currently installed version.
    public let currentVersion: String
    /// Latest available version from remote.
    public let latestVersion: String
    /// Whether the latest version is newer than current.
    public let updateAvailable: Bool
    /// List of dependency names that are not installed locally.
    public let unmetDependencies: [String]

    public init(
        pluginName: String,
        currentVersion: String,
        latestVersion: String,
        updateAvailable: Bool,
        unmetDependencies: [String] = []
    ) {
        self.pluginName = pluginName
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.updateAvailable = updateAvailable
        self.unmetDependencies = unmetDependencies
    }
}

// MARK: - Data Erasure

/// Response from the GDPR "delete all my data" endpoint.
///
/// Reports per-table deletion counts so the caller can verify
/// exactly what was removed.
public struct DataErasureResponse: Codable, Sendable, Hashable {
    /// Number of chat messages deleted.
    public var messagesDeleted: Int
    /// Number of chat sessions deleted.
    public var sessionsDeleted: Int
    /// Number of projects deleted.
    public var projectsDeleted: Int
    /// Number of custom themes deleted.
    public var themesDeleted: Int
    /// Number of fleet host configurations deleted.
    public var fleetHostsDeleted: Int
    /// Number of cached search results deleted.
    public var cacheEntriesDeleted: Int

    public init(
        messagesDeleted: Int = 0,
        sessionsDeleted: Int = 0,
        projectsDeleted: Int = 0,
        themesDeleted: Int = 0,
        fleetHostsDeleted: Int = 0,
        cacheEntriesDeleted: Int = 0
    ) {
        self.messagesDeleted = messagesDeleted
        self.sessionsDeleted = sessionsDeleted
        self.projectsDeleted = projectsDeleted
        self.themesDeleted = themesDeleted
        self.fleetHostsDeleted = fleetHostsDeleted
        self.cacheEntriesDeleted = cacheEntriesDeleted
    }
}

// MARK: - MCP Validation & Presets

/// Result of validating an MCP server configuration before applying it.
public struct MCPValidationResult: Codable, Sendable {
    /// Whether the configuration is valid and safe to apply.
    public let isValid: Bool
    /// Validation error messages that must be resolved.
    public let errors: [String]
    /// Non-blocking warnings about the configuration.
    public let warnings: [String]

    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Response containing the list of preset MCP server configurations.
public struct MCPPresetListResponse: Codable, Sendable {
    /// Available preset configurations grouped for display.
    public let presets: [MCPPreset]

    public init(presets: [MCPPreset]) {
        self.presets = presets
    }
}

// MARK: - Suggestion Responses

/// A suggested past session relevant to the current context.
public struct SessionSuggestion: Codable, Sendable, Identifiable {
    /// Unique identifier for this suggestion.
    public let id: UUID
    /// The suggested session.
    public let session: ChatSession
    /// Relevance score (0.0 – 1.0).
    public let score: Double
    /// Human-readable reason for the suggestion.
    public let reason: String

    public init(
        id: UUID = UUID(),
        session: ChatSession,
        score: Double,
        reason: String
    ) {
        self.id = id
        self.session = session
        self.score = score
        self.reason = reason
    }
}

/// A suggested skill relevant to the current project or context.
public struct SkillSuggestion: Codable, Sendable, Identifiable {
    /// Unique identifier for this suggestion.
    public let id: UUID
    /// The suggested skill.
    public let skill: Skill
    /// Relevance score (0.0 – 1.0).
    public let score: Double
    /// Human-readable reason for the suggestion.
    public let reason: String

    public init(
        id: UUID = UUID(),
        skill: Skill,
        score: Double,
        reason: String
    ) {
        self.id = id
        self.skill = skill
        self.score = score
        self.reason = reason
    }
}

/// A session that was abandoned and is worth resuming.
public struct AbandonedSessionSuggestion: Codable, Sendable, Identifiable {
    /// Unique identifier for this suggestion.
    public let id: UUID
    /// The abandoned session.
    public let session: ChatSession
    /// Time elapsed since the last activity in this session, in seconds.
    public let inactivityDuration: TimeInterval
    /// Human-readable reason why this session is flagged as abandoned.
    public let reason: String
    /// Estimated completion percentage of the work in this session (0–100).
    public let completionEstimate: Int

    public init(
        id: UUID = UUID(),
        session: ChatSession,
        inactivityDuration: TimeInterval,
        reason: String,
        completionEstimate: Int
    ) {
        precondition((0...100).contains(completionEstimate), "completionEstimate must be 0–100")
        self.id = id
        self.session = session
        self.inactivityDuration = inactivityDuration
        self.reason = reason
        self.completionEstimate = completionEstimate
    }
}
