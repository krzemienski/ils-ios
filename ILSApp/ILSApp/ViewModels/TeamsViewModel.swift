import Foundation
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
    var error: Error?
    var operationState: AsyncOperationState?
    var operationMessage: String?

    private let apiClient: APIClient
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var currentPollInterval: TimeInterval = 15
    @ObservationIgnored private var previousTeamHash: Int = 0
    private static let minPollInterval: TimeInterval = 15
    private static let maxPollInterval: TimeInterval = 120
    private static let backoffMultiplier: Double = 1.5

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        pollingTask?.cancel()
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load teams"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to create team"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to delete team"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load team detail"])
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Teammates

    func spawnTeammate(teamName: String, request: SpawnTeammateRequest) async {
        isLoading = true
        error = nil
        operationState = .connecting
        operationMessage = "Spawning teammate..."
        defer {
            operationState = nil
            operationMessage = nil
        }
        do {
            let response: APIResponse<TeamMember> = try await apiClient.post( "/teams/\(teamName)/spawn", body: request)
            if response.success {
                await loadTeamDetail(name: teamName)
            } else {
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to spawn teammate"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func shutdownTeammate(teamName: String, name: String) async {
        isLoading = true
        error = nil
        operationState = .connecting
        operationMessage = "Shutting down teammate..."
        defer {
            operationState = nil
            operationMessage = nil
        }
        do {
            let request = ShutdownTeammateRequest(memberName: name)
            let response: APIResponse<DeletedResponse> = try await apiClient.post( "/teams/\(teamName)/shutdown", body: request)
            if response.success {
                await loadTeamDetail(name: teamName)
            } else {
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to shutdown teammate"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load tasks"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to create task"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to update task"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load messages"])
            }
        } catch {
            self.error = error
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
                error = NSError(domain: "TeamsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to send message"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    // MARK: - Polling

    func startPolling(teamName: String) {
        stopPolling()
        currentPollInterval = Self.minPollInterval
        previousTeamHash = computeTeamHash()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.currentPollInterval ?? 15) * 1_000_000_000))
                guard !Task.isCancelled else { break }

                await self?.loadTeamDetail(name: teamName)

                // Check if data changed — apply exponential backoff when idle
                let newHash = self?.computeTeamHash() ?? 0
                if newHash == self?.previousTeamHash {
                    // No changes — increase interval with backoff
                    if let self {
                        self.currentPollInterval = min(
                            self.currentPollInterval * Self.backoffMultiplier,
                            Self.maxPollInterval
                        )
                    }
                } else {
                    // Data changed — reset to minimum interval
                    self?.currentPollInterval = Self.minPollInterval
                    self?.previousTeamHash = newHash
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        currentPollInterval = Self.minPollInterval
    }

    /// Compute a hash of the current team state for change detection
    private func computeTeamHash() -> Int {
        var hasher = Hasher()
        hasher.combine(selectedTeam?.name)
        hasher.combine(selectedTeam?.members.count)
        hasher.combine(tasks.count)
        hasher.combine(messages.count)
        return hasher.finalize()
    }
}

// Request types are defined in ILSShared/DTOs/TeamDTOs.swift:
// CreateTeamRequest, SpawnTeammateRequest, ShutdownTeammateRequest,
// CreateTeamTaskRequest, UpdateTeamTaskRequest, SendTeamMessageRequest
