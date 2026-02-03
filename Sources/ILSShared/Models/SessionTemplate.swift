import Foundation

/// Represents a session template with predefined configurations
public struct SessionTemplate: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var initialPrompt: String?
    public var model: String
    public var permissionMode: PermissionMode
    public var isFavorite: Bool
    public var isDefault: Bool
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        initialPrompt: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        isFavorite: Bool = false,
        isDefault: Bool = false,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.initialPrompt = initialPrompt
        self.model = model
        self.permissionMode = permissionMode
        self.isFavorite = isFavorite
        self.isDefault = isDefault
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
