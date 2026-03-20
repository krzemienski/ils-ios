import SwiftUI

/// Compact badge displaying the synchronization status of a session.
///
/// Designed to sit inline within a session row. Shows nothing when synced
/// (to reduce visual noise), and renders a compact capsule for other states.
///
/// ## Usage
/// ```swift
/// SessionSyncBadge(status: session.syncMetadata.syncStatus)
/// ```
struct SessionSyncBadge: View {

    // MARK: - Input

    let status: SyncStatus

    /// Optional callback invoked when the user taps "Retry" on a failed badge.
    var onRetry: (() -> Void)? = nil

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        switch status {
        case .synced:
            EmptyView()

        case .pending:
            badgeContent(
                icon: "icloud.and.arrow.up",
                label: "Pending",
                color: theme.warning
            )

        case .conflict:
            badgeContent(
                icon: "exclamationmark.triangle",
                label: "Conflict",
                color: theme.error
            )

        case .failed:
            HStack(spacing: theme.spacingXS) {
                badgeContent(
                    icon: "xmark.circle",
                    label: "Failed",
                    color: theme.error
                )

                if let onRetry {
                    Button(action: onRetry) {
                        Text("Retry")
                            .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry sync")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func badgeContent(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption - 1, weight: .semibold))

            Text(label)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        }
        .foregroundStyle(color)
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS / 2)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.4), lineWidth: 0.5)
                )
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    private var accessibilityLabel: String {
        switch status {
        case .synced:
            return "Session is synced."
        case .pending:
            return "Session has pending changes awaiting sync."
        case .conflict:
            return "Session has a sync conflict that needs resolution."
        case .failed:
            return "Session sync failed. Tap retry to try again."
        }
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        SessionSyncBadge(status: .synced)
        SessionSyncBadge(status: .pending)
        SessionSyncBadge(status: .conflict)
        SessionSyncBadge(status: .failed)
        SessionSyncBadge(status: .failed, onRetry: {})
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
