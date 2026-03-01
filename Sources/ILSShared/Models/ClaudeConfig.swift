import Foundation

/// Claude Code settings configuration.
public struct ClaudeConfig: Codable, Hashable, Sendable {
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
    /// Additional marketplace URLs for plugin discovery.
    /// Values can be either a plain URL string or a nested object with source info.
    public var extraKnownMarketplaces: [String: MarketplaceValue]?
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
        extraKnownMarketplaces: [String: MarketplaceValue]? = nil,
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

/// A marketplace value that can be either a simple URL string or a nested source object.
/// Claude Code configs may store marketplace entries in either format.
public enum MarketplaceValue: Codable, Hashable, Sendable {
    /// Simple string value (typically a URL or repo path)
    case string(String)
    /// Structured source object (e.g., {"source": {"source": "git", "url": "..."}})
    case structured([String: AnyCodableJSON])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let obj = try? container.decode([String: AnyCodableJSON].self) {
            self = .structured(obj)
        } else {
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .structured(let obj):
            try container.encode(obj)
        }
    }

    /// Extract a display-friendly string value regardless of format.
    public var displayValue: String {
        switch self {
        case .string(let str):
            return str
        case .structured:
            return "(configured)"
        }
    }
}

/// A simple type-erased JSON value for flexible decoding of unknown structures.
public enum AnyCodableJSON: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyCodableJSON])
    case array([AnyCodableJSON])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let obj = try? container.decode([String: AnyCodableJSON].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([AnyCodableJSON].self) {
            self = .array(arr)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

/// Theme configuration for UI preferences.
public struct ThemeConfig: Codable, Hashable, Sendable {
    /// Color scheme preference: "light", "dark", or "system"
    public var colorScheme: String?
    /// Accent color override (hex string)
    public var accentColor: String?

    public init(colorScheme: String? = nil, accentColor: String? = nil) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
    }
}

/// API key status for secure display (never exposes actual key).
public struct APIKeyStatus: Codable, Hashable, Sendable {
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

/// Permission configuration for Claude Code tool execution.
public struct PermissionsConfig: Codable, Hashable, Sendable {
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

/// Status line configuration for terminal display.
public struct StatusLineConfig: Codable, Hashable, Sendable {
    /// Status line type: "command", "git", etc.
    public var type: String?
    /// Shell command to execute for status content
    public var command: String?

    public init(type: String? = nil, command: String? = nil) {
        self.type = type
        self.command = command
    }
}

/// Hooks configuration for Claude Code lifecycle events.
/// Uses a dictionary keyed by PascalCase event type names (e.g., "PreToolUse", "Stop").
/// This approach naturally handles all current and future event types without silent data loss.
public struct HooksConfig: Codable, Hashable, Sendable {
    /// All hooks keyed by event type name (e.g., "PreToolUse", "Stop", "SessionEnd").
    public var events: [String: [HookGroup]]

    public init(events: [String: [HookGroup]] = [:]) {
        self.events = events
    }

    // Custom Codable: encode/decode directly as {"PreToolUse": [...], "PostToolUse": [...]}
    // This preserves the exact JSON structure Claude Code expects.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        events = try container.decode([String: [HookGroup]].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(events)
    }

    // MARK: - Backward-compatible computed accessors

    /// Hooks triggered before tool execution.
    public var preToolUse: [HookGroup]? { events["PreToolUse"] }
    /// Hooks triggered after tool execution.
    public var postToolUse: [HookGroup]? { events["PostToolUse"] }
    /// Hooks triggered when user submits a prompt.
    public var userPromptSubmit: [HookGroup]? { events["UserPromptSubmit"] }
    /// Hooks triggered at session start.
    public var sessionStart: [HookGroup]? { events["SessionStart"] }
    /// Hooks triggered when subagent starts.
    public var subagentStart: [HookGroup]? { events["SubagentStart"] }
}

/// Group of hooks with optional matcher pattern.
public struct HookGroup: Codable, Hashable, Sendable {
    /// Regular expression to match against context (optional)
    public var matcher: String?
    /// List of hooks to execute when matcher succeeds
    public var hooks: [HookDefinition]?

    public init(matcher: String? = nil, hooks: [HookDefinition]? = nil) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

/// Individual hook definition supporting all 4 Claude Code handler types.
/// Handler types: "command" (shell), "http" (webhook), "prompt" (LLM eval), "agent" (LLM with tools).
public struct HookDefinition: Codable, Hashable, Sendable {
    /// Handler type: "command", "http", "prompt", or "agent"
    public var type: String?

    // MARK: - Command handler fields

    /// Shell command to execute (command handler).
    public var command: String?
    /// If true, runs in background without blocking Claude (command handler).
    public var isAsync: Bool?

    // MARK: - HTTP handler fields

    /// URL to send POST request to (http handler).
    public var url: String?
    /// Additional HTTP headers (http handler).
    public var headers: [String: String]?
    /// Environment variables allowed in header value interpolation (http handler).
    public var allowedEnvVars: [String]?

    // MARK: - Prompt/Agent handler fields

    /// Prompt text for LLM evaluation (prompt/agent handler).
    public var prompt: String?
    /// Model to use for LLM evaluation (prompt/agent handler).
    public var model: String?

    // MARK: - Common optional fields

    /// Seconds before timeout cancellation.
    public var timeout: Int?
    /// Custom spinner message shown during execution.
    public var statusMessage: String?
    /// If true, runs only once per session (skills-based hooks).
    public var once: Bool?

    enum CodingKeys: String, CodingKey {
        case type, command, url, headers, allowedEnvVars, prompt, model
        case timeout, statusMessage, once
        case isAsync = "async"  // "async" is a Swift keyword but valid JSON key
    }

    public init(
        type: String? = nil,
        command: String? = nil,
        isAsync: Bool? = nil,
        url: String? = nil,
        headers: [String: String]? = nil,
        allowedEnvVars: [String]? = nil,
        prompt: String? = nil,
        model: String? = nil,
        timeout: Int? = nil,
        statusMessage: String? = nil,
        once: Bool? = nil
    ) {
        self.type = type
        self.command = command
        self.isAsync = isAsync
        self.url = url
        self.headers = headers
        self.allowedEnvVars = allowedEnvVars
        self.prompt = prompt
        self.model = model
        self.timeout = timeout
        self.statusMessage = statusMessage
        self.once = once
    }
}

/// Config scope information including source file and validation state.
public struct ConfigInfo: Codable, Hashable, Sendable {
    /// Configuration scope (user, project, or local).
    public let scope: ConfigScope
    /// File path where config was loaded from
    public let path: String
    /// Parsed configuration content
    public let content: ClaudeConfig
    /// Whether the config file is valid JSON/YAML
    public let isValid: Bool
    /// Validation errors (if any)
    public var errors: [String]?

    public init(
        scope: ConfigScope,
        path: String,
        content: ClaudeConfig,
        isValid: Bool = true,
        errors: [String]? = nil
    ) {
        precondition(!path.isEmpty, "ConfigInfo path must not be empty")
        self.scope = scope
        self.path = path
        self.content = content
        self.isValid = isValid
        self.errors = errors
    }
}
