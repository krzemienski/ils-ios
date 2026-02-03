import Foundation

/// Scope of MCP server configuration
public enum MCPScope: String, Codable, Sendable {
    /// User-level configuration (global to the user)
    case user
    /// Project-level configuration (specific to a project)
    case project
    /// Local configuration (machine-specific)
    case local
}

/// Health status of an MCP server
public enum MCPStatus: String, Codable, Sendable {
    /// Server is running and responsive
    case healthy
    /// Server is not responding or has errors
    case unhealthy
    /// Server status has not been determined
    case unknown
}

/// Represents an MCP (Model Context Protocol) server configuration
public struct MCPServer: Codable, Identifiable, Sendable {
    /// Unique identifier for the server instance
    public var id: UUID
    /// Display name of the MCP server
    public var name: String
    /// Executable command to start the server
    public var command: String
    /// Command-line arguments passed to the server
    public var args: [String]
    /// Environment variables for the server process
    public var env: [String: String]?
    /// Configuration scope (user, project, or local)
    public var scope: MCPScope
    /// Current health status of the server
    public var status: MCPStatus
    /// Path to the configuration file where this server is defined
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
