import Foundation

// MARK: - SSH Requests

/// Jump host (bastion) configuration for proxied SSH connections.
public struct SSHJumpHost: Codable, Sendable {
    /// Hostname or IP address of the jump/bastion host.
    public let host: String
    /// Port number of the jump host (default: 22).
    public let port: Int
    /// Username to authenticate with on the jump host.
    public let username: String
    /// Authentication method to use on the jump host (e.g., `"password"`, `"privateKey"`).
    public let authMethod: String
    /// Credential value for the jump host (password or private key content).
    public let credential: String

    /// Creates a new jump host configuration.
    /// - Parameters:
    ///   - host: Hostname or IP address of the jump/bastion host.
    ///   - port: SSH port (default: 22).
    ///   - username: Username for authentication on the jump host.
    ///   - authMethod: Authentication method (e.g., `"password"`, `"privateKey"`).
    ///   - credential: Password or private key content for the jump host.
    public init(host: String, port: Int = 22, username: String, authMethod: String, credential: String) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
    }
}

/// Request payload for establishing an SSH connection to a remote host.
public struct SSHConnectRequest: Codable, Sendable {
    /// Hostname or IP address of the remote SSH server.
    public let host: String
    /// Port number for the SSH connection (default: 22).
    public let port: Int
    /// Username to authenticate with on the remote host.
    public let username: String
    /// Authentication method to use (e.g., `"password"`, `"privateKey"`).
    public let authMethod: String
    /// Credential value corresponding to the chosen ``authMethod`` (password or private key).
    public let credential: String
    /// Whether to enable SSH agent forwarding for this connection.
    public let agentForwarding: Bool
    /// Optional jump host (bastion) to proxy the connection through.
    public let jumpHost: SSHJumpHost?

    /// Creates a new SSH connection request.
    /// - Parameters:
    ///   - host: Hostname or IP address of the remote server.
    ///   - port: SSH port (default: 22).
    ///   - username: Username for authentication.
    ///   - authMethod: Authentication method (e.g., `"password"`, `"privateKey"`).
    ///   - credential: Password or private key content for authentication.
    ///   - agentForwarding: Whether to enable SSH agent forwarding (default: false).
    ///   - jumpHost: Optional jump host configuration for proxied connections.
    public init(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: String,
        credential: String,
        agentForwarding: Bool = false,
        jumpHost: SSHJumpHost? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
        self.agentForwarding = agentForwarding
        self.jumpHost = jumpHost
    }
}

/// Request payload for executing a shell command over an established SSH connection.
public struct SSHExecuteRequest: Codable, Sendable {
    /// Shell command to run on the remote host.
    public let command: String
    /// Optional execution timeout in seconds. `nil` means no timeout is applied.
    public let timeout: Int?

    /// Creates a new SSH execute request.
    /// - Parameters:
    ///   - command: Shell command to execute remotely.
    ///   - timeout: Optional timeout in seconds before the command is terminated.
    public init(command: String, timeout: Int? = nil) {
        self.command = command
        self.timeout = timeout
    }
}

/// Request payload for starting SSH local port forwarding.
public struct SSHPortForwardRequest: Codable, Sendable {
    /// Local port to listen on.
    public let localPort: Int
    /// Remote host to forward connections to.
    public let remoteHost: String
    /// Remote port to forward connections to.
    public let remotePort: Int

    /// Creates a new port forward request.
    /// - Parameters:
    ///   - localPort: Local port to listen on.
    ///   - remoteHost: Remote host to forward to (e.g., "localhost").
    ///   - remotePort: Remote port to forward to.
    public init(localPort: Int, remoteHost: String, remotePort: Int) {
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }
}

/// Request payload for stopping an active SSH port forwarding.
public struct SSHStopPortForwardRequest: Codable, Sendable {
    /// Local port of the forwarding to stop.
    public let localPort: Int

    /// Creates a new stop-port-forward request.
    /// - Parameters:
    ///   - localPort: Local port of the forwarding to stop.
    public init(localPort: Int) {
        self.localPort = localPort
    }
}

// MARK: - SSH Responses

/// Response describing the current SSH connection status.
public struct SSHStatusResponse: Codable, Sendable {
    /// Whether an SSH connection is currently active.
    public let connected: Bool
    /// Hostname or IP address of the connected remote server, if connected.
    public let host: String?
    /// Username of the authenticated session, if connected.
    public let username: String?
    /// Operating system platform reported by the remote host, if connected.
    public let platform: String?
    /// Timestamp when the SSH connection was established, if connected.
    public let connectedAt: Date?
    /// Duration in seconds since the connection was established, if connected.
    public let uptime: TimeInterval?

    /// Creates a new SSH status response.
    /// - Parameters:
    ///   - connected: Whether an SSH connection is currently active.
    ///   - host: Remote hostname or IP address.
    ///   - username: Authenticated username.
    ///   - platform: Operating system platform of the remote host.
    ///   - connectedAt: Timestamp when the connection was established.
    ///   - uptime: Duration in seconds since the connection was established.
    public init(
        connected: Bool,
        host: String? = nil,
        username: String? = nil,
        platform: String? = nil,
        connectedAt: Date? = nil,
        uptime: TimeInterval? = nil
    ) {
        self.connected = connected
        self.host = host
        self.username = username
        self.platform = platform
        self.connectedAt = connectedAt
        self.uptime = uptime
    }
}

/// Response containing the output of a remotely executed shell command.
public struct SSHExecuteResponse: Codable, Sendable {
    /// Standard output produced by the command.
    public let stdout: String
    /// Standard error output produced by the command.
    public let stderr: String
    /// Exit code returned by the command (0 typically indicates success).
    public let exitCode: Int

    /// Creates a new SSH execute response.
    /// - Parameters:
    ///   - stdout: Standard output from the command.
    ///   - stderr: Standard error output from the command.
    ///   - exitCode: Exit status code of the command.
    public init(stdout: String, stderr: String, exitCode: Int) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// Response describing whether the remote host's platform is supported by ILS.
public struct SSHPlatformResponse: Codable, Sendable {
    /// Operating system platform identifier of the remote host (e.g., `"linux"`, `"darwin"`).
    public let platform: String
    /// Whether the detected platform is supported for ILS backend operations.
    public let isSupported: Bool
    /// Human-readable explanation of why the platform is not supported, if applicable.
    public let rejectionReason: String?

    /// Creates a new SSH platform response.
    /// - Parameters:
    ///   - platform: Platform identifier of the remote host.
    ///   - isSupported: Whether the platform is supported by ILS.
    ///   - rejectionReason: Optional reason the platform was rejected.
    public init(platform: String, isSupported: Bool, rejectionReason: String? = nil) {
        self.platform = platform
        self.isSupported = isSupported
        self.rejectionReason = rejectionReason
    }
}

/// Response describing an active SSH port forwarding.
public struct SSHPortForwardResponse: Codable, Sendable {
    /// Local port being listened on.
    public let localPort: Int
    /// Remote host connections are forwarded to.
    public let remoteHost: String
    /// Remote port connections are forwarded to.
    public let remotePort: Int
    /// URL for accessing the forwarded service (e.g., `"http://localhost:9999"`).
    public let serverUrl: String
    /// Whether the port forwarding is currently active.
    public let active: Bool

    /// Creates a new port forward response.
    public init(localPort: Int, remoteHost: String, remotePort: Int, serverUrl: String, active: Bool) {
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.serverUrl = serverUrl
        self.active = active
    }
}

/// Information about a single active port forwarding.
public struct SSHPortForwardInfo: Codable, Sendable {
    /// Local port being listened on.
    public let localPort: Int
    /// Remote host connections are forwarded to.
    public let remoteHost: String
    /// Remote port connections are forwarded to.
    public let remotePort: Int
    /// URL for accessing the forwarded service.
    public let serverUrl: String

    /// Creates a new port forward info.
    public init(localPort: Int, remoteHost: String, remotePort: Int, serverUrl: String) {
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.serverUrl = serverUrl
    }
}

/// Response listing all active port forwardings.
public struct SSHPortForwardStatusResponse: Codable, Sendable {
    /// All currently active port forwardings.
    public let forwardings: [SSHPortForwardInfo]

    /// Creates a new port forward status response.
    public init(forwardings: [SSHPortForwardInfo]) {
        self.forwardings = forwardings
    }
}
