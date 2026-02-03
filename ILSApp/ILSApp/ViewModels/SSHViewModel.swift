import Foundation
import ILSShared

@MainActor
class SSHViewModel: ObservableObject {
    @Published var servers: [SSHServer] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading SSH servers..."
        }
        return servers.isEmpty ? "No SSH servers yet" : ""
    }

    func loadServers() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<SSHServer>> = try await client.get("/ssh")
            if let data = response.data {
                servers = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func retryLoadServers() async {
        await loadServers()
    }

    func createServer(name: String, host: String, port: Int, username: String, authType: SSHAuthType, description: String?) async -> SSHServer? {
        do {
            let request = CreateSSHServerRequest(
                name: name,
                host: host,
                port: port,
                username: username,
                authType: authType,
                description: description
            )
            let response: APIResponse<SSHServer> = try await client.post("/ssh", body: request)
            if let server = response.data {
                servers.append(server)
                return server
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func updateServer(_ server: SSHServer, name: String?, host: String?, port: Int?, username: String?, authType: SSHAuthType?, description: String?) async -> SSHServer? {
        do {
            let request = UpdateSSHServerRequest(
                name: name,
                host: host,
                port: port,
                username: username,
                authType: authType,
                description: description
            )
            let response: APIResponse<SSHServer> = try await client.put("/ssh/\(server.id)", body: request)
            if let updated = response.data {
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func deleteServer(_ server: SSHServer) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/ssh/\(server.id)")
            servers.removeAll { $0.id == server.id }
        } catch {
            self.error = error
        }
    }

    /// Load remote sessions from the SSH server
    func loadRemoteSessions(serverId: UUID, credential: String) async -> [ChatSession]? {
        do {
            let response: APIResponse<ListResponse<ChatSession>> = try await client.get(
                "/ssh/\(serverId)/sessions",
                headers: ["X-SSH-Credential": credential]
            )
            return response.data?.items
        } catch {
            self.error = error
            return nil
        }
    }

    /// Load remote Claude Code config from the SSH server
    func loadRemoteConfig(serverId: UUID, credential: String, scope: String = "user") async -> ClaudeConfig? {
        do {
            let response: APIResponse<ClaudeConfig> = try await client.get(
                "/ssh/\(serverId)/config",
                query: ["scope": scope],
                headers: ["X-SSH-Credential": credential]
            )
            return response.data
        } catch {
            self.error = error
            return nil
        }
    }
}
