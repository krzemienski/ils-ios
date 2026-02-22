import Foundation
import ILSShared

/// Shared service for exporting chat sessions as Markdown.
///
/// Used by both ``ChatView`` and ``SessionInfoView`` to avoid
/// duplicating the session-to-Markdown conversion logic.
enum SessionExportService {

    /// Build a Markdown export from a ``ChatSession`` and its local ``ChatMessage`` array.
    ///
    /// This variant is used by ``ChatView``, which already holds messages in memory.
    static func exportMarkdown(session: ChatSession, messages: [ChatMessage]) -> String {
        var md = header(for: session)

        for message in messages {
            let role = message.isUser ? "User" : "Assistant"
            md += "## \(role)\n\n\(message.text)\n\n"
        }

        return md
    }

    /// Build a Markdown export from a ``ChatSession`` by fetching messages from the API.
    ///
    /// This variant is used by ``SessionInfoView``, which does not hold messages locally.
    static func exportMarkdown(session: ChatSession, apiClient: APIClient) async -> String {
        var md = header(for: session)

        do {
            let response: APIResponse<ListResponse<Message>> = try await apiClient.get(
                "/sessions/\(session.id.uuidString)/messages?limit=500"
            )
            if let messages = response.data?.items {
                for message in messages {
                    let role = message.role.rawValue.capitalized
                    md += "## \(role)\n\n\(message.content)\n\n"
                }
            }
        } catch {
            md += "_Failed to load messages: \(error.localizedDescription)_\n"
        }

        return md
    }

    // MARK: - Private

    private static func header(for session: ChatSession) -> String {
        var md = "# Session: \(session.name ?? "Unnamed")\n\n"
        md += "Model: \(session.model.capitalized)\n"
        md += "Status: \(session.status.rawValue.capitalized)\n"
        md += "Created: \(session.createdAt.formatted())\n"
        md += "Last Active: \(session.lastActiveAt.formatted())\n"
        if let cost = session.totalCostUSD {
            md += "Cost: $\(String(format: "%.4f", cost))\n"
        }
        md += "\n---\n\n"
        return md
    }
}
