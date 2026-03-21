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
/// currently open session.  Tapping the row triggers a scale/opacity press animation
/// via ``RowButtonStyle``; the animation is suppressed when
/// `accessibilityReduceMotion` is enabled.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The session model whose data drives the row
/// - ``isActive`` - Whether this row represents the currently open session
/// - ``searchText`` - Optional filter text whose matches are highlighted in accent colour
/// - ``onTap`` - Callback invoked (with haptic feedback) when the row is tapped
///
/// ### Display Helpers
/// - ``sessionDisplayName`` - Name-fallback chain: explicit name → first-prompt prefix → "Unnamed Session"
/// - ``highlightedDisplayName`` - AttributedString with search-term matches coloured in `theme.accent`
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
    /// Substring used to highlight matching characters in the session name.
    ///
    /// When non-empty and the session is not active, any case-insensitive occurrence of
    /// this string within ``sessionDisplayName`` is rendered in `theme.accent`.
    var searchText: String = ""
    /// Number of bookmarked messages in this session. When > 0 a small badge is shown.
    var bookmarkCount: Int = 0
    /// Sync status for this session. When not `.synced`, a ``SessionSyncBadge`` is shown.
    var syncStatus: SyncStatus = .synced
    /// Called when the user taps "Retry" on a failed sync badge.
    var onRetrySync: (() -> Void)? = nil
    /// Called when the user taps a conflict sync badge to present resolution UI.
    var onConflictTap: (() -> Void)? = nil
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
                    // Session name — with optional search-term highlighting
                    Text(highlightedDisplayName)
                        .font(.system(size: theme.fontCaption, weight: isActive ? .semibold : .medium, design: theme.fontDesign))
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

                if bookmarkCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9, design: theme.fontDesign))
                        Text("\(bookmarkCount)")
                            .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Sync status badge — hidden when synced to avoid visual noise
                if syncStatus != .synced {
                    SessionSyncBadge(
                        status: syncStatus,
                        onRetry: syncStatus == .failed ? onRetrySync : nil
                    )
                    .onTapGesture {
                        if syncStatus == .conflict {
                            onConflictTap?()
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
        }
        .buttonStyle(RowButtonStyle(isActive: isActive, theme: theme))
        .hoverState(cornerRadius: theme.cornerRadiusSmall)
        .accessibilityLabel("\(sessionDisplayName)\(session.projectName.map { ", \($0)" } ?? "")\(session.model.isEmpty ? "" : ", \(session.model.capitalized)"), \(relativeTime)\(syncStatus != .synced ? ", \(syncStatus.displayName)" : "")")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private var sessionDisplayName: String {
        session.displayName
    }

    /// Builds an `AttributedString` for the session name, highlighting every
    /// case-insensitive occurrence of `searchText` in `theme.accent`.
    ///
    /// When `isActive` is `true` the entire name uses the accent colour (no
    /// per-character highlighting needed).  When `searchText` is empty the name
    /// is returned in `theme.textPrimary` with no additional work.
    private var highlightedDisplayName: AttributedString {
        let name = sessionDisplayName

        // Active rows and empty queries skip the substring-scan path.
        guard !searchText.isEmpty, !isActive else {
            var result = AttributedString(name)
            result.foregroundColor = isActive ? theme.accent : theme.textPrimary
            return result
        }

        var result = AttributedString()
        let lowercasedName = name.lowercased()
        let lowercasedSearch = searchText.lowercased()
        var current = name.startIndex

        while current < name.endIndex {
            let searchRange = current..<name.endIndex
            if let matchRange = lowercasedName.range(of: lowercasedSearch, range: searchRange) {
                // Append text before the match in the default colour.
                if current < matchRange.lowerBound {
                    var segment = AttributedString(name[current..<matchRange.lowerBound])
                    segment.foregroundColor = theme.textPrimary
                    result.append(segment)
                }
                // Append the matched substring in accent colour.
                var match = AttributedString(name[matchRange])
                match.foregroundColor = theme.accent
                result.append(match)
                current = matchRange.upperBound
            } else {
                // Append the remaining non-matching tail.
                var tail = AttributedString(name[current...])
                tail.foregroundColor = theme.textPrimary
                result.append(tail)
                break
            }
        }

        return result
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

// MARK: - RowButtonStyle

private struct RowButtonStyle: ButtonStyle {
    let isActive: Bool
    let theme: ThemeSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive && isPressed {
            return theme.accent.opacity(0.18)
        } else if isActive {
            return theme.accent.opacity(0.12)
        } else if isPressed {
            return theme.accent.opacity(0.07)
        } else {
            return Color.clear
        }
    }
}
