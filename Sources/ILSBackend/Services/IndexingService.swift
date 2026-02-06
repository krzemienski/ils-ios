import Vapor
import Fluent

/// Storage key for shared IndexingService instance
struct IndexingServiceKey: StorageKey {
    typealias Value = IndexingService
}

extension Application {
    var indexingService: IndexingService {
        get {
            if let existing = self.storage[IndexingServiceKey.self] {
                return existing
            }
            let service = IndexingService(database: self.db)
            self.storage[IndexingServiceKey.self] = service
            return service
        }
        set {
            self.storage[IndexingServiceKey.self] = newValue
        }
    }
}

/// Fluent model for cached search results
final class CachedResult: Model, @unchecked Sendable {
    static let schema = "cached_results"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "query")
    var query: String

    @Field(key: "result_json")
    var resultJSON: String

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(id: UUID? = nil, query: String, resultJSON: String, createdAt: Date = Date(), expiresAt: Date) {
        self.id = id
        self.query = query
        self.resultJSON = resultJSON
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

/// Service for caching search results in SQLite
final class IndexingService: Sendable {
    let database: Database

    init(database: Database) {
        self.database = database
    }

    /// Cache search results with a 1-hour TTL
    func cacheSearchResults(query: String, results: String) async throws {
        // Remove any existing cache for this query
        try await CachedResult.query(on: database)
            .filter(\.$query == query)
            .delete()

        let cached = CachedResult(
            query: query,
            resultJSON: results,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600) // 1 hour TTL
        )
        try await cached.save(on: database)
    }

    /// Get cached results if not expired
    func getCachedResults(query: String) async throws -> String? {
        guard let cached = try await CachedResult.query(on: database)
            .filter(\.$query == query)
            .filter(\.$expiresAt > Date())
            .first() else {
            return nil
        }
        return cached.resultJSON
    }

    /// Delete all expired cache entries
    func pruneExpired() async throws {
        try await CachedResult.query(on: database)
            .filter(\.$expiresAt < Date())
            .delete()
    }
}
