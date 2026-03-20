import Foundation
import Observation
import ILSShared

/// View model for the session recovery UI.
///
/// Bridges `SessionRecoveryService` to the SwiftUI layer, exposing the list of
/// recoverable sessions and their checkpoints, and handling restore / dismiss
/// actions.
@Observable
@MainActor
class SessionRecoveryViewModel {
    var recoverableSessions: [ChatSession] = []
    var checkpointsBySession: [UUID: [SessionCheckpoint]] = [:]
    var isRestoring = false
    var restoredSession: ChatSession?
    var error: String?

    private var client: APIClient?
    private let service = SessionRecoveryService.shared

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Load

    /// Synchronises local state from the service, then triggers a refresh if needed.
    func loadIfNeeded() async {
        guard let client else { return }
        await syncFromService()
        await service.refreshIfNeeded(client: client)
        await syncFromService()
    }

    /// Forces an unconditional refresh from the backend.
    func refresh() async {
        guard let client else { return }
        await service.refresh(client: client)
        await syncFromService()
    }

    // MARK: - Restore

    /// One-tap restore: restores the most-recent checkpoint for the given session.
    func restoreLatestCheckpoint(for session: ChatSession) async {
        guard let client else { return }

        let checkpoints = checkpointsBySession[session.id] ?? []
        guard let latest = checkpoints.first else {
            error = "No checkpoint available for this session."
            return
        }

        await performRestore(checkpoint: latest, client: client)
    }

    /// Restores an arbitrary checkpoint (e.g., selected from the timeline).
    func restoreCheckpoint(_ checkpoint: SessionCheckpoint) async {
        guard let client else { return }
        await performRestore(checkpoint: checkpoint, client: client)
    }

    // MARK: - Dismiss

    /// Hides the given session from the recovery UI and persists the suppression.
    func dismissSession(_ session: ChatSession) async {
        await service.dismissRecovery(for: session.id)
        await syncFromService()
    }

    // MARK: - Private Helpers

    private func performRestore(checkpoint: SessionCheckpoint, client: APIClient) async {
        isRestoring = true
        error = nil

        do {
            let response: APIResponse<ChatSession> = try await client.restoreCheckpoint(id: checkpoint.id)
            restoredSession = response.data
        } catch {
            self.error = error.localizedDescription
        }

        isRestoring = false
    }

    /// Pulls the latest state from the actor-isolated service onto the main actor.
    private func syncFromService() async {
        let sessions = await service.recoverableSessions
        let checkpoints = await service.checkpointsBySession
        recoverableSessions = sessions
        checkpointsBySession = checkpoints
    }
}
