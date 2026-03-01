import SwiftUI

#if os(iOS)
import ActivityKit
import WidgetKit

// MARK: - Session Activity Status

/// Represents the current streaming/execution status of a session shown in the Live Activity.
///
/// This enum replaces the old `isStreaming: Bool` to provide richer status display,
/// enabling distinct UI treatment for streaming, waiting, complete, and error states.
enum SessionActivityStatus: String, Codable, Hashable {
    /// Claude is actively generating a response (tokens flowing).
    case streaming
    /// Claude is awaiting user input (tool use prompt, permission request, etc.).
    case waitingForInput
    /// Response generation completed successfully.
    case completed
    /// Session ended with an error.
    case error
}

// MARK: - Activity Attributes

/// Defines the static and dynamic data for a chat streaming Live Activity.
///
/// Static data (set once at activity start):
/// - `sessionId`: UUID string for deep-link navigation to the session
/// - `sessionName`: Human-readable session name
/// - `model`: Claude model being used (e.g., "Sonnet", "Opus")
///
/// Dynamic data (updated during streaming via `ContentState`):
/// - `status`: Current activity status (streaming, waitingForInput, completed, error)
/// - `messagePreview`: Truncated preview of the response text
/// - `tokenCount`: Approximate token count of the response
/// - `cost`: Running cost in USD
/// - `elapsedSeconds`: Seconds since streaming started
struct ChatStreamingAttributes: ActivityAttributes {
    /// UUID string for deep-link navigation (e.g., `ils://session/<sessionId>`).
    let sessionId: String
    let sessionName: String
    let model: String

    struct ContentState: Codable, Hashable {
        var status: SessionActivityStatus
        var messagePreview: String
        var tokenCount: Int
        var cost: Double
        var elapsedSeconds: Int
    }
}

// MARK: - Theme Colors (Widget-safe, no Environment access)

/// Static color constants matching the Obsidian/Cyberpunk dark aesthetic.
/// WidgetKit views cannot access SwiftUI `@Environment`, so colors are declared as constants.
private enum LiveActivityColors {
    static let background = Color(hex: "0A0A0F")
    static let backgroundSecondary = Color(hex: "111118")
    static let accent = Color(hex: "00D4FF") // Cyan accent (Cyberpunk)
    static let accentSecondary = Color(hex: "FF6933") // Orange accent (Obsidian)
    static let textPrimary = Color(hex: "E8ECF0")
    static let textSecondary = Color(hex: "888899")
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let destructive = Color(hex: "EF4444")
    static let border = Color(hex: "1A1A2E")
}

// MARK: - Lock Screen Widget View

/// Lock screen presentation for the chat streaming Live Activity.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────────┐
/// │ [icon] Session Name      model badge │
/// │ Claude is responding...              │
/// │ "Preview of the message text..."     │
/// │ 1,234 tokens              $0.0042    │
/// └──────────────────────────────────────┘
/// ```
@available(iOS 16.2, *)
struct ChatStreamingLockScreenView: View {
    let context: ActivityViewContext<ChatStreamingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: session name + model badge
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiveActivityColors.accent)

                Text(context.attributes.sessionName)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(LiveActivityColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(context.attributes.model)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(LiveActivityColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(LiveActivityColors.accent.opacity(0.15))
                    )
            }

            // Status line
            statusLineView(for: context.state.status)

            // Message preview
            if !context.state.messagePreview.isEmpty {
                Text(context.state.messagePreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(LiveActivityColors.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            // Stats row: tokens + cost
            HStack {
                Label {
                    Text(formatTokenCount(context.state.tokenCount))
                        .font(.caption.weight(.medium).monospaced())
                } icon: {
                    Image(systemName: "number.square")
                        .font(.caption)
                }
                .foregroundStyle(LiveActivityColors.textSecondary)

                Spacer()

                if context.state.elapsedSeconds > 0 {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.caption.weight(.medium).monospaced())
                        .foregroundStyle(LiveActivityColors.textSecondary)

                    Spacer()
                }

                Text(formatCost(context.state.cost))
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(LiveActivityColors.accent)
            }
        }
        .padding(16)
        .background(LiveActivityColors.background)
    }

    @ViewBuilder
    private func statusLineView(for status: SessionActivityStatus) -> some View {
        switch status {
        case .streaming:
            HStack(spacing: 4) {
                Text("Claude is responding")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiveActivityColors.success)
                StreamingDotsView()
            }
        case .waitingForInput:
            HStack(spacing: 4) {
                Image(systemName: "hand.raised")
                    .font(.footnote)
                    .foregroundStyle(LiveActivityColors.warning)
                Text("Waiting for input")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiveActivityColors.warning)
            }
        case .completed:
            Text("Response complete")
                .font(.footnote.weight(.medium))
                .foregroundStyle(LiveActivityColors.textSecondary)
        case .error:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(LiveActivityColors.destructive)
                Text("Session error")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiveActivityColors.destructive)
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk tokens", Double(count) / 1000.0)
        }
        return "\(count) tokens"
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        }
        return String(format: "$%.2f", cost)
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

/// Animated dots to indicate streaming is in progress.
@available(iOS 16.2, *)
private struct StreamingDotsView: View {
    @State private var dotCount = 0
    @State private var timer: Timer?

    var body: some View {
        Text(String(repeating: ".", count: (dotCount % 3) + 1))
            .font(.footnote.weight(.medium))
            .foregroundStyle(LiveActivityColors.success)
            .frame(width: 20, alignment: .leading)
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    dotCount += 1
                }
                timer?.tolerance = 0.3  // Enable timer coalescing for energy efficiency
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// MARK: - Dynamic Island Views

/// Compact leading view for Dynamic Island (small brain icon).
@available(iOS 16.2, *)
struct ChatStreamingCompactLeading: View {
    var body: some View {
        Image(systemName: "brain.head.profile")
            .font(.caption)
            .foregroundStyle(LiveActivityColors.accent)
    }
}

/// Compact trailing view for Dynamic Island (token count).
@available(iOS 16.2, *)
struct ChatStreamingCompactTrailing: View {
    let tokenCount: Int

    var body: some View {
        Text(tokenCount >= 1000
             ? String(format: "%.1fk", Double(tokenCount) / 1000.0)
             : "\(tokenCount)")
            .font(.caption.weight(.medium).monospaced())
            .foregroundStyle(LiveActivityColors.textPrimary)
    }
}

/// Expanded view for Dynamic Island.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────────┐
/// │ [icon]  Session Name                 │
/// │ Claude is responding...     $0.0042  │
/// │ 1,234 tokens                  0:42   │
/// └──────────────────────────────────────┘
/// ```
@available(iOS 16.2, *)
struct ChatStreamingExpandedView: View {
    let attributes: ChatStreamingAttributes
    let state: ChatStreamingAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: icon + session name
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiveActivityColors.accent)

                Text(attributes.sessionName)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(LiveActivityColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(attributes.model)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(LiveActivityColors.accent.opacity(0.8))
            }

            // Middle row: status + cost
            HStack {
                expandedStatusView(for: state.status)

                Spacer()

                Text(formatCost(state.cost))
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(LiveActivityColors.accent)
            }

            // Bottom row: tokens + elapsed
            HStack {
                Text(formatTokenCount(state.tokenCount))
                    .font(.caption.monospaced())
                    .foregroundStyle(LiveActivityColors.textSecondary)

                Spacer()

                if state.elapsedSeconds > 0 {
                    Text(formatElapsed(state.elapsedSeconds))
                        .font(.caption.monospaced())
                        .foregroundStyle(LiveActivityColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func expandedStatusView(for status: SessionActivityStatus) -> some View {
        switch status {
        case .streaming:
            HStack(spacing: 2) {
                Circle()
                    .fill(LiveActivityColors.success)
                    .frame(width: 6, height: 6)
                Text("Streaming")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LiveActivityColors.success)
            }
        case .waitingForInput:
            HStack(spacing: 2) {
                Circle()
                    .fill(LiveActivityColors.warning)
                    .frame(width: 6, height: 6)
                Text("Waiting")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LiveActivityColors.warning)
            }
        case .completed:
            Text("Complete")
                .font(.caption.weight(.medium))
                .foregroundStyle(LiveActivityColors.textSecondary)
        case .error:
            HStack(spacing: 2) {
                Circle()
                    .fill(LiveActivityColors.destructive)
                    .frame(width: 6, height: 6)
                Text("Error")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LiveActivityColors.destructive)
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk tokens", Double(count) / 1000.0)
        }
        return "\(count) tokens"
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        }
        return String(format: "$%.2f", cost)
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

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
