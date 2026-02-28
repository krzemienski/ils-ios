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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized ConfigScope: '\(raw)'. Expected: user, project, local, managed"
                )
            )
        }
        self = value
    }
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized MCPStatus: '\(raw)'. Expected: healthy, unhealthy, unknown"
                )
            )
        }
        self = value
    }
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
