import Foundation

// MARK: - Activity Event Type

/// Classification of an activity event in the feed.
///
/// Covers all observable events produced by Claude Code sessions,
/// from user-driven messages to autonomous agent file changes.
public enum ActivityEventType: String, Codable, Sendable, CaseIterable {
    /// A user message was sent to a session.
    case messageSent = "message_sent"
    /// A response was received from Claude.
    case messageReceived = "message_received"
    /// A tool-use permission request is awaiting approval.
    case permissionRequest = "permission_request"
    /// An error occurred within the session.
    case error = "error"
    /// A session task or turn completed successfully.
    case completion = "completion"
    /// A file was created, modified, or deleted by the session.
    case fileChange = "file_change"
    /// A generic system-level event (startup, shutdown, reconnect).
    case systemEvent = "system_event"
}

// MARK: - Activity Event Severity

/// Severity level of an activity event.
public enum ActivityEventSeverity: String, Codable, Sendable, CaseIterable {
    /// Informational — no action required.
    case info = "info"
    /// Warning — may need attention.
    case warning = "warning"
    /// Error — action likely required.
    case error = "error"
}

// MARK: - Activity Event

/// A single event in the cross-session activity feed.
///
/// Each event is linked to the originating session and optionally to a specific
/// message so the user can tap-to-navigate directly into context.
public struct ActivityEvent: Codable, Sendable, Identifiable {
    /// Unique event identifier (UUID string).
    public let id: String
    /// Session that produced this event.
    public let sessionId: String
    /// Human-readable session name, if available.
    public let sessionName: String?
    /// Project the session belongs to, if assigned.
    public let projectName: String?
    /// Categorisation of this event.
    public let eventType: ActivityEventType
    /// Short title suitable for list display.
    public let title: String
    /// Optional longer description or preview of event content.
    public let detail: String?
    /// When the event occurred (UTC).
    public let timestamp: Date
    /// Severity used for visual styling and filtering.
    public let severity: ActivityEventSeverity
    /// Whether the user has seen this event.
    public let isRead: Bool
    /// Linked message ID for tap-to-navigate into the session transcript.
    public let messageId: String?

    public init(
        id: String,
        sessionId: String,
        sessionName: String? = nil,
        projectName: String? = nil,
        eventType: ActivityEventType,
        title: String,
        detail: String? = nil,
        timestamp: Date,
        severity: ActivityEventSeverity = .info,
        isRead: Bool = false,
        messageId: String? = nil
    ) {
        precondition(!id.isEmpty, "ActivityEvent id must not be empty")
        precondition(!sessionId.isEmpty, "ActivityEvent sessionId must not be empty")
        precondition(!title.isEmpty, "ActivityEvent title must not be empty")
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.projectName = projectName
        self.eventType = eventType
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
        self.severity = severity
        self.isRead = isRead
        self.messageId = messageId
    }
}

// MARK: - Activity Feed Filter

/// Query parameters for fetching a filtered activity feed.
///
/// All fields are optional — omitting a field applies no constraint for that dimension.
public struct ActivityFeedFilter: Codable, Sendable {
    /// Restrict to events of these types.
    public let eventTypes: [ActivityEventType]?
    /// Restrict to a single session.
    public let sessionId: String?
    /// Restrict to sessions belonging to this project.
    public let projectName: String?
    /// Restrict to events at or above this severity.
    public let severity: ActivityEventSeverity?
    /// Return only events that occurred at or after this date.
    public let since: Date?
    /// Maximum number of events to return.
    public let limit: Int?

    public init(
        eventTypes: [ActivityEventType]? = nil,
        sessionId: String? = nil,
        projectName: String? = nil,
        severity: ActivityEventSeverity? = nil,
        since: Date? = nil,
        limit: Int? = nil
    ) {
        if let limit { precondition(limit > 0, "ActivityFeedFilter limit must be positive") }
        self.eventTypes = eventTypes
        self.sessionId = sessionId
        self.projectName = projectName
        self.severity = severity
        self.since = since
        self.limit = limit
    }
}

// MARK: - Activity Feed Response

/// Paginated response from the activity feed endpoint.
public struct ActivityFeedResponse: Codable, Sendable {
    /// Ordered list of events (newest first).
    public let events: [ActivityEvent]
    /// Total number of matching events (before pagination).
    public let totalCount: Int
    /// Number of unread events across all sessions.
    public let unreadCount: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        events: [ActivityEvent],
        totalCount: Int,
        unreadCount: Int,
        hasMore: Bool = false
    ) {
        precondition(totalCount >= 0, "ActivityFeedResponse totalCount must be non-negative")
        precondition(unreadCount >= 0, "ActivityFeedResponse unreadCount must be non-negative")
        self.events = events
        self.totalCount = totalCount
        self.unreadCount = unreadCount
        self.hasMore = hasMore
    }
}
