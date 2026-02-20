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
    var isLoading = false
    var error: String?

    private let apiClient: APIClient
    @ObservationIgnored private var pollingTimer: Timer?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        pollingTimer?.invalidate()
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

    // MARK: - Polling

    func startPolling(teamName: String) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadTeamDetail(name: teamName)
            }
        }
        pollingTimer?.tolerance = 1.0
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

// Request types are defined in ILSShared/DTOs/TeamDTOs.swift:
// CreateTeamRequest, SpawnTeammateRequest, ShutdownTeammateRequest,
// CreateTeamTaskRequest, UpdateTeamTaskRequest, SendTeamMessageRequest
