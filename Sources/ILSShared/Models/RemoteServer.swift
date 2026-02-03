import Foundation

/// Connection status of a remote server
public enum ServerStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case connecting
    case error
    case unknown
}

/// Authentication method for remote server connection
public enum ServerAuthMethod: String, Codable, Sendable {
    case apiKey
    case ssh
    case none
}

/// Represents a remote Claude Code server in the fleet
public struct RemoteServer: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var status: ServerStatus
    public var authMethod: ServerAuthMethod
    public var apiKey: String?
    public var description: String?
    public let createdAt: Date
    public var lastConnectedAt: Date?
    public var lastHealthCheck: Date?
    public var version: String?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 8080,
        status: ServerStatus = .unknown,
        authMethod: ServerAuthMethod = .apiKey,
        apiKey: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil,
        lastHealthCheck: Date? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.status = status
        self.authMethod = authMethod
        self.apiKey = apiKey
        self.description = description
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
        self.lastHealthCheck = lastHealthCheck
        self.version = version
    }
}
