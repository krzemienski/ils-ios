import SwiftUI

/// Small inline badge showing the number of outgoing messages queued while offline.
///
/// Only visible when `pendingCount > 0`. Intended for placement inside `ChatInputBar`
/// to inform the user that their typed messages are held and will be sent on reconnection.
///
/// ## Usage
/// ```swift
/// QueuedMessageBadge(pendingCount: messageQueueService.pendingCount)
/// ```
struct QueuedMessageBadge: View {

    // MARK: - Input

    let pendingCount: Int

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        if pendingCount > 0 {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "tray.and.arrow.up")
                    .font(.system(size: theme.fontCaption - 1, weight: .semibold))

                Text(label)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(theme.warning)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS / 2)
            .background(
                Capsule()
                    .fill(theme.warning.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(theme.warning.opacity(0.4), lineWidth: 0.5)
                    )
            )
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Private Helpers

    private var label: String {
        pendingCount == 1 ? "1 queued" : "\(pendingCount) queued"
    }

    private var accessibilityLabel: String {
        pendingCount == 1
            ? "1 message queued. Will send when connection is restored."
            : "\(pendingCount) messages queued. Will send when connection is restored."
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        QueuedMessageBadge(pendingCount: 1)
        QueuedMessageBadge(pendingCount: 3)
        QueuedMessageBadge(pendingCount: 12)
        QueuedMessageBadge(pendingCount: 0)  // hidden
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
