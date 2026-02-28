import Foundation
import Observation
import ILSShared

/// View model for host profile detail, extracting lifecycle and log operations
/// from `HostProfileDetailView` to follow unidirectional data-flow conventions.
@Observable
@MainActor
class HostProfileDetailViewModel {
    var logs: [String] = []
    var isLoadingLogs = false

    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
    }

    /// Sends a lifecycle action (start/stop/restart) to the host profile endpoint.
    ///
    /// Uses explicit error handling instead of silent `try?` to surface failures.
    func performLifecycle(_ action: LifecycleRequest.LifecycleAction, hostId: UUID) async {
        guard let client else { return }
        let request = LifecycleRequest(action: action, hostId: hostId)
        do {
            let _: LifecycleResponse = try await client.post("/host-profiles/\(hostId)/lifecycle", body: request)
        } catch {
            AppLogger.shared.error("Lifecycle \(action) failed for host \(hostId): \(error.localizedDescription)", category: "fleet")
        }
    }

    /// Loads log lines from the host profile endpoint.
    ///
    /// Uses explicit error handling instead of silent `try?`.
    func loadLogs(hostId: UUID) async {
        guard let client else { return }
        isLoadingLogs = true
        defer { isLoadingLogs = false }
        do {
            let response: RemoteLogsResponse = try await client.get("/host-profiles/\(hostId)/logs")
            logs = response.lines
        } catch {
            AppLogger.shared.error("Failed to load logs for host \(hostId): \(error.localizedDescription)", category: "fleet")
        }
    }
}
