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
    @ObservationIgnored private var healthTimer: Task<Void, Never>?

    // Spec 018: Batch operations
    var isSelecting = false
    var selectedServerIDs: Set<UUID> = []

    var selectedCount: Int { selectedServerIDs.count }

    /// Precomputed lowercase search strings keyed by server, rebuilt when servers change
    private var searchCache: [(server: MCPServer, searchText: String)] = []

    deinit {
        healthTimer?.cancel()
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

        do {
            let path = refresh ? "/mcp?refresh=true" : "/mcp"
            let response: APIResponse<ListResponse<MCPServer>> = try await client.get(path)
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

    /// Refresh servers by rescanning configuration files
    func refreshServers() async {
        await loadServers(refresh: true)
    }

    func retryLoadServers() async {
        await loadServers()
    }

    func addServer(name: String, command: String, args: [String], scope: String) async -> MCPServer? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: args,
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
    //
    // E-MED-5: MCPViewModel health polling is intentionally separate from PollingManager.
    // PollingManager handles the global backend connectivity check (health endpoint).
    // MCPViewModel polls the /mcp endpoint specifically to refresh server statuses,
    // which is different data from the general health check. Consolidation would mix
    // concerns: "is the backend reachable?" vs "what's the MCP server status?"
    //
    // E-MED-6: Adaptive polling by battery level is deferred. iOS already manages
    // background activity via Low Power Mode (which reduces CPU/network). The app
    // connects to localhost in typical usage, making battery-adaptive polling
    // over-engineering for the current deployment model.

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
        guard let client else { return }
        isHealthChecking = true
        do {
            // Only check reachability — do not reload full server list
            let _: APIResponse<ListResponse<MCPServer>> = try await client.get("/mcp")
            lastHealthCheck = Date()
        } catch {
            AppLogger.shared.warning("MCP health check failed: \(error.localizedDescription)", category: "mcp")
        }
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

    func updateServer(name: String, command: String, args: [String], scope: String) async -> MCPServer? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(name: name, command: command, args: args, scope: MCPScope(rawValue: scope))
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
}
