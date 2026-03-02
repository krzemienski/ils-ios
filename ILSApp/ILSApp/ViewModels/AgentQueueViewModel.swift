import Foundation
import Observation
import UserNotifications
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
    @ObservationIgnored private var knownItemStatuses: [String: AgentQueueStatus] = [:]
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
        executionMode: QueueExecutionMode? = nil,
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
                dependsOn: dependsOn,
                executionMode: executionMode
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

                guard let self else { break }
                let previousStatuses = self.knownItemStatuses
                await self.loadQueue()

                // Detect status transitions to completed or failed
                for item in self.items {
                    let previous = previousStatuses[item.id]
                    guard previous != nil, previous != item.status else { continue }
                    if item.status == .completed || item.status == .failed {
                        await self.postQueueTaskNotification(
                            taskId: item.id,
                            taskTitle: item.title,
                            status: item.status
                        )
                    }
                }
                // Record current statuses for next poll comparison
                self.knownItemStatuses = Dictionary(uniqueKeysWithValues: self.items.map { ($0.id, $0.status) })

                // Adaptive interval: active when items are running or queued, idle otherwise
                let hasActiveItems = self.items.contains(where: { $0.status == .running || $0.status == .queued })
                if hasActiveItems {
                    self.currentPollInterval = Self.activePollInterval
                } else {
                    self.currentPollInterval = Self.idlePollInterval
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        currentPollInterval = Self.activePollInterval
        knownItemStatuses = [:]
    }

    // MARK: - Notifications

    /// Post a local notification when a queued task transitions to `.completed` or `.failed`.
    ///
    /// Respects the `notif_queueTaskComplete` / `notif_queueTaskFailed` AppStorage flags
    /// and the quiet-hours window (`notif_quietHoursEnabled`, `notif_quietStartHour`,
    /// `notif_quietEndHour`).
    func postQueueTaskNotification(
        taskId: String,
        taskTitle: String,
        status: AgentQueueStatus
    ) async {
        // Check per-status notification preference
        let prefKey = status == .completed ? "notif_queueTaskComplete" : "notif_queueTaskFailed"
        guard UserDefaults.standard.object(forKey: prefKey) as? Bool ?? true else { return }

        // Check quiet hours
        let quietEnabled = UserDefaults.standard.object(forKey: "notif_quietHoursEnabled") as? Bool ?? false
        if quietEnabled {
            let quietStart = UserDefaults.standard.object(forKey: "notif_quietStartHour") as? Int ?? 22
            let quietEnd = UserDefaults.standard.object(forKey: "notif_quietEndHour") as? Int ?? 7
            let currentHour = Calendar.current.component(.hour, from: Date())
            let inQuietWindow: Bool
            if quietStart < quietEnd {
                // Window within a single day (e.g., 01:00–06:00)
                inQuietWindow = currentHour >= quietStart && currentHour < quietEnd
            } else {
                // Window spans midnight (e.g., 22:00–07:00)
                inQuietWindow = currentHour >= quietStart || currentHour < quietEnd
            }
            guard !inQuietWindow else { return }
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = status == .completed ? "Task Completed" : "Task Failed"
        content.body = taskTitle
        content.sound = .default
        content.userInfo = [
            "taskId": taskId,
            "type": "queue_task_\(status.rawValue)"
        ]

        let identifier = "queue-task-\(taskId)-\(status.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await center.add(request)
        } catch {
            AppLogger.shared.error("Failed to post queue task notification: \(error)", category: "notifications")
        }
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
