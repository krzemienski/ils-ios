import Foundation

/// Overall health status of the fleet
public enum FleetHealth: String, Codable, Sendable {
    case healthy
    case degraded
    case critical
    case unknown
}

/// Represents fleet-wide health and metrics for all remote servers
public struct FleetStatus: Codable, Identifiable, Sendable {
    public var id: UUID
    public var totalServers: Int
    public var healthyServers: Int
    public var unhealthyServers: Int
    public var connectingServers: Int
    public var unknownServers: Int
    public var overallHealth: FleetHealth
    public var lastUpdated: Date
    public var issues: [String]?

    public init(
        id: UUID = UUID(),
        totalServers: Int = 0,
        healthyServers: Int = 0,
        unhealthyServers: Int = 0,
        connectingServers: Int = 0,
        unknownServers: Int = 0,
        overallHealth: FleetHealth = .unknown,
        lastUpdated: Date = Date(),
        issues: [String]? = nil
    ) {
        self.id = id
        self.totalServers = totalServers
        self.healthyServers = healthyServers
        self.unhealthyServers = unhealthyServers
        self.connectingServers = connectingServers
        self.unknownServers = unknownServers
        self.overallHealth = overallHealth
        self.lastUpdated = lastUpdated
        self.issues = issues
    }
}
