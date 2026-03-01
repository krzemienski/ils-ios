import Foundation
import ILSShared

/// Manages automatic session checkpoints and integrity verification.
///
/// Tracks the message count at which the last auto-checkpoint was created for each
/// session (persisted in UserDefaults). When `didSendMessage(sessionId:newCount:client:)`
/// is called and the delta since the last checkpoint reaches the configured interval,
/// a new automatic checkpoint is created via the API.
///
/// The checkpoint interval is read from `UserDefaults.standard` under the key
/// `"checkpointInterval"`. If the stored value is 0 or missing, the default of 10 is used.
actor SessionBackupService {
    static let shared = SessionBackupService()

    // MARK: - Constants

    /// UserDefaults key for the checkpoint interval setting.
    private let intervalKey = "checkpointInterval"
    /// Default number of messages between automatic checkpoints.
    private let defaultInterval = 10
    /// UserDefaults key prefix used to store the message count at last checkpoint per session.
    private let lastCheckpointCountPrefix = "sessionLastCheckpointCount_"

    private init() {}

    // MARK: - Configuration

    /// The currently configured auto-checkpoint interval (minimum 1).
    var checkpointInterval: Int {
        let stored = UserDefaults.standard.integer(forKey: intervalKey)
        return stored > 0 ? stored : defaultInterval
    }

    // MARK: - Auto-Checkpoint

    /// Called whenever a new message is added to a session.
    ///
    /// Checks whether the message count has crossed the configured checkpoint interval
    /// boundary since the last auto-checkpoint and, if so, creates a new one.
    ///
    /// - Parameters:
    ///   - sessionId: The session that received a new message.
    ///   - newCount: The total number of messages in the session after the new message.
    ///   - client: The `APIClient` instance used to call the checkpoint API.
    func didSendMessage(sessionId: UUID, newCount: Int, client: APIClient) async {
        let interval = checkpointInterval
        let lastCountKey = lastCheckpointCountPrefix + sessionId.uuidString
        let lastCount = UserDefaults.standard.integer(forKey: lastCountKey)

        guard newCount > 0, newCount - lastCount >= interval else { return }

        do {
            let name = "Auto checkpoint (\(newCount) messages)"
            let _: APIResponse<SessionCheckpoint> = try await client.createCheckpoint(
                sessionId: sessionId,
                name: name,
                isAutomatic: true
            )
            UserDefaults.standard.set(newCount, forKey: lastCountKey)
            AppLogger.shared.info(
                "Auto-checkpoint created for session \(sessionId) at \(newCount) messages",
                category: "backup"
            )
        } catch {
            AppLogger.shared.error(
                "Auto-checkpoint failed for session \(sessionId): \(error.localizedDescription)",
                category: "backup"
            )
        }
    }

    /// Resets the stored checkpoint baseline for a session.
    ///
    /// Call this when a session is deleted or when the user manually wants to
    /// restart the auto-checkpoint counter.
    ///
    /// - Parameter sessionId: The session whose checkpoint state should be cleared.
    func resetCheckpointState(for sessionId: UUID) {
        let key = lastCheckpointCountPrefix + sessionId.uuidString
        UserDefaults.standard.removeObject(forKey: key)
        AppLogger.shared.info(
            "Checkpoint state reset for session \(sessionId)",
            category: "backup"
        )
    }

    // MARK: - Integrity Check

    /// Runs a server-side integrity check verifying that each session's stored
    /// `messageCount` matches the actual number of persisted messages.
    ///
    /// - Parameters:
    ///   - client: The `APIClient` instance used to call the integrity-check endpoint.
    ///   - fix: Pass `true` to have the backend repair any count mismatches in place.
    /// - Returns: An `APIResponse` wrapping an array of `IntegrityCheckResult` items.
    @discardableResult
    func runIntegrityCheck(
        client: APIClient,
        fix: Bool = false
    ) async -> APIResponse<[IntegrityCheckResult]>? {
        do {
            let result: APIResponse<[IntegrityCheckResult]> = try await client.runIntegrityCheck(
                fix: fix
            )
            let issueCount = result.data?.filter { !$0.passed }.count ?? 0
            AppLogger.shared.info(
                "Integrity check complete — \(issueCount) issue(s) found",
                category: "backup"
            )
            return result
        } catch {
            AppLogger.shared.error(
                "Integrity check failed: \(error.localizedDescription)",
                category: "backup"
            )
            return nil
        }
    }
}
