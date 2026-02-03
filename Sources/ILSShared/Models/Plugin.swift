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

    // Marketplace fields
    public var author: String?
    public var installCount: Int?
    public var rating: Double?
    public var reviewCount: Int?
    public var tags: [String]?
    public var hasUpdate: Bool?
    public var latestVersion: String?
    public var screenshots: [String]?

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
        author: String? = nil,
        installCount: Int? = nil,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        tags: [String]? = nil,
        hasUpdate: Bool? = nil,
        latestVersion: String? = nil,
        screenshots: [String]? = nil
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
        self.author = author
        self.installCount = installCount
        self.rating = rating
        self.reviewCount = reviewCount
        self.tags = tags
        self.hasUpdate = hasUpdate
        self.latestVersion = latestVersion
        self.screenshots = screenshots
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

    // Enhanced marketplace fields
    public var author: String?
    public var installCount: Int?
    public var rating: Double?
    public var reviewCount: Int?
    public var tags: [String]?
    public var version: String?
    public var screenshots: [String]?

    public init(
        name: String,
        description: String? = nil,
        author: String? = nil,
        installCount: Int? = nil,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        tags: [String]? = nil,
        version: String? = nil,
        screenshots: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.installCount = installCount
        self.rating = rating
        self.reviewCount = reviewCount
        self.tags = tags
        self.version = version
        self.screenshots = screenshots
    }
}
