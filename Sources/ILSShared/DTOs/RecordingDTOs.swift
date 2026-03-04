import Foundation

// MARK: - Recording Status

/// Lifecycle state of a session recording.
public enum RecordingStatus: String, Codable, Sendable, CaseIterable {
    /// Recording is actively capturing events.
    case recording = "recording"
    /// Recording is temporarily paused.
    case paused = "paused"
    /// Recording has been stopped and is stored.
    case stopped = "stopped"
    /// Recording is being processed (e.g. export).
    case processing = "processing"
    /// Recording is ready for playback or export.
    case ready = "ready"
    /// Recording failed and cannot be used.
    case failed = "failed"
}

// MARK: - Recording Event Type

/// Classification of a captured event within a session recording.
public enum RecordingEventType: String, Codable, Sendable, CaseIterable {
    /// A user message was sent to the session.
    case messageSent = "message_sent"
    /// A response was received from Claude.
    case messageReceived = "message_received"
    /// A file was created, modified, or deleted.
    case fileChange = "file_change"
    /// A tool-use permission request occurred.
    case permissionRequest = "permission_request"
    /// A permission request was granted or denied.
    case permissionDecision = "permission_decision"
    /// An error occurred within the session.
    case error = "error"
    /// A session task or turn completed.
    case completion = "completion"
    /// The session was started.
    case sessionStart = "session_start"
    /// The session was ended.
    case sessionEnd = "session_end"
    /// A generic system-level event.
    case systemEvent = "system_event"
}

// MARK: - Recording Event

/// A single captured event within a session recording.
///
/// Each event stores its offset from the recording start so playback can
/// reconstruct the exact temporal progression of the session.
public struct RecordingEvent: Codable, Sendable, Identifiable {
    /// Unique event identifier (UUID string).
    public let id: String
    /// Recording this event belongs to.
    public let recordingId: String
    /// Categorisation of the event.
    public let eventType: RecordingEventType
    /// Seconds elapsed since the recording started.
    public let offsetSeconds: Double
    /// Wall-clock time when the event occurred (UTC).
    public let timestamp: Date
    /// Short human-readable title for display.
    public let title: String
    /// Optional longer description or content preview.
    public let detail: String?
    /// Arbitrary metadata payload (file paths, message IDs, etc.).
    public let metadata: [String: String]?
    /// Whether this event is highlighted as a key moment.
    public let isKeyMoment: Bool

    public init(
        id: String,
        recordingId: String,
        eventType: RecordingEventType,
        offsetSeconds: Double,
        timestamp: Date,
        title: String,
        detail: String? = nil,
        metadata: [String: String]? = nil,
        isKeyMoment: Bool = false
    ) {
        precondition(!id.isEmpty, "RecordingEvent id must not be empty")
        precondition(!recordingId.isEmpty, "RecordingEvent recordingId must not be empty")
        precondition(!title.isEmpty, "RecordingEvent title must not be empty")
        precondition(offsetSeconds >= 0, "RecordingEvent offsetSeconds must be non-negative")
        self.id = id
        self.recordingId = recordingId
        self.eventType = eventType
        self.offsetSeconds = offsetSeconds
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.metadata = metadata
        self.isKeyMoment = isKeyMoment
    }
}

// MARK: - Session Recording

/// A complete session recording with metadata and event summary.
///
/// Stores events by reference — the actual event list is fetched separately
/// to keep list responses lightweight.
public struct SessionRecording: Codable, Sendable, Identifiable {
    /// Unique recording identifier (UUID string).
    public let id: String
    /// Session that was recorded.
    public let sessionId: String
    /// Human-readable session name at the time of recording.
    public let sessionName: String?
    /// Project the session belonged to, if any.
    public let projectName: String?
    /// Current lifecycle state of the recording.
    public let status: RecordingStatus
    /// When the recording started (UTC).
    public let startedAt: Date
    /// When the recording stopped, if applicable.
    public let stoppedAt: Date?
    /// Total duration of the recording in seconds.
    public let durationSeconds: Double?
    /// Total number of events captured.
    public let eventCount: Int
    /// Number of key moments identified within the recording.
    public let keyMomentCount: Int
    /// Whether sensitive content has been redacted for sharing.
    public let isRedacted: Bool

    public init(
        id: String,
        sessionId: String,
        sessionName: String? = nil,
        projectName: String? = nil,
        status: RecordingStatus,
        startedAt: Date,
        stoppedAt: Date? = nil,
        durationSeconds: Double? = nil,
        eventCount: Int = 0,
        keyMomentCount: Int = 0,
        isRedacted: Bool = false
    ) {
        precondition(!id.isEmpty, "SessionRecording id must not be empty")
        precondition(!sessionId.isEmpty, "SessionRecording sessionId must not be empty")
        precondition(eventCount >= 0, "SessionRecording eventCount must be non-negative")
        precondition(keyMomentCount >= 0, "SessionRecording keyMomentCount must be non-negative")
        if let duration = durationSeconds {
            precondition(duration >= 0, "SessionRecording durationSeconds must be non-negative")
        }
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.projectName = projectName
        self.status = status
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.durationSeconds = durationSeconds
        self.eventCount = eventCount
        self.keyMomentCount = keyMomentCount
        self.isRedacted = isRedacted
    }
}

// MARK: - Playback Speed

/// Supported playback speed multipliers for recording replay.
public enum PlaybackSpeed: Double, Codable, Sendable, CaseIterable {
    case oneX   = 1.0
    case twoX   = 2.0
    case fiveX  = 5.0
    case tenX   = 10.0

    /// Human-readable label for the speed.
    public var label: String {
        switch self {
        case .oneX:  return "1×"
        case .twoX:  return "2×"
        case .fiveX: return "5×"
        case .tenX:  return "10×"
        }
    }
}

// MARK: - Start Recording Request

/// Request body to begin recording a session.
public struct StartRecordingRequest: Codable, Sendable {
    /// ID of the session to record.
    public let sessionId: String

    public init(sessionId: String) {
        precondition(!sessionId.isEmpty, "StartRecordingRequest sessionId must not be empty")
        self.sessionId = sessionId
    }
}

// MARK: - Stop Recording Request

/// Request body to stop an active recording.
public struct StopRecordingRequest: Codable, Sendable {
    /// ID of the recording to stop.
    public let recordingId: String

    public init(recordingId: String) {
        precondition(!recordingId.isEmpty, "StopRecordingRequest recordingId must not be empty")
        self.recordingId = recordingId
    }
}

// MARK: - Recording List Response

/// Paginated list of session recordings.
public struct RecordingListResponse: Codable, Sendable {
    /// Ordered list of recordings (newest first).
    public let recordings: [SessionRecording]
    /// Total number of available recordings (before pagination).
    public let totalCount: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        recordings: [SessionRecording],
        totalCount: Int,
        hasMore: Bool = false
    ) {
        precondition(totalCount >= 0, "RecordingListResponse totalCount must be non-negative")
        self.recordings = recordings
        self.totalCount = totalCount
        self.hasMore = hasMore
    }
}

// MARK: - Recording Events Response

/// Full event list for a recording, used during playback.
public struct RecordingEventsResponse: Codable, Sendable {
    /// The recording these events belong to.
    public let recording: SessionRecording
    /// All captured events in chronological order.
    public let events: [RecordingEvent]

    public init(recording: SessionRecording, events: [RecordingEvent]) {
        self.recording = recording
        self.events = events
    }
}

// MARK: - Export Recording Request

/// Request to export a recording to a shareable format.
public struct ExportRecordingRequest: Codable, Sendable {
    /// ID of the recording to export.
    public let recordingId: String
    /// Whether to redact sensitive content before exporting.
    public let redactSensitiveContent: Bool

    public init(recordingId: String, redactSensitiveContent: Bool = false) {
        precondition(!recordingId.isEmpty, "ExportRecordingRequest recordingId must not be empty")
        self.recordingId = recordingId
        self.redactSensitiveContent = redactSensitiveContent
    }
}

// MARK: - Export Recording Response

/// Response from a recording export request.
public struct ExportRecordingResponse: Codable, Sendable {
    /// URL where the exported recording can be downloaded or viewed.
    public let exportUrl: String
    /// MIME type of the exported file (e.g. "application/json").
    public let contentType: String
    /// When the export URL expires (UTC), if applicable.
    public let expiresAt: Date?

    public init(exportUrl: String, contentType: String, expiresAt: Date? = nil) {
        precondition(!exportUrl.isEmpty, "ExportRecordingResponse exportUrl must not be empty")
        precondition(!contentType.isEmpty, "ExportRecordingResponse contentType must not be empty")
        self.exportUrl = exportUrl
        self.contentType = contentType
        self.expiresAt = expiresAt
    }
}
