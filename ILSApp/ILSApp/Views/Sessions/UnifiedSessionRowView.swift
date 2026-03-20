import SwiftUI
import ILSShared

/// Single row in the unified sessions list, showing a status dot, session metadata, and a
/// color-coded backend source pill.
///
/// Conforms to `Equatable` so callers can use `.equatable()` to suppress redraws when the
/// session identity and backend name have not changed. The equality check compares only
/// `session.id` and `backendName` — sufficient to detect meaningful changes without deep
/// inspection of the session payload.
///
/// ## Topics
/// ### Input Properties
/// - ``tagged`` - The session annotated with backend identity
///
/// ### Callbacks
/// - ``onSelected`` - Invoked when the user taps the row
struct UnifiedSessionRowView: View, Equatable {
    /// The tagged session to display.
    let tagged: TaggedSession
    /// Called when the user taps the row.
    var onSelected: ((TaggedSession) -> Void)?

    nonisolated static func == (lhs: UnifiedSessionRowView, rhs: UnifiedSessionRowView) -> Bool {
        lhs.tagged.session.id == rhs.tagged.session.id &&
        lhs.tagged.backendName == rhs.tagged.backendName
    }

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        let session = tagged.session
        Button {
            HapticManager.selection()
            onSelected?(tagged)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Status indicator dot
                Circle()
                    .fill(statusColor(for: session.status))
                    .frame(width: 6, height: 6)

                // Session metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let projectName = session.projectName, !projectName.isEmpty {
                        Text(projectName)
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Text(DateFormatters.relativeDateTime.localizedString(
                        for: session.lastActiveAt,
                        relativeTo: Date()
                    ))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                // Backend source pill
                backendPill(tagged)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("\(session.displayName), from \(tagged.backendName)")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Backend Pill

    /// Small rounded-rectangle badge showing the originating backend with its assigned color tint.
    ///
    /// Background uses the backend color at 20% opacity; foreground text uses full backend color.
    /// Backend name is capped at 10 characters to prevent overflow in narrow rows.
    private func backendPill(_ tagged: TaggedSession) -> some View {
        let pillColor = Color(hex: tagged.backendColorHex)
        return Text(String(tagged.backendName.prefix(10)))
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(pillColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    // MARK: - Helpers

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:    return theme.entitySession
        case .completed: return theme.success
        case .cancelled: return theme.warning
        case .error:     return theme.error
        }
    }
}
