import Foundation
import ILSShared

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading sessions..."
        }
        return sessions.isEmpty ? "No sessions" : ""
    }

    func loadSessions() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<ChatSession>> = try await client.get("/sessions")
            if let data = response.data {
                sessions = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load sessions: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadSessions() async {
        await loadSessions()
    }

    func createSession(projectId: UUID?, name: String?, model: String) async -> ChatSession? {
        guard let client else { return nil }
        do {
            let request = CreateSessionRequest(
                projectId: projectId,
                name: name,
                model: model
            )
            let response: APIResponse<ChatSession> = try await client.post("/sessions", body: request)
            if let session = response.data {
                sessions.insert(session, at: 0)
                return session
            }
        } catch {
            self.error = error
            print("❌ Failed to create session: \(error.localizedDescription)")
        }
        return nil
    }

    func deleteSession(_ session: ChatSession) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error
            print("❌ Failed to delete session: \(error.localizedDescription)")
        }
    }

    func forkSession(_ session: ChatSession) async -> ChatSession? {
        guard let client else { return nil }
        do {
            let response: APIResponse<ChatSession> = try await client.post("/sessions/\(session.id)/fork", body: EmptyBody())
            if let forked = response.data {
                sessions.insert(forked, at: 0)
                return forked
            }
        } catch {
            self.error = error
            print("❌ Failed to fork session: \(error.localizedDescription)")
        }
        return nil
    }
}

// MARK: - Request Types

struct CreateSessionRequest: Encodable {
    let projectId: UUID?
    let name: String?
    let model: String
}

struct DeletedResponse: Decodable {
    let deleted: Bool
}

struct EmptyBody: Encodable {}
