import Foundation
import Observation
import ILSShared

/// View model for the session info detail sheet.
///
/// Extracts API calls (load session, export markdown) from `SessionInfoView`
/// to follow the project's unidirectional data-flow convention.
@Observable
@MainActor
class SessionInfoViewModel {
    var loadedSession: ChatSession?
    var isLoading = true
    var errorMessage: String?
    var isExporting = false
    var exportMarkdown = ""

    /// Whether a model update request is currently in flight.
    var isUpdatingModel = false

    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
    }

    func loadSession(id: UUID) async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response: APIResponse<ChatSession> = try await client.get("/sessions/\(id.uuidString)")
            if let data = response.data {
                loadedSession = data
            } else {
                errorMessage = "No session data returned"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Update the Claude model for an existing session via `PATCH /sessions/:id/model`.
    ///
    /// - Parameters:
    ///   - sessionId: UUID of the session to update.
    ///   - model: New model short name (e.g. `"haiku"`, `"sonnet"`, `"opus"`).
    /// - Returns: `true` on success, `false` on failure.
    func updateModel(sessionId: UUID, model: String) async -> Bool {
        guard let client else { return false }
        isUpdatingModel = true
        defer { isUpdatingModel = false }

        do {
            let body = UpdateSessionModelRequest(model: model)
            let response: APIResponse<ChatSession> = try await client.patch(
                "/sessions/\(sessionId.uuidString)/model",
                body: body
            )
            if let updated = response.data {
                loadedSession = updated
                return true
            }
        } catch {
            AppLogger.shared.error("Failed to update session model: \(error)", category: "ui")
        }
        return false
    }

    func exportSession(session: ChatSession) async {
        guard let client else { return }
        isExporting = true
        exportMarkdown = await SessionExportService.exportMarkdown(
            session: session,
            apiClient: client
        )
        isExporting = false
    }
}
