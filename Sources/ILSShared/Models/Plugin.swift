import Foundation

/// Source type for plugins.
public enum PluginSource: String, Codable, Sendable {
    /// Official Claude Code plugin from Anthropic.
    case official
    /// Community-contributed plugin.
    case community
}

/// Represents a Claude Code plugin that extends functionality.
public struct Plugin: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this plugin.
    public let id: UUID
    /// Plugin name (used as display name and command prefix).
    public var name: String
    /// Human-readable description of the plugin's functionality.
    public var description: String?
    /// Marketplace where the plugin was discovered.
    public var marketplace: String?
    /// Whether the plugin is installed locally.
    public var isInstalled: Bool
    /// Whether the plugin is enabled and active.
    public var isEnabled: Bool
    /// Semantic version string (e.g., "1.2.3").
    public var version: String?
    /// Slash commands provided by this plugin.
    public var commands: [String]?
    /// Agent definitions provided by this plugin.
    public var agents: [String]?
    /// Filesystem path to the plugin installation.
    public var path: String?
    /// Number of GitHub stars (for marketplace plugins).
    public var stars: Int?
    /// Source of the plugin (official or community).
    public var source: PluginSource?
    /// Category for organizing plugins (e.g., "productivity", "testing").
    public var category: String?

    /// Creates a new plugin entry.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Plugin name. Must not be empty.
    ///   - description: Optional description of functionality.
    ///   - marketplace: Optional marketplace identifier.
    ///   - isInstalled: Whether the plugin is installed (default: true).
    ///   - isEnabled: Whether the plugin is enabled (default: true).
    ///   - version: Optional semantic version string.
    ///   - commands: Optional list of slash commands.
    ///   - agents: Optional list of agent definitions.
    ///   - path: Optional filesystem installation path.
    ///   - stars: Optional GitHub star count.
    ///   - source: Optional plugin source.
    ///   - category: Optional category for organization.
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
        precondition(!name.isEmpty, "Plugin name must not be empty")
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

/// Plugin marketplace information for plugin discovery.
public struct PluginMarketplace: Codable, Hashable, Sendable {
    /// Marketplace display name.
    public let name: String
    /// Marketplace source URL or identifier.
    public let source: String
    /// Available plugins in this marketplace.
    public var plugins: [PluginInfo]

    /// Creates a marketplace entry.
    /// - Parameters:
    ///   - name: Marketplace display name.
    ///   - source: Source URL or identifier.
    ///   - plugins: Available plugins.
    public init(name: String, source: String, plugins: [PluginInfo] = []) {
        self.name = name
        self.source = source
        self.plugins = plugins
    }
}

/// Basic plugin info from a marketplace listing.
public struct PluginInfo: Codable, Hashable, Sendable {
    /// Plugin name.
    public let name: String
    /// Brief description of the plugin.
    public let description: String?

    /// Creates a plugin info entry.
    /// - Parameters:
    ///   - name: Plugin name.
    ///   - description: Optional brief description.
    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
