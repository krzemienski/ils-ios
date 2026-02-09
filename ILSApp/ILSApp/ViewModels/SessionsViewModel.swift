import Foundation
import ILSShared

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMore = true
    @Published var searchQuery: String?
    private var currentPage = 1
    private let pageSize = 50

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

    func loadSessions(refresh: Bool = false) async {
        guard let client else { return }
        isLoading = true
        error = nil

        if refresh {
            currentPage = 1
            hasMore = true
        }

        do {
            var path = "/sessions?page=\(currentPage)&limit=\(pageSize)"
            if refresh { path += "&refresh=true" }
            if let searchQuery, !searchQuery.isEmpty {
                let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
                path += "&search=\(encoded)"
            }

            let response: APIResponse<PaginatedResponse<ChatSession>> = try await client.get(path)
            let newItems = response.data?.items ?? []
            hasMore = response.data?.hasMore ?? false

            if currentPage == 1 {
                sessions = newItems
            } else {
                sessions.append(contentsOf: newItems)
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load sessions: \(error.localizedDescription)", category: "sessions")
        }

        isLoading = false
    }

    func retryLoadSessions() async {
        await loadSessions()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        await loadSessions()
    }

    func createSession(projectId: UUID?, name: String?, model: String, permissionMode: PermissionMode? = nil, systemPrompt: String? = nil, maxBudgetUSD: Double? = nil, maxTurns: Int? = nil) async -> ChatSession? {
        guard let client else { return nil }
        do {
            let request = CreateSessionRequest(
                projectId: projectId,
                name: name,
                model: model,
                permissionMode: permissionMode,
                systemPrompt: systemPrompt,
                maxBudgetUSD: maxBudgetUSD,
                maxTurns: maxTurns
            )
            let response: APIResponse<ChatSession> = try await client.post("/sessions", body: request)
            if let session = response.data {
                sessions.insert(session, at: 0)
                return session
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to create session: \(error.localizedDescription)", category: "sessions")
        }
        return nil
    }

    func deleteSession(_ session: ChatSession) async {
        guard let client else { return }

        // External sessions can't be deleted from ILS DB
        if session.source == .external {
            sessions.removeAll { $0.id == session.id }
            return
        }

        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete session: \(error.localizedDescription)", category: "sessions")
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
            AppLogger.shared.error("Failed to fork session: \(error.localizedDescription)", category: "sessions")
        }
        return nil
    }
}
