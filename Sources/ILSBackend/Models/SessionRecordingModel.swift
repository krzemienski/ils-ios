import Fluent
import Vapor
import ILSShared

/// Fluent model for SessionRecording
final class SessionRecordingModel: Model, Content, @unchecked Sendable {
    static let schema = "session_recordings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "session_id")
    var session: SessionModel

    @OptionalField(key: "name")
    var name: String?

    @Field(key: "status")
    var status: String

    @Timestamp(key: "started_at", on: .create)
    var startedAt: Date?

    @OptionalField(key: "stopped_at")
    var stoppedAt: Date?

    @Field(key: "event_count")
    var eventCount: Int

    init() {}

    init(
        id: UUID? = nil,
        sessionId: UUID,
        name: String? = nil,
        status: RecordingStatus = .recording,
        eventCount: Int = 0
    ) {
        self.id = id
        self.$session.id = sessionId
        self.name = name
        self.status = status.rawValue
        self.eventCount = eventCount
    }

    /// Convert to shared SessionRecording type
    func toShared(sessionName: String? = nil, projectName: String? = nil) -> SessionRecording {
        let duration: Double?
        if let stopped = stoppedAt, let started = startedAt {
            duration = stopped.timeIntervalSince(started)
        } else {
            duration = nil
        }

        return SessionRecording(
            id: (id ?? UUID()).uuidString,
            sessionId: $session.id.uuidString,
            sessionName: sessionName,
            projectName: projectName,
            status: RecordingStatus(rawValue: status) ?? .recording,
            startedAt: startedAt ?? Date(),
            stoppedAt: stoppedAt,
            durationSeconds: duration,
            eventCount: eventCount,
            keyMomentCount: 0,
            isRedacted: false
        )
    }
}
