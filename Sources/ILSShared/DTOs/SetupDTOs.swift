import Foundation

// MARK: - Tunnel Types

public enum TunnelType: String, Codable, Sendable {
    case cloudflare
    case sshPortForward
}

public struct TunnelConfig: Codable, Sendable {
    public let type: TunnelType
    public let url: String
    public let remotePort: Int
    public let pid: Int?

    public init(type: TunnelType, url: String, remotePort: Int, pid: Int? = nil) {
        self.type = type
        self.url = url
        self.remotePort = remotePort
        self.pid = pid
    }
}

// MARK: - Setup Requests

public struct StartSetupRequest: Codable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: String
    public let credential: String
    public let backendPort: Int
    public let repositoryURL: String?
    public var tunnelType: TunnelType?
    /// Cloudflare tunnel token for named tunnels (stable custom domain).
    public let cfToken: String?
    /// Named tunnel name (informational).
    public let cfTunnelName: String?
    /// Custom domain for named tunnel (e.g. ils.example.com).
    public let cfDomain: String?

    public init(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: String,
        credential: String,
        backendPort: Int = 9090,
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

public struct LifecycleRequest: Codable, Sendable {
    public let action: LifecycleAction
    public let hostId: UUID?

    public enum LifecycleAction: String, Codable, Sendable {
        case start
        case stop
        case restart
    }

    public init(action: LifecycleAction, hostId: UUID? = nil) {
        self.action = action
        self.hostId = hostId
    }
}

public struct LifecycleResponse: Codable, Sendable {
    public let success: Bool
    public let action: String
    public let message: String?

    public init(success: Bool, action: String, message: String? = nil) {
        self.success = success
        self.action = action
        self.message = message
    }
}

public struct RemoteLogsResponse: Codable, Sendable {
    public let lines: [String]
    public let hostId: UUID?

    public init(lines: [String], hostId: UUID? = nil) {
        self.lines = lines
        self.hostId = hostId
    }
}
