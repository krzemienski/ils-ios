import Foundation

public struct ConnectionResponse: Codable, Sendable {
    public let success: Bool
    public let sessionId: String?
    public let serverInfo: ServerInfo?
    public let error: String?

    public init(success: Bool, sessionId: String? = nil, serverInfo: ServerInfo? = nil, error: String? = nil) {
        self.success = success
        self.sessionId = sessionId
        self.serverInfo = serverInfo
        self.error = error
    }
}

public struct ServerInfo: Codable, Sendable {
    public let claudeInstalled: Bool
    public let claudeVersion: String?
    public let configPaths: ClaudeConfigPaths?

    public init(claudeInstalled: Bool, claudeVersion: String? = nil, configPaths: ClaudeConfigPaths? = nil) {
        self.claudeInstalled = claudeInstalled
        self.claudeVersion = claudeVersion
        self.configPaths = configPaths
    }
}

public struct ClaudeConfigPaths: Codable, Sendable {
    public let userSettings: String?
    public let projectSettings: String?
    public let localSettings: String?
    public let userMCP: String?
    public let skills: String?

    public init(userSettings: String? = nil, projectSettings: String? = nil, localSettings: String? = nil, userMCP: String? = nil, skills: String? = nil) {
        self.userSettings = userSettings
        self.projectSettings = projectSettings
        self.localSettings = localSettings
        self.userMCP = userMCP
        self.skills = skills
    }
}

public struct ServerStatus: Codable, Sendable {
    public let connected: Bool
    public let claudeVersion: String?
    public let uptime: TimeInterval?
    public let configPaths: ClaudeConfigPaths?

    public init(connected: Bool, claudeVersion: String? = nil, uptime: TimeInterval? = nil, configPaths: ClaudeConfigPaths? = nil) {
        self.connected = connected
        self.claudeVersion = claudeVersion
        self.uptime = uptime
        self.configPaths = configPaths
    }
}

// ConnectRequest removed — use SSHConnectRequest from SSHDTOs.swift instead
// (both had identical fields: host, port, username, authMethod, credential)
