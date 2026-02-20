import Foundation

/// Response returned after attempting to connect to the ILS backend server.
///
/// Indicates whether the connection succeeded and provides server metadata
/// or an error message when the connection fails.
public struct ConnectionResponse: Codable, Sendable {
    /// Whether the connection attempt succeeded.
    public let success: Bool
    /// The established session identifier, if a session was created.
    public let sessionId: String?
    /// Metadata about the connected server, including Claude installation details.
    public let serverInfo: ServerInfo?
    /// Human-readable error message when `success` is `false`.
    public let error: String?

    /// Creates a connection response.
    /// - Parameters:
    ///   - success: Whether the connection attempt succeeded.
    ///   - sessionId: The established session identifier.
    ///   - serverInfo: Metadata about the connected server.
    ///   - error: Human-readable error message on failure.
    public init(success: Bool, sessionId: String? = nil, serverInfo: ServerInfo? = nil, error: String? = nil) {
        self.success = success
        self.sessionId = sessionId
        self.serverInfo = serverInfo
        self.error = error
    }
}

/// Metadata about the ILS backend server returned on successful connection.
public struct ServerInfo: Codable, Sendable {
    /// Whether the Claude CLI is installed and available on the server.
    public let claudeInstalled: Bool
    /// Version string of the installed Claude CLI, if available.
    public let claudeVersion: String?
    /// Filesystem paths to Claude configuration files on the server.
    public let configPaths: ClaudeConfigPaths?

    /// Creates a server info value.
    /// - Parameters:
    ///   - claudeInstalled: Whether the Claude CLI is installed on the server.
    ///   - claudeVersion: Version string of the installed Claude CLI.
    ///   - configPaths: Filesystem paths to Claude configuration files.
    public init(claudeInstalled: Bool, claudeVersion: String? = nil, configPaths: ClaudeConfigPaths? = nil) {
        self.claudeInstalled = claudeInstalled
        self.claudeVersion = claudeVersion
        self.configPaths = configPaths
    }
}

/// Filesystem paths to Claude configuration and data files on the server.
public struct ClaudeConfigPaths: Codable, Sendable {
    /// Path to the user-level Claude settings file.
    public let userSettings: String?
    /// Path to the project-level Claude settings file.
    public let projectSettings: String?
    /// Path to the local (workspace) Claude settings file.
    public let localSettings: String?
    /// Path to the user-level MCP (Model Context Protocol) configuration file.
    public let userMCP: String?
    /// Path to the Claude skills directory.
    public let skills: String?

    /// Creates a Claude config paths value.
    /// - Parameters:
    ///   - userSettings: Path to the user-level Claude settings file.
    ///   - projectSettings: Path to the project-level Claude settings file.
    ///   - localSettings: Path to the local (workspace) Claude settings file.
    ///   - userMCP: Path to the user-level MCP configuration file.
    ///   - skills: Path to the Claude skills directory.
    public init(userSettings: String? = nil, projectSettings: String? = nil, localSettings: String? = nil, userMCP: String? = nil, skills: String? = nil) {
        self.userSettings = userSettings
        self.projectSettings = projectSettings
        self.localSettings = localSettings
        self.userMCP = userMCP
        self.skills = skills
    }
}

/// Current runtime status of the ILS backend server.
///
/// Used to poll server health and retrieve live connection metadata
/// without performing a full reconnection handshake.
public struct ServerStatus: Codable, Sendable {
    /// Whether the server is currently connected and accepting requests.
    public let connected: Bool
    /// Version string of the Claude CLI running on the server.
    public let claudeVersion: String?
    /// Time in seconds the server has been running since last start.
    public let uptime: TimeInterval?
    /// Filesystem paths to Claude configuration files on the server.
    public let configPaths: ClaudeConfigPaths?

    /// Creates a server status value.
    /// - Parameters:
    ///   - connected: Whether the server is connected and accepting requests.
    ///   - claudeVersion: Version string of the Claude CLI on the server.
    ///   - uptime: Seconds elapsed since the server started.
    ///   - configPaths: Filesystem paths to Claude configuration files.
    public init(connected: Bool, claudeVersion: String? = nil, uptime: TimeInterval? = nil, configPaths: ClaudeConfigPaths? = nil) {
        self.connected = connected
        self.claudeVersion = claudeVersion
        self.uptime = uptime
        self.configPaths = configPaths
    }
}

// ConnectRequest removed — use SSHConnectRequest from SSHDTOs.swift instead
// (both had identical fields: host, port, username, authMethod, credential)
