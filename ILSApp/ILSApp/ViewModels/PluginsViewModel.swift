import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class PluginsViewModel {
    var plugins: [Plugin] = []
    var isLoading = false
    var error: Error?
    var searchText = ""
    var marketplaceSearchText = ""
    var selectedCategory: String = "All"
    var isSearchingMarketplace = false
    var searchResults: [PluginInfo] = []
    var installingPlugins: Set<String> = []
    var gitHubSearchText = ""
    var gitHubResults: [GitHubSearchResult] = []
    var isSearchingGitHub = false
    var gitHubError: String?
    var rateLimitCountdown: Int = 0
    var lastUpdated: Date?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    private var client: APIClient?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init() {}

    deinit {
        searchTask?.cancel()
        countdownTask?.cancel()
    }

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

    /// Available plugin categories derived from marketplace field
    var pluginCategories: [String] {
        var categories = Set<String>()
        categories.insert("All")
        for plugin in plugins {
            if let marketplace = plugin.marketplace, !marketplace.isEmpty {
                categories.insert(marketplace)
            }
        }
        return categories.sorted()
    }

    /// Plugins filtered by search text and selected category
    var filteredPluginsByCategory: [Plugin] {
        let baseFiltered = filteredPlugins
        if selectedCategory == "All" {
            return baseFiltered
        }
        return baseFiltered.filter { $0.marketplace == selectedCategory }
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
                lastUpdated = Date()
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

    // MARK: - GitHub Browse

    /// Update GitHub search text and trigger debounced search.
    /// Call this instead of assigning `gitHubSearchText` directly.
    func updateGitHubSearchText(_ text: String) {
        gitHubSearchText = text
        debouncedGitHubSearch()
    }

    /// Trigger a debounced GitHub search based on current `gitHubSearchText`.
    private func debouncedGitHubSearch() {
        searchTask?.cancel()
        guard !gitHubSearchText.isEmpty else {
            gitHubResults = []
            gitHubError = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await searchGitHub(query: gitHubSearchText)
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        rateLimitCountdown = 60
        countdownTask = Task { @MainActor [weak self] in
            while let self, self.rateLimitCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.rateLimitCountdown -= 1
            }
            guard let self, !Task.isCancelled else { return }
            self.gitHubError = nil
            self.rateLimitCountdown = 0
        }
    }

    /// Search GitHub for plugins matching the query.
    func searchGitHub(query: String) async {
        guard let client, !query.isEmpty else {
            gitHubResults = []
            return
        }
        isSearchingGitHub = true
        gitHubError = nil
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: APIResponse<ListResponse<GitHubSearchResult>> = try await client.get("/plugins/github-search?q=\(encoded)")
            if let data = response.data {
                gitHubResults = data.items
            }
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("rate limit") || desc.contains("429") || desc.contains("limit reached") {
                gitHubError = "GitHub rate limit reached"
                startCountdown()
            } else {
                self.error = error
            }
            AppLogger.shared.error("Plugin GitHub search failed: \(error.localizedDescription)", category: "plugins")
        }
        isSearchingGitHub = false
    }

    /// Install a plugin from a GitHub search result.
    func installFromGitHub(result: GitHubSearchResult) async -> Bool {
        guard let client else { return false }
        let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.repository
        installingPlugins.insert(result.repository)
        defer { installingPlugins.remove(result.repository) }
        do {
            let request = InstallPluginRequest(pluginName: repoName, marketplace: result.repository)
            let _: APIResponse<Plugin> = try await client.post("/plugins/install", body: request)
            await loadPlugins()
            return true
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to install plugin from GitHub: \(error.localizedDescription)", category: "plugins")
            return false
        }
    }

    /// Check if a GitHub search result is already installed locally.
    func isInstalled(result: GitHubSearchResult) -> Bool {
        let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.repository
        return plugins.contains { $0.name == repoName || ($0.path?.contains(repoName) ?? false) }
    }
}
