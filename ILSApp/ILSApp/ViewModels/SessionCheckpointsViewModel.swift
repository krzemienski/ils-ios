import Foundation
import Observation
import ILSShared

/// View model for managing session checkpoints.
///
/// Provides CRUD operations for session checkpoints and handles restore
/// (fork) operations that return a new `ChatSession`.
@Observable
@MainActor
class SessionCheckpointsViewModel {
    var checkpoints: [SessionCheckpoint] = []
    var isLoading = false
    var error: String?

    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Load

    func loadCheckpoints(sessionId: UUID) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<[SessionCheckpoint]> = try await client.listCheckpoints(sessionId: sessionId)
            checkpoints = response.data ?? []
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create

    func createCheckpoint(sessionId: UUID, name: String) async {
        guard let client else { return }
        error = nil

        do {
            let response: APIResponse<SessionCheckpoint> = try await client.createCheckpoint(
                sessionId: sessionId,
                name: name
            )
            if let checkpoint = response.data {
                checkpoints.insert(checkpoint, at: 0)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteCheckpoint(_ checkpoint: SessionCheckpoint) async {
        guard let client else { return }
        error = nil

        do {
            let _: APIResponse<DeletedResponse> = try await client.deleteCheckpoint(id: checkpoint.id)
            checkpoints.removeAll { $0.id == checkpoint.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Restore

    /// Restores (forks) a session from the given checkpoint.
    /// - Returns: The newly forked `ChatSession`, or `nil` if the restore failed.
    func restoreCheckpoint(_ checkpoint: SessionCheckpoint) async -> ChatSession? {
        guard let client else { return nil }
        error = nil

        do {
            let response: APIResponse<ChatSession> = try await client.restoreCheckpoint(id: checkpoint.id)
            return response.data
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
