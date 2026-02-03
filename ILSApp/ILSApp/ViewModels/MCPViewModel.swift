import Foundation
import ILSShared

@MainActor
class MCPViewModel: BaseViewModel<MCPServerItem> {
    @Published var searchText = ""

    /// Convenience accessor for servers
    var servers: [MCPServerItem] {
        items
    }

    override var resourcePath: String {
        "/mcp"
    }

    override var loadingStateText: String {
        "Loading MCP servers..."
    }

    override var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        if !searchText.isEmpty && filteredServers.isEmpty {
            return "No MCP servers found"
        }
        return items.isEmpty ? "No MCP servers configured" : ""
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

    /// Load servers from backend
    /// - Parameter refresh: If true, bypasses server cache to rescan configuration files
    func loadServers(refresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            let path = refresh ? "/mcp?refresh=true" : "/mcp"
            let response: APIResponse<ListResponse<MCPServerItem>> = try await client.get(path)
            if let data = response.data {
                items = data.items
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
        let request = CreateMCPRequest(
            name: name,
            command: command,
            args: args,
            scope: scope
        )
        return await self.createItem(body: request)
    }

    func deleteServer(_ server: MCPServerItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/mcp/\(server.name)?scope=\(server.scope)")
            items.removeAll { $0.id == server.id }
        } catch {
            self.error = error
            print("❌ Failed to delete MCP server '\(server.name)': \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Types

struct CreateMCPRequest: Encodable {
    let name: String
    let command: String
    let args: [String]
    let scope: String
}
