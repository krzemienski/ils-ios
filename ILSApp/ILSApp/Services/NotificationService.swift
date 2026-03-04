import SwiftUI
import UIKit
import Observation
import UserNotifications
import ILSShared

/// Manages native iOS notifications for session events
@MainActor
@Observable
class NotificationService: NSObject {
    /// Whether notification permissions have been granted
    private(set) var isAuthorized: Bool = false

    /// Singleton instance for app-wide access
    static let shared = NotificationService()

    /// The notification center
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        // MEM-03: UNUserNotificationCenter.delegate is weak (per Apple docs), so no retain cycle.
        // NotificationService is a singleton — delegate assignment persists for app lifetime.
        center.delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - Permission Management

    /// Request notification permissions from the user
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)
        isAuthorized = granted
    }

    /// Check current authorization status
    private func checkAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Notification Posting

    /// Post a notification for a new message
    /// - Parameters:
    ///   - sessionId: The ID of the session where the message arrived
    ///   - sessionName: The name of the session
    ///   - messagePreview: A preview of the message content
    func postMessageNotification(
        sessionId: UUID,
        sessionName: String,
        messagePreview: String
    ) async {
        // Only post notification if app is not active in the foreground
        guard UIApplication.shared.applicationState != .active else { return }

        // Only post if authorized
        guard isAuthorized else { return }

        // Suppress during quiet hours
        guard !isInQuietHours() else { return }

        let content = UNMutableNotificationContent()
        content.title = sessionName
        content.body = messagePreview
        content.sound = .default

        // Store session ID in user info for notification handling
        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "type": "message"
        ]

        // Use session ID as identifier to replace previous notifications from same session
        let identifier = "message-\(sessionId.uuidString)"

        // Create request with immediate trigger
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.shared.error("Failed to post notification: \(error)", category: "notifications")
        }
    }

    /// Post a notification for streaming completion
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - sessionName: The name of the session
    func postStreamingCompleteNotification(
        sessionId: UUID,
        sessionName: String
    ) async {
        // Only post notification if app is not active in the foreground
        guard UIApplication.shared.applicationState != .active else { return }

        // Only post if authorized
        guard isAuthorized else { return }

        // Respect user preference
        guard UserDefaults.standard.bool(forKey: "notif_sessionCompleteAlerts") else { return }

        // Suppress during quiet hours
        guard !isInQuietHours() else { return }

        let content = UNMutableNotificationContent()
        content.title = sessionName
        content.body = "Response complete"
        content.sound = .default

        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "type": "streaming_complete"
        ]

        let identifier = "streaming-complete-\(sessionId.uuidString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.shared.error("Failed to post streaming notification: \(error)", category: "notifications")
        }
    }

    /// Post a notification for a session error
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - sessionName: The name of the session
    ///   - errorMessage: A brief description of the error
    func postSessionErrorNotification(
        sessionId: UUID,
        sessionName: String,
        errorMessage: String
    ) async {
        // Only post notification if app is not active in the foreground
        guard UIApplication.shared.applicationState != .active else { return }

        // Only post if authorized
        guard isAuthorized else { return }

        // Respect user preference
        guard UserDefaults.standard.bool(forKey: "notif_sessionErrorAlerts") else { return }

        // Suppress during quiet hours
        guard !isInQuietHours() else { return }

        let content = UNMutableNotificationContent()
        content.title = sessionName
        content.body = errorMessage
        content.sound = .defaultCritical

        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "type": "session_error"
        ]

        let identifier = "session-error-\(sessionId.uuidString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.shared.error("Failed to post error notification: \(error)", category: "notifications")
        }
    }

    // MARK: - Quiet Hours

    /// Returns true if the current time falls within the user-configured quiet hours window.
    private func isInQuietHours() -> Bool {
        guard UserDefaults.standard.bool(forKey: "notif_quietHoursEnabled") else { return false }
        let startHour = UserDefaults.standard.integer(forKey: "notif_quietStartHour")
        let endHour = UserDefaults.standard.integer(forKey: "notif_quietEndHour")
        let currentHour = Calendar.current.component(.hour, from: Date())
        // Handle wrap-around midnight (e.g. 22:00 – 07:00)
        if startHour <= endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            return currentHour >= startHour || currentHour < endHour
        }
    }

    // MARK: - Notification Removal

    /// Remove all delivered notifications for a session
    /// - Parameter sessionId: The session ID
    func removeNotifications(for sessionId: UUID) {
        let identifiers = [
            "message-\(sessionId.uuidString)",
            "streaming-complete-\(sessionId.uuidString)",
            "session-error-\(sessionId.uuidString)"
        ]
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Remove all delivered notifications
    func removeAllNotifications() {
        center.removeAllDeliveredNotifications()
    }

    /// Remove all pending notification requests
    func removePendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground.
    /// nonisolated because UNUserNotificationCenterDelegate is not @MainActor in the SDK.
    /// This method doesn't access any @MainActor state — just calls the completion handler.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Don't show notification banner when app is active
        // (we already show messages in the UI)
        completionHandler([])
    }

    /// Handle notification interaction (when user taps on notification).
    /// nonisolated because UNUserNotificationCenterDelegate is not @MainActor in the SDK.
    /// Hops to MainActor for NotificationCenter access.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract session ID and open the session
        if let sessionIdString = userInfo["sessionId"] as? String,
           let sessionId = UUID(uuidString: sessionIdString) {
            Task { @MainActor in
                // Post notification to open session
                // This will be handled by SessionsViewModel or the root view
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenSessionFromNotification"),
                    object: sessionId
                )
            }
        }

        completionHandler()
    }
}
