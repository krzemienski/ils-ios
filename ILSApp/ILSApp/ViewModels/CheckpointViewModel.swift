import Foundation
import Observation
import ILSShared

/// View model for checkpoint management within a session.
///
/// Handles loading, creating, restoring, and deleting checkpoints for a given session.
/// Auto-checkpoint settings are persisted via `AppStorage` and shared with the settings UI.
///
/// ## Topics
/// ### Properties
/// - ``checkpoints`` - Array of all loaded checkpoints, newest first
/// - ``isRestoring`` - Whether a restore operation is in progress
/// - ``showRestoreConfirmation`` - Controls the restore confirmation alert
/// - ``pendingRestoreCheckpoint`` - The checkpoint staged for restore
///
/// ### Checkpoint Operations
/// - ``loadCheckpoints(sessionId:)`` - Fetch all checkpoints for a session
/// - ``createCheckpoint(sessionId:label:isAuto:)`` - Create a new checkpoint
/// - ``restoreCheckpoint(sessionId:checkpointId:)`` - Restore session to a checkpoint
/// - ``deleteCheckpoint(sessionId:checkpointId:)`` - Delete a specific checkpoint
@Observable
@MainActor
class CheckpointViewModel: BaseViewModel {
    // MARK: - State

    /// Checkpoints for the current session, sorted newest first.
    var checkpoints: [Checkpoint] = []

    /// Whether a restore operation is currently in progress.
    var isRestoring = false

    /// Error from the most recent restore attempt, if any.
    var restoreError: Error?

    /// Controls visibility of the restore confirmation alert.
    var showRestoreConfirmation = false

    /// The checkpoint staged for restore, pending user confirmation.
    var pendingRestoreCheckpoint: Checkpoint?

    /// Optional callback invoked on the main actor after a checkpoint restore completes successfully.
    ///
    /// Consumers (e.g. `ChatView`) assign this closure to react to restores — for example,
    /// by reloading the message list so stale messages are replaced.
    var onRestoreCompleted: (() -> Void)?

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - API Operations

    /// Load all checkpoints for the given session.
    ///
    /// Replaces the current ``checkpoints`` array with fresh data from the server.
    /// - Parameter sessionId: The session whose checkpoints to load.
    func loadCheckpoints(sessionId: UUID) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<[Checkpoint]> = try await client.get(
                "/sessions/\(sessionId.uuidString.lowercased())/checkpoints"
            )
            checkpoints = response.data ?? []
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load checkpoints: \(error.localizedDescription)",
                category: "checkpoints"
            )
        }

        isLoading = false
    }

    /// Create a new checkpoint for the given session.
    ///
    /// - Parameters:
    ///   - sessionId: The session to checkpoint.
    ///   - label: Optional display label for the checkpoint.
    ///   - isAuto: `true` when created automatically by the system; `false` for manual checkpoints.
    /// - Returns: The created `Checkpoint`, or `nil` on failure.
    @discardableResult
    func createCheckpoint(sessionId: UUID, label: String?, isAuto: Bool) async -> Checkpoint? {
        guard let client else { return nil }

        do {
            let maxCount = UserDefaults.standard.integer(forKey: "checkpointMaxCount")
            let request = CreateCheckpointRequest(
                label: label,
                isAuto: isAuto,
                maxRetained: isAuto && maxCount > 0 ? maxCount : nil
            )
            let response: APIResponse<Checkpoint> = try await client.post(
                "/sessions/\(sessionId.uuidString.lowercased())/checkpoints",
                body: request
            )
            if let checkpoint = response.data {
                // Insert at front — server returns newest-first ordering
                checkpoints.insert(checkpoint, at: 0)
                return checkpoint
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to create checkpoint: \(error.localizedDescription)",
                category: "checkpoints"
            )
        }
        return nil
    }

    /// Restore a session to the state captured in a checkpoint.
    ///
    /// This permanently removes any messages that were created after the checkpoint.
    /// The caller should present ``showRestoreConfirmation`` before invoking this method.
    ///
    /// - Parameters:
    ///   - sessionId: The session to restore.
    ///   - checkpointId: The checkpoint to restore to.
    /// - Returns: A ``RestoreCheckpointResponse`` describing the restored state, or `nil` on failure.
    @discardableResult
    func restoreCheckpoint(sessionId: UUID, checkpointId: UUID) async -> RestoreCheckpointResponse? {
        guard let client else { return nil }
        isRestoring = true
        restoreError = nil

        do {
            let path = "/sessions/\(sessionId.uuidString.lowercased())/checkpoints/\(checkpointId.uuidString.lowercased())/restore"
            let response: APIResponse<RestoreCheckpointResponse> = try await client.post(
                path,
                body: EmptyBody()
            )
            isRestoring = false
            showRestoreConfirmation = false
            pendingRestoreCheckpoint = nil
            onRestoreCompleted?()
            return response.data
        } catch {
            restoreError = error
            AppLogger.shared.error(
                "Failed to restore checkpoint: \(error.localizedDescription)",
                category: "checkpoints"
            )
        }

        isRestoring = false
        return nil
    }

    /// Delete a specific checkpoint.
    ///
    /// Removes the checkpoint from both the server and the local ``checkpoints`` array.
    ///
    /// - Parameters:
    ///   - sessionId: The session that owns the checkpoint.
    ///   - checkpointId: The checkpoint to delete.
    func deleteCheckpoint(sessionId: UUID, checkpointId: UUID) async {
        guard let client else { return }

        do {
            let path = "/sessions/\(sessionId.uuidString.lowercased())/checkpoints/\(checkpointId.uuidString.lowercased())"
            let _: APIResponse<DeletedResponse> = try await client.delete(path)
            checkpoints.removeAll { $0.id == checkpointId }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to delete checkpoint: \(error.localizedDescription)",
                category: "checkpoints"
            )
        }
    }

    // MARK: - Confirmation Helpers

    /// Stage a checkpoint for restore, triggering the confirmation alert.
    /// - Parameter checkpoint: The checkpoint the user wants to restore to.
    func requestRestore(checkpoint: Checkpoint) {
        pendingRestoreCheckpoint = checkpoint
        showRestoreConfirmation = true
    }

    /// Cancel a pending restore, dismissing the confirmation alert.
    func cancelRestore() {
        pendingRestoreCheckpoint = nil
        showRestoreConfirmation = false
    }
}
