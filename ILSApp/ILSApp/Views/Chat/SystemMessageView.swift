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

// MARK: - SystemMessageView

/// Horizontally centered pill that surfaces system-level events within the chat timeline.
///
/// Used for non-conversational status lines such as "Session started", "Session forked",
/// or "Context window cleared". An SF Symbol icon and subtle tinted background visually
/// distinguish event types — green for lifecycle starts, amber for context resets — so
/// users scanning long histories can identify important system events at a glance.
///
/// When `eventType` is omitted it defaults to `.generic`, rendering a neutral info icon
/// as a fallback for unclassified messages, preserving backward compatibility with existing
/// call sites that pass only a `message` string.
///
/// The view carries no interactive elements; its accessibility label prefixes the raw
/// string with "System: " to distinguish it from user or assistant content when read
/// aloud by VoiceOver.
///
/// ## Topics
/// ### Input Properties
/// - ``message`` - The system event string to display (e.g. "Session started")
/// - ``eventType`` - Semantic classification that determines the icon and tint colour
struct SystemMessageView: View {
    /// The system event string to display in the timeline (e.g. "Session started").
    let message: String
    /// Semantic classification controlling the icon and tint colour. Defaults to `.generic`.
    var eventType: SystemEventType = .generic

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: theme.spacingSM) {
                Image(systemName: eventType.iconName)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(eventType.color(from: theme))
                    .frame(width: 16)

                Text(message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(eventType.color(from: theme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, theme.spacingXS)
            .padding(.horizontal, theme.spacingSM)
            .background(eventType.color(from: theme).opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(eventType.color(from: theme).opacity(0.3), lineWidth: 0.5)
            )

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System message: \(message)")
    }
}
