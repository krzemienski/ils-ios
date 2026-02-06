import Foundation

/// Source type for plugins
public enum PluginSource: String, Codable, Sendable {
    case official
    case community
}

/// Represents a Claude Code plugin
public struct Plugin: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var marketplace: String?
    public var isInstalled: Bool
    public var isEnabled: Bool
    public var version: String?
    public var commands: [String]?
    public var agents: [String]?
    public var path: String?
    public var stars: Int?
    public var source: PluginSource?
    public var category: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        marketplace: String? = nil,
        isInstalled: Bool = true,
        isEnabled: Bool = true,
        version: String? = nil,
        commands: [String]? = nil,
        agents: [String]? = nil,
        path: String? = nil,
        stars: Int? = nil,
        source: PluginSource? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.marketplace = marketplace
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.version = version
        self.commands = commands
        self.agents = agents
        self.path = path
        self.stars = stars
        self.source = source
        self.category = category
    }
}

/// Plugin marketplace information
public struct PluginMarketplace: Codable, Sendable {
    public let name: String
    public let source: String
    public var plugins: [PluginInfo]

    public init(name: String, source: String, plugins: [PluginInfo] = []) {
        self.name = name
        self.source = source
        self.plugins = plugins
    }
}

/// Basic plugin info from marketplace
public struct PluginInfo: Codable, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
