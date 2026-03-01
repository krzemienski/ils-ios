import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class PluginsViewModel: BaseViewModel {
    var plugins: [Plugin] = []
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
    var lastInstallError: Error?
    var rateLimitCountdown: Int = 0
    var lastUpdated: Date?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// Precomputed lowercase search strings keyed by plugin, rebuilt when plugins change
    @ObservationIgnored private var searchCache: [(plugin: Plugin, searchText: String)] = []

    deinit {
        searchTask?.cancel()
        countdownTask?.cancel()
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

    /// Filtered plugins based on search text using precomputed lowercase cache
    var filteredPlugins: [Plugin] {
        guard !searchText.isEmpty else { return plugins }
        let query = searchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.plugin)
    }

    /// Rebuild the lowercase search cache when plugins array changes
    private func rebuildSearchCache() {
        searchCache = plugins.map { plugin in
            let text = [
                plugin.name.lowercased(),
                plugin.description?.lowercased() ?? ""
            ].joined(separator: " ")
            return (plugin, text)
        }
    }

    func loadPlugins() async {
        guard let client else { return }
        isLoading = true
        error = nil

        // Cache-first: show cached data immediately while fetching from API
        if plugins.isEmpty {
            let cached = await CacheService.shared.getCachedPlugins()
            if !cached.isEmpty {
                plugins = cached
                rebuildSearchCache()
                AppLogger.shared.info("Loaded \(cached.count) plugins from cache", category: "plugins")
            }
        }

        do {
            let response: APIResponse<ListResponse<Plugin>> = try await client.get("/plugins")
            if let data = response.data {
                plugins = data.items
                lastUpdated = Date()
                rebuildSearchCache()
                // CONC-03: Use Task instead of Task.detached — CacheService actor handles isolation.
                Task {
                    await CacheService.shared.cachePlugins(data.items)
                }
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
                rebuildSearchCache()
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
            rebuildSearchCache()
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
                rebuildSearchCache()
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
                rebuildSearchCache()
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
        lastInstallError = nil
        defer { installingPlugins.remove(result.repository) }
        do {
            let request = InstallPluginRequest(pluginName: repoName, marketplace: result.repository)
            let _: APIResponse<Plugin> = try await client.post("/plugins/install", body: request)
            await loadPlugins()
            return true
        } catch {
            self.lastInstallError = error
            self.error = error
            AppLogger.shared.error("Failed to install plugin from GitHub: \(error.localizedDescription)", category: "plugins")
            return false
        }
    }

    /// Fetch preview data (README + file tree) for a GitHub repository.
    /// Returns nil on failure (network error, rate limit, etc.).
    func fetchPreview(repository: String) async -> GitHubRepoPreview? {
        guard let client else { return nil }
        do {
            let encoded = repository.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? repository
            let response: APIResponse<GitHubRepoPreview> = try await client.get("/plugins/preview?repo=\(encoded)")
            return response.data
        } catch {
            AppLogger.shared.error("Failed to fetch plugin preview for \(repository): \(error.localizedDescription)", category: "plugins")
            return nil
        }
    }

    /// Check for updates for a specific plugin via the backend API.
    func checkForUpdate(pluginName: String) async -> PluginUpdateInfo? {
        guard let client else { return nil }
        do {
            let encoded = pluginName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pluginName
            let response: APIResponse<PluginUpdateInfo> = try await client.get("/plugins/\(encoded)/check-update")
            return response.data
        } catch {
            AppLogger.shared.error("Failed to check update for '\(pluginName)': \(error.localizedDescription)", category: "plugins")
            return nil
        }
    }

    /// Check if a plugin has unmet dependencies by comparing against installed plugins.
    func getUnmetDependencies(for plugin: Plugin) -> [String] {
        guard let deps = plugin.dependencies, !deps.isEmpty else { return [] }
        let installedNames = Set(plugins.map { $0.name })
        return deps.filter { !installedNames.contains($0) }
    }

    /// Check if a GitHub search result is already installed locally.
    func isInstalled(result: GitHubSearchResult) -> Bool {
        let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.repository
        return plugins.contains { $0.name == repoName || ($0.path?.contains(repoName) ?? false) }
    }
}
