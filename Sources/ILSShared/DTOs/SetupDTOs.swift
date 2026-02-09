import Foundation

// MARK: - Setup Requests

public struct StartSetupRequest: Codable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: String
    public let credential: String
    public let backendPort: Int
    public let repositoryURL: String?

    public init(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: String,
        credential: String,
        backendPort: Int = 9090,
        repositoryURL: String? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.credential = credential
        self.backendPort = backendPort
        self.repositoryURL = repositoryURL
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
