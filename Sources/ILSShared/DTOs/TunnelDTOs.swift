import Foundation

// MARK: - Tunnel Start Request

/// Request body for starting a Cloudflare tunnel.
public struct TunnelStartRequest: Codable, Sendable {
    /// Optional Cloudflare API token for named tunnels.
    public let token: String?
    /// Optional tunnel name for named tunnels.
    public let tunnelName: String?
    /// Optional custom domain for named tunnels.
    public let domain: String?

    public init(token: String? = nil, tunnelName: String? = nil, domain: String? = nil) {
        self.token = token
        self.tunnelName = tunnelName
        self.domain = domain
    }
}

// MARK: - Tunnel Start Response

/// Response after starting a tunnel, containing the public URL.
public struct TunnelStartResponse: Codable, Sendable {
    /// The public tunnel URL (e.g. https://xxx.trycloudflare.com).
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

// MARK: - Tunnel Stop Response

/// Response after stopping a tunnel.
public struct TunnelStopResponse: Codable, Sendable {
    /// Whether the tunnel was successfully stopped.
    public let stopped: Bool

    public init(stopped: Bool) {
        self.stopped = stopped
    }
}

// MARK: - Tunnel Status Response

/// Current tunnel status information.
public struct TunnelStatusResponse: Codable, Sendable {
    /// Whether the tunnel is currently running.
    public let running: Bool
    /// The public tunnel URL, if running.
    public let url: String?
    /// Seconds since the tunnel was started, if running.
    public let uptime: Int?

    public init(running: Bool, url: String? = nil, uptime: Int? = nil) {
        self.running = running
        self.url = url
        self.uptime = uptime
    }
}
