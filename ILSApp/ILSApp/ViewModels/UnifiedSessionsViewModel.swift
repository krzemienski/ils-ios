import Foundation
import Observation
import ILSShared

/// View model for a unified session list aggregating sessions from all configured backends.
///
/// Concurrently fetches sessions from every backend registered in ``BackendManager`` using
/// a structured-concurrency `TaskGroup`, wraps each ``ChatSession`` in a ``TaggedSession``
/// (adding backend name and color metadata), then merges and sorts the results by
/// `lastActiveAt` descending so the most recently active sessions appear first.
///
/// Search is applied client-side across *all* backends simultaneously using a precomputed
/// lowercase cache that includes backend name as a searchable field, letting users filter
/// by backend label (e.g., "Work Mac") as well as session content.
///
/// ## Error Handling
/// Failures from individual backends are captured in ``backendErrors`` without aborting
/// results from other backends. ``error`` is set only when *all* backends fail.
///
/// ## Topics
/// ### Properties
/// - ``sessions`` - Merged, sorted TaggedSession array from all backends
/// - ``isLoading`` - Whether a fetch is in progress
/// - ``searchText`` - Client-side search query applied across all backends
/// - ``backendErrors`` - Per-backend errors from the most recent fetch
///
/// ### Operations
/// - ``loadSessions(refresh:)`` - Concurrently fetch from all backends
@Observable
@MainActor
final class UnifiedSessionsViewModel {

    // MARK: - Published State

    /// Merged, sorted array of sessions from all reachable backends.
    var sessions: [TaggedSession] = []
    /// Whether sessions are currently being fetched.
    var isLoading = false
    /// Aggregate error set when every backend fails; `nil` on partial success.
    var error: Error?
    /// Client-side search text filtered across all backends simultaneously.
    var searchText: String = ""
    /// Timestamp of the most recent successful data load.
    var lastUpdated: Date?
    /// Per-backend errors from the most recent fetch. Empty on full success.
    var backendErrors: [UUID: Error] = [:]

    // MARK: - Private Cache State

    /// Precomputed lowercase search strings including backend name, rebuilt when sessions change.
    private var searchCache: [(session: TaggedSession, searchText: String)] = []
    /// Monotonically increasing counter used to invalidate grouped-session caches.
    private var sessionsMutationVersion: Int = 0

    /// Cached time-grouped sessions.
    private var cachedGroupedByTime: [(key: String, value: [TaggedSession])] = []
    /// The search text used to build the cached time-grouped sessions.
    private var cachedGroupedByTimeSearchText: String = ""
    /// The session count used to invalidate the time-grouped cache.
    private var cachedGroupedByTimeSessionCount: Int = -1

    /// Cached backend-grouped sessions.
    private var cachedGroupedByBackend: [(key: String, value: [TaggedSession])] = []
    /// The mutation version at which the backend-grouped cache was last built.
    private var cachedGroupedByBackendVersion: Int = -1
    /// The search text used to build the cached backend-grouped sessions.
    private var cachedGroupedByBackendSearchText: String = ""

    // MARK: - Dependencies

    @ObservationIgnored private let manager: BackendManager

    // MARK: - Init

    /// Creates the view model.
    /// - Parameter manager: The backend manager to query (defaults to the shared singleton).
    init(manager: BackendManager = .shared) {
        self.manager = manager
    }

    // MARK: - Filtered Sessions

    /// Sessions filtered by the local search text using a precomputed lowercase cache.
    ///
    /// The cache includes backend name as a searchable field so users can type a
    /// backend label (e.g., "Work Mac") to narrow results.
    var filteredSessions: [TaggedSession] {
        guard !searchText.isEmpty else { return sessions }
        let query = searchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.session)
    }

    /// Builds a single search-cache entry for a tagged session.
    ///
    /// Includes `backendName` so users can search by backend label.
    private func makeSearchEntry(for tagged: TaggedSession) -> (session: TaggedSession, searchText: String) {
        let s = tagged.session
        let text = """
            \(s.name?.lowercased() ?? "") \
            \(s.projectName?.lowercased() ?? "") \
            \(s.firstPrompt?.lowercased() ?? "") \
            \(tagged.backendName.lowercased())
            """
        return (tagged, text)
    }

    /// Rebuilds the lowercase search cache and invalidates grouped caches.
    private func rebuildSearchCache() {
        searchCache = sessions.map { makeSearchEntry(for: $0) }
        sessionsMutationVersion += 1
        cachedGroupedByTimeSessionCount = -1
    }

    // MARK: - Grouped Sessions (by Time)

    /// Filtered sessions grouped by relative time (Today/Yesterday/This Week/Earlier),
    /// sorted by most recently active within each bucket.
    ///
    /// Result is cached and only rebuilt when sessions or searchText change.
    var groupedSessionsByTime: [(key: String, value: [TaggedSession])] {
        guard cachedGroupedByTimeSearchText != searchText
                || cachedGroupedByTimeSessionCount != sessions.count else {
            return cachedGroupedByTime
        }
        let filtered = filteredSessions
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        var today: [TaggedSession] = []
        var yesterday: [TaggedSession] = []
        var thisWeek: [TaggedSession] = []
        var earlier: [TaggedSession] = []

        for tagged in filtered {
            let lastActive = tagged.lastActiveAt
            if lastActive >= startOfToday {
                today.append(tagged)
            } else if lastActive >= startOfYesterday {
                yesterday.append(tagged)
            } else if lastActive >= startOfWeek {
                thisWeek.append(tagged)
            } else {
                earlier.append(tagged)
            }
        }

        var result: [(key: String, value: [TaggedSession])] = []
        if !today.isEmpty { result.append((key: "Today", value: today)) }
        if !yesterday.isEmpty { result.append((key: "Yesterday", value: yesterday)) }
        if !thisWeek.isEmpty { result.append((key: "This Week", value: thisWeek)) }
        if !earlier.isEmpty { result.append((key: "Earlier", value: earlier)) }

        cachedGroupedByTime = result
        cachedGroupedByTimeSearchText = searchText
        cachedGroupedByTimeSessionCount = sessions.count
        return result
    }

    // MARK: - Grouped Sessions (by Backend)

    /// Filtered sessions grouped by backend name, sorted by most recently active per backend.
    ///
    /// Useful for a backend-centric list view. Result is cached and only rebuilt when
    /// sessions or searchText change.
    var groupedSessionsByBackend: [(key: String, value: [TaggedSession])] {
        guard cachedGroupedByBackendSearchText != searchText
                || cachedGroupedByBackendVersion != sessionsMutationVersion else {
            return cachedGroupedByBackend
        }
        let filtered = filteredSessions
        let grouped = Dictionary(grouping: filtered) { $0.backendName }
        let sorted = grouped.sorted { lhs, rhs in
            let latest1 = lhs.value.map(\.lastActiveAt).max() ?? .distantPast
            let latest2 = rhs.value.map(\.lastActiveAt).max() ?? .distantPast
            return latest1 > latest2
        }
        cachedGroupedByBackend = sorted
        cachedGroupedByBackendSearchText = searchText
        cachedGroupedByBackendVersion = sessionsMutationVersion
        return sorted
    }

    // MARK: - Load

    /// Concurrently fetches sessions from all configured backends and merges them.
    ///
    /// Each backend is queried in parallel via a `TaskGroup`. Partial failures are
    /// captured in ``backendErrors`` without suppressing results from healthy backends.
    ///
    /// - Parameter refresh: Ignored for now — every call performs a full refresh.
    ///   Reserved for future cache-first optimization.
    func loadSessions(refresh: Bool = false) async {
        let allBackends = manager.backends
        guard !allBackends.isEmpty else {
            sessions = []
            backendErrors = [:]
            rebuildSearchCache()
            lastUpdated = Date()
            return
        }

        isLoading = true
        error = nil
        backendErrors = [:]

        // Snapshot backend metadata on the main actor before entering the task group.
        // BackendConnection is Sendable (value-type struct) so safe to capture.
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
                    AppLogger.shared.warning(
                        "Failed to load sessions from backend \(backendId): \(err.localizedDescription)",
                        category: "unified-sessions"
                    )
                } else {
                    allTagged.append(contentsOf: tagged)
                }
            }
        }

        // Sort merged results by lastActiveAt descending.
        allTagged.sort { $0.lastActiveAt > $1.lastActiveAt }

        sessions = allTagged
        backendErrors = fetchErrors
        rebuildSearchCache()
        lastUpdated = Date()

        // Surface a top-level error only when every backend failed.
        if fetchErrors.count == backendSnapshots.count, let first = fetchErrors.values.first {
            error = first
        }

        isLoading = false
    }

    // MARK: - Helpers

    /// Empty-state description for UI display.
    var emptyStateText: String {
        if isLoading { return "Loading sessions..." }
        if manager.backends.isEmpty { return "No backends configured" }
        if !backendErrors.isEmpty && sessions.isEmpty { return "Could not reach any backend" }
        return sessions.isEmpty ? "No sessions" : ""
    }

    /// Whether at least one backend is currently reachable (healthy or status unknown).
    var hasAnyReachableBackend: Bool {
        manager.backends.contains { $0.healthStatus != .unreachable }
    }
}
