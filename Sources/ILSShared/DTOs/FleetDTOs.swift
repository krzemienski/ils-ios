import Foundation

// MARK: - Fleet Requests

public struct RegisterFleetHostRequest: Codable, Sendable {
    public let name: String
    public let host: String
    public let port: Int
    public let backendPort: Int
    public let username: String?
    public let authMethod: String?
    public let credential: String?

    public init(
        name: String,
        host: String,
        port: Int = 22,
        backendPort: Int = 9090,
        username: String? = nil,
        authMethod: String? = nil,
        credential: String? = nil
    ) {
        self.name = name
        self.host = host
        self.port = port
        self.backendPort = backendPort
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
    }
}

// MARK: - Fleet Responses

public struct FleetListResponse: Codable, Sendable {
    public let hosts: [FleetHost]
    public let activeHostId: UUID?

    public init(hosts: [FleetHost], activeHostId: UUID? = nil) {
        self.hosts = hosts
        self.activeHostId = activeHostId
    }
}

public struct FleetHealthResponse: Codable, Sendable {
    public let hostId: UUID
    public let status: FleetHost.HealthStatus
    public let backendVersion: String?
    public let claudeAvailable: Bool
    public let lastChecked: Date

    public init(
        hostId: UUID,
        status: FleetHost.HealthStatus,
        backendVersion: String? = nil,
        claudeAvailable: Bool = false,
        lastChecked: Date = Date()
    ) {
        self.hostId = hostId
        self.status = status
        self.backendVersion = backendVersion
        self.claudeAvailable = claudeAvailable
        self.lastChecked = lastChecked
    }
}
