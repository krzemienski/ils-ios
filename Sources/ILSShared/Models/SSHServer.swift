import Foundation

/// Authentication type for SSH connection
public enum SSHAuthType: String, Codable, Sendable {
    case password
    case key
}

/// Represents an SSH server configuration for remote access
public struct SSHServer: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authType: SSHAuthType
    public var description: String?
    public let createdAt: Date
    public var lastConnectedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: SSHAuthType = .password,
        description: String? = nil,
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.description = description
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }
}
