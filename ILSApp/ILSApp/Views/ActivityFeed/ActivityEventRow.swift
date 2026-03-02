import SwiftUI
import ILSShared

/// A single timeline row in the cross-session activity feed.
///
/// Renders a circular icon badge (SF Symbol keyed to the event type, coloured by
/// severity) on the left, and a two-line content stack on the right:
/// - **Title line**: event summary (semibold when unread) + relative timestamp
/// - **Detail line**: optional longer description (up to 2 lines; shows "+ N more"
///   when the view model has collapsed a burst of events into this representative row)
/// - **Footer line**: session name / project name context
///
/// An unread indicator dot is shown at the trailing edge when `event.isRead` is `false`.
///
/// ## Topics
/// ### Inputs
/// - ``event`` - The ``ActivityEvent`` model driving all displayed content
/// - ``onTap`` - Closure invoked (with haptic feedback) when the row is tapped
///
/// ### Display Helpers
/// - ``eventTypeIcon`` - SF Symbol name matched to `event.eventType`
/// - ``severityColor`` - Theme colour mapped from `event.severity`
/// - ``relativeTime`` - Human-readable relative timestamp
struct ActivityEventRow: View {
    /// The activity event whose data drives all displayed content.
    let event: ActivityEvent
    /// Called when the user taps the row; fired after a selection haptic.
    let onTap: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(alignment: .top, spacing: theme.spacingSM) {
                // Event type icon badge
                ZStack {
                    Circle()
                        .fill(severityColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: eventTypeIcon)
                        .font(.system(size: theme.fontBody - 1, weight: .medium))
                        .foregroundStyle(severityColor)
                }

                // Content stack
                VStack(alignment: .leading, spacing: 3) {
                    // Title + timestamp
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacingXS) {
                        Text(event.title)
                            .font(.system(
                                size: theme.fontBody,
                                weight: event.isRead ? .regular : .semibold,
                                design: theme.fontDesign
                            ))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: theme.spacingXS)

                        Text(relativeTime)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .layoutPriority(1)
                    }

                    // Optional detail / collapsed group indicator
                    if let detail = event.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }

                    // Session / project context footer
                    HStack(spacing: theme.spacingXS) {
                        if let sessionName = event.sessionName, !sessionName.isEmpty {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: theme.fontCaption - 1))
                                .foregroundStyle(theme.entitySession)
                            Text(sessionName)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }

                        if let projectName = event.projectName, !projectName.isEmpty {
                            if event.sessionName != nil {
                                Text("·")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Image(systemName: "folder.fill")
                                .font(.system(size: theme.fontCaption - 1))
                                .foregroundStyle(theme.entityProject)
                            Text(projectName)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                }

                // Unread indicator dot
                if !event.isRead {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(event.isRead ? Color.clear : theme.accent.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this activity event")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    /// SF Symbol name matched to the event type.
    private var eventTypeIcon: String {
        switch event.eventType {
        case .messageSent:
            return "message.fill"
        case .messageReceived:
            return "message.fill"
        case .permissionRequest:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .completion:
            return "checkmark.circle.fill"
        case .fileChange:
            return "doc.fill"
        case .systemEvent:
            return "bolt.fill"
        }
    }

    /// Theme colour derived from the event's severity level.
    ///
    /// - `info` maps to `theme.accent` (no special action required)
    /// - `warning` maps to `theme.warning`
    /// - `error` maps to `theme.error`
    private var severityColor: Color {
        switch event.severity {
        case .info:
            return theme.accent
        case .warning:
            return theme.warning
        case .error:
            return theme.error
        }
    }

    private var relativeTime: String {
        DateFormatters.relativeDateTime.localizedString(for: event.timestamp, relativeTo: Date())
    }

    private var accessibilityLabel: String {
        var parts: [String] = [event.title]
        if let detail = event.detail, !detail.isEmpty {
            parts.append(detail)
        }
        if let sessionName = event.sessionName {
            parts.append("Session: \(sessionName)")
        }
        if let projectName = event.projectName {
            parts.append("Project: \(projectName)")
        }
        parts.append(relativeTime)
        if !event.isRead {
            parts.append("Unread")
        }
        return parts.joined(separator: ", ")
    }
}
