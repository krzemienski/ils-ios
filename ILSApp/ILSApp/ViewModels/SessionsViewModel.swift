import Foundation
import ILSShared

@MainActor
class SessionsViewModel: BaseViewModel<ChatSession> {
    /// Convenience accessor for sessions
    var sessions: [ChatSession] {
        items
    }

    override var resourcePath: String {
        "/sessions"
    }

    override var loadingStateText: String {
        "Loading sessions..."
    }

    override var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        return items.isEmpty ? "No sessions" : ""
    }

    func loadSessions() async {
        await loadItems()
    }

    func retryLoadSessions() async {
        await retryLoad()
    }

    func createSession(projectId: UUID?, name: String?, model: String) async -> ChatSession? {
        let request = CreateSessionRequest(
            projectId: projectId,
            name: name,
            model: model
        )
        return await self.createItem(body: request)
    }

    func deleteSession(_ session: ChatSession) async {
        await self.deleteItem(id: session.id)
    }

    func forkSession(_ session: ChatSession) async -> ChatSession? {
        do {
            let response: APIResponse<ChatSession> = try await client.post("/sessions/\(session.id)/fork", body: EmptyBody())
            if let forked = response.data {
                items.insert(forked, at: 0)
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

struct EmptyBody: Encodable {}
