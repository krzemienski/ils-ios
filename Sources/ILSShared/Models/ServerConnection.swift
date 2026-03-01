import Foundation

/// A box type used to allow recursive references in `ServerConnection`.
/// `ServerConnection` is a value type (struct), so a direct recursive property
/// would be invalid. This box wraps the connection in a class to enable the
/// jump host pattern.
public final class ServerConnectionBox: Codable, Sendable {
    /// The wrapped server connection.
    public let connection: ServerConnection

    /// Creates a new box around a server connection.
    public init(_ connection: ServerConnection) {
        self.connection = connection
    }
}

extension ServerConnectionBox: Hashable {
    public static func == (lhs: ServerConnectionBox, rhs: ServerConnectionBox) -> Bool {
        lhs.connection == rhs.connection
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(connection)
    }
}

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
    /// Whether to enable SSH agent forwarding when connecting.
    public var agentForwarding: Bool
    /// Optional jump host (bastion server) to proxy this connection through.
    public var jumpHost: ServerConnectionBox?

    /// Authentication method for SSH connections.
    public enum AuthMethod: String, Codable, Sendable {
        /// Password-based authentication.
        case password
        /// SSH key-based authentication.
        case sshKey

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized AuthMethod: '\(raw)'. Expected: password, sshKey"
                    )
                )
            }
            self = value
        }
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
    ///   - agentForwarding: Whether to enable SSH agent forwarding (default: false).
    ///   - jumpHost: Optional jump host (bastion) to proxy this connection through.
    public init(
        id: UUID = UUID(),
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod,
        label: String? = nil,
        lastConnected: Date? = nil,
        agentForwarding: Bool = false,
        jumpHost: ServerConnectionBox? = nil
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
        self.agentForwarding = agentForwarding
        self.jumpHost = jumpHost
    }
}
