import Foundation
import ILSShared

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMore = true
    private var currentOffset = 0
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
            currentOffset = 0
            hasMore = true
        }

        do {
            // Load ILS database sessions
            let path = "/sessions?limit=\(pageSize)&offset=\(currentOffset)" + (refresh ? "&refresh=true" : "")
            let response: APIResponse<ListResponse<ChatSession>> = try await client.get(path)
            var allSessions = response.data?.items ?? []
            hasMore = allSessions.count == pageSize

            // Also load external Claude Code sessions
            do {
                let scanResponse: APIResponse<SessionScanResponse> = try await client.get("/sessions/scan")
                if let externalSessions = scanResponse.data?.items {
                    let converted = externalSessions.compactMap { ext -> ChatSession? in
                        // Skip if already in ILS sessions (by claudeSessionId)
                        let isDuplicate = allSessions.contains { $0.claudeSessionId == ext.claudeSessionId }
                        guard !isDuplicate else { return nil }

                        return ChatSession(
                            id: UUID(),
                            claudeSessionId: ext.claudeSessionId,
                            name: ext.name ?? ext.summary,
                            projectName: ext.projectName,
                            model: "sonnet",
                            permissionMode: .default,
                            status: .completed,
                            messageCount: ext.messageCount ?? 0,
                            source: .external,
                            createdAt: ext.createdAt ?? ext.lastActiveAt ?? Date(),
                            lastActiveAt: ext.lastActiveAt ?? Date(),
                            encodedProjectPath: ext.encodedProjectPath,
                            firstPrompt: ext.firstPrompt
                        )
                    }
                    allSessions.append(contentsOf: converted)
                }
            } catch {
                // External session scan is best-effort — don't fail the whole load
                AppLogger.shared.warning("External session scan failed: \(error.localizedDescription)")
            }

            // Sort by last active date, most recent first
            allSessions.sort { $0.lastActiveAt > $1.lastActiveAt }

            if currentOffset == 0 {
                sessions = allSessions
            } else {
                sessions.append(contentsOf: allSessions)
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load sessions: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadSessions() async {
        await loadSessions()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentOffset += pageSize
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
            AppLogger.shared.error("Failed to create session: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to delete session: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to fork session: \(error.localizedDescription)")
        }
        return nil
    }
}
