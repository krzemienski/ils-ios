import Foundation

// MARK: - FeedbackRating

/// Rating for an AI response (thumbs up or thumbs down).
public enum FeedbackRating: String, Codable, Sendable {
    /// Positive rating indicating the response was helpful.
    case thumbsUp
    /// Negative rating indicating the response was not helpful.
    case thumbsDown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized FeedbackRating: '\(raw)'. Expected: thumbsUp, thumbsDown"
                )
            )
        }
        self = value
    }
}

// MARK: - ResponseFeedback

/// Represents user feedback on an AI-generated response.
public struct ResponseFeedback: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this feedback entry.
    public let id: UUID
    /// Rating given by the user (thumbs up or thumbs down).
    public let rating: FeedbackRating
    /// Optional comment explaining the feedback.
    public let comment: String?
    /// ID of the message that received the feedback.
    public let messageId: UUID
    /// ID of the session containing the message.
    public let sessionId: UUID
    /// ID of the project associated with this feedback.
    public let projectId: UUID?
    /// Name of the AI model that generated the response.
    public let modelName: String?
    /// Timestamp when the feedback was submitted.
    public let createdAt: Date

    /// Creates a new response feedback entry.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - rating: Thumbs up or thumbs down rating.
    ///   - comment: Optional explanation for the feedback.
    ///   - messageId: ID of the rated message.
    ///   - sessionId: ID of the parent session.
    ///   - projectId: Optional ID of the associated project.
    ///   - modelName: Optional name of the AI model used.
    ///   - createdAt: Submission timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        rating: FeedbackRating,
        comment: String? = nil,
        messageId: UUID,
        sessionId: UUID,
        projectId: UUID? = nil,
        modelName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rating = rating
        self.comment = comment
        self.messageId = messageId
        self.sessionId = sessionId
        self.projectId = projectId
        self.modelName = modelName
        self.createdAt = createdAt
    }
}
