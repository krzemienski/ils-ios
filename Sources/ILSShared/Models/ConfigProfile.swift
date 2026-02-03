import Foundation

/// Represents a named configuration profile for managing MCP servers, skills, and Claude settings
public struct ConfigProfile: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var mcpServers: [MCPServer]
    public var enabledSkills: [String]
    public var config: ClaudeConfig?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        mcpServers: [MCPServer] = [],
        enabledSkills: [String] = [],
        config: ClaudeConfig? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.mcpServers = mcpServers
        self.enabledSkills = enabledSkills
        self.config = config
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
