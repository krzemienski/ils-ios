import Foundation
import ILSShared
import CloudKit

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?
    private var cloudKitService: CloudKitService?

    init() {}

    func configure(client: APIClient, cloudKitService: CloudKitService? = nil) {
        self.client = client
        self.cloudKitService = cloudKitService
    }

    /// Check if iCloud sync is enabled
    private var isSyncEnabled: Bool {
        // Default to true if key doesn't exist (first launch)
        if UserDefaults.standard.object(forKey: "ils_icloud_sync_enabled_v2") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "ils_icloud_sync_enabled_v2")
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading sessions..."
        }
        return sessions.isEmpty ? "No sessions" : ""
    }

    func loadSessions() async {
        isLoading = true
        error = nil

        do {
            // Load from CloudKit if sync is enabled, otherwise use API
            if isSyncEnabled, let cloudKitService {
                // Load from CloudKit
                let cloudSessions = try await cloudKitService.fetchSessions()
                sessions = cloudSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
            } else if let client {
                // Fallback to API
                let response: APIResponse<ListResponse<ChatSession>> = try await client.get("/sessions")
                if let data = response.data {
                    sessions = data.items
                }
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

                // Sync to CloudKit if enabled
                if isSyncEnabled, let cloudKitService {
                    Task {
                        do {
                            _ = try await cloudKitService.saveSession(session)
                        } catch {
                            print("❌ Failed to sync session to CloudKit: \(error.localizedDescription)")
                        }
                    }
                }

                return session
            }
        } catch {
            self.error = error
            print("❌ Failed to create session: \(error.localizedDescription)")
        }
        return nil
    }

    func deleteSession(_ session: ChatSession) async {
        do {
            // Delete from CloudKit if sync is enabled
            if isSyncEnabled, let cloudKitService {
                try await cloudKitService.deleteSession(session.id)
            } else if let client {
                // Fallback to API
                let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            }

            // Remove from local list
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

                // Sync to CloudKit if enabled
                if isSyncEnabled, let cloudKitService {
                    Task {
                        do {
                            _ = try await cloudKitService.saveSession(forked)
                        } catch {
                            print("❌ Failed to sync forked session to CloudKit: \(error.localizedDescription)")
                        }
                    }
                }

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
