import SwiftUI
import ILSShared

/// Sheet listing session checkpoints with create, delete, and restore (fork) actions.
///
/// Displays each ``SessionCheckpoint`` with its name, creation date, and a message-count
/// badge. The user can:
/// - **Add** a named checkpoint via the toolbar button (text-field alert).
/// - **Delete** any checkpoint with a swipe-left gesture.
/// - **Restore** a checkpoint by tapping it, which forks the session at that point and
///   invokes ``onRestored`` with the newly created ``ChatSession``.
///
/// An empty state illustration is shown when no checkpoints exist.
///
/// ## Topics
/// ### Callbacks
/// - ``onRestored`` — Invoked after a successful checkpoint restore (fork).
struct SessionCheckpointsView: View {
    let session: ChatSession
    /// Called when the user successfully restores a checkpoint, passing the forked session.
    var onRestored: ((ChatSession) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionCheckpointsViewModel()

    // MARK: - Alert state

    /// Controls the "add checkpoint" name-input alert.
    @State private var showAddAlert = false
    /// The name typed by the user in the add-checkpoint alert.
    @State private var newCheckpointName = ""

    /// The checkpoint the user tapped for a restore confirmation.
    @State private var checkpointToRestore: SessionCheckpoint?
    /// Controls the fork-confirmation alert.
    @State private var showRestoreAlert = false

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading checkpoints…")
            } else if let error = viewModel.error {
                errorView(message: error)
            } else if viewModel.checkpoints.isEmpty {
                emptyStateView
            } else {
                checkpointsList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Checkpoints")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newCheckpointName = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        // MARK: Add checkpoint alert
        .alert("New Checkpoint", isPresented: $showAddAlert) {
            TextField("Checkpoint name", text: $newCheckpointName)
            Button("Save") {
                let name = newCheckpointName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await viewModel.createCheckpoint(sessionId: session.id, name: name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this checkpoint snapshot.")
        }
        // MARK: Restore confirmation alert
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

    // MARK: - Subviews

    private var checkpointsList: some View {
        List {
            ForEach(viewModel.checkpoints) { checkpoint in
                checkpointRow(checkpoint)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        checkpointToRestore = checkpoint
                        showRestoreAlert = true
                    }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { viewModel.checkpoints[$0] }
                Task {
                    for checkpoint in toDelete {
                        await viewModel.deleteCheckpoint(checkpoint)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

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
                .background(theme.bgSecondary, in: Capsule())
        }
        .padding(.vertical, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(theme.textSecondary)

            Text("No Checkpoints")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Text("Tap + to save a named snapshot of this session.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.warning)

            Text("Failed to load checkpoints")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            Button("Retry") {
                Task { await viewModel.loadCheckpoints(sessionId: session.id) }
            }
        }
        .padding()
    }
}
