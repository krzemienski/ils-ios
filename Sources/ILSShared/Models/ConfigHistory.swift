import Foundation

/// Represents a configuration history snapshot
public struct ConfigHistory: Codable, Identifiable, Sendable {
    public let id: UUID
    public var scope: String
    public var configContent: String
    public var changeDescription: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        scope: String,
        configContent: String,
        changeDescription: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.configContent = configContent
        self.changeDescription = changeDescription
        self.createdAt = createdAt
    }
}
