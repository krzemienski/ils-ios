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
public struct MCPServer: Codable, Identifiable, Sendable {
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
