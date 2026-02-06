import Foundation

/// Claude Code settings configuration
public struct ClaudeConfig: Codable, Sendable {
    /// Default model to use for Claude CLI (e.g., "claude-sonnet-4")
    public var model: String?
    /// Permission configuration for tool execution
    public var permissions: PermissionsConfig?
    /// Environment variables to pass to Claude CLI
    public var env: [String: String]?
    /// Hook configuration for lifecycle events
    public var hooks: HooksConfig?
    /// Plugin enablement status (plugin name → enabled)
    public var enabledPlugins: [String: Bool]?
    /// Additional marketplace URLs for plugin discovery
    public var extraKnownMarketplaces: [String: String]?
    /// Whether to include co-authored-by attribution in commits
    public var includeCoAuthoredBy: Bool?
    /// Status line configuration for terminal display
    public var statusLine: StatusLineConfig?
    /// Whether to enable extended thinking mode by default
    public var alwaysThinkingEnabled: Bool?
    /// Auto-update channel ("stable", "beta", etc.)
    public var autoUpdatesChannel: String?
    /// UI theme preferences
    public var theme: ThemeConfig?

    /// API key status for display (masked for security).
    /// The actual API key is stored in environment variables, not in config.
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
    /// Color scheme preference: "light", "dark", or "system"
    public var colorScheme: String?
    /// Accent color override (hex string)
    public var accentColor: String?

    public init(colorScheme: String? = nil, accentColor: String? = nil) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
    }
}

/// API key status for secure display (never exposes actual key)
public struct APIKeyStatus: Codable, Sendable {
    /// Whether an API key is configured
    public let isConfigured: Bool
    /// Masked key showing only last 4 characters (e.g., "...ABCD")
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
    /// Tools or patterns explicitly allowed
    public var allow: [String]?
    /// Tools or patterns explicitly denied
    public var deny: [String]?
    /// Default permission mode: "ask", "allow", or "deny"
    public var defaultMode: String?

    public init(allow: [String]? = nil, deny: [String]? = nil, defaultMode: String? = nil) {
        self.allow = allow
        self.deny = deny
        self.defaultMode = defaultMode
    }
}

/// Status line configuration
public struct StatusLineConfig: Codable, Sendable {
    /// Status line type: "command", "git", etc.
    public var type: String?
    /// Shell command to execute for status content
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Hooks configuration for Claude Code
public struct HooksConfig: Codable, Sendable {
    /// Hooks triggered at session start
    public var sessionStart: [HookGroup]?
    /// Hooks triggered when subagent starts
    public var subagentStart: [HookGroup]?
    /// Hooks triggered when user submits a prompt
    public var userPromptSubmit: [HookGroup]?
    /// Hooks triggered before tool execution
    public var preToolUse: [HookGroup]?
    /// Hooks triggered after tool execution
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
    /// Regular expression to match against context (optional)
    public var matcher: String?
    /// List of hooks to execute when matcher succeeds
    public var hooks: [HookDefinition]?

    public init(matcher: String? = nil, hooks: [HookDefinition]? = nil) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

/// Individual hook definition
public struct HookDefinition: Codable, Sendable {
    /// Hook type: "command", "script", etc.
    public var type: String?
    /// Shell command or script to execute
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Config scope information
public struct ConfigInfo: Codable, Sendable {
    /// Configuration scope: "user", "project", or "local"
    public let scope: String
    /// File path where config was loaded from
    public let path: String
    /// Parsed configuration content
    public let content: ClaudeConfig
    /// Whether the config file is valid JSON/YAML
    public let isValid: Bool
    /// Validation errors (if any)
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
