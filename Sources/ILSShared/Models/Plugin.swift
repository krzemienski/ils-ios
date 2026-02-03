import Foundation

/// Represents a Claude Code plugin
public struct Plugin: Codable, Identifiable, Sendable {
    /// Unique identifier for the plugin
    public let id: UUID
    /// Plugin name
    public var name: String
    /// Optional description of the plugin's functionality
    public var description: String?
    /// Name of the marketplace where the plugin is available
    public var marketplace: String?
    /// Whether the plugin is currently installed
    public var isInstalled: Bool
    /// Whether the plugin is currently enabled
    public var isEnabled: Bool
    /// Installed version of the plugin
    public var version: String?
    /// Available commands provided by the plugin
    public var commands: [String]?
    /// Available agents provided by the plugin
    public var agents: [String]?
    /// File system path to the plugin
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
    /// Marketplace name
    public let name: String
    /// Source URL or identifier for the marketplace
    public let source: String
    /// List of plugins available in this marketplace
    public var plugins: [PluginInfo]

    public init(name: String, source: String, plugins: [PluginInfo] = []) {
        self.name = name
        self.source = source
        self.plugins = plugins
    }
}

/// Basic plugin info from marketplace
public struct PluginInfo: Codable, Sendable {
    /// Plugin name
    public let name: String
    /// Optional description of the plugin
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
