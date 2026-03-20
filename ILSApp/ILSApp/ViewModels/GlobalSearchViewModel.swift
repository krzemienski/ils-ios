import Foundation
import Observation
import ILSShared

/// View model for cross-session full-text message search.
///
/// Provides debounced search-as-you-type across all session messages using
/// FTS5, with optional filters for role, date range, project, and code-only results.
/// Search history is persisted server-side and loaded on appearance.
///
/// ## Topics
/// ### Properties
/// - ``searchQuery`` - The current search query string
/// - ``searchResults`` - Results from the most recent search
/// - ``searchHistory`` - Recent search queries (up to 20)
/// - ``totalResults`` - Total number of matching messages (before pagination)
/// - ``isShowingFilters`` - Whether the filter panel is expanded
///
/// ### Filtering
/// - ``selectedRole`` - Optional role filter (user / assistant / system)
/// - ``dateFrom`` - Optional lower bound for message creation date
/// - ``dateTo`` - Optional upper bound for message creation date
/// - ``selectedProjectId`` - Optional project scope filter
/// - ``codeOnly`` - When true, restrict to messages containing code blocks
///
/// ### Methods
/// - ``scheduleSearch()`` - Trigger a debounced search after query/filter changes
/// - ``search()`` - Execute search immediately with current state
/// - ``loadHistory()`` - Load recent search history from the server
/// - ``clearHistory()`` - Delete all search history entries
/// - ``clearFilters()`` - Reset all active filters
@Observable
@MainActor
class GlobalSearchViewModel: BaseViewModel {

    // MARK: - Search State

    /// The current search query typed by the user.
    var searchQuery: String = ""
    /// Results returned by the most recent search call.
    var searchResults: [MessageSearchResult] = []
    /// Total matching messages available on the server for the current query + filters.
    var totalResults: Int = 0
    /// Recent searches loaded from `GET /sessions/search/history`.
    var searchHistory: [SearchHistoryEntry] = []
    /// Whether the filter panel is visible in the UI.
    var isShowingFilters: Bool = false

    // MARK: - Filters

    /// Restrict results to messages from a specific role.
    var selectedRole: MessageRole? = nil
    /// Include only messages created on or after this date.
    var dateFrom: Date? = nil
    /// Include only messages created on or before this date.
    var dateTo: Date? = nil
    /// Restrict search to sessions belonging to this project.
    var selectedProjectId: UUID? = nil
    /// When true, only return messages that contain a code block (```).
    var codeOnly: Bool = false

    // MARK: - Internals

    @ObservationIgnored nonisolated(unsafe) private var searchTask: Task<Void, Never>?

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Public API

    /// Schedule a debounced search call 300 ms after the last invocation.
    ///
    /// Call this from `.onChange(of: searchQuery)` (and filter onChange handlers)
    /// rather than calling `search()` directly to avoid hammering the API on every keystroke.
    ///
    /// Filter/ranking work runs inside a `Task.detached(priority: .userInitiated)` block
    /// so it executes off the MainActor. Results are assigned back on the MainActor via
    /// `await MainActor.run`. Cancelling `searchTask` cooperatively cancels in-flight work
    /// via `Task.isCancelled` checks inside the detached block.
    func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        guard !query.isEmpty else {
            searchResults = []
            totalResults = 0
            return
        }

        // Snapshot all filter state on MainActor before detaching so the detached
        // task never needs to hop back just to read properties.
        let role = selectedRole
        let from = dateFrom
        let to = dateTo
        let projectId = selectedProjectId
        let codeOnlyFlag = codeOnly
        let capturedClient = client

        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            // Debounce: sleep off the main actor so the main thread stays free.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            guard let client = capturedClient else { return }

            // Signal loading state on MainActor before network work begins.
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            // Build query items off the main actor — pure value computation.
            var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
            if let role {
                items.append(URLQueryItem(name: "role", value: role.rawValue))
            }
            let iso = ISO8601DateFormatter()
            if let from {
                items.append(URLQueryItem(name: "from", value: iso.string(from: from)))
            }
            if let to {
                items.append(URLQueryItem(name: "to", value: iso.string(from: to)))
            }
            if let projectId {
                items.append(URLQueryItem(name: "projectId", value: projectId.uuidString.lowercased()))
            }
            if codeOnlyFlag {
                items.append(URLQueryItem(name: "codeOnly", value: "true"))
            }

            var components = URLComponents()
            components.queryItems = items
            let queryString = components.percentEncodedQuery ?? ""
            let path = "/sessions/search?\(queryString)"

            do {
                let response: APIResponse<ListResponse<MessageSearchResult>> = try await client.get(path)
                guard !Task.isCancelled else { return }
                let results = response.data?.items ?? []
                let total = response.data?.total ?? 0

                // Hop back to MainActor only to assign results.
                await MainActor.run {
                    self.searchResults = results
                    self.totalResults = total
                    self.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    AppLogger.shared.error("Global search failed: \(error.localizedDescription)", category: "search")
                }
            }
        }
    }

    /// Execute the search immediately using the current query and all active filters.
    ///
    /// Calls `GET /sessions/search` with `q`, optional `role`, `from`, `to`,
    /// `projectId`, and `codeOnly` query parameters.
    func search() async {
        guard let client else { return }
        let query = searchQuery
        guard !query.isEmpty else {
            searchResults = []
            totalResults = 0
            return
        }

        isLoading = true
        error = nil

        do {
            var components = URLComponents()
            components.queryItems = buildQueryItems(query: query)
            let queryString = components.percentEncodedQuery ?? ""
            let path = "/sessions/search?\(queryString)"

            let response: APIResponse<ListResponse<MessageSearchResult>> = try await client.get(path)
            searchResults = response.data?.items ?? []
            totalResults = response.data?.total ?? 0
        } catch {
            self.error = error
            AppLogger.shared.error("Global search failed: \(error.localizedDescription)", category: "search")
        }

        isLoading = false
    }

    /// Load recent search history from `GET /sessions/search/history`.
    func loadHistory() async {
        guard let client else { return }
        do {
            let response: APIResponse<[SearchHistoryEntry]> = try await client.get("/sessions/search/history")
            searchHistory = response.data ?? []
        } catch {
            AppLogger.shared.error("Failed to load search history: \(error.localizedDescription)", category: "search")
        }
    }

    /// Delete all search history entries via `DELETE /sessions/search/history`.
    func clearHistory() async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/sessions/search/history")
            searchHistory = []
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to clear search history: \(error.localizedDescription)", category: "search")
        }
    }

    /// Reset all active filters to their default (off) state and re-run the search.
    func clearFilters() {
        selectedRole = nil
        dateFrom = nil
        dateTo = nil
        selectedProjectId = nil
        codeOnly = false
        scheduleSearch()
    }

    /// Whether any filter is currently active.
    var hasActiveFilters: Bool {
        selectedRole != nil || dateFrom != nil || dateTo != nil
            || selectedProjectId != nil || codeOnly
    }

    // MARK: - Helpers

    /// Build the URL query items for the search request from the current state.
    private func buildQueryItems(query: String) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query)
        ]

        if let role = selectedRole {
            items.append(URLQueryItem(name: "role", value: role.rawValue))
        }

        let iso = ISO8601DateFormatter()
        if let from = dateFrom {
            items.append(URLQueryItem(name: "from", value: iso.string(from: from)))
        }
        if let to = dateTo {
            items.append(URLQueryItem(name: "to", value: iso.string(from: to)))
        }

        if let projectId = selectedProjectId {
            items.append(URLQueryItem(name: "projectId", value: projectId.uuidString.lowercased()))
        }

        if codeOnly {
            items.append(URLQueryItem(name: "codeOnly", value: "true"))
        }

        return items
    }
}
