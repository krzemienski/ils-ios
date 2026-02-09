import Foundation

// MARK: - SSH Requests

public struct SSHConnectRequest: Codable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: String
    public let credential: String

    public init(host: String, port: Int = 22, username: String, authMethod: String, credential: String) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
    }
}

public struct SSHExecuteRequest: Codable, Sendable {
    public let command: String
    public let timeout: Int?

    public init(command: String, timeout: Int? = nil) {
        self.command = command
        self.timeout = timeout
    }
}

// MARK: - SSH Responses

public struct SSHStatusResponse: Codable, Sendable {
    public let connected: Bool
    public let host: String?
    public let username: String?
    public let platform: String?
    public let connectedAt: Date?
    public let uptime: TimeInterval?

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

public struct SSHExecuteResponse: Codable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int

    public init(stdout: String, stderr: String, exitCode: Int) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public struct SSHPlatformResponse: Codable, Sendable {
    public let platform: String
    public let isSupported: Bool
    public let rejectionReason: String?

    public init(platform: String, isSupported: Bool, rejectionReason: String? = nil) {
        self.platform = platform
        self.isSupported = isSupported
        self.rejectionReason = rejectionReason
    }
}
