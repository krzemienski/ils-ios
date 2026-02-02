import Foundation

/// Claude Code settings configuration
public struct ClaudeConfig: Codable, Sendable {
    public var model: String?
    public var permissions: PermissionsConfig?
    public var env: [String: String]?
    public var hooks: HooksConfig?
    public var enabledPlugins: [String: Bool]?
    public var extraKnownMarketplaces: [String: String]?
    public var includeCoAuthoredBy: Bool?
    public var statusLine: StatusLineConfig?
    public var alwaysThinkingEnabled: Bool?
    public var autoUpdatesChannel: String?
    public var theme: ThemeConfig?

    // API key status for display (masked for security)
    // The actual API key is stored in environment variables, not in config
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
    public var colorScheme: String?  // "light", "dark", "system"
    public var accentColor: String?

    public init(colorScheme: String? = nil, accentColor: String? = nil) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
    }
}

/// API key status for secure display (never exposes actual key)
public struct APIKeyStatus: Codable, Sendable {
    public let isConfigured: Bool
    public let maskedKey: String?  // Shows only last 4 characters, e.g., "...ABCD"
    public let source: String?     // "environment", "config", etc.

    public init(isConfigured: Bool, maskedKey: String? = nil, source: String? = nil) {
        self.isConfigured = isConfigured
        self.maskedKey = maskedKey
        self.source = source
    }
}

/// Permission configuration for Claude Code
public struct PermissionsConfig: Codable, Sendable {
    public var allow: [String]?
    public var deny: [String]?
    public var defaultMode: String?

    public init(allow: [String]? = nil, deny: [String]? = nil, defaultMode: String? = nil) {
        self.allow = allow
        self.deny = deny
        self.defaultMode = defaultMode
    }
}

/// Status line configuration
public struct StatusLineConfig: Codable, Sendable {
    public var type: String?
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Hooks configuration for Claude Code
public struct HooksConfig: Codable, Sendable {
    public var sessionStart: [HookGroup]?
    public var subagentStart: [HookGroup]?
    public var userPromptSubmit: [HookGroup]?
    public var preToolUse: [HookGroup]?
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
    public var matcher: String?
    public var hooks: [HookDefinition]?

    public init(matcher: String? = nil, hooks: [HookDefinition]? = nil) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

/// Individual hook definition
public struct HookDefinition: Codable, Sendable {
    public var type: String?
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Config scope information
public struct ConfigInfo: Codable, Sendable {
    public let scope: String
    public let path: String
    public let content: ClaudeConfig
    public let isValid: Bool
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
