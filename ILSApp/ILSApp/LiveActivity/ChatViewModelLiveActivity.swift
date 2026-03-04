import SwiftUI

#if os(iOS)
import ActivityKit

// MARK: - ChatViewModel Live Activity Extension

extension ChatViewModel {

    /// Start a Live Activity for the current chat streaming session.
    ///
    /// Delegates to `LiveActivityManager` which tracks one activity per session UUID,
    /// preventing duplicates when multiple sessions stream simultaneously.
    ///
    /// The caller should set `LiveActivityManager.shared.onPushTokenRegistered` before
    /// this call (done in `ChatViewModel.setupBindings`) so the APNs token is
    /// registered with the backend for background push updates.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string for deep-link navigation to the session
    ///   - sessionName: Display name for the session
    ///   - model: Claude model being used (e.g., "Sonnet")
    @available(iOS 16.2, *)
    func startLiveActivity(sessionId: String, sessionName: String, model: String) {
        LiveActivityManager.shared.startActivity(
            sessionId: sessionId,
            sessionName: sessionName,
            model: model
        )
    }

    /// Register the APNs push token callback on `LiveActivityManager`.
    ///
    /// Must be called with a non-nil `apiClient` before `startLiveActivity` so the
    /// activity push token is forwarded to the backend as soon as ActivityKit
    /// generates it. Registers a new closure on each call (one callback at a time).
    ///
    /// - Parameter apiClient: The authenticated `APIClient` instance for REST calls.
    @available(iOS 16.2, *)
    func registerLiveActivityPushTokenCallback(apiClient: APIClient) {
        LiveActivityManager.shared.onPushTokenRegistered = { sid, token in
            Task {
                do {
                    try await apiClient.registerLiveActivityToken(token, forSession: sid)
                    AppLogger.shared.info(
                        "Registered Live Activity push token for session \(sid)",
                        category: "liveActivity"
                    )
                } catch {
                    AppLogger.shared.error(
                        "Failed to register Live Activity push token: \(error)",
                        category: "liveActivity"
                    )
                }
            }
        }
    }

    /// Update the running Live Activity with new streaming data.
    ///
    /// - Parameters:
    ///   - preview: Truncated preview of the assistant message (max ~120 chars)
    ///   - tokens: Current approximate token count
    ///   - cost: Running cost in USD
    @available(iOS 16.2, *)
    func updateLiveActivity(preview: String, tokens: Int, cost: Double) {
        guard let sid = sessionId?.uuidString.lowercased() else { return }
        let elapsed: Int
        if let start = streamStartTime {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = 0
        }

        let state = ChatStreamingAttributes.ContentState(
            status: .streaming,
            messagePreview: String(preview.prefix(120)),
            tokenCount: tokens,
            cost: cost,
            elapsedSeconds: elapsed
        )

        LiveActivityManager.shared.updateActivity(sessionId: sid, state: state)
    }

    /// Update Live Activity with a specific status, preserving current preview and token data.
    ///
    /// Used for state transitions such as waiting for user input (permission requests).
    ///
    /// - Parameter status: The new status to display in the Live Activity.
    @available(iOS 16.2, *)
    func updateLiveActivityStatus(_ status: SessionActivityStatus) {
        guard let sid = sessionId?.uuidString.lowercased() else { return }
        let elapsed: Int
        if let start = streamStartTime {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = 0
        }

        let preview: String
        if let lastMsg = messages.last, !lastMsg.isUser {
            preview = String(lastMsg.text.prefix(120))
        } else {
            preview = ""
        }

        let state = ChatStreamingAttributes.ContentState(
            status: status,
            messagePreview: preview,
            tokenCount: streamTokenCount,
            cost: currentStreamingMessage?.cost ?? 0.0,
            elapsedSeconds: elapsed
        )

        LiveActivityManager.shared.updateActivity(sessionId: sid, state: state)
    }

    /// End the running Live Activity for this session.
    ///
    /// Sets `status` to `.completed` and dismisses the activity after a brief delay
    /// so the user can see the final stats.
    @available(iOS 16.2, *)
    func endLiveActivity() {
        guard let sid = sessionId?.uuidString.lowercased() else { return }
        let finalTokens = streamTokenCount
        let finalCost = currentStreamingMessage?.cost ?? 0.0
        let finalPreview: String
        if let lastMessage = messages.last, !lastMessage.isUser {
            finalPreview = String(lastMessage.text.prefix(120))
        } else {
            finalPreview = ""
        }

        let elapsed: Int
        if let start = streamStartTime {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = 0
        }

        let finalState = ChatStreamingAttributes.ContentState(
            status: .completed,
            messagePreview: finalPreview,
            tokenCount: finalTokens,
            cost: finalCost,
            elapsedSeconds: elapsed
        )

        LiveActivityManager.shared.endActivity(sessionId: sid, finalState: finalState)
    }
}

#endif
