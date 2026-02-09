import Foundation

public struct FleetHost: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var backendPort: Int
    public var username: String?
    public var authMethod: ServerConnection.AuthMethod?
    public var isActive: Bool
    public var healthStatus: HealthStatus
    public var lastHealthCheck: Date?
    public var platform: String?

    public enum HealthStatus: String, Codable, Sendable {
        case healthy
        case degraded
        case unreachable
        case unknown
    }

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        backendPort: Int = 9090,
        username: String? = nil,
        authMethod: ServerConnection.AuthMethod? = nil,
        isActive: Bool = false,
        healthStatus: HealthStatus = .unknown,
        lastHealthCheck: Date? = nil,
        platform: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.backendPort = backendPort
        self.username = username
        self.authMethod = authMethod
        self.isActive = isActive
        self.healthStatus = healthStatus
        self.lastHealthCheck = lastHealthCheck
        self.platform = platform
    }
}
