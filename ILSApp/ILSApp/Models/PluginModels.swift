import Foundation

// MARK: - Plugin Models (extracted from PluginsListView.swift)

struct PluginItem: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String?
    let marketplace: String?
    let isInstalled: Bool
    var isEnabled: Bool
    let version: String?
    let commands: [String]?
    let agents: [String]?
}

struct MarketplaceInfo: Decodable {
    let name: String
    let source: String
    let plugins: [MarketplacePlugin]
}

struct MarketplacePlugin: Decodable {
    let name: String
    let description: String?
    let category: String?
}
