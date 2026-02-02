import Foundation

/// Scope of MCP server configuration
public enum MCPScope: String, Codable, Sendable {
    case user
    case project
    case local
}

/// Health status of an MCP server
public enum MCPStatus: String, Codable, Sendable {
    case healthy
    case unhealthy
    case unknown
}

/// Represents an MCP (Model Context Protocol) server configuration
public struct MCPServer: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var command: String
    public var args: [String]
    public var env: [String: String]?
    public var scope: MCPScope
    public var status: MCPStatus
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
