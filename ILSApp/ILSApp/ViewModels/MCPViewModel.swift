import Foundation
import ILSShared

@MainActor
class MCPViewModel: ObservableObject {
    @Published var servers: [MCPServerItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    @Published var selectedScope: String = "user"

    // Spec 012: Health monitoring
    @Published var lastHealthCheck: Date?
    @Published var isHealthChecking = false
    private var healthTimer: Task<Void, Never>?

    // Spec 018: Batch operations
    @Published var isSelecting = false
    @Published var selectedServerIDs: Set<UUID> = []

    var selectedCount: Int { selectedServerIDs.count }

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Filtered servers based on search text (client-side filtering for responsiveness)
    var filteredServers: [MCPServerItem] {
        guard !searchText.isEmpty else { return servers }
        let query = searchText.lowercased()
        return servers.filter { server in
            server.name.lowercased().contains(query) ||
            server.command.lowercased().contains(query) ||
            server.scope.lowercased().contains(query) ||
            server.args.contains { $0.lowercased().contains(query) }
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
            let response: APIResponse<ListResponse<MCPServerItem>> = try await client.get(path)
            if let data = response.data {
                servers = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load MCP servers: \(error.localizedDescription)")
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

    func addServer(name: String, command: String, args: [String], scope: String) async -> MCPServerItem? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: args,
                scope: MCPScope(rawValue: scope)
            )
            let response: APIResponse<MCPServerItem> = try await client.post("/mcp", body: request)
            if let server = response.data {
                servers.append(server)
                return server
            }
        } catch {
            self.error = error
            print("❌ Failed to add MCP server '\(name)': \(error.localizedDescription)")
        }
        return nil
    }

    func deleteServer(_ server: MCPServerItem) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/mcp/\(server.name)?scope=\(server.scope)")
            servers.removeAll { $0.id == server.id }
        } catch {
            self.error = error
            print("❌ Failed to delete MCP server '\(server.name)': \(error.localizedDescription)")
        }
    }

    func loadServers(scope: String) async {
        guard let client else { return }
        isLoading = true
        error = nil
        selectedScope = scope

        do {
            let response: APIResponse<ListResponse<MCPServerItem>> = try await client.get("/mcp?scope=\(scope)")
            if let data = response.data {
                servers = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load MCP servers: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Spec 012: Health Monitoring

    func startHealthPolling(interval: TimeInterval = 30) {
        stopHealthPolling()
        healthTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkHealth()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
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

    func toggleSelection(for server: MCPServerItem) {
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

    func updateServer(name: String, command: String, args: [String], scope: String) async -> MCPServerItem? {
        guard let client else { return nil }
        do {
            let request = CreateMCPRequest(name: name, command: command, args: args, scope: MCPScope(rawValue: scope))
            let response: APIResponse<MCPServerItem> = try await client.put("/mcp/\(name)", body: request)
            if let server = response.data {
                if let index = servers.firstIndex(where: { $0.name == name }) {
                    servers[index] = server
                }
                return server
            }
        } catch {
            self.error = error
            print("❌ Failed to update MCP server '\(name)': \(error.localizedDescription)")
        }
        return nil
    }
}
