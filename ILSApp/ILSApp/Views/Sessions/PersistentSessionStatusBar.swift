import SwiftUI
import ILSShared

// MARK: - PersistentSessionStatusBar

/// Compact horizontal status strip shown on iPhone when 2 or more sessions are pinned.
///
/// Renders a scrollable row of tappable chips — one per pinned session — each containing
/// a ``SessionStatusBadge`` dot and the session name truncated to 8 characters.
/// Tapping a chip fires the `onSessionSelected` callback so the caller can navigate
/// to that session.
///
/// The bar is invisible when fewer than 2 sessions are pinned.
///
/// ## Usage
/// ```swift
/// PersistentSessionStatusBar(
///     pinnedSessions: pinnedSessions,
///     streamingSessionIds: streamingIds,
///     onSessionSelected: { session in activeSession = session }
/// )
/// ```
struct PersistentSessionStatusBar: View {

    // MARK: - Inputs

    /// Ordered list of currently pinned sessions.
    let pinnedSessions: [ChatSession]
    /// Set of session IDs that are currently streaming a response.
    var streamingSessionIds: Set<UUID> = []
    /// Called when the user taps a session chip.
    let onSessionSelected: (ChatSession) -> Void

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        // Only render when at least 2 sessions are pinned.
        if pinnedSessions.count >= 2 {
            VStack(spacing: 0) {
                Divider()
                    .overlay(theme.divider)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingSM) {
                        ForEach(pinnedSessions) { session in
                            sessionChip(for: session)
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingXS)
                }
                .frame(height: 44)
                .background(theme.bgSecondary)
            }
        }
    }

    // MARK: - Subviews

    /// A tappable chip that shows the session's activity dot and truncated name.
    @ViewBuilder
    private func sessionChip(for session: ChatSession) -> some View {
        let isStreaming = streamingSessionIds.contains(session.id)
        let displayName = sessionDisplayName(session)

        Button {
            onSessionSelected(session)
        } label: {
            HStack(spacing: theme.spacingXS) {
                SessionStatusBadge(
                    sessionStatus: session.status,
                    isStreaming: isStreaming,
                    sizeMode: .compact
                )

                Text(displayName)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgPrimary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.divider, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to session \(displayName)")
        .accessibilityHint("Double tap to navigate to this session")
    }

    // MARK: - Helpers

    /// Derives a display name for a session, truncated to 8 characters.
    private func sessionDisplayName(_ session: ChatSession) -> String {
        let raw = session.name
            ?? session.firstPrompt
            ?? "Session"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }
        return String(trimmed.prefix(8))
    }
}

// MARK: - Previews

#Preview("Two sessions") {
    let sessions = [
        ChatSession(name: "Frontend Build", status: .active),
        ChatSession(name: "Tests", status: .error),
        ChatSession(name: "Backend", status: .active)
    ]
    VStack {
        PersistentSessionStatusBar(
            pinnedSessions: sessions,
            streamingSessionIds: [sessions[0].id],
            onSessionSelected: { _ in }
        )
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}

#Preview("One session — hidden") {
    let sessions = [
        ChatSession(name: "Solo Session", status: .active)
    ]
    VStack {
        PersistentSessionStatusBar(
            pinnedSessions: sessions,
            onSessionSelected: { _ in }
        )
        Text("Bar is hidden above (fewer than 2 sessions)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
