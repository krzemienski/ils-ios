import SwiftUI
import Observation
import ILSShared

@MainActor
@Observable
class TeamsViewModel {
    var teams: [AgentTeam] = []
    var selectedTeam: AgentTeam?
    var tasks: [TeamTask] = []
    var messages: [TeamMessage] = []
    var templates: [TeamTemplate] = []
    var metrics: TeamMetricsResponse?
    var isLoading = false
    var error: String?
    var scenePhase: ScenePhase = .active {
        didSet {
            handleScenePhaseChange()
        }
    }

    private let apiClient: APIClient
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var activeTeamName: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        pollingTask?.cancel()
    }

    private func handleScenePhaseChange() {
        switch scenePhase {
        case .active:
            if let teamName = activeTeamName {
                startPolling(teamName: teamName)
            }
        case .inactive, .background:
            pollingTask?.cancel()
            pollingTask = nil
        @unknown default:
            break
        }
    }

    // MARK: - Teams

    func loadTeams() async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<[AgentTeam]> = try await apiClient.get( "/teams")
            if response.success, let data = response.data {
                teams = data
            } else {
                error = response.error?.message ?? "Failed to load teams"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createTeam(name: String, description: String?) async {
        isLoading = true
        error = nil
        do {
            let request = CreateTeamRequest(name: name, description: description)
            let response: APIResponse<AgentTeam> = try await apiClient.post( "/teams", body: request)
            if response.success {
                await loadTeams()
            } else {
                error = response.error?.message ?? "Failed to create team"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteTeam(name: String) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<DeletedResponse> = try await apiClient.delete( "/teams/\(name)")
            if response.success {
                await loadTeams()
            } else {
                error = response.error?.message ?? "Failed to delete team"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadTeamDetail(name: String) async {
        error = nil
        do {
            let response: APIResponse<AgentTeam> = try await apiClient.get( "/teams/\(name)")
            if response.success, let data = response.data {
                selectedTeam = data
            } else {
                error = response.error?.message ?? "Failed to load team detail"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Teammates

    func spawnTeammate(teamName: String, request: SpawnTeammateRequest) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<TeamMember> = try await apiClient.post( "/teams/\(teamName)/spawn", body: request)
            if response.success {
                await loadTeamDetail(name: teamName)
            } else {
                error = response.error?.message ?? "Failed to spawn teammate"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func shutdownTeammate(teamName: String, name: String) async {
        isLoading = true
        error = nil
        do {
            let request = ShutdownTeammateRequest(memberName: name)
            let response: APIResponse<DeletedResponse> = try await apiClient.post( "/teams/\(teamName)/shutdown", body: request)
            if response.success {
                await loadTeamDetail(name: teamName)
            } else {
                error = response.error?.message ?? "Failed to shutdown teammate"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Tasks

    func loadTasks(teamName: String) async {
        error = nil
        do {
            let response: APIResponse<[TeamTask]> = try await apiClient.get( "/teams/\(teamName)/tasks")
            if response.success, let data = response.data {
                tasks = data
            } else {
                error = response.error?.message ?? "Failed to load tasks"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTask(teamName: String, subject: String, description: String?) async {
        isLoading = true
        error = nil
        do {
            let request = CreateTeamTaskRequest(subject: subject, description: description)
            let response: APIResponse<TeamTask> = try await apiClient.post( "/teams/\(teamName)/tasks", body: request)
            if response.success {
                await loadTasks(teamName: teamName)
            } else {
                error = response.error?.message ?? "Failed to create task"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func updateTask(teamName: String, id: String, status: TeamTaskStatus?, owner: String?) async {
        isLoading = true
        error = nil
        do {
            let request = UpdateTeamTaskRequest(status: status, owner: owner)
            let response: APIResponse<TeamTask> = try await apiClient.put( "/teams/\(teamName)/tasks/\(id)", body: request)
            if response.success {
                await loadTasks(teamName: teamName)
            } else {
                error = response.error?.message ?? "Failed to update task"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Messages

    func loadMessages(teamName: String) async {
        error = nil
        do {
            let response: APIResponse<[TeamMessage]> = try await apiClient.get( "/teams/\(teamName)/messages")
            if response.success, let data = response.data {
                messages = data
            } else {
                error = response.error?.message ?? "Failed to load messages"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage(teamName: String, content: String, to: String?, from: String?) async {
        isLoading = true
        error = nil
        do {
            let request = SendTeamMessageRequest(to: to, content: content, from: from)
            let response: APIResponse<TeamMessage> = try await apiClient.post( "/teams/\(teamName)/messages", body: request)
            if response.success {
                await loadMessages(teamName: teamName)
            } else {
                error = response.error?.message ?? "Failed to send message"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Templates

    func loadTemplates() async {
        error = nil
        do {
            let response: APIResponse<[TeamTemplate]> = try await apiClient.get("/teams/templates")
            if response.success, let data = response.data {
                templates = data
            } else {
                error = response.error?.message ?? "Failed to load templates"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func getTemplate(id: String) async -> TeamTemplate? {
        error = nil
        do {
            let response: APIResponse<TeamTemplate> = try await apiClient.get("/teams/templates/\(id)")
            if response.success, let data = response.data {
                return data
            } else {
                error = response.error?.message ?? "Failed to get template"
                return nil
            }
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func createTemplate(request: CreateTemplateRequest) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<TeamTemplate> = try await apiClient.post("/teams/templates", body: request)
            if response.success {
                await loadTemplates()
            } else {
                error = response.error?.message ?? "Failed to create template"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func updateTemplate(id: String, request: UpdateTemplateRequest) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<TeamTemplate> = try await apiClient.put("/teams/templates/\(id)", body: request)
            if response.success {
                await loadTemplates()
            } else {
                error = response.error?.message ?? "Failed to update template"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteTemplate(id: String) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<DeletedResponse> = try await apiClient.delete("/teams/templates/\(id)")
            if response.success {
                await loadTemplates()
            } else {
                error = response.error?.message ?? "Failed to delete template"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyTemplate(id: String, teamName: String, teamDescription: String?) async {
        isLoading = true
        error = nil
        do {
            let request = ApplyTemplateRequest(teamName: teamName, teamDescription: teamDescription)
            let response: APIResponse<AgentTeam> = try await apiClient.post("/teams/templates/\(id)/apply", body: request)
            if response.success {
                await loadTeams()
            } else {
                error = response.error?.message ?? "Failed to apply template"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Metrics

    func loadMetrics(teamName: String) async {
        error = nil
        do {
            let response: APIResponse<TeamMetricsResponse> = try await apiClient.get( "/teams/\(teamName)/metrics")
            if response.success, let data = response.data {
                metrics = data
            } else {
                error = response.error?.message ?? "Failed to load metrics"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Polling

    func startPolling(teamName: String) {
        stopPolling()
        activeTeamName = teamName
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.loadTeamDetail(name: teamName)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        activeTeamName = nil
    }
}

// Request types are defined in ILSShared/DTOs/TeamDTOs.swift:
// CreateTeamRequest, SpawnTeammateRequest, ShutdownTeammateRequest,
// CreateTeamTaskRequest, UpdateTeamTaskRequest, SendTeamMessageRequest
