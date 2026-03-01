import Foundation
import Observation
import ILSShared

/// Private request body for creating a search result bookmark.
private struct AddBookmarkRequest: Codable, Sendable {
    /// ID of the message to bookmark.
    let messageId: UUID
    /// ID of the session the message belongs to.
    let sessionId: UUID
}

/// View model for cross-session message search.
///
/// Manages the search query, active filters, paginated search results,
/// and bookmark operations for the cross-session search feature.
///
/// Supports offset-based pagination, optimistic bookmark updates, and
/// URL query construction for all active filter parameters.
///
/// ## Topics
/// ### Properties
/// - ``searchQuery`` - Current search query text
/// - ``filters`` - Active search filters (date range, project, role)
/// - ``results`` - Paginated search results
/// - ``bookmarks`` - Bookmarked search results
/// - ``isLoading`` - Whether results are currently loading
/// - ``hasMore`` - Whether more result pages are available
///
/// ### Search Operations
/// - ``search()`` - Perform a fresh search from the beginning
/// - ``loadMore()`` - Load the next page of results
/// - ``clearSearch()`` - Reset all search state
/// - ``applyFilters(_:)`` - Apply new filters and re-run the search
///
/// ### Bookmark Operations
/// - ``loadBookmarks()`` - Load all saved bookmarks
/// - ``toggleBookmark(_:)`` - Add or remove a bookmark for a result
@Observable
@MainActor
class CrossSessionSearchViewModel {

    // MARK: - Search State

    /// Current search query text.
    var searchQuery: String = ""

    /// Active filters constraining the search (date range, project, role).
    var filters: SearchFilters = SearchFilters()

    // MARK: - Results State

    /// Paginated search results from the most recent query.
    var results: [MessageSearchResult] = []

    /// Total number of matching results available on the server.
    var totalCount: Int = 0

    /// Whether results are currently loading.
    var isLoading = false

    /// Whether more result pages are available for pagination.
    var hasMore = true

    /// Current error, if any.
    var error: Error?

    // MARK: - Bookmarks State

    /// Bookmarked search results for future reference.
    var bookmarks: [SearchBookmark] = []

    /// Whether bookmarks are currently loading.
    var isLoadingBookmarks = false

    // MARK: - Private State

    private var currentOffset = 0
    private let pageSize = 20
    private var client: APIClient?

    init() {}

    // MARK: - Configuration

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed Properties

    /// Search results grouped by session name, sorted alphabetically by session name.
    var groupedResults: [(key: String, value: [MessageSearchResult])] {
        let grouped = Dictionary(grouping: results) { result in
            result.sessionName ?? result.sessionId.uuidString
        }
        return grouped.sorted { $0.key < $1.key }
    }

    /// Whether a given search result has been bookmarked.
    /// - Parameter result: The search result to check
    /// - Returns: `true` if the result exists in the bookmarks list
    func isBookmarked(_ result: MessageSearchResult) -> Bool {
        bookmarks.contains { $0.result.id == result.id }
    }

    /// Whether the search query is empty or whitespace only.
    var isEmptySearch: Bool {
        searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Search Operations

    /// Perform a fresh search from the beginning, resetting all pagination state.
    func search() async {
        guard !isEmptySearch, let client else { return }
        currentOffset = 0
        results = []
        totalCount = 0
        hasMore = true
        error = nil
        isLoading = true
        await performSearch(client: client, offset: 0, appending: false)
    }

    /// Load the next page of results, appending to the existing list.
    func loadMore() async {
        guard hasMore, !isLoading, !isEmptySearch, let client else { return }
        isLoading = true
        await performSearch(client: client, offset: currentOffset, appending: true)
    }

    /// Clear all search state including query, filters, and results.
    func clearSearch() {
        searchQuery = ""
        filters = SearchFilters()
        results = []
        totalCount = 0
        currentOffset = 0
        hasMore = true
        error = nil
    }

    /// Apply updated filters and re-run the current search if a query is active.
    /// - Parameter newFilters: The new filters to apply
    func applyFilters(_ newFilters: SearchFilters) async {
        filters = newFilters
        if !isEmptySearch {
            await search()
        }
    }

    private func performSearch(client: APIClient, offset: Int, appending: Bool) async {
        let path = buildSearchPath(offset: offset)
        do {
            let response: APIResponse<ListResponse<MessageSearchResult>> = try await client.get(path, cacheTTL: 0)
            if let list = response.data {
                if appending {
                    results.append(contentsOf: list.items)
                } else {
                    results = list.items
                }
                totalCount = list.total
                currentOffset = results.count
                hasMore = results.count < list.total
            } else if let apiError = response.error {
                error = NSError(
                    domain: "CrossSessionSearch",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: apiError.message]
                )
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Build the search URL path including all active query parameters.
    private func buildSearchPath(offset: Int) -> String {
        var components = URLComponents()
        components.path = "/sessions/search"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(pageSize))
        ]
        if let dateFrom = filters.dateFrom {
            items.append(URLQueryItem(name: "dateFrom", value: ISO8601DateFormatter().string(from: dateFrom)))
        }
        if let dateTo = filters.dateTo {
            items.append(URLQueryItem(name: "dateTo", value: ISO8601DateFormatter().string(from: dateTo)))
        }
        if let projectName = filters.projectName, !projectName.isEmpty {
            items.append(URLQueryItem(name: "projectName", value: projectName))
        }
        if let role = filters.role, !role.isEmpty {
            items.append(URLQueryItem(name: "role", value: role))
        }
        components.queryItems = items
        return components.string ?? "/sessions/search"
    }

    // MARK: - Bookmark Operations

    /// Load all saved bookmarks from the server.
    func loadBookmarks() async {
        guard let client else { return }
        isLoadingBookmarks = true
        do {
            let response: APIResponse<ListResponse<SearchBookmark>> = try await client.get(
                "/sessions/search/bookmarks",
                cacheTTL: 0
            )
            if let list = response.data {
                bookmarks = list.items
            }
        } catch {
            // Bookmarks are non-critical; failures are silently ignored
        }
        isLoadingBookmarks = false
    }

    /// Toggle the bookmark state for a search result.
    ///
    /// Applies an optimistic update immediately, then syncs with the server.
    /// Reverts the optimistic update on failure.
    /// - Parameter result: The search result to bookmark or un-bookmark
    func toggleBookmark(_ result: MessageSearchResult) async {
        if isBookmarked(result) {
            await removeBookmark(for: result)
        } else {
            await addBookmark(for: result)
        }
    }

    private func addBookmark(for result: MessageSearchResult) async {
        guard let client else { return }
        let optimistic = SearchBookmark(result: result)
        bookmarks.insert(optimistic, at: 0)
        do {
            let body = AddBookmarkRequest(messageId: result.id, sessionId: result.sessionId)
            let response: APIResponse<SearchBookmark> = try await client.post(
                "/sessions/search/bookmarks",
                body: body
            )
            if let saved = response.data {
                if let idx = bookmarks.firstIndex(where: { $0.id == optimistic.id }) {
                    bookmarks[idx] = saved
                }
            } else {
                bookmarks.removeAll { $0.id == optimistic.id }
            }
        } catch {
            bookmarks.removeAll { $0.id == optimistic.id }
        }
    }

    private func removeBookmark(for result: MessageSearchResult) async {
        guard let client,
              let existing = bookmarks.first(where: { $0.result.id == result.id }) else { return }
        bookmarks.removeAll { $0.result.id == result.id }
        do {
            let _: APIResponse<SearchBookmark> = try await client.delete(
                "/sessions/search/bookmarks/\(existing.id.uuidString)"
            )
        } catch {
            bookmarks.insert(existing, at: 0)
        }
    }
}
