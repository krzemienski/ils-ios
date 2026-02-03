import Fluent
import Vapor

/// Fluent model for Analytics Event persistence
final class AnalyticsEventModel: Model, Content, @unchecked Sendable {
    static let schema = "analytics_events"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "event_name")
    var eventName: String

    @Field(key: "event_data")
    var eventData: String

    @OptionalField(key: "device_id")
    var deviceId: String?

    @OptionalField(key: "user_id")
    var userId: UUID?

    @OptionalField(key: "session_id")
    var sessionId: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        eventName: String,
        eventData: String,
        deviceId: String? = nil,
        userId: UUID? = nil,
        sessionId: String? = nil
    ) {
        self.id = id
        self.eventName = eventName
        self.eventData = eventData
        self.deviceId = deviceId
        self.userId = userId
        self.sessionId = sessionId
    }
}
