import Foundation

// MARK: - Tunnel Types

/// The type of tunnel used to expose the remote backend to the iOS client.
public enum TunnelType: String, Codable, Sendable {
    /// Cloudflare Tunnel (named tunnel or quick tunnel).
    case cloudflare
    /// SSH local port-forward tunnel.
    case sshPortForward

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized TunnelType: '\(raw)'. Expected: cloudflare, sshPortForward"
                )
            )
        }
        self = value
    }
}

/// Configuration describing an active tunnel connection to the remote backend.
public struct TunnelConfig: Codable, Sendable {
    /// The tunneling technology used to establish the connection.
    public let type: TunnelType
    /// Public URL at which the tunneled backend is reachable.
    public let url: String
    /// Remote port that the tunnel forwards traffic to.
    public let remotePort: Int
    /// Process ID of the tunnel process, if available.
    public let pid: Int?

    /// Creates a new tunnel configuration.
    /// - Parameters:
    ///   - type: The tunneling technology used.
    ///   - url: Public URL for the tunneled backend.
    ///   - remotePort: Remote port the tunnel forwards to.
    ///   - pid: Process ID of the tunnel process.
    public init(type: TunnelType, url: String, remotePort: Int, pid: Int? = nil) {
        self.type = type
        self.url = url
        self.remotePort = remotePort
        self.pid = pid
    }
}

// MARK: - Setup Requests

/// Request payload for initiating remote host setup via SSH.
///
/// Contains all connection parameters needed to SSH into the remote machine,
/// install the ILS backend, and optionally configure a tunnel.
public struct StartSetupRequest: Codable, Sendable {
    /// Hostname or IP address of the remote machine.
    public let host: String
    /// SSH port on the remote machine (default: 22).
    public let port: Int
    /// SSH username for authentication.
    public let username: String
    /// Authentication method identifier (e.g., `"password"` or `"key"`).
    public let authMethod: String
    /// Credential value — password text or private key content.
    public let credential: String
    /// Port on which the ILS backend will listen on the remote machine.
    public let backendPort: Int
    /// Optional Git repository URL to clone on the remote machine.
    public let repositoryURL: String?
    /// Tunnel type to configure after setup, if any.
    public var tunnelType: TunnelType?
    /// Cloudflare tunnel token for named tunnels (stable custom domain).
    public let cfToken: String?
    /// Named tunnel name (informational).
    public let cfTunnelName: String?
    /// Custom domain for named tunnel (e.g. ils.example.com).
    public let cfDomain: String?

    /// Creates a new setup request.
    /// - Parameters:
    ///   - host: Hostname or IP address of the remote machine.
    ///   - port: SSH port (default: 22).
    ///   - username: SSH username.
    ///   - authMethod: Authentication method identifier.
    ///   - credential: Password or private key content.
    ///   - backendPort: Port for the ILS backend to listen on (default: 9999).
    ///   - repositoryURL: Optional Git repository to clone on the remote machine.
    ///   - tunnelType: Tunnel type to configure after setup.
    ///   - cfToken: Cloudflare named tunnel token.
    ///   - cfTunnelName: Cloudflare named tunnel name.
    ///   - cfDomain: Custom domain for the Cloudflare named tunnel.
    public init(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: String,
        credential: String,
        backendPort: Int = 9999,
        repositoryURL: String? = nil,
        tunnelType: TunnelType? = nil,
        cfToken: String? = nil,
        cfTunnelName: String? = nil,
        cfDomain: String? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
        self.backendPort = backendPort
        self.repositoryURL = repositoryURL
        self.tunnelType = tunnelType
        self.cfToken = cfToken
        self.cfTunnelName = cfTunnelName
        self.cfDomain = cfDomain
    }
}

// MARK: - Lifecycle Requests

/// Request to perform a lifecycle action on the remote ILS backend service.
public struct LifecycleRequest: Codable, Sendable {
    /// The lifecycle action to perform.
    public let action: LifecycleAction
    /// ID of the specific host to target, or `nil` for the default host.
    public let hostId: UUID?

    /// Lifecycle actions available for the remote backend service.
    public enum LifecycleAction: String, Codable, Sendable {
        /// Start the backend service.
        case start
        /// Stop the backend service.
        case stop
        /// Restart the backend service.
        case restart

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized LifecycleAction: '\(raw)'. Expected: start, stop, restart"
                    )
                )
            }
            self = value
        }
    }

    /// Creates a new lifecycle request.
    /// - Parameters:
    ///   - action: The lifecycle action to perform.
    ///   - hostId: ID of the target host, or `nil` for the default host.
    public init(action: LifecycleAction, hostId: UUID? = nil) {
        self.action = action
        self.hostId = hostId
    }
}

/// Response from a lifecycle action performed on the remote backend service.
public struct LifecycleResponse: Codable, Sendable {
    /// Whether the lifecycle action completed successfully.
    public let success: Bool
    /// The action that was performed (echoed from the request).
    public let action: String
    /// Optional human-readable message describing the outcome.
    public let message: String?

    /// Creates a new lifecycle response.
    /// - Parameters:
    ///   - success: Whether the action succeeded.
    ///   - action: The action that was performed.
    ///   - message: Optional descriptive message.
    public init(success: Bool, action: String, message: String? = nil) {
        self.success = success
        self.action = action
        self.message = message
    }
}

/// Response containing log lines fetched from a remote host.
public struct RemoteLogsResponse: Codable, Sendable {
    /// Log lines retrieved from the remote backend process.
    public let lines: [String]
    /// ID of the host the logs were retrieved from, or `nil` for the default host.
    public let hostId: UUID?

    /// Creates a new remote logs response.
    /// - Parameters:
    ///   - lines: Log lines from the remote backend.
    ///   - hostId: ID of the host the logs came from.
    public init(lines: [String], hostId: UUID? = nil) {
        self.lines = lines
        self.hostId = hostId
    }
}
