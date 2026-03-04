import Foundation
import Observation
import ILSShared

// MARK: - ExportFormat

/// Supported session export formats.
enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case markdown
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json:     return "JSON"
        case .markdown: return "Markdown"
        case .pdf:      return "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .json:     return "json"
        case .markdown: return "md"
        case .pdf:      return "pdf"
        }
    }
}

// MARK: - SessionInfoViewModel

/// View model for the session info detail sheet.
///
/// Extracts API calls (load session, export markdown/JSON/PDF, integrity check)
/// from `SessionInfoView` to follow the project's unidirectional data-flow convention.
@Observable
@MainActor
class SessionInfoViewModel {
    var loadedSession: ChatSession?
    var isLoading = true
    var errorMessage: String?
    var isExporting = false
    var exportMarkdown = ""
    /// Binary export payload for JSON or PDF exports.
    var exportData: Data?
    /// Results from the most recent integrity check.
    var integrityResults: [IntegrityCheckResult] = []

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

    // MARK: - Multi-Format Export

    /// Export the session as pretty-printed JSON, storing the result in ``exportData``.
    ///
    /// Fetches a `ChatExport` from the backend and encodes it to UTF-8 JSON bytes.
    func exportJSON(session: ChatSession) async {
        guard let client else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let response: APIResponse<ChatExport> = try await client.get(
                "/sessions/\(session.id.uuidString)/export?format=json"
            )
            if let chatExport = response.data {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                exportData = try encoder.encode(chatExport)
            } else {
                errorMessage = "No export data returned"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Export the session as a PDF, storing the result in ``exportData``.
    ///
    /// Fetches messages from the API, maps them to `ChatMessage` values, and renders
    /// the PDF via ``SessionExportService/exportPDF(session:messages:)``.
    func exportPDF(session: ChatSession) async {
        guard let client else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let response: APIResponse<ListResponse<Message>> = try await client.get(
                "/sessions/\(session.id.uuidString)/messages?limit=500"
            )
            let messages: [ChatMessage] = (response.data?.items ?? []).map { message in
                ChatMessage(
                    id: message.id,
                    isUser: message.role == .user,
                    text: message.content,
                    timestamp: message.createdAt
                )
            }
            exportData = SessionExportService.exportPDF(session: session, messages: messages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Integrity Check

    /// Run a session integrity check and populate ``integrityResults``.
    ///
    /// Calls the backend `/sessions/integrity-check` endpoint and stores
    /// any detected mismatches for display in the UI.
    func runIntegrityCheck() async {
        guard let client else { return }

        do {
            let response: APIResponse<[IntegrityCheckResult]> = try await client.runIntegrityCheck()
            integrityResults = response.data ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
