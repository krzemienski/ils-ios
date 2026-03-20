import Foundation

/// Paginated response wrapper for list endpoints.
public struct PaginatedResponse<T: Codable>: Codable where T: Sendable {
    /// The items contained in the current page of results.
    public let items: [T]
    /// The total number of items available across all pages.
    public let total: Int
    /// Whether additional pages of results exist beyond the current page.
    public let hasMore: Bool
    /// The current page number (1-based). Defaults to 1 if not provided.
    public let page: Int
    /// The maximum number of items per page. Defaults to 50 if not provided.
    public let limit: Int

    /// Creates a paginated response.
    /// - Parameters:
    ///   - items: The items contained in the current page of results.
    ///   - total: The total number of items available across all pages.
    ///   - hasMore: Whether additional pages of results exist beyond the current page.
    ///   - page: The current page number (1-based). Defaults to 1.
    ///   - limit: The maximum number of items per page. Defaults to 50.
    public init(items: [T], total: Int, hasMore: Bool, page: Int = 1, limit: Int = 50) {
        self.items = items
        self.total = total
        self.hasMore = hasMore
        self.page = page
        self.limit = limit
    }
}
