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
