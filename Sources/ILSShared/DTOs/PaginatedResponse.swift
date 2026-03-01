import Foundation

/// Paginated response wrapper for list endpoints.
public struct PaginatedResponse<T: Codable>: Codable where T: Sendable {
    /// The items contained in the current page of results.
    public let items: [T]
    /// The total number of items available across all pages.
    public let total: Int
    /// Whether additional pages of results exist beyond the current page.
    public let hasMore: Bool

    /// Creates a paginated response.
    /// - Parameters:
    ///   - items: The items contained in the current page of results.
    ///   - total: The total number of items available across all pages.
    ///   - hasMore: Whether additional pages of results exist beyond the current page.
    public init(items: [T], total: Int, hasMore: Bool) {
        self.items = items
        self.total = total
        self.hasMore = hasMore
    }
}
