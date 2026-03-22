import SwiftUI
import ILSShared

/// A row displaying a single cross-session message search result.
///
/// Shows: role icon, session name (bold), optional project name, model badge,
/// a timestamp, and a snippet of text around the match with `<mark>` regions
/// highlighted in the accent colour.
///
/// The row is tappable; callers supply an `onTap` closure that receives the
/// full `MessageSearchResult` so they can navigate to the relevant session.
struct GlobalSearchResultRow: View {
    let result: MessageSearchResult
    let onTap: (MessageSearchResult) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button {
            onTap(result)
        } label: {
            HStack(alignment: .top, spacing: theme.spacingSM) {
                // Role icon
                Image(systemName: roleIconName)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(roleIconColor)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    // Header: session name + project + model badge + timestamp
                    HStack(spacing: theme.spacingXS) {
                        if let sessionName = result.sessionName, !sessionName.isEmpty {
                            Text(sessionName)
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        } else {
                            Text("Untitled")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        }

                        if let projectName = result.projectName, !projectName.isEmpty {
                            Text("· \(projectName)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        }

                        Spacer()

                        // Model badge
                        if let model = result.sessionModel, !model.isEmpty {
                            Text(shortModelName(model))
                                .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(theme.bgTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        }

                        // Timestamp
                        Text(formattedTimestamp(result.createdAt))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    // Snippet with <mark> highlighting, or plain content fallback
                    if let snippet = result.snippet, !snippet.isEmpty {
                        snippetView(snippet)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .lineLimit(3)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    } else {
                        Text(result.content)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                }
            }
            .padding(.vertical, theme.spacingXS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Snippet Highlighting

    /// Build a `Text` view from a raw snippet that may contain `<mark>…</mark>` tags.
    ///
    /// Uses SwiftUI `Text` concatenation (+) so highlighted segments are rendered
    /// in the accent colour without requiring platform-specific `UIColor`/`NSColor`.
    @ViewBuilder
    private func snippetView(_ raw: String) -> some View {
        buildHighlightedText(raw)
    }

    private func buildHighlightedText(_ raw: String) -> Text {
        var composed = Text("")
        var remaining = raw

        while let openRange = remaining.range(of: "<mark>") {
            // Append the plain text before the opening tag
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
            if !before.isEmpty {
                composed = composed + Text(before).foregroundColor(theme.textSecondary)
            }

            remaining = String(remaining[openRange.upperBound...])

            if let closeRange = remaining.range(of: "</mark>") {
                let highlighted = String(remaining[remaining.startIndex..<closeRange.lowerBound])
                composed = composed + Text(highlighted)
                    .foregroundColor(theme.accent)
                    .fontWeight(.medium)
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                // Malformed markup — append the rest as plain text
                composed = composed + Text(remaining).foregroundColor(theme.textSecondary)
                return composed
            }
        }

        // Append any trailing plain text
        if !remaining.isEmpty {
            composed = composed + Text(remaining).foregroundColor(theme.textSecondary)
        }

        return composed
    }

    // MARK: - Helpers

    private var roleIconName: String {
        switch result.role {
        case .user:       return "person.fill"
        case .assistant:  return "sparkles"
        case .system:     return "gearshape.fill"
        }
    }

    private var roleIconColor: Color {
        switch result.role {
        case .user:       return theme.textSecondary
        case .assistant:  return theme.accent
        case .system:     return theme.textTertiary
        }
    }

    private func shortModelName(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("opus")    { return "opus" }
        if lower.contains("sonnet")  { return "sonnet" }
        if lower.contains("haiku")   { return "haiku" }
        return String(model.prefix(8))
    }

    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }

    private var accessibilityDescription: String {
        let session = result.sessionName ?? "Untitled"
        let role = result.role == .user ? "You" : "Claude"
        return "\(role) in \(session): \(result.content.prefix(100))"
    }
}
