import Foundation
import ILSShared

@MainActor
class PluginsViewModel: ObservableObject {
    @Published var plugins: [Plugin] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    @Published var marketplaceSearchText = ""
    @Published var selectedCategory: String = "All"
    @Published var isSearchingMarketplace = false
    @Published var searchResults: [PluginInfo] = []
    @Published var installingPlugins: Set<String> = []

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

    /// Filtered plugins based on search text
    var filteredPlugins: [Plugin] {
        if searchText.isEmpty {
            return plugins
        }
        return plugins.filter { plugin in
            plugin.name.localizedCaseInsensitiveContains(searchText) ||
            (plugin.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func loadPlugins() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<Plugin>> = try await client.get("/plugins")
            if let data = response.data {
                plugins = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load plugins: \(error.localizedDescription)", category: "plugins")
        }

        isLoading = false
    }

    func retryLoadPlugins() async {
        await loadPlugins()
    }

    func installPlugin(name: String, marketplace: String) async {
        guard let client else { return }
        installingPlugins.insert(name)
        do {
            let request = InstallPluginRequest(pluginName: name, marketplace: marketplace)
            let response: APIResponse<Plugin> = try await client.post("/plugins/install", body: request)
            if let plugin = response.data {
                plugins.append(plugin)
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to install plugin '\(name)': \(error.localizedDescription)", category: "plugins")
        }
        installingPlugins.remove(name)
    }

    func uninstallPlugin(_ plugin: Plugin) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/plugins/\(plugin.name)")
            plugins.removeAll { $0.id == plugin.id }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to uninstall plugin '\(plugin.name)': \(error.localizedDescription)", category: "plugins")
        }
    }

    func enablePlugin(_ plugin: Plugin) async {
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
            AppLogger.shared.error("Failed to enable plugin '\(plugin.name)': \(error.localizedDescription)", category: "plugins")
        }
    }

    func disablePlugin(_ plugin: Plugin) async {
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
            AppLogger.shared.error("Failed to disable plugin '\(plugin.name)': \(error.localizedDescription)", category: "plugins")
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
            let response: APIResponse<ListResponse<PluginInfo>> = try await client.get("/plugins/search?q=\(encoded)")
            if let data = response.data {
                searchResults = data.items
            }
        } catch {
            AppLogger.shared.error("Plugin search failed: \(error.localizedDescription)", category: "plugins")
        }
        isSearchingMarketplace = false
    }

    func addMarketplace(repo: String) async -> Bool {
        guard let client, !repo.isEmpty else { return false }
        do {
            let request = AddMarketplaceRequest(source: "github", repo: repo)
            let _: APIResponse<PluginMarketplace> = try await client.post("/marketplaces", body: request)
            return true
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to add marketplace: \(error.localizedDescription)", category: "plugins")
            return false
        }
    }
}
