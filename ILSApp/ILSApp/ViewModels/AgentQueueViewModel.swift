import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class AgentQueueViewModel {
    var items: [AgentQueueItem] = []
    var templates: [QueueItemTemplate] = []
    var queueState: AgentQueue?
    var isLoading = false
    var error: Error?

    private let apiClient: APIClient
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var currentPollInterval: TimeInterval = 15
    private static let activePollInterval: TimeInterval = 15
    private static let idlePollInterval: TimeInterval = 60

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Queue

    func loadQueue() async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<AgentQueue> = try await apiClient.get("/queue")
            if response.success, let data = response.data {
                queueState = data
                items = data.items
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load queue"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func createItem(
        title: String,
        description: String?,
        projectId: String?,
        priority: Int?,
        dependsOn: [String]? = nil
    ) async {
        isLoading = true
        error = nil
        do {
            let request = CreateQueueItemRequest(
                title: title,
                description: description,
                projectId: projectId,
                priority: priority,
                dependsOn: dependsOn
            )
            let response: APIResponse<AgentQueueItem> = try await apiClient.post("/queue", body: request)
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to create queue item"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func updateItem(
        id: String,
        title: String?,
        description: String?,
        priority: Int?,
        dependsOn: [String]? = nil
    ) async {
        isLoading = true
        error = nil
        do {
            let request = UpdateQueueItemRequest(
                title: title,
                description: description,
                priority: priority,
                dependsOn: dependsOn
            )
            let response: APIResponse<AgentQueueItem> = try await apiClient.put("/queue/\(id)", body: request)
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to update queue item"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func deleteItem(id: String) async {
        isLoading = true
        error = nil
        do {
            let response: APIResponse<DeletedResponse> = try await apiClient.delete("/queue/\(id)")
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to delete queue item"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func pauseItem(id: String) async {
        error = nil
        do {
            let response: APIResponse<AgentQueueItem> = try await apiClient.post("/queue/\(id)/pause", body: EmptyBody())
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to pause queue item"])
            }
        } catch {
            self.error = error
        }
    }

    func resumeItem(id: String) async {
        error = nil
        do {
            let response: APIResponse<AgentQueueItem> = try await apiClient.post("/queue/\(id)/resume", body: EmptyBody())
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to resume queue item"])
            }
        } catch {
            self.error = error
        }
    }

    func cancelItem(id: String) async {
        error = nil
        do {
            let response: APIResponse<AgentQueueItem> = try await apiClient.post("/queue/\(id)/cancel", body: EmptyBody())
            if response.success {
                await loadQueue()
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to cancel queue item"])
            }
        } catch {
            self.error = error
        }
    }

    func reorderItems(orderedIds: [String]) async {
        error = nil
        do {
            let request = ReorderQueueRequest(orderedIds: orderedIds)
            let response: APIResponse<AgentQueue> = try await apiClient.post("/queue/reorder", body: request)
            if response.success, let data = response.data {
                queueState = data
                items = data.items
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to reorder queue"])
            }
        } catch {
            self.error = error
        }
    }

    func loadTemplates() async {
        error = nil
        do {
            let response: APIResponse<[QueueItemTemplate]> = try await apiClient.get("/queue/templates")
            if response.success, let data = response.data {
                templates = data
            } else {
                error = NSError(domain: "AgentQueueViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load templates"])
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()
        currentPollInterval = Self.activePollInterval

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.currentPollInterval ?? 15) * 1_000_000_000))
                guard !Task.isCancelled else { break }

                await self?.loadQueue()

                // Adaptive interval: active when items are running or queued, idle otherwise
                let hasActiveItems = self?.items.contains(where: { $0.status == .running || $0.status == .queued }) ?? false
                if hasActiveItems {
                    self?.currentPollInterval = Self.activePollInterval
                } else {
                    self?.currentPollInterval = Self.idlePollInterval
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        currentPollInterval = Self.activePollInterval
    }

    // MARK: - Computed Properties

    /// Items filtered to show only active work (queued or running).
    var activeItems: [AgentQueueItem] {
        items.filter { $0.status == .queued || $0.status == .running }
    }

    /// Items that have finished (completed, failed, or cancelled).
    var finishedItems: [AgentQueueItem] {
        items.filter { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }
}

// QueueItemTemplate is defined in AgentQueueController.swift (backend) but needs to be
// available on iOS. Declared here as it is not in ILSShared.
struct QueueItemTemplate: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let prompt: String
    let tags: [String]
}
