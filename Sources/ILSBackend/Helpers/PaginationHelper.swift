import Vapor

/// Reusable pagination parameters extracted from query strings.
///
/// Standard query params:
/// - `page`: 1-based page number (default 1)
/// - `limit`: Items per page (default 50, max 200)
///
/// Usage:
/// ```swift
/// let pagination = try PaginationParams(from: req)
/// let result = pagination.apply(to: allItems)
/// ```
struct PaginationParams {
    /// Current page number (1-based).
    let page: Int
    /// Items per page.
    let limit: Int
    /// Computed offset for slicing.
    var offset: Int { (page - 1) * limit }

    /// Extract pagination parameters from a Vapor request's query string.
    init(from req: Request, defaultLimit: Int = 50, maxLimit: Int = 200) {
        let rawPage = req.query[Int.self, at: "page"] ?? 1
        let rawLimit = req.query[Int.self, at: "limit"] ?? defaultLimit
        self.page = max(rawPage, 1)
        self.limit = min(max(rawLimit, 1), maxLimit)
    }

    /// Apply pagination to an in-memory array and return a `PaginatedResult`.
    func apply<T>(to items: [T]) -> PaginatedResult<T> {
        let total = items.count
        let totalPages = limit > 0 ? max(1, Int(ceil(Double(total) / Double(limit)))) : 1
        let start = min(offset, total)
        let end = min(start + limit, total)
        let slice = Array(items[start..<end])

        return PaginatedResult(
            items: slice,
            pagination: PaginationMeta(
                total: total,
                page: page,
                limit: limit,
                totalPages: totalPages
            )
        )
    }
}

/// Pagination metadata included in paginated API responses.
struct PaginationMeta: Codable, Sendable {
    /// Total number of items across all pages.
    let total: Int
    /// Current page number (1-based).
    let page: Int
    /// Items per page.
    let limit: Int
    /// Total number of pages.
    let totalPages: Int
}

/// Result of applying pagination to a collection.
struct PaginatedResult<T> {
    let items: [T]
    let pagination: PaginationMeta
}
