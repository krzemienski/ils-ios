import Foundation
import SwiftUI

/// Analytics service for tracking user events and sending to backend
/// Respects privacy settings and queues events for batch sending
actor AnalyticsService {
    static let shared = AnalyticsService()

    private let apiClient: APIClient
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 50
    private let flushInterval: TimeInterval = 60 // seconds
    private var flushTimer: Task<Void, Never>?
    private let deviceId: String

    private init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        self.deviceId = Self.getOrCreateDeviceId()

        // Start periodic flush timer
        startFlushTimer()
    }

    // MARK: - Public API

    /// Track an analytics event
    /// Events are queued and sent in batches to reduce network overhead
    func track(_ event: AnalyticsEvent) async {
        // Check if analytics is enabled
        guard isAnalyticsEnabled() else {
            Logger.shared.debug("Analytics disabled, skipping event: \(event.eventName)")
            return
        }

        // Add event to queue
        eventQueue.append(event)
        Logger.shared.debug("Queued analytics event: \(event.eventName) (queue size: \(eventQueue.count))")

        // Flush if queue is full
        if eventQueue.count >= maxQueueSize {
            await flush()
        }
    }

    /// Track an event with a custom name and data
    func track(eventName: String, data: [String: String] = [:]) async {
        let event = AnalyticsEvent(
            eventName: eventName,
            eventData: data,
            deviceId: deviceId
        )
        await track(event)
    }

    /// Manually flush all queued events to the backend
    func flush() async {
        guard !eventQueue.isEmpty else {
            return
        }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        Logger.shared.info("Flushing \(eventsToSend.count) analytics events to backend")

        // Send events one by one (could be optimized to batch endpoint if backend supports it)
        for event in eventsToSend {
            await sendEvent(event)
        }
    }

    /// Get the device ID for this device
    func getDeviceId() -> String {
        return deviceId
    }

    // MARK: - Private Methods

    private func sendEvent(_ event: AnalyticsEvent) async {
        do {
            // Create request matching backend API
            let request = CreateAnalyticsEventRequest(
                eventName: event.eventName,
                eventData: event.eventDataJSON(),
                deviceId: event.deviceId,
                userId: event.userId,
                sessionId: event.sessionId?.uuidString
            )

            // Send to backend
            let _: CreatedResponse = try await apiClient.post("/analytics/events", body: request)
            Logger.shared.debug("Successfully sent analytics event: \(event.eventName)")

        } catch {
            Logger.shared.error("Failed to send analytics event: \(event.eventName)", error: error)

            // Re-queue the event on failure (up to max queue size)
            if eventQueue.count < maxQueueSize {
                eventQueue.append(event)
            }
        }
    }

    private func startFlushTimer() {
        flushTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flush()
            }
        }
    }

    private func isAnalyticsEnabled() -> Bool {
        // Check UserDefaults for analytics opt-out setting
        // Default to true (enabled) if not set
        return UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
    }

    private static func getOrCreateDeviceId() -> String {
        let key = "deviceId"

        // Check if device ID already exists
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }

        // Generate new device ID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        Logger.shared.info("Generated new device ID: \(newId)")

        return newId
    }
}

// MARK: - Backend API Types

/// Request to create an analytics event
private struct CreateAnalyticsEventRequest: Codable, Sendable {
    let eventName: String
    let eventData: String
    let deviceId: String?
    let userId: UUID?
    let sessionId: String?
}

/// Response from creating an analytics event
private struct CreatedResponse: Codable, Sendable {
    let id: UUID
    let createdAt: Date
}
