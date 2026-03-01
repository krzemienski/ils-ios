import Foundation

/// Scope of configuration: user-level, project-level, or local override.
public enum ConfigScope: String, Codable, Sendable {
    /// User-level configuration (~/.claude/).
    case user
    /// Project-level configuration.
    case project
    /// Local configuration (current directory).
    case local
    /// Managed configuration (enterprise/system-wide settings).
    case managed
}

/// Backward-compatible alias. Prefer `ConfigScope` in new code.
public typealias MCPScope = ConfigScope

/// Health status of an MCP server.
public enum MCPStatus: String, Codable, Sendable {
    /// Server is healthy and responsive.
    case healthy
    /// Server failed health check.
    case unhealthy
    /// Health status not yet determined.
    case unknown
}

/// Represents an MCP (Model Context Protocol) server configuration.
public struct MCPServer: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this server instance
    public var id: UUID
    /// Human-readable server name (e.g., "filesystem", "postgres")
    public var name: String
    /// Executable command to start the server (e.g., "npx", "python3")
    public var command: String
    /// Command-line arguments passed to the server
    public var args: [String]
    /// Environment variables for the server process
    public var env: [String: String]?
    /// Configuration scope (user, project, or local)
    public var scope: MCPScope
    /// Current health check status (healthy, unhealthy, or unknown)
    public var status: MCPStatus
    /// File path where this server was configured
    public var configPath: String?
    /// Whether this server is enabled (active in Claude Code configuration)
    public var isEnabled: Bool

    /// Creates a new MCP server configuration.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Server display name. Must not be empty.
    ///   - command: Executable command. Must not be empty.
    ///   - args: Command-line arguments.
    ///   - env: Environment variables.
    ///   - scope: Configuration scope.
    ///   - status: Health check status.
    ///   - configPath: Path to config file.
    ///   - isEnabled: Whether the server is enabled.
    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String]? = nil,
        scope: MCPScope = .user,
        status: MCPStatus = .unknown,
        configPath: String? = nil,
        isEnabled: Bool = true
    ) {
        precondition(!name.isEmpty, "MCPServer name must not be empty")
        precondition(!command.isEmpty, "MCPServer command must not be empty")
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
        self.status = status
        self.configPath = configPath
        self.isEnabled = isEnabled
    }
}

/// Category of a preset MCP server configuration.
public enum MCPPresetCategory: String, Codable, Sendable, CaseIterable {
    /// File system access tools.
    case filesystem
    /// Database connectivity tools.
    case database
    /// Developer tools and integrations.
    case developer
    /// Communication and messaging integrations.
    case communication
    /// Web browsing and scraping tools.
    case web
    /// General utility tools.
    case utility
}

/// A preset template for a popular MCP server configuration.
public struct MCPPreset: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this preset
    public var id: UUID
    /// Display name of the preset (e.g., "Filesystem", "GitHub")
    public var name: String
    /// Brief description of what this server provides
    public var description: String
    /// Executable command to start the server
    public var command: String
    /// Default command-line arguments
    public var args: [String]
    /// Default environment variable keys (values left blank for user to fill)
    public var env: [String: String]?
    /// Recommended configuration scope
    public var scope: MCPScope
    /// Category for grouping presets in the UI
    public var category: MCPPresetCategory

    /// Creates a new MCP preset template.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Preset display name. Must not be empty.
    ///   - description: Human-readable description.
    ///   - command: Executable command. Must not be empty.
    ///   - args: Default arguments.
    ///   - env: Default environment variable keys.
    ///   - scope: Recommended scope.
    ///   - category: Grouping category.
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        command: String,
        args: [String] = [],
        env: [String: String]? = nil,
        scope: MCPScope = .user,
        category: MCPPresetCategory = .utility
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
        self.category = category
    }
}
