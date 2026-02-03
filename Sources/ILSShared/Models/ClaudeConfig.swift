import Foundation

/// Claude Code settings configuration
public struct ClaudeConfig: Codable, Sendable {
    /// Claude AI model to use (e.g., "claude-3-opus", "claude-3-sonnet")
    public var model: String?

    /// Permission rules for Claude Code operations
    public var permissions: PermissionsConfig?

    /// Environment variables to pass to Claude Code sessions
    public var env: [String: String]?

    /// Hook configurations for various Claude Code lifecycle events
    public var hooks: HooksConfig?

    /// Map of plugin names to their enabled/disabled state
    public var enabledPlugins: [String: Bool]?

    /// Additional marketplace URLs for plugin discovery
    public var extraKnownMarketplaces: [String: String]?

    /// Whether to include "Co-Authored-By: Claude" in git commits
    public var includeCoAuthoredBy: Bool?

    /// Status line display configuration
    public var statusLine: StatusLineConfig?

    /// Whether "Always Thinking" mode is enabled for detailed reasoning
    public var alwaysThinkingEnabled: Bool?

    /// Auto-update channel ("stable", "beta", etc.)
    public var autoUpdatesChannel: String?

    /// UI theme preferences
    public var theme: ThemeConfig?

    /// API key status for secure display (masked for security)
    /// The actual API key is stored in environment variables, not in config
    public var apiKeyStatus: APIKeyStatus?

    public init(
        model: String? = nil,
        permissions: PermissionsConfig? = nil,
        env: [String: String]? = nil,
        hooks: HooksConfig? = nil,
        enabledPlugins: [String: Bool]? = nil,
        extraKnownMarketplaces: [String: String]? = nil,
        includeCoAuthoredBy: Bool? = nil,
        statusLine: StatusLineConfig? = nil,
        alwaysThinkingEnabled: Bool? = nil,
        autoUpdatesChannel: String? = nil,
        theme: ThemeConfig? = nil,
        apiKeyStatus: APIKeyStatus? = nil
    ) {
        self.model = model
        self.permissions = permissions
        self.env = env
        self.hooks = hooks
        self.enabledPlugins = enabledPlugins
        self.extraKnownMarketplaces = extraKnownMarketplaces
        self.includeCoAuthoredBy = includeCoAuthoredBy
        self.statusLine = statusLine
        self.alwaysThinkingEnabled = alwaysThinkingEnabled
        self.autoUpdatesChannel = autoUpdatesChannel
        self.theme = theme
        self.apiKeyStatus = apiKeyStatus
    }
}

/// Theme configuration for UI preferences
public struct ThemeConfig: Codable, Sendable {
    /// Color scheme preference: "light", "dark", or "system" for automatic
    public var colorScheme: String?

    /// Accent color for UI elements (hex code or named color)
    public var accentColor: String?

    public init(colorScheme: String? = nil, accentColor: String? = nil) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
    }
}

/// API key status for secure display (never exposes actual key)
public struct APIKeyStatus: Codable, Sendable {
    /// Whether an API key is configured and available
    public let isConfigured: Bool

    /// Masked representation of the key showing only last 4 characters (e.g., "...ABCD")
    public let maskedKey: String?

    /// Source of the API key: "environment", "config", etc.
    public let source: String?

    public init(isConfigured: Bool, maskedKey: String? = nil, source: String? = nil) {
        self.isConfigured = isConfigured
        self.maskedKey = maskedKey
        self.source = source
    }
}

/// Permission configuration for Claude Code
public struct PermissionsConfig: Codable, Sendable {
    /// List of explicitly allowed operations or patterns
    public var allow: [String]?

    /// List of explicitly denied operations or patterns
    public var deny: [String]?

    /// Default permission mode when no rule matches
    public var defaultMode: String?

    public init(allow: [String]? = nil, deny: [String]? = nil, defaultMode: String? = nil) {
        self.allow = allow
        self.deny = deny
        self.defaultMode = defaultMode
    }
}

/// Status line configuration
public struct StatusLineConfig: Codable, Sendable {
    /// Type of status line display
    public var type: String?

    /// Command to execute for dynamic status line content
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Hooks configuration for Claude Code
public struct HooksConfig: Codable, Sendable {
    /// Hooks triggered when a new session starts
    public var sessionStart: [HookGroup]?

    /// Hooks triggered when a subagent is launched
    public var subagentStart: [HookGroup]?

    /// Hooks triggered when user submits a prompt
    public var userPromptSubmit: [HookGroup]?

    /// Hooks triggered before a tool is used
    public var preToolUse: [HookGroup]?

    /// Hooks triggered after a tool is used
    public var postToolUse: [HookGroup]?

    enum CodingKeys: String, CodingKey {
        case sessionStart = "SessionStart"
        case subagentStart = "SubagentStart"
        case userPromptSubmit = "UserPromptSubmit"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
    }

    public init(
        sessionStart: [HookGroup]? = nil,
        subagentStart: [HookGroup]? = nil,
        userPromptSubmit: [HookGroup]? = nil,
        preToolUse: [HookGroup]? = nil,
        postToolUse: [HookGroup]? = nil
    ) {
        self.sessionStart = sessionStart
        self.subagentStart = subagentStart
        self.userPromptSubmit = userPromptSubmit
        self.preToolUse = preToolUse
        self.postToolUse = postToolUse
    }
}

/// Group of hooks with optional matcher
public struct HookGroup: Codable, Sendable {
    /// Pattern to match against for conditional hook execution
    public var matcher: String?

    /// Array of hook definitions to execute when matcher succeeds
    public var hooks: [HookDefinition]?

    public init(matcher: String? = nil, hooks: [HookDefinition]? = nil) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

/// Individual hook definition
public struct HookDefinition: Codable, Sendable {
    /// Type of hook action to perform
    public var type: String?

    /// Command or script to execute for this hook
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Config scope information
public struct ConfigInfo: Codable, Sendable {
    /// Configuration scope level ("user", "project", etc.)
    public let scope: String

    /// File system path to the configuration file
    public let path: String

    /// Parsed configuration content
    public let content: ClaudeConfig

    /// Whether the configuration is valid and successfully parsed
    public let isValid: Bool

    /// Validation or parsing errors, if any
    public var errors: [String]?

    public init(
        scope: String,
        path: String,
        content: ClaudeConfig,
        isValid: Bool = true,
        errors: [String]? = nil
    ) {
        self.scope = scope
        self.path = path
        self.content = content
        self.isValid = isValid
        self.errors = errors
    }
}
