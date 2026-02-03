import Foundation

/// Authentication type for remote SSH connection
public enum RemoteAuthType: String, Codable, Sendable {
    case password
    case key
}

/// Connection status of a remote server
public enum RemoteServerStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case error
    case unknown
}

/// Represents an SSH remote server configuration
public struct RemoteServer: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authType: RemoteAuthType
    public var status: RemoteServerStatus
    public var lastConnected: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: RemoteAuthType = .key,
        status: RemoteServerStatus = .unknown,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.status = status
        self.lastConnected = lastConnected
    }
}
