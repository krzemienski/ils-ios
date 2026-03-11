import Foundation

// MARK: - Submit Feedback

/// Request payload for submitting feedback on an AI response.
public struct SubmitFeedbackRequest: Codable, Sendable {
    /// Rating for the response: 1 for thumbs up, -1 for thumbs down.
    public let rating: Int
    /// Optional free-text comment accompanying the rating.
    public let comment: String?
    /// Identifier of the message being rated.
    public let messageId: String
    /// Identifier of the session in which the message occurred.
    public let sessionId: String
    /// Identifier of the project associated with the session.
    public let projectId: String
    /// Model name that generated the response (e.g., "claude-opus-4-5").
    public let model: String
    /// The full text content of the AI message being rated. Stored so the
    /// Best-Of collection can surface response previews without a messages join.
    public let messageContent: String?

    public init(
        rating: Int,
        comment: String? = nil,
        messageId: String,
        sessionId: String,
        projectId: String,
        model: String,
        messageContent: String? = nil
    ) {
        self.rating = rating
        self.comment = comment
        self.messageId = messageId
        self.sessionId = sessionId
        self.projectId = projectId
        self.model = model
        self.messageContent = messageContent
    }
}

// MARK: - Feedback Response

/// The saved feedback record returned after a successful submission.
public struct FeedbackResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for this feedback record.
    public let id: String
    /// Rating value: 1 for thumbs up, -1 for thumbs down.
    public let rating: Int
    /// Optional free-text comment provided by the user.
    public let comment: String?
    /// Identifier of the message that was rated.
    public let messageId: String
    /// Identifier of the session in which the message occurred.
    public let sessionId: String
    /// Identifier of the project associated with the session.
    public let projectId: String
    /// Model name that generated the rated response.
    public let model: String
    /// ISO-8601 timestamp when the feedback was recorded.
    public let createdAt: String

    public init(
        id: String,
        rating: Int,
        comment: String? = nil,
        messageId: String,
        sessionId: String,
        projectId: String,
        model: String,
        createdAt: String
    ) {
        self.id = id
        self.rating = rating
        self.comment = comment
        self.messageId = messageId
        self.sessionId = sessionId
        self.projectId = projectId
        self.model = model
        self.createdAt = createdAt
    }
}

// MARK: - Quality Trend

/// A single data point in a quality trend chart.
public struct QualityTrendPoint: Codable, Sendable, Identifiable {
    /// Unique identifier for this trend point.
    public var id: String { date }
    /// ISO-8601 date string for this data point.
    public let date: String
    /// Number of thumbs-up ratings on this date.
    public let thumbsUp: Int
    /// Number of thumbs-down ratings on this date.
    public let thumbsDown: Int
    /// Computed quality score for this date (0.0–1.0).
    public let score: Double

    public init(date: String, thumbsUp: Int, thumbsDown: Int, score: Double) {
        self.date = date
        self.thumbsUp = thumbsUp
        self.thumbsDown = thumbsDown
        self.score = score
    }
}

/// Quality trend response containing data points over a date range.
public struct QualityTrendResponse: Codable, Sendable {
    /// Project identifier the trend belongs to.
    public let projectId: String
    /// Ordered list of quality trend data points.
    public let dataPoints: [QualityTrendPoint]
    /// Start of the date range (ISO-8601).
    public let startDate: String
    /// End of the date range (ISO-8601).
    public let endDate: String

    public init(
        projectId: String,
        dataPoints: [QualityTrendPoint],
        startDate: String,
        endDate: String
    ) {
        self.projectId = projectId
        self.dataPoints = dataPoints
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Best Of

/// A highly-rated AI response surfaced for review or export.
public struct BestOfItem: Codable, Sendable, Identifiable {
    /// Unique identifier for this item (message ID).
    public var id: String { messageId }
    /// The full content of the AI message that was rated positively.
    public let messageContent: String
    /// Identifier of the session in which the message occurred.
    public let sessionId: String
    /// Rating value: 1 for thumbs up, -1 for thumbs down.
    public let rating: Int
    /// Optional free-text comment left by the user.
    public let comment: String?
    /// Model name that generated this response.
    public let model: String
    /// ISO-8601 timestamp when the feedback was recorded.
    public let timestamp: String
    /// Identifier of the message that was rated.
    public let messageId: String

    public init(
        messageContent: String,
        sessionId: String,
        rating: Int,
        comment: String? = nil,
        model: String,
        timestamp: String,
        messageId: String
    ) {
        self.messageContent = messageContent
        self.sessionId = sessionId
        self.rating = rating
        self.comment = comment
        self.model = model
        self.timestamp = timestamp
        self.messageId = messageId
    }
}

// MARK: - Feedback Export

/// Full feedback export payload for a project.
public struct FeedbackExportData: Codable, Sendable {
    /// Project identifier this export belongs to.
    public let projectId: String
    /// ISO-8601 timestamp when the export was generated.
    public let exportedAt: String
    /// All feedback records included in the export.
    public let feedbackRecords: [FeedbackResponse]
    /// Quality trend data points over the export period.
    public let qualityTrend: [QualityTrendPoint]
    /// Highly-rated responses surfaced for review.
    public let bestOf: [BestOfItem]
    /// Schema version for forward-compatibility.
    public let schemaVersion: String

    public init(
        projectId: String,
        exportedAt: String,
        feedbackRecords: [FeedbackResponse],
        qualityTrend: [QualityTrendPoint],
        bestOf: [BestOfItem],
        schemaVersion: String = "1.0"
    ) {
        self.projectId = projectId
        self.exportedAt = exportedAt
        self.feedbackRecords = feedbackRecords
        self.qualityTrend = qualityTrend
        self.bestOf = bestOf
        self.schemaVersion = schemaVersion
    }
}
