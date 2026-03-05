import SwiftUI
import AppKit
import Observation
import UserNotifications
import ILSShared

/// Manages native macOS notifications for message updates
@MainActor
@Observable
class NotificationManager: NSObject {
    /// Whether notification permissions have been granted
    private(set) var isAuthorized: Bool = false

    /// Singleton instance for app-wide access
    static let shared = NotificationManager()

    /// The notification center
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        // MEM-03: UNUserNotificationCenter.delegate is weak (per Apple docs), so no retain cycle.
        // NotificationManager is a singleton — delegate assignment persists for app lifetime.
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
        // Only post notification if app is not frontmost
        guard !NSApplication.shared.isActive else { return }

        // Only post if authorized
        guard isAuthorized else { return }

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
        // Only post notification if app is not frontmost
        guard !NSApplication.shared.isActive else { return }

        // Only post if authorized
        guard isAuthorized else { return }

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

    /// Post a notification for an automation rule trigger
    /// - Parameters:
    ///   - ruleName: The name of the automation rule that triggered
    ///   - message: The notification message from the rule configuration
    ///   - sessionId: The ID of the session where the rule triggered
    ///   - sessionName: Optional name of the session
    func postAutomationRuleNotification(
        ruleName: String,
        message: String,
        sessionId: UUID,
        sessionName: String? = nil
    ) async {
        // Only post notification if app is not frontmost
        guard !NSApplication.shared.isActive else { return }

        // Only post if authorized
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = ruleName
        content.body = message
        content.sound = .default

        // Store session ID and rule info in user info for notification handling
        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "type": "automation_rule",
            "ruleName": ruleName
        ]

        // Use rule name + session ID for identifier to allow multiple rule notifications
        // but replace previous notifications from the same rule for the same session
        let identifier = "automation-rule-\(ruleName.replacingOccurrences(of: " ", with: "-"))-\(sessionId.uuidString)"

        // Create request with immediate trigger
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.shared.error("Failed to post automation rule notification: \(error)", category: "notifications")
        }
    }

    /// Remove all delivered notifications for a session
    /// - Parameter sessionId: The session ID
    func removeNotifications(for sessionId: UUID) {
        // Note: We don't remove automation rule notifications here because they may contain
        // important information. Users can dismiss them manually or they'll be cleared
        // when removeAllNotifications() is called.
        let identifiers = [
            "message-\(sessionId.uuidString)",
            "streaming-complete-\(sessionId.uuidString)"
        ]
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Remove all notifications
    func removeAllNotifications() {
        center.removeAllDeliveredNotifications()
    }

    /// Remove all pending notification requests
    func removePendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
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

    /// Handle notification interaction (when user clicks on notification).
    /// nonisolated because UNUserNotificationCenterDelegate is not @MainActor in the SDK.
    /// Hops to MainActor for NSApplication and NotificationCenter access.
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
                // This will be handled by MacContentView or SessionsViewModel
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenSessionFromNotification"),
                    object: sessionId
                )

                // Bring app to front
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }

        completionHandler()
    }
}
