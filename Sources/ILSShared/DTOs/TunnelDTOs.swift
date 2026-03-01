import Foundation

// MARK: - Tunnel Connection State

/// Represents the current connection state of a Cloudflare tunnel.
public enum TunnelConnectionState: String, Codable, Sendable {
    /// Tunnel is not running.
    case disconnected
    /// Tunnel is in the process of connecting.
    case connecting
    /// Tunnel is connected and operational.
    case connected
    /// Tunnel encountered an error and is not operational.
    case error
    /// Tunnel is reconnecting after a disruption.
    case reconnecting
}

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
    /// Tunnel mode: "quick" or "named".
    public let mode: String?
    /// The detailed connection state of the tunnel.
    public let connectionState: TunnelConnectionState?

    public init(
        running: Bool,
        url: String? = nil,
        uptime: Int? = nil,
        mode: String? = nil,
        connectionState: TunnelConnectionState? = nil
    ) {
        self.running = running
        self.url = url
        self.uptime = uptime
        self.mode = mode
        self.connectionState = connectionState
    }
}

// MARK: - Tunnel Health Response

/// Health metrics for a running tunnel.
public struct TunnelHealthResponse: Codable, Sendable {
    /// The current connection state of the tunnel.
    public let connectionState: TunnelConnectionState
    /// Round-trip latency in milliseconds, if measurable.
    public let latencyMs: Int?
    /// Seconds the tunnel has been running.
    public let uptime: Int?
    /// Total bytes received through the tunnel.
    public let bytesReceived: Int?
    /// Total bytes sent through the tunnel.
    public let bytesSent: Int?
    /// Number of active connections through the tunnel.
    public let activeConnections: Int?

    public init(
        connectionState: TunnelConnectionState,
        latencyMs: Int? = nil,
        uptime: Int? = nil,
        bytesReceived: Int? = nil,
        bytesSent: Int? = nil,
        activeConnections: Int? = nil
    ) {
        self.connectionState = connectionState
        self.latencyMs = latencyMs
        self.uptime = uptime
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.activeConnections = activeConnections
    }
}

// MARK: - Tunnel Log Entry

/// A single log entry from the tunnel process.
public struct TunnelLogEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for this log entry.
    public let id: String
    /// ISO 8601 timestamp of the log entry.
    public let timestamp: String
    /// Severity level of the log entry.
    public let level: TunnelLogLevel
    /// The log message text.
    public let message: String

    public init(id: String, timestamp: String, level: TunnelLogLevel, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

/// Log severity levels for tunnel log entries.
public enum TunnelLogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

// MARK: - Tunnel Logs Response

/// A paginated list of tunnel log entries.
public struct TunnelLogsResponse: Codable, Sendable {
    /// The log entries for this page.
    public let entries: [TunnelLogEntry]
    /// Total number of log entries available.
    public let total: Int
    /// Whether there are more entries beyond this page.
    public let hasMore: Bool

    public init(entries: [TunnelLogEntry], total: Int, hasMore: Bool) {
        self.entries = entries
        self.total = total
        self.hasMore = hasMore
    }
}
