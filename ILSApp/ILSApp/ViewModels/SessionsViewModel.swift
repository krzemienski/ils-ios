import Foundation
import ILSShared

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    func loadSessions() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<ChatSession>> = try await client.get("/sessions")
            if let data = response.data {
                sessions = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createSession(projectId: UUID?, name: String?, model: String) async -> ChatSession? {
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
        }
        return nil
    }

    func deleteSession(_ session: ChatSession) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error
        }
    }

    func forkSession(_ session: ChatSession) async -> ChatSession? {
        do {
            let response: APIResponse<ChatSession> = try await client.post("/sessions/\(session.id)/fork", body: EmptyBody())
            if let forked = response.data {
                sessions.insert(forked, at: 0)
                return forked
            }
        } catch {
            self.error = error
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
