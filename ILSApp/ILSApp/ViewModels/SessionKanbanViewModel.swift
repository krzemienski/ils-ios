import Foundation
import Observation
@preconcurrency import ILSShared

/// View model for the session kanban board.
///
/// Aggregates sessions from all configured backends (via ``BackendManager``) and
/// agent queue items (via ``APIClient``) into a unified kanban board grouped by
/// ``KanbanColumn``. Supports client-side filtering, adaptive polling, and
/// drag-and-drop column transitions.
///
/// ## Topics
/// ### Properties
/// - ``columnItems`` - Items grouped by kanban column
/// - ``isLoading`` - Whether a fetch is in progress
/// - ``searchText`` - Client-side search query
/// - ``selectedProject`` - Optional project name filter
/// - ``dateRange`` - Optional date range filter
///
/// ### Operations
/// - ``loadBoard()`` - Fetch sessions and queue items
/// - ``moveItem(item:toColumn:)`` - Transition an item to a different column
/// - ``startPolling()`` - Begin adaptive background polling
/// - ``stopPolling()`` - Cancel background polling
@Observable
@MainActor
final class SessionKanbanViewModel {

    // MARK: - Published State

    /// All board items before filtering, grouped by column.
    var allItems: [KanbanBoardItem] = []
    /// Whether data is currently being fetched.
    var isLoading = false
    /// Aggregate error from the most recent load.
    var error: Error?
    /// Timestamp of the most recent successful data load.
    var lastUpdated: Date?
    /// Per-backend errors from the most recent session fetch.
    var backendErrors: [UUID: Error] = [:]

    // MARK: - Filtering

    /// Client-side search text for filtering board items.
    var searchText: String = ""
    /// Optional project name filter.
    var selectedProject: String?
    /// Optional date range filter.
    var dateRange: FilterDateRange?

    // MARK: - Dependencies

    @ObservationIgnored private let manager: BackendManager
    @ObservationIgnored private let apiClient: APIClient

    // MARK: - Polling

    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var currentPollInterval: TimeInterval = 15
    private static let activePollInterval: TimeInterval = 15
    private static let idlePollInterval: TimeInterval = 60

    // MARK: - Init

    /// Creates the kanban view model.
    /// - Parameters:
    ///   - manager: The backend manager for multi-backend session fetching.
    ///   - apiClient: The API client for queue item operations.
    init(manager: BackendManager = .shared, apiClient: APIClient) {
        self.manager = manager
        self.apiClient = apiClient
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Computed Properties

    /// Items filtered by search text, project, and date range.
    var filteredItems: [KanbanBoardItem] {
        var result = allItems

        // Search text filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                switch item {
                case .session(let tagged):
                    return tagged.displayName.lowercased().contains(query)
                        || (tagged.session.projectName?.lowercased().contains(query) ?? false)
                        || (tagged.session.firstPrompt?.lowercased().contains(query) ?? false)
                        || tagged.backendName.lowercased().contains(query)
                case .queueItem(let queueItem):
                    return queueItem.title.lowercased().contains(query)
                        || (queueItem.description?.lowercased().contains(query) ?? false)
                }
            }
        }

        // Project filter
        if let project = selectedProject {
            let projectLower = project.lowercased()
            result = result.filter { item in
                switch item {
                case .session(let tagged):
                    return tagged.session.projectName?.lowercased().contains(projectLower) ?? false
                case .queueItem:
                    // Queue items don't have a direct project association in the same way
                    return true
                }
            }
        }

        // Date range filter
        if let dateRange {
            let interval = dateRange.dateInterval()
            result = result.filter { item in
                switch item {
                case .session(let tagged):
                    return interval.contains(tagged.lastActiveAt)
                case .queueItem(let queueItem):
                    return interval.contains(queueItem.createdAt)
                }
            }
        }

        return result
    }

    /// Filtered items grouped by their kanban column.
    var columnItems: [KanbanColumn: [KanbanBoardItem]] {
        Dictionary(grouping: filteredItems) { $0.column }
    }

    /// Items for a specific column, sorted by recency.
    func items(for column: KanbanColumn) -> [KanbanBoardItem] {
        columnItems[column] ?? []
    }

    /// Whether any items are in an active state (active, queued, or waiting).
    var hasActiveItems: Bool {
        allItems.contains { item in
            let col = item.column
            return col == .active || col == .queued || col == .waitingForApproval
        }
    }

    /// Distinct project names from current session items, sorted alphabetically.
    var availableProjects: [String] {
        let projects = allItems.compactMap { item -> String? in
            switch item {
            case .session(let tagged): return tagged.session.projectName
            case .queueItem: return nil
            }
        }
        return Array(Set(projects)).sorted()
    }

    // MARK: - Load

    /// Fetches sessions from all backends and queue items, then merges them into board items.
    func loadBoard() async {
        isLoading = true
        error = nil
        backendErrors = [:]

        async let sessionsResult = fetchSessions()
        async let queueResult = fetchQueueItems()

        let (taggedSessions, queueItems) = await (sessionsResult, queueResult)

        var items: [KanbanBoardItem] = []
        items.append(contentsOf: taggedSessions.map { .session($0) })
        items.append(contentsOf: queueItems.map { .queueItem($0) })

        allItems = items
        lastUpdated = Date()
        isLoading = false
    }

    /// Concurrently fetches sessions from all configured backends.
    private func fetchSessions() async -> [TaggedSession] {
        let allBackends = manager.backends
        guard !allBackends.isEmpty else { return [] }

        let backendSnapshots: [(backend: BackendConnection, client: APIClient)] = allBackends.compactMap { backend in
            guard let client = manager.client(for: backend.id) else { return nil }
            return (backend, client)
        }

        var allTagged: [TaggedSession] = []
        var fetchErrors: [UUID: Error] = [:]

        await withTaskGroup(of: (UUID, [TaggedSession], Error?).self) { group in
            for snapshot in backendSnapshots {
                let backend = snapshot.backend
                let client = snapshot.client
                group.addTask {
                    do {
                        let response: APIResponse<PaginatedResponse<ChatSession>> =
                            try await client.get("/sessions?page=1&limit=50")
                        let items = response.data?.items ?? []
                        let tagged = items.map {
                            TaggedSession(
                                session: $0,
                                backendId: backend.id,
                                backendName: backend.name,
                                backendColorHex: backend.colorHex
                            )
                        }
                        return (backend.id, tagged, nil)
                    } catch {
                        return (backend.id, [], error)
                    }
                }
            }

            for await (backendId, tagged, err) in group {
                if let err {
                    fetchErrors[backendId] = err
                } else {
                    allTagged.append(contentsOf: tagged)
                }
            }
        }

        allTagged.sort { $0.lastActiveAt > $1.lastActiveAt }
        backendErrors = fetchErrors

        // Surface a top-level error only when every backend failed.
        if fetchErrors.count == backendSnapshots.count, let first = fetchErrors.values.first {
            error = first
        }

        return allTagged
    }

    /// Fetches queue items from the primary API client.
    private func fetchQueueItems() async -> [AgentQueueItem] {
        do {
            let response: APIResponse<AgentQueue> = try await apiClient.get("/queue")
            if response.success, let data = response.data {
                return data.items
            }
            return []
        } catch {
            // Queue fetch failure is non-fatal — sessions alone are still useful.
            return []
        }
    }

    // MARK: - Polling

    /// Starts adaptive background polling.
    ///
    /// Poll interval adjusts based on board activity:
    /// - 15 seconds when active/queued items exist
    /// - 60 seconds when all items are idle
    func startPolling() {
        stopPolling()
        currentPollInterval = Self.activePollInterval

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                try? await Task.sleep(nanoseconds: UInt64(self.currentPollInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }

                await self.loadBoard()

                // Adaptive interval based on board activity
                if self.hasActiveItems {
                    self.currentPollInterval = Self.activePollInterval
                } else {
                    self.currentPollInterval = Self.idlePollInterval
                }
            }
        }
    }

    /// Stops background polling.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        currentPollInterval = Self.activePollInterval
    }

    // MARK: - Item Actions

    /// Moves a board item to a different column by invoking the appropriate API action.
    ///
    /// Supported transitions:
    /// - Session → `.failed`: Cancels the session
    /// - Queue item → `.paused`: Pauses the queue item
    /// - Queue item → `.active`: Resumes the queue item
    /// - Queue item → `.failed`: Cancels the queue item
    ///
    /// - Parameters:
    ///   - item: The board item to move.
    ///   - column: The target kanban column.
    func moveItem(item: KanbanBoardItem, toColumn column: KanbanColumn) async {
        error = nil

        switch item {
        case .session(let tagged):
            await moveSession(tagged, toColumn: column)
        case .queueItem(let queueItem):
            await moveQueueItem(queueItem, toColumn: column)
        }

        // Refresh board after state change
        await loadBoard()
    }

    /// Handles column transitions for sessions.
    private func moveSession(_ tagged: TaggedSession, toColumn column: KanbanColumn) async {
        let sessionId = tagged.session.id.uuidString.lowercased()

        guard let client = manager.client(for: tagged.backendId) else {
            error = NSError(
                domain: "SessionKanbanViewModel",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Backend not available for session"]
            )
            return
        }

        switch column {
        case .failed:
            // Cancel the session
            do {
                let _: APIResponse<ChatSession> = try await client.post(
                    "/sessions/\(sessionId)/cancel",
                    body: EmptyBody()
                )
            } catch {
                self.error = error
            }
        default:
            // Other session transitions are not directly supported via API
            error = NSError(
                domain: "SessionKanbanViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot move session to \(column.displayTitle)"]
            )
        }
    }

    /// Handles column transitions for queue items.
    private func moveQueueItem(_ item: AgentQueueItem, toColumn column: KanbanColumn) async {
        switch column {
        case .paused:
            do {
                let _: APIResponse<AgentQueueItem> = try await apiClient.post(
                    "/queue/\(item.id)/pause",
                    body: EmptyBody()
                )
            } catch {
                self.error = error
            }

        case .active:
            do {
                let _: APIResponse<AgentQueueItem> = try await apiClient.post(
                    "/queue/\(item.id)/resume",
                    body: EmptyBody()
                )
            } catch {
                self.error = error
            }

        case .failed:
            do {
                let _: APIResponse<AgentQueueItem> = try await apiClient.post(
                    "/queue/\(item.id)/cancel",
                    body: EmptyBody()
                )
            } catch {
                self.error = error
            }

        default:
            error = NSError(
                domain: "SessionKanbanViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot move queue item to \(column.displayTitle)"]
            )
        }
    }

    // MARK: - Filter Actions

    /// Clears all active filters.
    func clearFilters() {
        searchText = ""
        selectedProject = nil
        dateRange = nil
    }

    /// Whether any filter is currently active.
    var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedProject != nil || dateRange != nil
    }

    // MARK: - Helpers

    /// Empty-state description for UI display.
    var emptyStateText: String {
        if isLoading { return "Loading board..." }
        if manager.backends.isEmpty { return "No backends configured" }
        if !backendErrors.isEmpty && allItems.isEmpty { return "Could not reach any backend" }
        if hasActiveFilters && filteredItems.isEmpty { return "No items match current filters" }
        return allItems.isEmpty ? "No sessions or queue items" : ""
    }
}
