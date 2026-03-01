import SwiftUI

#if os(iOS)
import ActivityKit

// MARK: - ChatViewModel Live Activity Extension

extension ChatViewModel {

    /// Start a Live Activity for the current chat streaming session.
    ///
    /// Creates a new `Activity<ChatStreamingAttributes>` that appears on the lock screen
    /// and Dynamic Island while Claude streams a response.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string for deep-link navigation to the session
    ///   - sessionName: Display name for the session
    ///   - model: Claude model being used (e.g., "Sonnet")
    @available(iOS 16.2, *)
    func startLiveActivity(sessionId: String, sessionName: String, model: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.shared.info("Live Activities not enabled by user", category: "liveActivity")
            return
        }

        let attributes = ChatStreamingAttributes(
            sessionId: sessionId,
            sessionName: sessionName,
            model: model
        )

        let initialState = ChatStreamingAttributes.ContentState(
            status: .streaming,
            messagePreview: "",
            tokenCount: 0,
            cost: 0.0,
            elapsedSeconds: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            AppLogger.shared.info(
                "Started Live Activity: \(activity.id)",
                category: "liveActivity"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to start Live Activity: \(error)",
                category: "liveActivity"
            )
        }
    }

    /// Update the running Live Activity with new streaming data.
    ///
    /// Finds the most recent `ChatStreamingAttributes` activity and updates its state.
    ///
    /// - Parameters:
    ///   - preview: Truncated preview of the assistant message (max ~120 chars)
    ///   - tokens: Current approximate token count
    ///   - cost: Running cost in USD
    @available(iOS 16.2, *)
    func updateLiveActivity(preview: String, tokens: Int, cost: Double) {
        let elapsed: Int
        if let start = streamStartTime {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = 0
        }

        let updatedState = ChatStreamingAttributes.ContentState(
            status: .streaming,
            messagePreview: String(preview.prefix(120)),
            tokenCount: tokens,
            cost: cost,
            elapsedSeconds: elapsed
        )

        Task {
            for activity in Activity<ChatStreamingAttributes>.activities {
                await activity.update(
                    ActivityContent(state: updatedState, staleDate: nil)
                )
            }
        }
    }

    /// Update Live Activity with a specific status, preserving current preview and token data.
    ///
    /// Used for state transitions such as waiting for user input (permission requests).
    ///
    /// - Parameter status: The new status to display in the Live Activity.
    @available(iOS 16.2, *)
    func updateLiveActivityStatus(_ status: SessionActivityStatus) {
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

        let updatedState = ChatStreamingAttributes.ContentState(
            status: status,
            messagePreview: preview,
            tokenCount: streamTokenCount,
            cost: currentStreamingMessage?.cost ?? 0.0,
            elapsedSeconds: elapsed
        )

        Task {
            for activity in Activity<ChatStreamingAttributes>.activities {
                await activity.update(
                    ActivityContent(state: updatedState, staleDate: nil)
                )
            }
        }
    }

    /// End all running chat streaming Live Activities.
    ///
    /// Sets `status` to `.completed` and dismisses the activity after a brief delay
    /// so the user can see the final stats.
    @available(iOS 16.2, *)
    func endLiveActivity() {
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

        Task {
            for activity in Activity<ChatStreamingAttributes>.activities {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .after(.now + 30)
                )
            }
        }
    }
}

#endif
