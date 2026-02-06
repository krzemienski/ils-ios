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
    /// Unique identifier.
    public var id: UUID
    /// Server name.
    public var name: String
    /// Command to execute the server.
    public var command: String
    /// Command-line arguments.
    public var args: [String]
    /// Environment variables.
    public var env: [String: String]?
    /// Configuration scope.
    public var scope: MCPScope
    /// Current health status.
    public var status: MCPStatus
    /// Path to the configuration file.
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
