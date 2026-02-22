import Foundation

// MARK: - Host Profiles Typealiases (migration path)

/// Typealias for migration path — new code should use `RegisterHostProfileRequest`.
public typealias RegisterHostProfileRequest = RegisterFleetHostRequest
/// Typealias for migration path — new code should use `HostProfileListResponse`.
public typealias HostProfileListResponse = FleetListResponse
/// Typealias for migration path — new code should use `HostProfileHealthResponse`.
public typealias HostProfileHealthResponse = FleetHealthResponse

// MARK: - Fleet Requests

/// Request payload for registering a new fleet host with the ILS backend.
///
/// Sent when adding a remote machine to the fleet so ILS can connect to it
/// via SSH and proxy Claude Code sessions through the remote backend.
public struct RegisterFleetHostRequest: Codable, Sendable {
    /// Human-readable display name for the fleet host.
    public let name: String
    /// Hostname or IP address of the remote machine.
    public let host: String
    /// SSH port on the remote machine (default: 22).
    public let port: Int
    /// Port on which the ILS backend is running on the remote machine (default: 9999).
    public let backendPort: Int
    /// SSH username for authenticating with the remote machine.
    public let username: String?
    /// Authentication method to use (e.g., `"password"`, `"key"`).
    public let authMethod: String?
    /// Credential value associated with the chosen auth method (password or private key path).
    public let credential: String?

    /// Creates a new fleet host registration request.
    /// - Parameters:
    ///   - name: Human-readable display name for the host.
    ///   - host: Hostname or IP address of the remote machine.
    ///   - port: SSH port on the remote machine (default: 22).
    ///   - backendPort: Port the ILS backend listens on remotely (default: 9999).
    ///   - username: Optional SSH username for authentication.
    ///   - authMethod: Optional authentication method identifier.
    ///   - credential: Optional credential (password or key) for authentication.
    public init(
        name: String,
        host: String,
        port: Int = 22,
        backendPort: Int = 9999,
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

/// Response payload containing the full list of registered fleet hosts.
public struct FleetListResponse: Codable, Sendable {
    /// All fleet hosts registered with this ILS instance.
    public let hosts: [FleetHost]
    /// Identifier of the currently active (selected) host, if any.
    public let activeHostId: UUID?

    /// Creates a fleet list response.
    /// - Parameters:
    ///   - hosts: Array of registered fleet hosts.
    ///   - activeHostId: Optional ID of the currently active host.
    public init(hosts: [FleetHost], activeHostId: UUID? = nil) {
        self.hosts = hosts
        self.activeHostId = activeHostId
    }
}

/// Response payload describing the health status of a single fleet host.
public struct FleetHealthResponse: Codable, Sendable {
    /// Identifier of the fleet host this health report belongs to.
    public let hostId: UUID
    /// Current health status of the host (e.g., online, offline, unreachable).
    public let status: FleetHost.HealthStatus
    /// Version string of the ILS backend running on the remote host, if reachable.
    public let backendVersion: String?
    /// Whether Claude Code is available and responsive on the remote host.
    public let claudeAvailable: Bool
    /// Timestamp of the most recent health check for this host.
    public let lastChecked: Date

    /// Creates a fleet health response.
    /// - Parameters:
    ///   - hostId: Identifier of the fleet host.
    ///   - status: Current health status.
    ///   - backendVersion: Optional backend version string.
    ///   - claudeAvailable: Whether Claude Code is available (default: `false`).
    ///   - lastChecked: Timestamp of the health check (default: now).
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
