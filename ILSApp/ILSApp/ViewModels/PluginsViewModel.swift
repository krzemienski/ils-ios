import Foundation
import ILSShared

@MainActor
class PluginsViewModel: ObservableObject {
    @Published var plugins: [PluginItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText: String = ""
    @Published var selectedTags: [String] = []
    @Published var marketplaces: [MarketplaceInfo] = []
    @Published var isLoadingMarketplace = false

    private let client = APIClient()

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading plugins..."
        }
        return plugins.isEmpty ? "No plugins installed" : ""
    }

    /// Filtered installed plugins based on search text
    var filteredPlugins: [PluginItem] {
        if searchText.isEmpty {
            return plugins
        }
        return plugins.filter { plugin in
            plugin.name.localizedCaseInsensitiveContains(searchText) ||
            plugin.description?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    /// Filtered marketplace plugins based on search text and selected tags
    var filteredMarketplaces: [MarketplaceInfo] {
        var filtered = marketplaces

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.compactMap { marketplace in
                let filteredPlugins = marketplace.plugins.filter { plugin in
                    plugin.name.localizedCaseInsensitiveContains(searchText) ||
                    plugin.description?.localizedCaseInsensitiveContains(searchText) == true
                }
                if filteredPlugins.isEmpty {
                    return nil
                }
                return MarketplaceInfo(
                    name: marketplace.name,
                    source: marketplace.source,
                    plugins: filteredPlugins
                )
            }
        }

        // Filter by selected tags
        if !selectedTags.isEmpty {
            filtered = filtered.compactMap { marketplace in
                let filteredPlugins = marketplace.plugins.filter { plugin in
                    guard let tags = plugin.tags else { return false }
                    return selectedTags.allSatisfy { selectedTag in
                        tags.contains(selectedTag)
                    }
                }
                if filteredPlugins.isEmpty {
                    return nil
                }
                return MarketplaceInfo(
                    name: marketplace.name,
                    source: marketplace.source,
                    plugins: filteredPlugins
                )
            }
        }

        return filtered
    }

    func loadPlugins() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<PluginItem>> = try await client.get("/plugins")
            if let data = response.data {
                plugins = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load plugins: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadPlugins() async {
        await loadPlugins()
    }

    func installPlugin(name: String, marketplace: String) async {
        do {
            let request = InstallPluginRequest(pluginName: name, marketplace: marketplace)
            let response: APIResponse<PluginItem> = try await client.post("/plugins/install", body: request)
            if let plugin = response.data {
                plugins.append(plugin)
            }
        } catch {
            self.error = error
            print("❌ Failed to install plugin '\(name)': \(error.localizedDescription)")
        }
    }

    func uninstallPlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/plugins/\(plugin.name)")
            plugins.removeAll { $0.id == plugin.id }
        } catch {
            self.error = error
            print("❌ Failed to uninstall plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func enablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/enable", body: EmptyBody())
            if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
                var updated = plugins[index]
                updated.isEnabled = true
                plugins[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to enable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func disablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/disable", body: EmptyBody())
            if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
                var updated = plugins[index]
                updated.isEnabled = false
                plugins[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to disable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func loadMarketplaces() async {
        isLoadingMarketplace = true
        error = nil

        do {
            // Build query parameters for search and tag filtering
            var queryItems: [URLQueryItem] = []
            if !searchText.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: searchText))
            }
            for tag in selectedTags {
                queryItems.append(URLQueryItem(name: "tag", value: tag))
            }

            let endpoint: String
            if queryItems.isEmpty {
                endpoint = "/plugins/marketplace"
            } else {
                var components = URLComponents(string: "/plugins/marketplace")
                components?.queryItems = queryItems
                endpoint = components?.string ?? "/plugins/marketplace"
            }

            let response: APIResponse<[MarketplaceInfo]> = try await client.get(endpoint)
            if let data = response.data {
                marketplaces = data
            }
        } catch {
            self.error = error
            print("❌ Failed to load marketplaces: \(error.localizedDescription)")
        }

        isLoadingMarketplace = false
    }

    func retryLoadMarketplaces() async {
        await loadMarketplaces()
    }
}

// MARK: - Request Types

struct InstallPluginRequest: Encodable {
    let pluginName: String
    let marketplace: String
}

struct EnabledResponse: Decodable {
    let enabled: Bool
}

// MARK: - Marketplace Types

struct MarketplaceInfo: Decodable {
    let name: String
    let source: String
    let plugins: [MarketplacePlugin]
}

struct MarketplacePlugin: Decodable {
    let name: String
    let description: String?
    let author: String?
    let installCount: Int?
    let rating: Double?
    let reviewCount: Int?
    let tags: [String]?
    let version: String?
    let screenshots: [String]?
}
