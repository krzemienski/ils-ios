import Foundation
import ILSShared

@MainActor
class MCPViewModel: ObservableObject {
    @Published var servers: [MCPServerItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""

    private let client = APIClient()

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
    /// - Parameter clearCache: If true, clears APIClient cache before fetching fresh data
    func loadServers(clearCache: Bool = false) async {
        isLoading = true
        error = nil

        do {
            // Use clearCache parameter to bypass cache on refresh
            let response: APIResponse<ListResponse<MCPServerItem>> = try await client.get("/mcp", clearCache: clearCache)
            if let data = response.data {
                servers = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load MCP servers: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refresh servers by clearing cache and fetching fresh data
    func refreshServers() async {
        // Clear cache and reload with fresh data
        await loadServers(clearCache: true)
    }

    func retryLoadServers() async {
        await loadServers()
    }

    func addServer(name: String, command: String, args: [String], scope: String) async -> MCPServerItem? {
        do {
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: args,
                scope: scope
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
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/mcp/\(server.name)?scope=\(server.scope)")
            servers.removeAll { $0.id == server.id }
        } catch {
            self.error = error
            print("❌ Failed to delete MCP server '\(server.name)': \(error.localizedDescription)")
        }
    }
}
