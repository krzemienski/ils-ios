import SwiftUI
import ILSShared

/// A reusable list-item row that displays a single chat session inside the sidebar.
///
/// Renders a small status-colour dot, a smart display name, and a relative timestamp.
/// The display name falls back from ``ChatSession/name`` → first 40 characters of
/// ``ChatSession/firstPrompt`` → "Unnamed Session" so that every row always shows
/// meaningful text.  The status dot colour is mapped from ``ChatSession/status``:
/// active → `entitySession`, completed → `success`, cancelled → `warning`,
/// error → `error`.  When ``isActive`` is `true` the dot switches to `accent` and
/// the row receives a light accent background with semibold text to communicate the
/// currently open session.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The session model whose data drives the row
/// - ``isActive`` - Whether this row represents the currently open session
/// - ``onTap`` - Callback invoked (with haptic feedback) when the row is tapped
///
/// ### Display Helpers
/// - ``sessionDisplayName`` - Name-fallback chain: explicit name → first-prompt prefix → "Unnamed Session"
/// - ``relativeTime`` - Human-readable relative timestamp derived from `lastActiveAt`
/// - ``statusColor`` - Theme colour corresponding to the session's lifecycle status
struct SidebarSessionRow: View {
    /// The session model whose metadata (name, status, timestamps) drives the row.
    let session: ChatSession
    /// Whether this row represents the currently active/open session.
    ///
    /// When `true` the indicator dot uses `accent`, the row background gains a tinted
    /// highlight, and the session name is rendered semibold in the accent colour.
    var isActive: Bool = false
    /// Called when the user taps the row; fired after a selection haptic.
    let onTap: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(spacing: theme.spacingSM) {
                // Active indicator
                Circle()
                    .fill(isActive ? theme.accent : statusColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    // Session name
                    Text(sessionDisplayName)
                        .font(.system(size: theme.fontCaption, weight: isActive ? .semibold : .medium, design: theme.fontDesign))
                        .foregroundStyle(isActive ? theme.accent : theme.textPrimary)
                        .lineLimit(1)

                    // Project name (secondary context)
                    if let projectName = session.projectName, !projectName.isEmpty {
                        Text(projectName)
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    // Model badge + relative time + message count
                    HStack(spacing: theme.spacingXS) {
                        if !session.model.isEmpty {
                            Text(session.model.capitalized)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entitySession)
                            Text("·")
                                .foregroundStyle(theme.textTertiary)
                        }

                        Text(relativeTime)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)

                        if session.messageCount > 0 {
                            Text("·")
                                .foregroundStyle(theme.textTertiary)
                            Text("\(session.messageCount) msgs")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }

                        if session.source == .external {
                            Text("·")
                                .foregroundStyle(theme.textTertiary)
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(isActive ? theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("\(sessionDisplayName)\(session.projectName.map { ", \($0)" } ?? "")\(session.model.isEmpty ? "" : ", \(session.model)"), \(relativeTime)")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private var sessionDisplayName: String {
        session.displayName
    }

    private var relativeTime: String {
        DateFormatters.relativeDateTime.localizedString(for: session.lastActiveAt, relativeTo: Date())
    }

    private var statusColor: Color {
        switch session.status {
        case .active:
            return theme.entitySession
        case .completed:
            return theme.success
        case .cancelled:
            return theme.warning
        case .error:
            return theme.error
        }
    }
}
