import Foundation
import ILSShared

@MainActor
class PluginsViewModel: ObservableObject {
    @Published var plugins: [PluginItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var marketplaceSearchText = ""
    @Published var selectedCategory: String = "All"
    @Published var isSearchingMarketplace = false
    @Published var searchResults: [MarketplacePlugin] = []

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading plugins..."
        }
        return plugins.isEmpty ? "No plugins installed" : ""
    }

    func loadPlugins() async {
        guard let client else { return }
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
        guard let client else { return }
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
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/plugins/\(plugin.name)")
            plugins.removeAll { $0.id == plugin.id }
        } catch {
            self.error = error
            print("❌ Failed to uninstall plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func enablePlugin(_ plugin: PluginItem) async {
        guard let client else { return }
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
        guard let client else { return }
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

    func searchMarketplace(query: String) async {
        guard let client, !query.isEmpty else {
            searchResults = []
            return
        }
        isSearchingMarketplace = true
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: APIResponse<ListResponse<MarketplacePlugin>> = try await client.get("/plugins/search?q=\(encoded)")
            if let data = response.data {
                searchResults = data.items
            }
        } catch {
            print("❌ Plugin search failed: \(error.localizedDescription)")
        }
        isSearchingMarketplace = false
    }

    func addMarketplace(repo: String) async -> Bool {
        guard let client, !repo.isEmpty else { return false }
        do {
            let request = AddMarketplaceRequest(source: "github", repo: repo)
            let _: APIResponse<MarketplaceInfo> = try await client.post("/marketplaces", body: request)
            return true
        } catch {
            self.error = error
            print("❌ Failed to add marketplace: \(error.localizedDescription)")
            return false
        }
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
