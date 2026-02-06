import Foundation

public struct ServerConnection: Codable, Identifiable, Sendable {
    public let id: UUID
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod
    public var label: String?
    public var lastConnected: Date?

    public enum AuthMethod: String, Codable, Sendable {
        case password
        case sshKey
    }

    public init(id: UUID = UUID(), host: String, port: Int = 22, username: String, authMethod: AuthMethod, label: String? = nil, lastConnected: Date? = nil) {
        self.id = id
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.label = label
        self.lastConnected = lastConnected
    }
}
