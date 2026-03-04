import SwiftUI

// MARK: - SystemEventType

/// Semantic classification of a system-level chat event.
///
/// Each case carries an SF Symbol name and resolves the appropriate semantic colour from
/// the current `ThemeSnapshot`, allowing `SystemMessageView` to render a contextually
/// tinted icon and background without hard-coding colours.
///
/// ## Cases
/// - ``sessionStarted`` - Green success tint for session lifecycle start
/// - ``sessionForked`` - Accent tint for structural fork events
/// - ``contextCleared`` - Warning tint for context-window resets
/// - ``planModeEntered`` - Info tint for plan-mode entry
/// - ``planModeExited`` - Success tint for plan-mode completion
/// - ``generic`` - Neutral secondary tint for uncategorised events
enum SystemEventType {
    /// A new session has been created or resumed.
    case sessionStarted
    /// The session was forked from another session.
    case sessionForked
    /// The context window was explicitly cleared.
    case contextCleared
    /// Plan mode was entered.
    case planModeEntered
    /// Plan mode was exited after approval.
    case planModeExited
    /// An uncategorised system notification.
    case generic

    /// The SF Symbol name for the icon associated with this event type.
    var iconName: String {
        switch self {
        case .sessionStarted:  return "play.circle.fill"
        case .sessionForked:   return "arrow.branch"
        case .contextCleared:  return "xmark.circle.fill"
        case .planModeEntered: return "doc.text.magnifyingglass"
        case .planModeExited:  return "checkmark.seal.fill"
        case .generic:         return "info.circle.fill"
        }
    }

    /// Resolves the semantic colour for this event type from the given theme snapshot.
    func color(from theme: ThemeSnapshot) -> Color {
        switch self {
        case .sessionStarted:  return theme.success
        case .sessionForked:   return theme.accent
        case .contextCleared:  return theme.warning
        case .planModeEntered: return theme.info
        case .planModeExited:  return theme.success
        case .generic:         return theme.textSecondary
        }
    }
}

// MARK: - SystemEventKind

/// Classifies a system event message into a visual category.
///
/// Each case provides an SF Symbol icon name and a semantic theme color so that
/// `SystemMessageView` can render contextually appropriate visual treatments for
/// different kinds of system events (lifecycle, structural, mode changes, etc.)
/// without requiring callers to annotate messages explicitly.
///
/// ## Topics
/// ### Detection
/// - ``detect(from:)`` - Infers the kind by scanning message text for keywords
///
/// ### Presentation
/// - ``iconName`` - SF Symbol name for this event kind
/// - ``color(theme:)`` - Semantic theme color for icon, text, and tinted background
fileprivate enum SystemEventKind {
    case sessionStarted
    case sessionEnded
    case sessionForked
    case planMode
    case autoMode
    case contextCleared
    case warning
    case error
    case info

    /// Infers the event kind by scanning `message` for characteristic keywords.
    ///
    /// Checks are ordered from most-specific to least-specific so that compound
    /// strings (e.g. "Forked session started") resolve to the most meaningful kind.
    static func detect(from message: String) -> SystemEventKind {
        let lower = message.lowercased()
        if lower.contains("fork") || lower.contains("branch") { return .sessionForked }
        if lower.contains("started") || lower.contains("created") || lower.contains("connected") { return .sessionStarted }
        if lower.contains("ended") || lower.contains("closed") || lower.contains("disconnected") || lower.contains("terminated") { return .sessionEnded }
        if lower.contains("auto mode") || lower.contains("agent mode") { return .autoMode }
        if lower.contains("plan mode") { return .planMode }
        if (lower.contains("context") && lower.contains("clear")) || lower.contains("compacted") { return .contextCleared }
        if lower.contains("error") || lower.contains("failed") { return .error }
        if lower.contains("warning") || lower.contains("warn") { return .warning }
        return .info
    }

    /// SF Symbol name representing this event kind.
    var iconName: String {
        switch self {
        case .sessionStarted: return "play.circle.fill"
        case .sessionEnded:   return "stop.circle.fill"
        case .sessionForked:  return "arrow.branch"
        case .planMode:       return "pencil.circle.fill"
        case .autoMode:       return "wand.and.stars"
        case .contextCleared: return "xmark.circle.fill"
        case .warning:        return "exclamationmark.circle.fill"
        case .error:          return "exclamationmark.triangle.fill"
        case .info:           return "info.circle.fill"
        }
    }

    /// Semantic color from the active theme for icon, text, and tinted background.
    func color(theme: ThemeSnapshot) -> Color {
        switch self {
        case .sessionStarted: return theme.info
        case .sessionEnded:   return theme.textTertiary
        case .sessionForked:  return theme.info
        case .planMode:       return theme.warning
        case .autoMode:       return theme.warning
        case .contextCleared: return theme.warning
        case .warning:        return theme.warning
        case .error:          return theme.error
        case .info:           return theme.textTertiary
        }
    }
}

// MARK: - SystemMessageView

/// Horizontally centered card that surfaces system-level events within the chat timeline.
///
/// Used for non-conversational status lines such as "Session started", "Session forked",
/// or "Entered plan mode". The message text is scanned by ``SystemEventKind/detect(from:)``
/// to pick an appropriate SF Symbol icon and semantic theme color; the card background is
/// tinted at 10 % opacity with a 0.5 pt stroke at 30 % opacity — matching the visual
/// language established by `ErrorMessageView` while remaining appropriately subtle.
///
/// The `eventType` parameter is accepted for call-site compatibility with existing callers
/// that supply a `SystemEventType`; visual rendering uses keyword-based ``SystemEventKind``
/// auto-detection for richer per-word classification.
///
/// The view carries no interactive elements; its accessibility label prefixes the raw
/// string with "System: " to distinguish it from user or assistant content when read
/// aloud by VoiceOver.
///
/// ## Topics
/// ### Input Properties
/// - ``message`` - The system event string to display (e.g. "Session started")
/// - ``eventType`` - Semantic classification accepted for call-site compatibility
struct SystemMessageView: View {
    /// The system event string to display in the timeline (e.g. "Session started").
    let message: String
    /// Semantic classification accepted for call-site compatibility. Visual rendering
    /// uses keyword-based ``SystemEventKind`` auto-detection for richer classification.
    var eventType: SystemEventType = .generic

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        let kind = SystemEventKind.detect(from: message)
        let color = kind.color(theme: theme)

        HStack {
            Spacer()
            HStack(spacing: theme.spacingXS) {
                Image(systemName: kind.iconName)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(color)

                Text(message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
            )
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System message: \(message)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        SystemMessageView(message: "Session started")
        SystemMessageView(message: "Session forked from abc123")
        SystemMessageView(message: "Entered plan mode")
        SystemMessageView(message: "Entered auto mode")
        SystemMessageView(message: "Context window cleared")
        SystemMessageView(message: "Unknown event occurred")
    }
    .padding()
}
