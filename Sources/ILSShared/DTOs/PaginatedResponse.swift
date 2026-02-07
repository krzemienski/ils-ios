import Foundation

/// Paginated response wrapper for list endpoints.
public struct PaginatedResponse<T: Codable>: Codable where T: Sendable {
    public let items: [T]
    public let total: Int
    public let hasMore: Bool

    public init(items: [T], total: Int, hasMore: Bool) {
        self.items = items
        self.total = total
        self.hasMore = hasMore
    }
}
