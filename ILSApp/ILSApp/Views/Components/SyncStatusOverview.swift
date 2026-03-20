import SwiftUI

/// Summary card showing aggregate sync health across all sessions.
///
/// Displays counts for synced, pending, conflict, and failed sessions
/// with colored indicators. Provides "Sync All" and "Retry Failed" actions.
/// Intended for placement in a sidebar or settings view.
struct SyncStatusOverview: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var syncedCount: Int = 0
    @State private var pendingCount: Int = 0
    @State private var conflictCount: Int = 0
    @State private var failedCount: Int = 0
    @State private var isSyncing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: theme.fontBody, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text("Sync Status")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()
            }

            // Status indicators
            HStack(spacing: theme.spacingSM) {
                statusPill(count: syncedCount, label: "synced", color: theme.success)
                statusPill(count: pendingCount, label: "pending", color: theme.warning)
                statusPill(count: conflictCount, label: "conflicts", color: theme.error)
                statusPill(count: failedCount, label: "failed", color: theme.error.opacity(0.8))
            }

            // Action buttons
            HStack(spacing: theme.spacingSM) {
                Button {
                    Task {
                        isSyncing = true
                        await SyncCoordinator.shared.drainIfPossible()
                        isSyncing = false
                    }
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: theme.fontCaption))
                        }
                        Text("Sync All")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.12))
                    )
                }
                .disabled(isSyncing)
                .accessibilityLabel("Sync all pending changes")

                if failedCount > 0 {
                    Button {
                        Task {
                            await retryAllFailed()
                        }
                    } label: {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "exclamationmark.arrow.circlepath")
                                .font(.system(size: theme.fontCaption))
                            Text("Retry Failed")
                                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.error)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            Capsule()
                                .fill(theme.error.opacity(0.12))
                        )
                    }
                    .accessibilityLabel("Retry \(failedCount) failed sync operations")
                }

                Spacer()
            }
        }
        .glassCard()
        .task {
            await refreshCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncStatusDidChange)) { _ in
            Task { await refreshCounts() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sync status overview")
    }

    // MARK: - Status Pill

    @ViewBuilder
    private func statusPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text("\(count) \(label)")
                .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityLabel("\(count) \(label)")
    }

    // MARK: - Data

    private func refreshCounts() async {
        let statusMap = await SyncCoordinator.shared.syncStatusMap
        var synced = 0
        var pending = 0
        var conflict = 0
        var failed = 0

        for (_, status) in statusMap {
            switch status {
            case .synced: synced += 1
            case .pending: pending += 1
            case .conflict: conflict += 1
            case .failed: failed += 1
            }
        }

        await MainActor.run {
            syncedCount = synced
            pendingCount = pending
            conflictCount = conflict
            failedCount = failed
        }
    }

    private func retryAllFailed() async {
        let statusMap = await SyncCoordinator.shared.syncStatusMap
        let failedSessionIds = statusMap
            .filter { $0.value == .failed }
            .map(\.key)

        for sessionId in failedSessionIds {
            await SyncCoordinator.shared.retryFailed(sessionId: sessionId)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SyncStatusOverview()
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
