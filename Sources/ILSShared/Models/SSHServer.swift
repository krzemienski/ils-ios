import Foundation

/// Authentication type for SSH connection
public enum SSHAuthType: String, Codable, Sendable {
    case key
    case password
}

/// SSH server connection status
public enum SSHConnectionStatus: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

/// Represents an SSH server connection configuration
public struct SSHServer: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authType: SSHAuthType
    public var status: SSHConnectionStatus
    public let createdAt: Date
    public var lastConnectedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: SSHAuthType = .key,
        status: SSHConnectionStatus = .disconnected,
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.status = status
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }
}
