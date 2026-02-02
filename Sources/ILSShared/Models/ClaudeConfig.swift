import Foundation

/// Claude Code settings configuration
public struct ClaudeConfig: Codable, Sendable {
    public var model: String?
    public var permissions: PermissionsConfig?
    public var env: [String: String]?
    public var hooks: HooksConfig?
    public var enabledPlugins: [String: Bool]?
    public var extraKnownMarketplaces: [String: String]?

    public init(
        model: String? = nil,
        permissions: PermissionsConfig? = nil,
        env: [String: String]? = nil,
        hooks: HooksConfig? = nil,
        enabledPlugins: [String: Bool]? = nil,
        extraKnownMarketplaces: [String: String]? = nil
    ) {
        self.model = model
        self.permissions = permissions
        self.env = env
        self.hooks = hooks
        self.enabledPlugins = enabledPlugins
        self.extraKnownMarketplaces = extraKnownMarketplaces
    }
}

/// Permission configuration for Claude Code
public struct PermissionsConfig: Codable, Sendable {
    public var allow: [String]?
    public var deny: [String]?

    public init(allow: [String]? = nil, deny: [String]? = nil) {
        self.allow = allow
        self.deny = deny
    }
}

/// Hooks configuration for Claude Code
public struct HooksConfig: Codable, Sendable {
    public var preToolUse: [HookDefinition]?
    public var postToolUse: [HookDefinition]?

    enum CodingKeys: String, CodingKey {
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
    }

    public init(preToolUse: [HookDefinition]? = nil, postToolUse: [HookDefinition]? = nil) {
        self.preToolUse = preToolUse
        self.postToolUse = postToolUse
    }
}

/// Individual hook definition
public struct HookDefinition: Codable, Sendable {
    public var matcher: String?
    public var command: String?

    public init(matcher: String? = nil, command: String? = nil) {
        self.matcher = matcher
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
