import Fluent
import Vapor

/// Fluent model for search query history persistence
final class SearchHistoryModel: Model, Content, @unchecked Sendable {
    static let schema = "search_history"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "query")
    var query: String

    @Field(key: "result_count")
    var resultCount: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        query: String,
        resultCount: Int
    ) {
        self.id = id
        self.query = query
        self.resultCount = resultCount
    }
}
