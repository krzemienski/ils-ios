import SwiftUI
import ILSShared

/// Sheet presenting an interrupted session's recovery timeline.
///
/// Displays the session name, interruption reason (or a generic fallback), and the last
/// active timestamp. Below the header a timeline lists all available checkpoints in
/// descending chronological order; each row shows the checkpoint name, creation date,
/// a message-count badge, and a per-row **Restore** button.
///
/// A prominent **Restore Latest Checkpoint** primary button at the top of the checkpoint
/// section lets users recover in a single tap. An empty state is shown when no checkpoints
/// exist for the session.
///
/// ## Topics
/// ### Callbacks
/// - ``onRestored`` — Invoked after a successful checkpoint restore, passing the forked ``ChatSession``.
struct RecoveryTimelineView: View {
    /// The interrupted session to recover from.
    let session: ChatSession
    /// Called when the user successfully restores a checkpoint, passing the forked session.
    var onRestored: ((ChatSession) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionCheckpointsViewModel()

    /// The checkpoint selected for a per-row restore confirmation.
    @State private var checkpointToRestore: SessionCheckpoint?
    /// Controls the restore-confirmation alert for per-row taps.
    @State private var showRestoreAlert = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider()
                    .padding(.vertical, 16)
                checkpointsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Session Recovery")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Dismiss") { dismiss() }
            }
        }
        // MARK: Per-row restore confirmation alert
        .alert("Restore Checkpoint?", isPresented: $showRestoreAlert, presenting: checkpointToRestore) { checkpoint in
            Button("Fork Session") {
                Task {
                    if let forked = await viewModel.restoreCheckpoint(checkpoint) {
                        onRestored?(forked)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { checkpoint in
            Text("This will create a new session forked from \"\(checkpoint.name)\" (\(checkpoint.messageCount) messages). Your current session will not be modified.")
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadCheckpoints(sessionId: session.id)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Interruption icon
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    Text(interruptionReasonText)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }

            // Last active timestamp
            Label {
                Text("Last active: \(session.lastActiveAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(theme.textSecondary)
            }
            .font(.caption)
        }
    }

    /// The human-readable interruption reason, falling back to a generic message.
    private var interruptionReasonText: String {
        if let reason = session.interruptionReason, !reason.isEmpty {
            return reason
        }
        return "Session was interrupted"
    }

    // MARK: - Checkpoints section

    @ViewBuilder
    private var checkpointsSection: some View {
        if viewModel.isLoading {
            ProgressView("Loading checkpoints…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let error = viewModel.error {
            errorView(message: error)
        } else if viewModel.checkpoints.isEmpty {
            emptyStateView
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Prominent one-tap restore button for the latest checkpoint
                if let latest = viewModel.checkpoints.first {
                    Button {
                        checkpointToRestore = latest
                        showRestoreAlert = true
                    } label: {
                        Label("Restore Latest Checkpoint", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                // Timeline label
                Text("All Checkpoints")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 4)

                // Timeline rows (checkpoints already sorted descending from the API/ViewModel)
                VStack(spacing: 0) {
                    ForEach(viewModel.checkpoints) { checkpoint in
                        checkpointRow(checkpoint)

                        if checkpoint.id != viewModel.checkpoints.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Checkpoint row

    private func checkpointRow(_ checkpoint: SessionCheckpoint) -> some View {
        HStack(spacing: 12) {
            // Checkpoint type indicator
            Image(systemName: checkpoint.isAutomatic ? "clock.arrow.circlepath" : "bookmark.fill")
                .font(.system(size: 16))
                .foregroundStyle(checkpoint.isAutomatic ? theme.textSecondary : theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(checkpoint.name)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)

                Text(checkpoint.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            // Message count badge
            Text("\(checkpoint.messageCount)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.bgPrimary, in: Capsule())

            // Per-row restore button
            Button {
                checkpointToRestore = checkpoint
                showRestoreAlert = true
            } label: {
                Text("Restore")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(theme.textSecondary)

            Text("No Checkpoints")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Text("No checkpoints were saved for this session. You can still continue where the session left off.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Error state

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.warning)

            Text("Failed to load checkpoints")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            Button("Retry") {
                Task { await viewModel.loadCheckpoints(sessionId: session.id) }
            }
            .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
