import Vapor

/// Pagination parameters for list endpoints.
struct PaginationParams {
    let page: Int
    let limit: Int
    let offset: Int

    /// Initialize pagination parameters from request query params.
    /// - Parameter req: Vapor Request with optional page/limit query params
    init(from req: Request) {
        let requestedPage = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let requestedLimit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 200)

        self.page = requestedPage
        self.limit = requestedLimit
        self.offset = (requestedPage - 1) * requestedLimit
    }

    /// Apply pagination to an array.
    /// - Parameter items: Array to paginate
    /// - Returns: Paginated result with items and pagination metadata
    func apply<T>(to items: [T]) -> PaginatedResult<T> {
        let total = items.count
        let start = min(offset, total)
        let end = min(start + limit, total)
        let pageItems = Array(items[start..<end])

        return PaginatedResult(
            items: pageItems,
            pagination: PaginationMetadata(
                page: page,
                limit: limit,
                total: total
            )
        )
    }
}

/// Paginated result with metadata.
struct PaginatedResult<T> {
    let items: [T]
    let pagination: PaginationMetadata
}

/// Pagination metadata.
struct PaginationMetadata {
    let page: Int
    let limit: Int
    let total: Int
}
