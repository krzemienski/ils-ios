import Foundation

/// SSH connection status enumeration
public enum SSHConnectionStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case connecting
    case error
}

/// Represents an active SSH connection state
public struct SSHConnection: Codable, Identifiable, Sendable {
    public let id: UUID
    public let serverId: UUID
    public var status: SSHConnectionStatus
    public var connectedAt: Date?
    public var error: String?

    public init(
        id: UUID = UUID(),
        serverId: UUID,
        status: SSHConnectionStatus = .disconnected,
        connectedAt: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.status = status
        self.connectedAt = connectedAt
        self.error = error
    }
}
