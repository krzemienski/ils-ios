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

    /// Load servers from backend
    /// - Parameter refresh: If true, bypasses server cache to rescan configuration files
    func loadServers(refresh: Bool = false) async {
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
        }

        isLoading = false
    }

    /// Refresh servers by rescanning configuration files
    func refreshServers() async {
        await loadServers(refresh: true)
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
        }
        return nil
    }

    func deleteServer(_ server: MCPServerItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/mcp/\(server.name)?scope=\(server.scope)")
            servers.removeAll { $0.id == server.id }
        } catch {
            self.error = error
        }
    }
}
