import Fluent
import Vapor
import ILSShared

/// Fluent model for ResponseFeedback persistence
final class ResponseFeedbackModel: Model, Content, @unchecked Sendable {
    static let schema = "response_feedback"

    @ID(key: .id)
    var id: UUID?

    @OptionalField(key: "message_id")
    var messageId: UUID?

    @Field(key: "session_id")
    var sessionId: UUID

    @OptionalField(key: "project_id")
    var projectId: UUID?

    @Field(key: "rating")
    var rating: String

    @OptionalField(key: "comment")
    var comment: String?

    @OptionalField(key: "model")
    var model: String?

    @OptionalField(key: "message_content")
    var messageContent: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        messageId: UUID? = nil,
        sessionId: UUID,
        projectId: UUID? = nil,
        rating: FeedbackRating,
        comment: String? = nil,
        model: String? = nil,
        messageContent: String? = nil
    ) {
        self.id = id
        self.messageId = messageId
        self.sessionId = sessionId
        self.projectId = projectId
        self.rating = rating.rawValue
        self.comment = comment
        self.model = model
        self.messageContent = messageContent
    }

    /// Convert to shared ResponseFeedback type
    func toShared() -> ResponseFeedback {
        ResponseFeedback(
            id: id ?? UUID(),
            rating: FeedbackRating(rawValue: rating) ?? .thumbsDown,
            comment: comment,
            messageId: messageId ?? UUID(),
            sessionId: sessionId,
            projectId: projectId,
            modelName: model,
            createdAt: createdAt ?? Date()
        )
    }
}
