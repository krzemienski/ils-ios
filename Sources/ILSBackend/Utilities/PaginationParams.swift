import Foundation
import Vapor
import ILSShared

/// Pagination parameters extracted from request query params.
struct PaginationParams {
    let limit: Int
    let offset: Int

    init(from req: Request) {
        self.limit = req.query[Int.self, at: "limit"] ?? 100
        self.offset = req.query[Int.self, at: "offset"] ?? 0
    }

    /// Apply pagination to an array and return paginated result.
    func apply<T: Codable & Sendable>(to items: [T]) -> PaginatedResult<T> {
        let total = items.count
        let end = min(offset + limit, total)
        let paginatedItems = offset < total ? Array(items[offset..<end]) : []
        let hasMore = end < total

        return PaginatedResult(
            items: paginatedItems,
            pagination: PaginationMeta(
                total: total,
                limit: limit,
                offset: offset,
                hasMore: hasMore
            )
        )
    }
}

/// Result of applying pagination to a collection.
struct PaginatedResult<T: Codable & Sendable> {
    let items: [T]
    let pagination: PaginationMeta
}

/// Pagination metadata included in API responses.
struct PaginationMeta: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}
