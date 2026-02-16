import Foundation

/// Represents a remote host in the ILS fleet for distributed Claude Code execution.
public struct FleetHost: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this fleet host.
    public let id: UUID
    /// Human-readable name for the host.
    public var name: String
    /// Hostname or IP address.
    public var host: String
    /// SSH port number (default: 22).
    public var port: Int
    /// ILS backend port on the remote host (default: 9999).
    public var backendPort: Int
    /// SSH username for authentication.
    public var username: String?
    /// Authentication method for SSH connections.
    public var authMethod: ServerConnection.AuthMethod?
    /// Whether this host is currently the active target.
    public var isActive: Bool
    /// Current health check status.
    public var healthStatus: HealthStatus
    /// Timestamp of the last health check.
    public var lastHealthCheck: Date?
    /// Operating system platform (e.g., "macOS", "Linux").
    public var platform: String?

    /// Health status of a fleet host.
    public enum HealthStatus: String, Codable, Sendable {
        /// Host is healthy and fully operational.
        case healthy
        /// Host is partially functional.
        case degraded
        /// Host cannot be reached.
        case unreachable
        /// Health status has not been checked.
        case unknown
    }

    /// Creates a new fleet host entry.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name. Must not be empty.
    ///   - host: Hostname or IP address. Must not be empty.
    ///   - port: SSH port number (default: 22).
    ///   - backendPort: ILS backend port (default: 9999).
    ///   - username: Optional SSH username.
    ///   - authMethod: Optional authentication method.
    ///   - isActive: Whether this is the active host.
    ///   - healthStatus: Current health status.
    ///   - lastHealthCheck: Last health check timestamp.
    ///   - platform: Operating system platform.
    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        backendPort: Int = 9999,
        username: String? = nil,
        authMethod: ServerConnection.AuthMethod? = nil,
        isActive: Bool = false,
        healthStatus: HealthStatus = .unknown,
        lastHealthCheck: Date? = nil,
        platform: String? = nil
    ) {
        precondition(!name.isEmpty, "FleetHost name must not be empty")
        precondition(!host.isEmpty, "FleetHost host must not be empty")
        precondition(port > 0 && port <= 65535, "FleetHost SSH port must be 1-65535")
        precondition(backendPort > 0 && backendPort <= 65535, "FleetHost backend port must be 1-65535")
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
