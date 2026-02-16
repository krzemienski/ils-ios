import Foundation
import Observation
import ILSShared

/// View model for session list and management.
///
/// Manages both ILS-managed sessions (from database) and external Claude Code sessions
/// (discovered from `~/.claude/projects/`). Supports pagination, search, and project grouping.
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
class SessionsViewModel {
    /// Array of all loaded chat sessions.
    var sessions: [ChatSession] = []
    /// Total number of sessions available.
    var totalCount: Int = 0
    /// Whether sessions are currently loading.
    var isLoading = false
    /// Current error, if any.
    var error: Error?
    /// Whether more sessions are available for pagination.
    var hasMore = true
    /// Server-side search query.
    var searchQuery: String?
    /// Client-side search text for filtering.
    var searchText: String = ""

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

    private var client: APIClient?

    /// Precomputed lowercase search strings keyed by session, rebuilt when sessions change
    private var searchCache: [(session: ChatSession, searchText: String)] = []
    /// Cached grouped sessions, rebuilt when filteredSessions changes
    private var cachedGroupedSessions: [(key: String, value: [ChatSession])] = []
    /// The search text used to build the cached grouped sessions
    private var cachedGroupedSearchText: String = ""
    /// The session count used to invalidate grouped cache
    private var cachedGroupedSessionCount: Int = -1

    init() {}

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests
    func configure(client: APIClient) {
        self.client = client
    }

    /// Sessions filtered by the local search text using precomputed lowercase cache
    var filteredSessions: [ChatSession] {
        guard !searchText.isEmpty else { return sessions }
        let query = searchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.session)
    }

    /// Rebuild the lowercase search cache when sessions array changes
    private func rebuildSearchCache() {
        searchCache = sessions.map { session in
            let text = [
                session.name?.lowercased() ?? "",
                session.projectName?.lowercased() ?? "",
                session.firstPrompt?.lowercased() ?? ""
            ].joined(separator: " ")
            return (session, text)
        }
        // Invalidate grouped cache
        cachedGroupedSessionCount = -1
    }

    /// Filtered sessions grouped by project, sorted by most recently active.
    /// Result is cached and only rebuilt when sessions or searchText change.
    var groupedSessions: [(key: String, value: [ChatSession])] {
        if cachedGroupedSearchText == searchText && cachedGroupedSessionCount == sessions.count {
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
        cachedGroupedSearchText = searchText
        cachedGroupedSessionCount = sessions.count
        return sorted
    }

    /// Filtered project groups based on search text
    var filteredProjectGroups: [ProjectGroupInfo] {
        guard !searchText.isEmpty else { return projectGroups }
        let query = searchText.lowercased()
        return projectGroups.filter { group in
            group.name.lowercased().contains(query)
        }
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading sessions..."
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
                // Update cache with fresh data in background
                Task.detached {
                    await CacheService.shared.cacheSessions(newItems)
                }
            } else {
                sessions.append(contentsOf: newItems)
            }
            rebuildSearchCache()
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
                rebuildSearchCache()
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
            let _: APIResponse<ChatSession> = try await client.renameSession(id: session.id, name: newName)
            await loadSessions(refresh: true)
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
            rebuildSearchCache()
            return
        }

        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/\(session.id)")
            sessions.removeAll { $0.id == session.id }
            rebuildSearchCache()
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
                rebuildSearchCache()
                return forked
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to fork session: \(error.localizedDescription)", category: "sessions")
        }
        return nil
    }
}
