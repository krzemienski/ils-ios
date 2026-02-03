import Foundation

/// Represents an analytics event to be tracked
struct AnalyticsEvent: Codable, Sendable {
    let eventName: String
    let eventData: [String: String]
    let deviceId: String?
    let userId: UUID?
    let sessionId: UUID?
    let timestamp: Date

    init(
        eventName: String,
        eventData: [String: String] = [:],
        deviceId: String? = nil,
        userId: UUID? = nil,
        sessionId: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.eventName = eventName
        self.eventData = eventData
        self.deviceId = deviceId
        self.userId = userId
        self.sessionId = sessionId
        self.timestamp = timestamp
    }

    /// Convert eventData dictionary to JSON string for backend API
    func eventDataJSON() -> String {
        guard !eventData.isEmpty else {
            return "{}"
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            Logger.shared.error("Failed to serialize event data", error: error)
            return "{}"
        }
    }
}

// MARK: - Convenience Initializers

extension AnalyticsEvent {
    /// Track app launch
    static func appLaunch(deviceId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            eventName: "app_launch",
            eventData: ["platform": "ios"],
            deviceId: deviceId
        )
    }

    /// Track project creation
    static func projectCreated(projectId: UUID, deviceId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            eventName: "project_created",
            eventData: ["project_id": projectId.uuidString],
            deviceId: deviceId
        )
    }

    /// Track chat session start
    static func chatStarted(sessionId: UUID, projectId: UUID?, deviceId: String) -> AnalyticsEvent {
        var data: [String: String] = ["session_id": sessionId.uuidString]
        if let projectId = projectId {
            data["project_id"] = projectId.uuidString
        }

        return AnalyticsEvent(
            eventName: "chat_started",
            eventData: data,
            deviceId: deviceId,
            sessionId: sessionId
        )
    }

    /// Track message sent
    static func messageSent(sessionId: UUID, messageLength: Int, deviceId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            eventName: "message_sent",
            eventData: [
                "session_id": sessionId.uuidString,
                "message_length": String(messageLength)
            ],
            deviceId: deviceId,
            sessionId: sessionId
        )
    }

    /// Track error occurred
    static func errorOccurred(error: String, context: String, deviceId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            eventName: "error_occurred",
            eventData: [
                "error": error,
                "context": context
            ],
            deviceId: deviceId
        )
    }

    /// Track crash report
    static func crash(stackTrace: String, deviceId: String, osVersion: String) -> AnalyticsEvent {
        AnalyticsEvent(
            eventName: "crash",
            eventData: [
                "stack_trace": stackTrace,
                "os_version": osVersion,
                "platform": "ios"
            ],
            deviceId: deviceId
        )
    }
}
