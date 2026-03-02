import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class MCPViewModel: BaseViewModel {
    var servers: [MCPServer] = []
    var searchText = ""
    var selectedScope: String = "user"

    // Spec 012: Health monitoring
    var lastHealthCheck: Date?
    var isHealthChecking = false
    var lastUpdated: Date?
    @ObservationIgnored nonisolated(unsafe) private var healthTimer: Task<Void, Never>?

    // Spec 018: Batch operations
    var isSelecting = false
    var selectedServerIDs: Set<UUID> = []

    var selectedCount: Int { selectedServerIDs.count }

    // MARK: - GitHub Marketplace Discovery
    var gitHubResults: [GitHubSearchResult] = []
    var isSearchingGitHub = false
    var gitHubSearchText = ""
    var installingMCPServers: Set<String> = []
    var gitHubError: String?
    var rateLimitCountdown: Int = 0
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// Update GitHub search text and trigger debounced search.
    /// Call this instead of assigning `gitHubSearchText` directly.
    /// For SwiftUI TextField bindings, call from `.onChange(of:)`.
    func updateGitHubSearchText(_ text: String) {
        gitHubSearchText = text
        debouncedGitHubSearch()
    }

    /// Trigger a debounced GitHub search based on current `gitHubSearchText`.
    private func debouncedGitHubSearch() {
        searchTask?.cancel()
        guard !gitHubSearchText.isEmpty else {
            gitHubResults = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await searchGitHub(query: gitHubSearchText)
        }
    }

    /// Precomputed lowercase search strings keyed by server, rebuilt when servers change
    private var searchCache: [(server: MCPServer, searchText: String)] = []

    deinit {
        healthTimer?.cancel()
        searchTask?.cancel()
        countdownTask?.cancel()
    }

    /// Filtered servers based on search text using precomputed lowercase cache
    var filteredServers: [MCPServer] {
        guard !searchText.isEmpty else { return servers }
        let query = searchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.server)
    }

    /// Rebuild the lowercase search cache when servers array changes
    private func rebuildSearchCache() {
        searchCache = servers.map { server in
            let text = [
                server.name.lowercased(),
                server.command.lowercased(),
                server.scope.rawValue.lowercased(),
                server.args.map { $0.lowercased() }.joined(separator: " ")
            ].joined(separator: " ")
            return (server, text)
        }
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading MCP servers..."
        }
        if !searchText.isEmpty && filteredServers.isEmpty {
            return "No MCP servers found"
        }
        return servers.isEmpty ? "No MCP servers configured" : ""
    }

    /// Load servers from backend
    /// - Parameter refresh: If true, bypasses server cache to rescan configuration files
    func loadServers(refresh: Bool = false) async {
        guard let client else { return }
        isLoading = true
        error = nil

        // Cache-first: show cached data immediately while network request is in flight
        if servers.isEmpty {
            let cached = await CacheService.shared.getCachedMCPServers()
            if !cached.isEmpty {
                servers = cached
                rebuildSearchCache()
                AppLogger.shared.info("Loaded \(cached.count) MCP servers from cache", category: "mcp")
            }
        }

        do {
            let path = refresh ? "/mcp?refresh=true" : "/mcp"
            let response: APIResponse<ListResponse<MCPServer>> = try await client.get(path)
            if let data = response.data {
                servers = data.items
                rebuildSearchCache()
                lastUpdated = Date()
                // CONC-03: Use Task instead of Task.detached — CacheService actor handles isolation.
                Task {
                    await CacheService.shared.cacheMCPServers(data.items)
                }
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load MCP servers: \(error.localizedDescription)", category: "mcp")
        }

        isLoading = false
    }

    /// Refresh servers by rescanning configuration files
    func refreshServers() async {
        await loadServers(refresh: true)
    }

    func retryLoadServers() async {
        await loadServers()
    }

    func addServer(name: String, command: String, args: [String], env: [String: String]? = nil, scope: String) async -> MCPServer? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: args,
                env: env,
                scope: MCPScope(rawValue: scope)
            )
            let response: APIResponse<MCPServer> = try await client.post("/mcp", body: request)
            if let server = response.data {
                servers.append(server)
                rebuildSearchCache()
                return server
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to add MCP server '\(name)': \(error.localizedDescription)", category: "mcp")
        }
        return nil
    }

    func deleteServer(_ server: MCPServer) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/mcp/\(server.name)?scope=\(server.scope.rawValue)")
            servers.removeAll { $0.id == server.id }
            rebuildSearchCache()
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete MCP server '\(server.name)': \(error.localizedDescription)", category: "mcp")
        }
    }

    func loadServers(scope: String) async {
        guard let client else { return }
        isLoading = true
        error = nil
        selectedScope = scope

        do {
            let response: APIResponse<ListResponse<MCPServer>> = try await client.get("/mcp?scope=\(scope)")
            if let data = response.data {
                servers = data.items
                rebuildSearchCache()
                lastUpdated = Date()
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load MCP servers: \(error.localizedDescription)", category: "mcp")
        }

        isLoading = false
    }

    // MARK: - Spec 012: Health Monitoring

    func startHealthPolling(interval: TimeInterval = 30) {
        stopHealthPolling()
        healthTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkHealth()
                // ENRG-CRIT: Respect Low Power Mode — increase interval to 120s when active
                let effectiveInterval = ProcessInfo.processInfo.isLowPowerModeEnabled
                    ? max(interval, 120)
                    : interval
                try? await Task.sleep(nanoseconds: UInt64(effectiveInterval * 1_000_000_000))
            }
        }
    }

    func stopHealthPolling() {
        healthTimer?.cancel()
        healthTimer = nil
    }

    func checkHealth() async {
        isHealthChecking = true
        await loadServers()
        lastHealthCheck = Date()
        isHealthChecking = false
    }

    // MARK: - Spec 018: Batch Operations

    func toggleSelection(for server: MCPServer) {
        if selectedServerIDs.contains(server.id) {
            selectedServerIDs.remove(server.id)
        } else {
            selectedServerIDs.insert(server.id)
        }
    }

    func selectAll() {
        selectedServerIDs = Set(filteredServers.map(\.id))
    }

    func deselectAll() {
        selectedServerIDs.removeAll()
    }

    func deleteSelected() async {
        let toDelete = servers.filter { selectedServerIDs.contains($0.id) }
        for server in toDelete {
            await deleteServer(server)
        }
        selectedServerIDs.removeAll()
        isSelecting = false
    }

    func updateServer(name: String, command: String, args: [String], env: [String: String]? = nil, scope: String) async -> MCPServer? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(name: name, command: command, args: args, env: env, scope: MCPScope(rawValue: scope))
            let response: APIResponse<MCPServer> = try await client.put("/mcp/\(name)", body: request)
            if let server = response.data {
                if let index = servers.firstIndex(where: { $0.name == name }) {
                    servers[index] = server
                    rebuildSearchCache()
                }
                return server
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to update MCP server '\(name)': \(error.localizedDescription)", category: "mcp")
        }
        return nil
    }

    // MARK: - GitHub Marketplace Methods

    func searchGitHub(query: String) async {
        guard let client, !query.isEmpty else {
            gitHubResults = []
            return
        }
        isSearchingGitHub = true
        gitHubError = nil
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: APIResponse<ListResponse<GitHubSearchResult>> = try await client.get("/mcp/search?q=\(encoded)")
            if let data = response.data {
                gitHubResults = data.items
            }
            gitHubError = nil
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("rate limit") || desc.contains("429") || desc.contains("limit reached") {
                gitHubError = "GitHub rate limit reached"
                startCountdown()
            } else {
                self.error = error
            }
            AppLogger.shared.error("GitHub MCP search failed: \(error.localizedDescription)", category: "mcp")
        }
        isSearchingGitHub = false
    }

    /// Install an MCP server from a GitHub marketplace result using the existing POST /mcp endpoint.
    func installFromMarketplace(result: GitHubSearchResult, command: String, args: [String], env: [String: String]?, scope: String) async -> Bool {
        guard let client else { return false }
        installingMCPServers.insert(result.repository)
        defer { installingMCPServers.remove(result.repository) }
        do {
            let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.name
            let request = CreateMCPRequest(
                name: repoName,
                command: command,
                args: args,
                env: env,
                scope: MCPScope(rawValue: scope)
            )
            let response: APIResponse<MCPServer> = try await client.post("/mcp", body: request)
            if let server = response.data {
                servers.append(server)
                rebuildSearchCache()
            }
            return true
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to install MCP server from marketplace '\(result.repository)': \(error.localizedDescription)", category: "mcp")
            return false
        }
    }

    /// Check if a GitHub search result is already installed as an MCP server.
    func isInstalled(result: GitHubSearchResult) -> Bool {
        let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.repository
        return servers.contains { $0.name == repoName }
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

    // MARK: - Logs, Validation & Presets

    /// Preset MCP server configurations loaded from the backend.
    var presets: [MCPPreset] = []

    /// Fetch recent log entries for a specific MCP server.
    /// - Parameters:
    ///   - server: The MCP server to fetch logs for.
    ///   - limit: Maximum number of log entries to return (clamped by backend to 1–500).
    /// - Returns: Array of log entries, or empty array on failure.
    func fetchLogs(for server: MCPServer, limit: Int = 100) async -> [MCPLogEntry] {
        guard let client else { return [] }
        do {
            let response: APIResponse<MCPLogsResponse> = try await client.get("/mcp/\(server.name)/logs?limit=\(limit)")
            return response.data?.logs ?? []
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to fetch logs for MCP server '\(server.name)': \(error.localizedDescription)", category: "mcp")
            return []
        }
    }

    /// Validate an MCP server configuration against the backend before saving.
    /// - Parameters:
    ///   - name: Proposed server name.
    ///   - command: Executable command.
    ///   - args: Command-line arguments.
    ///   - env: Environment variables.
    ///   - scope: Configuration scope.
    /// - Returns: Validation result with errors and warnings, or nil on request failure.
    func validateConfig(
        name: String,
        command: String,
        args: [String],
        env: [String: String]?,
        scope: String
    ) async -> MCPValidationResult? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: args,
                env: env,
                scope: MCPScope(rawValue: scope)
            )
            let response: APIResponse<MCPValidationResult> = try await client.post("/mcp/validate", body: request)
            return response.data
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to validate MCP config for '\(name)': \(error.localizedDescription)", category: "mcp")
            return nil
        }
    }

    /// Load preset MCP server configurations from the backend.
    /// Results are stored in the `presets` property.
    func loadPresets() async {
        guard let client else { return }
        do {
            let response: APIResponse<MCPPresetListResponse> = try await client.get("/mcp/presets")
            if let data = response.data {
                presets = data.presets
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load MCP presets: \(error.localizedDescription)", category: "mcp")
        }
    }

    // MARK: - Enable/Disable

    /// Toggle the enabled state of an MCP server.
    func toggleEnabled(_ server: MCPServer) async {
        if server.isEnabled {
            await disableServer(server)
        } else {
            await enableServer(server)
        }
    }

    /// Enable an MCP server by adding it to the active configuration.
    func enableServer(_ server: MCPServer) async {
        guard let client else { return }
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/mcp/\(server.name)/enable", body: EmptyBody())
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isEnabled = true
                rebuildSearchCache()
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to enable MCP server '\(server.name)': \(error.localizedDescription)", category: "mcp")
        }
    }

    /// Disable an MCP server by removing it from the active configuration.
    func disableServer(_ server: MCPServer) async {
        guard let client else { return }
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/mcp/\(server.name)/disable", body: EmptyBody())
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isEnabled = false
                rebuildSearchCache()
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to disable MCP server '\(server.name)': \(error.localizedDescription)", category: "mcp")
        }
    }
}
