import Foundation

/// Scope of MCP server configuration.
public enum MCPScope: String, Codable, Sendable {
    /// User-level configuration (~/.claude/).
    case user
    /// Project-level configuration.
    case project
    /// Local configuration (current directory).
    case local
}

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
    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String]? = nil,
        scope: MCPScope = .user,
        status: MCPStatus = .unknown,
        configPath: String? = nil
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
    }
}
