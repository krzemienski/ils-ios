import Foundation

/// Source type for plugins.
public enum PluginSource: String, Codable, Sendable {
    /// Official Claude Code plugin.
    case official
    /// Community-contributed plugin.
    case community
}

/// Represents a Claude Code plugin.
public struct Plugin: Codable, Identifiable, Sendable {
    /// Unique identifier.
    public let id: UUID
    /// Plugin name.
    public var name: String
    /// Plugin description.
    public var description: String?
    /// Marketplace identifier.
    public var marketplace: String?
    /// Whether the plugin is installed.
    public var isInstalled: Bool
    /// Whether the plugin is enabled.
    public var isEnabled: Bool
    /// Plugin version.
    public var version: String?
    /// Commands provided by the plugin.
    public var commands: [String]?
    /// Agents provided by the plugin.
    public var agents: [String]?
    /// Installation path.
    public var path: String?
    /// GitHub stars.
    public var stars: Int?
    /// Plugin source.
    public var source: PluginSource?
    /// Plugin category.
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

/// Plugin marketplace information.
public struct PluginMarketplace: Codable, Sendable {
    /// Marketplace name.
    public let name: String
    /// Marketplace source URL or identifier.
    public let source: String
    /// Available plugins in this marketplace.
    public var plugins: [PluginInfo]

    public init(name: String, source: String, plugins: [PluginInfo] = []) {
        self.name = name
        self.source = source
        self.plugins = plugins
    }
}

/// Basic plugin info from marketplace listing.
public struct PluginInfo: Codable, Sendable {
    /// Plugin name.
    public let name: String
    /// Brief description.
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
