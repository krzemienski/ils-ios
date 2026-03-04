import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class NewSessionViewModel {
    var isCreating = false
    var recentSessions: [ChatSession] = []
    var isLoadingSessions = false

    /// Whether a smart routing suggestion request is in flight.
    var isLoadingRoutingSuggestion = false
    /// Reasoning text from the last routing suggestion, shown inline under the model picker.
    var routingReasoning: String?

    private var apiClient: APIClient?

    func configure(client: APIClient) {
        self.apiClient = client
    }

    /// Request a smart model suggestion from the backend routing service.
    ///
    /// - Parameters:
    ///   - prompt: Task description or session name used for complexity analysis.
    ///   - maxBudget: Optional budget ceiling in USD.
    /// - Returns: The routing response on success, or `nil` on failure.
    func suggestModel(prompt: String, maxBudget: Double?) async -> ModelRoutingResponse? {
        guard let apiClient else { return nil }
        isLoadingRoutingSuggestion = true
        defer { isLoadingRoutingSuggestion = false }

        let request = ModelRoutingRequest(
            prompt: prompt.isEmpty ? "general task" : prompt,
            maxBudgetUSD: maxBudget
        )

        do {
            let response: APIResponse<ModelRoutingResponse> = try await apiClient.post(
                "/sessions/suggest-model",
                body: request
            )
            if let result = response.data {
                routingReasoning = result.reasoning
                return result
            }
        } catch {
            AppLogger.shared.error("Failed to fetch model routing suggestion: \(error)", category: "ui")
        }
        return nil
    }

    /// Loads recent sessions for the fork picker.
    func loadRecentSessions() async {
        guard let apiClient else { return }
        isLoadingSessions = true
        do {
            let response: APIResponse<ListResponse<ChatSession>> = try await apiClient.get("/sessions?limit=30")
            if let data = response.data {
                recentSessions = data.items
            }
        } catch {
            AppLogger.shared.error("Failed to load recent sessions: \(error)", category: "ui")
        }
        isLoadingSessions = false
    }

    /// Create a new session, optionally associated with a project.
    /// Returns the created session on success, nil on failure.
    func createSession(
        projectId: UUID?,
        name: String?,
        model: String,
        permissionMode: String,
        systemPrompt: String?,
        maxBudget: String,
        maxTurns: String
    ) async -> ChatSession? {
        guard let apiClient else { return nil }
        isCreating = true
        defer { isCreating = false }

        let request = CreateSessionRequest(
            projectId: projectId,
            name: name,
            model: model,
            permissionMode: PermissionMode(rawValue: permissionMode),
            systemPrompt: systemPrompt,
            maxBudgetUSD: Double(maxBudget),
            maxTurns: Int(maxTurns)
        )

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions", body: request)
            if let session = response.data {
                HapticManager.notification(.success)
                return session
            }
        } catch {
            HapticManager.notification(.error)
            AppLogger.shared.error("Failed to create session: \(error)", category: "ui")
        }
        return nil
    }

    /// Fork an existing session.
    /// Returns the forked session on success, nil on failure.
    func forkSession(sourceSessionId: UUID) async -> ChatSession? {
        guard let apiClient else { return nil }
        isCreating = true
        defer { isCreating = false }

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post(
                "/sessions/\(sourceSessionId)/fork",
                body: EmptyBody()
            )
            if let forkedSession = response.data {
                HapticManager.notification(.success)
                return forkedSession
            }
        } catch {
            HapticManager.notification(.error)
            AppLogger.shared.error("Failed to fork session: \(error)", category: "ui")
        }
        return nil
    }

    /// Create a new project and then create a session within it.
    /// Returns the created session on success, nil on failure.
    func createProjectAndSession(
        projectName: String,
        projectPath: String,
        sessionName: String?,
        model: String,
        permissionMode: String,
        systemPrompt: String?,
        maxBudget: String,
        maxTurns: String,
        projectsViewModel: ProjectsViewModel
    ) async -> ChatSession? {
        guard let apiClient else { return nil }
        isCreating = true
        defer { isCreating = false }

        guard let project = await projectsViewModel.createProject(
            name: projectName,
            path: projectPath,
            defaultModel: model,
            description: nil
        ) else {
            HapticManager.notification(.error)
            AppLogger.shared.error("Failed to create project '\(projectName)'", category: "ui")
            return nil
        }

        let request = CreateSessionRequest(
            projectId: project.id,
            name: sessionName,
            model: model,
            permissionMode: PermissionMode(rawValue: permissionMode),
            systemPrompt: systemPrompt,
            maxBudgetUSD: Double(maxBudget),
            maxTurns: Int(maxTurns)
        )

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions", body: request)
            if let session = response.data {
                HapticManager.notification(.success)
                return session
            }
        } catch {
            HapticManager.notification(.error)
            AppLogger.shared.error("Failed to create session for new project: \(error)", category: "ui")
        }
        return nil
    }
}
