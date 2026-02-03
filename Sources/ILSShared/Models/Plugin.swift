import Foundation

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
        path: String? = nil
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
    public var author: String?
    public var version: String?
    public var category: String?
    public var tags: [String]
    public var rating: Double?
    public var installCount: Int?
    public var compatibility: String?
    public var homepage: String?
    public var repository: String?

    public init(
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        category: String? = nil,
        tags: [String] = [],
        rating: Double? = nil,
        installCount: Int? = nil,
        compatibility: String? = nil,
        homepage: String? = nil,
        repository: String? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.tags = tags
        self.rating = rating
        self.installCount = installCount
        self.compatibility = compatibility
        self.homepage = homepage
        self.repository = repository
    }
}
