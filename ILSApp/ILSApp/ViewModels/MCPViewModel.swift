import Foundation
import ILSShared

@MainActor
class MCPViewModel: ObservableObject {
    @Published var servers: [MCPServerItem] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    func loadServers() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<MCPServerItem>> = try await client.get("/mcp")
            if let data = response.data {
                servers = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
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
