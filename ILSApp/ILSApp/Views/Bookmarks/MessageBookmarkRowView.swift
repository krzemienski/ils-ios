import SwiftUI
import ILSShared

/// A single row in the bookmarks browser list displaying a bookmarked message.
///
/// Renders a role pill badge (USER/ASST), the session name, a content preview
/// (up to 3 lines), tag chips, a relative bookmark date, and an optional note.
/// Tapping the row fires ``onTap`` which should navigate to the session at that message.
///
/// ## Topics
/// ### Inputs
/// - ``bookmark`` — The ``MessageBookmark`` model driving this row.
/// - ``onTap`` — Callback invoked (with haptic feedback) when the row is tapped.
struct MessageBookmarkRowView: View {
    /// The bookmark model driving this row.
    let bookmark: MessageBookmark
    /// Called when the user taps the row to navigate to the session message.
    let onTap: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // MARK: Header — role badge + session name + date
                HStack(alignment: .center, spacing: theme.spacingSM) {
                    roleBadge

                    Text(sessionDisplayName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: theme.spacingXS)

                    Text(relativeDate)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                // MARK: Message content preview
                if let content = bookmark.messageContent, !content.isEmpty {
                    Text(content)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // MARK: Note (if present)
                if let note = bookmark.note, !note.isEmpty {
                    HStack(alignment: .top, spacing: theme.spacingXS) {
                        Image(systemName: "note.text")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)

                        Text(note)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                }

                // MARK: Tag chips
                if !bookmark.tags.isEmpty {
                    tagChips
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingSM)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this message in its session")
        .contextMenu {
            if let shareURL = URL(string: "ils://bookmark/\(bookmark.id.uuidString.lowercased())") {
                ShareLink(item: shareURL) {
                    Label("Share Bookmark", systemImage: "square.and.arrow.up")
                }
            }
        }
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

    private var tagChips: some View {
        HStack(spacing: theme.spacingXS) {
            ForEach(bookmark.tags.prefix(4), id: \.self) { tagName in
                Text(tagName)
                    .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.bgSecondary.cornerRadius(4))
            }

            if bookmark.tags.count > 4 {
                Text("+\(bookmark.tags.count - 4)")
                    .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private var sessionDisplayName: String {
        bookmark.sessionName ?? "Session \(bookmark.sessionId.uuidString.prefix(8))"
    }

    private var relativeDate: String {
        DateFormatters.relativeDateTime.localizedString(for: bookmark.createdAt, relativeTo: Date())
    }

    private var roleName: String {
        switch bookmark.messageRole?.lowercased() {
        case "user":
            return "USER"
        case "assistant":
            return "ASST"
        default:
            return "SYS"
        }
    }

    private var roleBadgeColor: Color {
        switch bookmark.messageRole?.lowercased() {
        case "user":
            return theme.accent
        case "assistant":
            return theme.entityMCP
        default:
            return theme.entitySystem
        }
    }

    private var accessibilityLabel: String {
        var parts = ["\(roleName) message in \(sessionDisplayName)"]
        if let content = bookmark.messageContent, !content.isEmpty {
            parts.append(String(content.prefix(100)))
        }
        if !bookmark.tags.isEmpty {
            parts.append("Tags: \(bookmark.tags.joined(separator: ", "))")
        }
        parts.append(relativeDate)
        return parts.joined(separator: ". ")
    }
}
