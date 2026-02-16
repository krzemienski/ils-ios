import Foundation

/// Represents an SSH server connection for remote Claude Code execution.
public struct ServerConnection: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this connection.
    public let id: UUID
    /// Hostname or IP address of the remote server.
    public var host: String
    /// SSH port number (default: 22).
    public var port: Int
    /// SSH username for authentication.
    public var username: String
    /// Authentication method (password or SSH key).
    public var authMethod: AuthMethod
    /// Optional human-readable label for this connection.
    public var label: String?
    /// Timestamp of the last successful connection.
    public var lastConnected: Date?

    /// Authentication method for SSH connections.
    public enum AuthMethod: String, Codable, Sendable {
        /// Password-based authentication.
        case password
        /// SSH key-based authentication.
        case sshKey
    }

    /// Creates a new server connection.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - host: Hostname or IP address. Must not be empty.
    ///   - port: SSH port number (default: 22).
    ///   - username: SSH username. Must not be empty.
    ///   - authMethod: Authentication method to use.
    ///   - label: Optional human-readable label.
    ///   - lastConnected: Timestamp of last successful connection.
    public init(
        id: UUID = UUID(),
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod,
        label: String? = nil,
        lastConnected: Date? = nil
    ) {
        precondition(!host.isEmpty, "ServerConnection host must not be empty")
        precondition(!username.isEmpty, "ServerConnection username must not be empty")
        precondition(port > 0 && port <= 65535, "ServerConnection port must be 1-65535")
        self.id = id
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.label = label
        self.lastConnected = lastConnected
    }
}
