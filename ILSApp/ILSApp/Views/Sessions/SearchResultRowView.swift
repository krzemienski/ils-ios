import SwiftUI
import ILSShared

/// A reusable list-item row that displays a single cross-session message search result.
///
/// Renders a role pill badge (USER/ASST), the session name, a content snippet (up to 2 lines),
/// a relative timestamp, and a bookmark star toggle. The role badge colour is mapped from
/// ``MessageSearchResult/role``: `.user` → `accent`, `.assistant` → `entityMCP`.
/// The bookmark star is filled when the result is currently bookmarked.
///
/// ## Topics
/// ### Inputs
/// - ``result`` - The search result model whose data drives the row
/// - ``isBookmarked`` - Whether this result is currently bookmarked
/// - ``onTap`` - Callback invoked (with haptic feedback) when the row body is tapped
/// - ``onBookmark`` - Callback invoked when the bookmark star is toggled
struct SearchResultRowView: View {
    /// The search result model driving this row.
    let result: MessageSearchResult
    /// Whether this result is currently bookmarked.
    var isBookmarked: Bool = false
    /// Called when the user taps the row body (fires a selection haptic).
    let onTap: () -> Void
    /// Called when the user taps the bookmark star to toggle the bookmark state.
    let onBookmark: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(alignment: .top, spacing: theme.spacingSM) {
                // MARK: Role Badge
                roleBadge

                // MARK: Content
                VStack(alignment: .leading, spacing: 3) {
                    // Session name
                    Text(sessionDisplayName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)

                    // Content snippet (prefer matchContext when available)
                    Text(snippet)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: theme.spacingXS)

                // MARK: Timestamp + Bookmark
                VStack(alignment: .trailing, spacing: theme.spacingXS) {
                    // Relative timestamp
                    Text(relativeTime)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    // Bookmark toggle button
                    Button(action: {
                        HapticManager.selection()
                        onBookmark()
                    }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: theme.fontCaption + 1))
                            .foregroundStyle(isBookmarked ? theme.accent : theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")
                    .accessibilityHint("Toggles the bookmark for this search result")
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(roleName) message in \(sessionDisplayName): \(snippet), \(relativeTime)")
        .accessibilityHint("Opens this message in its session")
    }

    // MARK: - Sub-views

    private var roleBadge: some View {
        Text(roleName)
            .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleBadgeColor.cornerRadius(4))
            .fixedSize()
    }

    // MARK: - Helpers

    private var sessionDisplayName: String {
        result.sessionName ?? "Session \(result.sessionId.uuidString.prefix(8))"
    }

    private var snippet: String {
        if let ctx = result.matchContext, !ctx.isEmpty {
            return ctx
        }
        return result.content
    }

    private var relativeTime: String {
        DateFormatters.relativeDateTime.localizedString(for: result.createdAt, relativeTo: Date())
    }

    private var roleName: String {
        switch result.role {
        case .user:
            return "USER"
        case .assistant:
            return "ASST"
        }
    }

    private var roleBadgeColor: Color {
        switch result.role {
        case .user:
            return theme.accent
        case .assistant:
            return theme.entityMCP
        }
    }
}
