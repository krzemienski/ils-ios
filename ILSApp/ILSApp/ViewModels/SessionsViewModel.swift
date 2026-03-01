import Foundation
import Observation
import ILSShared

/// View model for session list and management.
///
/// Manages both ILS-managed sessions (from database) and external Claude Code sessions
/// (discovered from `~/.claude/projects/`). Supports pagination, search, and project grouping.
///
/// SA-MED-1: This ViewModel has 19+ properties — accepted as cohesive domain scope.
/// All properties serve tightly coupled session concerns: pagination (offset, total, hasMore),
/// search (searchText, filteredSessions), grouping (groupedSessions, projectGroups),
/// caching (cacheService), and CRUD operations. Splitting would fragment cache invalidation
/// logic and create cross-ViewModel coordination complexity without meaningful benefit.
///
/// ## Topics
/// ### Properties
/// - ``sessions`` - Array of all loaded sessions
/// - ``projectGroups`` - Project groups for sidebar navigation
/// - ``isLoading`` - Whether data is currently loading
/// - ``searchText`` - Current search query text
///
/// ### Session Operations
/// - ``loadSessions()`` - Load paginated session list
/// - ``loadProjectGroups()`` - Load project groups for sidebar
/// - ``createSession(name:projectId:model:permissionMode:)`` - Create a new session
/// - ``deleteSession(_:)`` - Delete a session
/// - ``forkSession(_:)`` - Fork an existing session
/// - ``renameSession(_:newName:)`` - Rename a session
@Observable
@MainActor
class SessionsViewModel: BaseViewModel {
    /// Array of all loaded chat sessions.
    var sessions: [ChatSession] = []
    /// Total number of sessions available.
    var totalCount: Int = 0
    /// Whether more sessions are available for pagination.
    var hasMore = true
    /// Server-side search query.
    var searchQuery: String?
    /// Client-side search text for filtering.
    var searchText: String = ""
    /// Debounced version of searchText used for actual filtering.
    var debouncedSearchText: String = ""
    /// Timestamp of most recent successful data load from API.
    var lastUpdated: Date?

    /// Project groups for sidebar navigation.
    var projectGroups: [ProjectGroupInfo] = []
    /// Sessions grouped by project name.
    var projectSessions: [String: [ChatSession]] = [:]
    /// Projects currently being loaded.
    var loadingProjects: Set<String> = []
    /// Whether each project has more sessions to load.
    var projectHasMore: [String: Bool] = [:]

    private var currentPage = 1
    private let pageSize = 50
    private var projectPages: [String: Int] = [:]

    /// Precomputed lowercase search strings keyed by session, rebuilt when sessions change
    private var searchCache: [(session: ChatSession, searchText: String)] = []
    /// Cached grouped sessions, rebuilt when filteredSessions changes
    private var cachedGroupedSessions: [(key: String, value: [ChatSession])] = []
    /// The search text used to build the cached grouped sessions
    private var cachedGroupedSearchText: String = ""
    /// Monotonically increasing counter incremented on every sessions mutation.
    /// Replaces the flawed count-based check (same count ≠ same content).
    private var sessionsMutationVersion: Int = 0
    /// The mutation version at which groupedSessions cache was last built
    private var cachedGroupedVersion: Int = -1

    /// Cached time-grouped sessions, rebuilt when filteredSessions changes
    private var cachedGroupedByTime: [(key: String, value: [ChatSession])] = []
    /// The search text used to build the cached time-grouped sessions
    private var cachedGroupedByTimeSearchText: String = ""
    /// The mutation version at which groupedSessionsByTime cache was last built
    private var cachedGroupedByTimeVersion: Int = -1

    @ObservationIgnored nonisolated(unsafe) private var searchTask: Task<Void, Never>?

    deinit {
        searchTask?.cancel()
    }

    /// Schedule a debounced update of debouncedSearchText.
    /// Call this from `.onChange(of: searchText)` in the view instead of filtering on every keystroke.
    func scheduleSearchDebounce() {
        searchTask?.cancel()
        let text = searchText
        guard !text.isEmpty else {
            debouncedSearchText = ""
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            debouncedSearchText = text
        }
    }

    /// Clear search text and debounced text immediately.
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        debouncedSearchText = ""
    }

    /// Number of sessions matching the current debounced search text.
    var filteredCount: Int {
        guard !debouncedSearchText.isEmpty else { return sessions.count }
        return filteredSessions.count
    }


    /// Sessions filtered by the local search text using precomputed lowercase cache
    var filteredSessions: [ChatSession] {
        guard !debouncedSearchText.isEmpty else { return sessions }
        let query = debouncedSearchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.session)
    }

    /// Build a single search-cache entry for a session.
    /// Centralises the lowercasing logic so callers can do O(1) inserts.
    private func makeSearchEntry(for session: ChatSession) -> (session: ChatSession, searchText: String) {
        // String interpolation avoids intermediate Array<String> + .joined() allocation
        let text = "\(session.name?.lowercased() ?? "") \(session.projectName?.lowercased() ?? "") \(session.firstPrompt?.lowercased() ?? "")"
        return (session, text)
    }

    /// Rebuild the lowercase search cache when sessions array changes
    private func rebuildSearchCache() {
        searchCache = sessions.map { makeSearchEntry(for: $0) }
        // Increment version to invalidate both grouped caches
        sessionsMutationVersion += 1
    }

    /// Filtered sessions grouped by project, sorted by most recently active.
    /// Result is cached and only rebuilt when sessions or searchText change.
    var groupedSessions: [(key: String, value: [ChatSession])] {
        if cachedGroupedSearchText == debouncedSearchText && cachedGroupedVersion == sessionsMutationVersion {
            return cachedGroupedSessions
        }
        let filtered = filteredSessions
        let grouped = Dictionary(grouping: filtered) { session in
            session.projectName ?? "Ungrouped"
        }
        let sorted = grouped.sorted { group1, group2 in
            let latest1 = group1.value.map(\.lastActiveAt).max() ?? .distantPast
            let latest2 = group2.value.map(\.lastActiveAt).max() ?? .distantPast
            return latest1 > latest2
        }
        cachedGroupedSessions = sorted
        cachedGroupedSearchText = debouncedSearchText
        cachedGroupedVersion = sessionsMutationVersion
        return sorted
    }

    /// Filtered sessions grouped by relative time (Today/Yesterday/This Week/Earlier).
    /// Sessions within each bucket are sorted by most recently active.
    /// Result is cached and only rebuilt when sessions or searchText change.
    var groupedSessionsByTime: [(key: String, value: [ChatSession])] {
        if cachedGroupedByTimeSearchText == debouncedSearchText && cachedGroupedByTimeVersion == sessionsMutationVersion {
            return cachedGroupedByTime
        }
        let filtered = filteredSessions
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        var today: [ChatSession] = []
        var yesterday: [ChatSession] = []
        var thisWeek: [ChatSession] = []
        var earlier: [ChatSession] = []

        for session in filtered {
            let lastActive = session.lastActiveAt
            if lastActive >= startOfToday {
                today.append(session)
            } else if lastActive >= startOfYesterday {
                yesterday.append(session)
            } else if lastActive >= startOfWeek {
                thisWeek.append(session)
            } else {
                earlier.append(session)
            }
        }

        var result: [(key: String, value: [ChatSession])] = []
        if !today.isEmpty { result.append((key: "Today", value: today)) }
        if !yesterday.isEmpty { result.append((key: "Yesterday", value: yesterday)) }
        if !thisWeek.isEmpty { result.append((key: "This Week", value: thisWeek)) }
        if !earlier.isEmpty { result.append((key: "Earlier", value: earlier)) }

        cachedGroupedByTime = result
        cachedGroupedByTimeSearchText = debouncedSearchText
        cachedGroupedByTimeVersion = sessionsMutationVersion
        return result
    }

    /// Filtered project groups based on debounced search text
    var filteredProjectGroups: [ProjectGroupInfo] {
        guard !debouncedSearchText.isEmpty else { return projectGroups }
        let query = debouncedSearchText.lowercased()
        return projectGroups.filter { group in
            group.name.lowercased().contains(query)
        }
    }

    /// Look up a session by its ID. Uses a linear scan which is fine for the
    /// typical loaded session count (~50). Called once during state restoration.
    func session(byID id: UUID) -> ChatSession? {
        sessions.first { $0.id == id }
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading sessions..."
        }
        if !debouncedSearchText.isEmpty && filteredSessions.isEmpty {
            return "No sessions found"
        }
        return sessions.isEmpty ? "No sessions" : ""
    }

    // MARK: - Project Groups (for sidebar)

    func loadProjectGroups() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<[ProjectGroupInfo]> = try await client.get("/sessions/projects")
            projectGroups = response.data ?? []
            totalCount = projectGroups.reduce(0) { $0 + $1.sessionCount }
            lastUpdated = Date()
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load project groups: \(error.localizedDescription)", category: "sessions")
        }

        isLoading = false
    }

    /// Load sessions for a specific project (on expand)
    func loadSessionsForProject(_ projectName: String) async {
        guard let client else { return }
        guard !loadingProjects.contains(projectName) else { return }

        loadingProjects.insert(projectName)
        let page = projectPages[projectName] ?? 1

        do {
            let encodedName = projectName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? projectName
            let path = "/sessions?projectName=\(encodedName)&page=\(page)&limit=\(pageSize)"
            let response: APIResponse<PaginatedResponse<ChatSession>> = try await client.get(path, cacheTTL: 10)
            let newItems = response.data?.items ?? []
            let hasMore = response.data?.hasMore ?? false

            if page == 1 {
                projectSessions[projectName] = newItems
            } else {
                var existing = projectSessions[projectName] ?? []
                existing.append(contentsOf: newItems)
                projectSessions[projectName] = existing
            }
            projectHasMore[projectName] = hasMore
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load sessions for \(projectName): \(error.localizedDescription)", category: "sessions")
        }

        loadingProjects.remove(projectName)
    }

    /// Load more sessions for a specific project
    func loadMoreForProject(_ projectName: String) async {
        guard projectHasMore[projectName] == true else { return }
        guard !loadingProjects.contains(projectName) else { return }
        let currentPage = projectPages[projectName] ?? 1
        projectPages[projectName] = currentPage + 1
        await loadSessionsForProject(projectName)
    }

    // MARK: - Legacy full-list loading (used by iOS tab views)

    func loadSessions(refresh: Bool = false) async {
        guard let client else { return }
        isLoading = true
        error = nil

        if refresh {
            currentPage = 1
            hasMore = true
        }

        // Cache-first: show cached data immediately on first page load
        if currentPage == 1 && sessions.isEmpty {
            let cached = await CacheService.shared.getCachedSessions()
            if !cached.isEmpty {
                sessions = cached
                totalCount = cached.count
                rebuildSearchCache()
                AppLogger.shared.info("Loaded \(cached.count) sessions from cache", category: "sessions")
            }
        }

        do {
            var path = "/sessions?page=\(currentPage)&limit=\(pageSize)"
            if refresh { path += "&refresh=true" }
            if let searchQuery, !searchQuery.isEmpty {
                let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
                path += "&search=\(encoded)"
            }

            let response: APIResponse<PaginatedResponse<ChatSession>> = try await client.get(path)
            let newItems = response.data?.items ?? []
            hasMore = response.data?.hasMore ?? false
            totalCount = response.data?.total ?? totalCount

            if currentPage == 1 {
                sessions = newItems
                rebuildSearchCache()
                lastUpdated = Date()
                // Update cache with fresh data in background
                Task.detached {
                    await CacheService.shared.cacheSessions(newItems)
                }
            } else {
                // O(k) incremental append — avoids O(n) full rebuild on pagination
                sessions.append(contentsOf: newItems)
                searchCache.append(contentsOf: newItems.map { makeSearchEntry(for: $0) })
                sessionsMutationVersion += 1
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load sessions: \(error.localizedDescription)", category: "sessions")
        }

        isLoading = false
    }

    func retryLoadSessions() async {
        await loadSessions()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
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
                searchCache.insert(makeSearchEntry(for: session), at: 0)
                sessionsMutationVersion += 1
                return session
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to create session: \(error.localizedDescription)", category: "sessions")
        }
        return nil
    }

    func renameSession(_ session: ChatSession, to newName: String) async {
        guard let client else { return }
        do {
            let response: APIResponse<ChatSession> = try await client.renameSession(id: session.id, name: newName)
            if let updated = response.data {
                // Incremental in-place update — avoids O(n) full reload
                if let idx = sessions.firstIndex(where: { $0.id == updated.id }) {
                    sessions[idx] = updated
                }
                if let idx = searchCache.firstIndex(where: { $0.session.id == updated.id }) {
                    searchCache[idx] = makeSearchEntry(for: updated)
                }
                sessionsMutationVersion += 1
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to rename session: \(error.localizedDescription)", category: "sessions")
        }
    }

    func deleteSession(_ session: ChatSession) async {
        guard let client else { return }

        // External sessions can't be deleted from ILS DB
        if session.source == .external {
            sessions.removeAll { $0.id == session.id }
            // O(1) incremental remove — avoids O(n) full rebuild
            searchCache.removeAll { $0.session.id == session.id }
            sessionsMutationVersion += 1
            return
        }

        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
            // O(1) incremental remove — avoids O(n) full rebuild
            searchCache.removeAll { $0.session.id == session.id }
            sessionsMutationVersion += 1
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete session: \(error.localizedDescription)", category: "sessions")
        }
    }

    func forkSession(_ session: ChatSession) async -> ChatSession? {
        guard let client else { return nil }
        do {
            let response: APIResponse<ChatSession> = try await client.post("/sessions/\(session.id)/fork", body: EmptyBody())
            if let forked = response.data {
                sessions.insert(forked, at: 0)
                searchCache.insert(makeSearchEntry(for: forked), at: 0)
                sessionsMutationVersion += 1
                return forked
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to fork session: \(error.localizedDescription)", category: "sessions")
        }
        return nil
    }
}
