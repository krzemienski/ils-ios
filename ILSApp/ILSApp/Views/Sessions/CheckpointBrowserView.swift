import SwiftUI
import ILSShared

/// Browse, create, restore, and delete session checkpoints.
///
/// Displays all saved checkpoints for a session in a list ordered newest-first.
/// Each row shows an Auto/Manual badge, the relative timestamp, an optional label,
/// and the message count captured at that point. Rows support swipe-to-delete and
/// a Restore button that presents a confirmation alert before discarding later messages.
///
/// A toolbar button opens a sheet for creating a manual checkpoint with an optional label.
/// While a restore is in progress a full-screen spinner overlay is presented.
///
/// ## Topics
/// ### Parameters
/// - ``session`` - The session whose checkpoints are being managed
/// - ``viewModel`` - Injected ``CheckpointViewModel`` for all checkpoint operations
struct CheckpointBrowserView: View {
    let session: ChatSession
    @Bindable var viewModel: CheckpointViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var showCreateSheet = false
    @State private var newCheckpointLabel = ""
    @State private var isCreating = false
    @State private var showCreatedToast = false
    @AppStorage("checkpointInterval") private var checkpointInterval: Int = 5

    var body: some View {
        ZStack {
            checkpointList
                .background(theme.bgPrimary)

            if viewModel.isRestoring {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: theme.spacingMD) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(theme.accent)
                    Text("Restoring…")
                        .font(.subheadline)
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(theme.spacingLG)
                .background(theme.bgSecondary.opacity(0.95))
                .cornerRadius(theme.cornerRadius)
            }
        }
        .navigationTitle("Checkpoints")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newCheckpointLabel = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Save checkpoint")
            }
        }
        // MARK: Create checkpoint sheet
        .sheet(isPresented: $showCreateSheet) {
            createCheckpointSheet
        }
        // MARK: Restore confirmation alert
        .alert("Restore Checkpoint?", isPresented: $viewModel.showRestoreConfirmation) {
            Button("Restore", role: .destructive) {
                guard let checkpoint = viewModel.pendingRestoreCheckpoint else { return }
                Task {
                    await viewModel.restoreCheckpoint(
                        sessionId: session.id,
                        checkpointId: checkpoint.id
                    )
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelRestore()
            }
        } message: {
            if let checkpoint = viewModel.pendingRestoreCheckpoint {
                Text(
                    "Restore to \"\(checkpoint.displayTitle)\"? Messages created after this checkpoint will be removed."
                )
            }
        }
        .toast(isPresented: $showCreatedToast, message: "Checkpoint saved")
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadCheckpoints(sessionId: session.id)
        }
    }

    // MARK: - Checkpoint List

    @ViewBuilder
    private var checkpointList: some View {
        if viewModel.isLoading {
            ProgressView("Loading checkpoints…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            errorView(message: error.localizedDescription)
        } else if viewModel.checkpoints.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(viewModel.checkpoints) { checkpoint in
                    checkpointRow(checkpoint)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteCheckpoint(
                                        sessionId: session.id,
                                        checkpointId: checkpoint.id
                                    )
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Checkpoint Row

    @ViewBuilder
    private func checkpointRow(_ checkpoint: Checkpoint) -> some View {
        HStack(alignment: .center, spacing: theme.spacingSM) {
            // Auto / Manual badge
            Text(checkpoint.isAuto ? "Auto" : "Manual")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    checkpoint.isAuto
                        ? theme.accent.opacity(0.15)
                        : theme.warning.opacity(0.15)
                )
                .foregroundStyle(
                    checkpoint.isAuto
                        ? theme.accent
                        : theme.warning
                )
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(checkpoint.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(checkpoint.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Text("\(checkpoint.messageCount) msg\(checkpoint.messageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.requestRestore(checkpoint: checkpoint)
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body)
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore to \(checkpoint.displayTitle)")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(theme.textSecondary.opacity(0.5))

            Text("No checkpoints yet")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Text("Checkpoints are created automatically every \(checkpointInterval) messages. Tap + to save one manually.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.warning)

            Text("Failed to load checkpoints")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.loadCheckpoints(sessionId: session.id) }
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create Checkpoint Sheet

    @ViewBuilder
    private var createCheckpointSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (optional)", text: $newCheckpointLabel)
                        .submitLabel(.done)
                } header: {
                    Text("Checkpoint Label")
                } footer: {
                    Text("A label helps you identify this checkpoint later. Leave blank to use the default name.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Save Checkpoint")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isCreating = true
                            let label = newCheckpointLabel.trimmingCharacters(in: .whitespaces)
                            await viewModel.createCheckpoint(
                                sessionId: session.id,
                                label: label.isEmpty ? nil : label,
                                isAuto: false
                            )
                            isCreating = false
                            showCreateSheet = false
                            showCreatedToast = true
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isCreating)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }
}
