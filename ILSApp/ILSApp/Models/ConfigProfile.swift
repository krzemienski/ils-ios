import Foundation

struct ConfigProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var mcpServers: [String]  // Server names included
    var skills: [String]      // Skill names included
    var settings: [String: String]  // Key-value settings
    var projectPaths: [String]  // Assigned project directories
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    init(id: UUID = UUID(), name: String = "", description: String = "", mcpServers: [String] = [], skills: [String] = [], settings: [String: String] = [:], projectPaths: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date(), isActive: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.mcpServers = mcpServers
        self.skills = skills
        self.settings = settings
        self.projectPaths = projectPaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }

    static let defaults: [ConfigProfile] = [
        ConfigProfile(name: "Default", description: "Standard configuration", mcpServers: ["filesystem", "memory"], skills: ["code-review"], isActive: true),
        ConfigProfile(name: "Minimal", description: "Lightweight setup for quick tasks", mcpServers: ["filesystem"], skills: []),
        ConfigProfile(name: "Full Stack", description: "All servers and skills enabled", mcpServers: ["filesystem", "memory", "postgres", "redis"], skills: ["code-review", "testing", "deployment"])
    ]
}
