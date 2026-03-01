import Foundation

#if os(iOS)
import ActivityKit

/// Manages one `Activity<ChatStreamingAttributes>` per active session UUID.
///
/// Ensures each session maps to exactly one Live Activity, preventing duplicate
/// activities when multiple Claude Code sessions stream simultaneously.
///
/// Usage:
/// ```swift
/// // Start
/// LiveActivityManager.shared.startActivity(sessionId: id, sessionName: name, model: model)
/// // Update
/// LiveActivityManager.shared.updateActivity(sessionId: id, state: newState)
/// // End
/// LiveActivityManager.shared.endActivity(sessionId: id, finalState: finalState)
/// ```
@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    /// Maps session UUID string → its running Live Activity.
    private var activities: [String: Activity<ChatStreamingAttributes>] = [:]

    private init() {}

    // MARK: - Public API

    /// Start a Live Activity for the given session.
    ///
    /// If an activity already exists for this session, no duplicate is created.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string identifying the session
    ///   - sessionName: Display name shown in the Live Activity
    ///   - model: Claude model name (e.g. "Sonnet")
    func startActivity(sessionId: String, sessionName: String, model: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.shared.info("Live Activities not enabled by user", category: "liveActivity")
            return
        }

        guard activities[sessionId] == nil else {
            AppLogger.shared.info(
                "Live Activity already running for session \(sessionId)",
                category: "liveActivity"
            )
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
            activities[sessionId] = activity
            AppLogger.shared.info(
                "Started Live Activity \(activity.id) for session \(sessionId)",
                category: "liveActivity"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to start Live Activity for session \(sessionId): \(error)",
                category: "liveActivity"
            )
        }
    }

    /// Update the Live Activity for the given session with new content state.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string identifying the session
    ///   - state: New content state to display
    func updateActivity(sessionId: String, state: ChatStreamingAttributes.ContentState) {
        guard let activity = activities[sessionId] else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// End the Live Activity for the given session.
    ///
    /// Displays the final state for 30 seconds before dismissing.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string identifying the session
    ///   - finalState: Final content state to display before dismissal
    func endActivity(sessionId: String, finalState: ChatStreamingAttributes.ContentState) {
        guard let activity = activities.removeValue(forKey: sessionId) else { return }
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 30)
            )
        }
        AppLogger.shared.info(
            "Ended Live Activity for session \(sessionId)",
            category: "liveActivity"
        )
    }
}

#endif
