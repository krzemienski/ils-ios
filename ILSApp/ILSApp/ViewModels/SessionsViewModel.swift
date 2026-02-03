import Foundation
import ILSShared

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

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
            let response: APIResponse<ListResponse<ChatSession>> = try await client.get("/sessions")
            if let data = response.data {
                sessions = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load sessions: \(error.localizedDescription)")

            // Track error analytics
            let deviceId = await AnalyticsService.shared.getDeviceId()
            let errorEvent = AnalyticsEvent.errorOccurred(
                error: error.localizedDescription,
                context: "load_sessions",
                deviceId: deviceId
            )
            await AnalyticsService.shared.track(errorEvent)
        }

        isLoading = false
    }

    func retryLoadSessions() async {
        await loadSessions()
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

                // Track chat started analytics
                let deviceId = await AnalyticsService.shared.getDeviceId()
                let event = AnalyticsEvent.chatStarted(
                    sessionId: session.id,
                    projectId: projectId,
                    deviceId: deviceId
                )
                await AnalyticsService.shared.track(event)

                return session
            }
        } catch {
            self.error = error
            print("❌ Failed to create session: \(error.localizedDescription)")

            // Track error analytics
            let deviceId = await AnalyticsService.shared.getDeviceId()
            let errorEvent = AnalyticsEvent.errorOccurred(
                error: error.localizedDescription,
                context: "create_session",
                deviceId: deviceId
            )
            await AnalyticsService.shared.track(errorEvent)
        }
        return nil
    }

    func deleteSession(_ session: ChatSession) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error
            print("❌ Failed to delete session: \(error.localizedDescription)")

            // Track error analytics
            let deviceId = await AnalyticsService.shared.getDeviceId()
            let errorEvent = AnalyticsEvent.errorOccurred(
                error: error.localizedDescription,
                context: "delete_session",
                deviceId: deviceId
            )
            await AnalyticsService.shared.track(errorEvent)
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
            print("❌ Failed to fork session: \(error.localizedDescription)")

            // Track error analytics
            let deviceId = await AnalyticsService.shared.getDeviceId()
            let errorEvent = AnalyticsEvent.errorOccurred(
                error: error.localizedDescription,
                context: "fork_session",
                deviceId: deviceId
            )
            await AnalyticsService.shared.track(errorEvent)
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
