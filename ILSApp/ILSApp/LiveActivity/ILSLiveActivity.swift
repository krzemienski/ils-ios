import SwiftUI

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Activity Attributes

/// Defines the static and dynamic data for a chat streaming Live Activity.
///
/// Static data (set once at activity start):
/// - `sessionName`: Human-readable session name
/// - `model`: Claude model being used (e.g., "Sonnet", "Opus")
///
/// Dynamic data (updated during streaming via `ContentState`):
/// - `isStreaming`: Whether Claude is actively generating
/// - `messagePreview`: Truncated preview of the response text
/// - `tokenCount`: Approximate token count of the response
/// - `cost`: Running cost in USD
/// - `elapsedSeconds`: Seconds since streaming started
struct ChatStreamingAttributes: ActivityAttributes {
    let sessionName: String
    let model: String

    struct ContentState: Codable, Hashable {
        var isStreaming: Bool
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
    static let border = Color(hex: "1A1A2E")
}

// MARK: - Lock Screen Widget View

#if canImport(WidgetKit) && canImport(ActivityKit)

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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LiveActivityColors.accent)

                Text(context.attributes.sessionName)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(context.attributes.model)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(LiveActivityColors.accent.opacity(0.15))
                    )
            }

            // Status line
            if context.state.isStreaming {
                HStack(spacing: 4) {
                    Text("Claude is responding")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LiveActivityColors.success)

                    StreamingDotsView()
                }
            } else {
                Text("Response complete")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LiveActivityColors.textSecondary)
            }

            // Message preview
            if !context.state.messagePreview.isEmpty {
                Text(context.state.messagePreview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            // Stats row: tokens + cost
            HStack {
                Label {
                    Text(formatTokenCount(context.state.tokenCount))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                } icon: {
                    Image(systemName: "number.square")
                        .font(.system(size: 11))
                }
                .foregroundStyle(LiveActivityColors.textSecondary)

                Spacer()

                if context.state.elapsedSeconds > 0 {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(LiveActivityColors.textSecondary)

                    Spacer()
                }

                Text(formatCost(context.state.cost))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.accent)
            }
        }
        .padding(16)
        .background(LiveActivityColors.background)
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

    var body: some View {
        Text(String(repeating: ".", count: (dotCount % 3) + 1))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(LiveActivityColors.success)
            .frame(width: 20, alignment: .leading)
            .onAppear {
                // Timer-based animation for dot cycling
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    dotCount += 1
                }
            }
    }
}

// MARK: - Dynamic Island Views

/// Compact leading view for Dynamic Island (small brain icon).
@available(iOS 16.2, *)
struct ChatStreamingCompactLeading: View {
    var body: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 12))
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
            .font(.system(size: 12, weight: .medium, design: .monospaced))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LiveActivityColors.accent)

                Text(attributes.sessionName)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(attributes.model)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.accent.opacity(0.8))
            }

            // Middle row: status + cost
            HStack {
                if state.isStreaming {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(LiveActivityColors.success)
                            .frame(width: 6, height: 6)
                        Text("Streaming")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LiveActivityColors.success)
                    }
                } else {
                    Text("Complete")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LiveActivityColors.textSecondary)
                }

                Spacer()

                Text(formatCost(state.cost))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.accent)
            }

            // Bottom row: tokens + elapsed
            HStack {
                Text(formatTokenCount(state.tokenCount))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LiveActivityColors.textSecondary)

                Spacer()

                if state.elapsedSeconds > 0 {
                    Text(formatElapsed(state.elapsedSeconds))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LiveActivityColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
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

#endif

// MARK: - ChatViewModel Live Activity Extension

extension ChatViewModel {
    #if canImport(ActivityKit)

    /// Start a Live Activity for the current chat streaming session.
    ///
    /// Creates a new `Activity<ChatStreamingAttributes>` that appears on the lock screen
    /// and Dynamic Island while Claude streams a response.
    ///
    /// - Parameters:
    ///   - sessionName: Display name for the session
    ///   - model: Claude model being used (e.g., "Sonnet")
    @available(iOS 16.2, *)
    func startLiveActivity(sessionName: String, model: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.shared.info("Live Activities not enabled by user", category: "liveActivity")
            return
        }

        let attributes = ChatStreamingAttributes(
            sessionName: sessionName,
            model: model
        )

        let initialState = ChatStreamingAttributes.ContentState(
            isStreaming: true,
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
    ///   - preview: Truncated preview of the assistant message (max ~100 chars)
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
            isStreaming: true,
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
    /// Sets `isStreaming` to `false` and dismisses the activity after a brief delay
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
            isStreaming: false,
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

    #endif
}
