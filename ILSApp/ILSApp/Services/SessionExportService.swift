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

    /// Build a Markdown comparison export from two ``ChatSession`` objects and their message arrays.
    ///
    /// Produces a document with a header naming both sessions, a metrics table, and numbered
    /// parallel message turns (one column per session). Missing turns are shown as _(no message)_.
    ///
    /// This variant is used by ``SessionComparisonView`` when sharing the comparison report.
    static func exportComparisonMarkdown(
        sessionA: ChatSession,
        messagesA: [Message],
        sessionB: ChatSession,
        messagesB: [Message]
    ) -> String {
        var md = "# Session Comparison\n\n"

        // Session headers
        md += "## Sessions\n\n"
        md += "**Session A:** \(sessionA.name ?? "Unnamed")\n"
        md += "**Session B:** \(sessionB.name ?? "Unnamed")\n\n"

        // Metrics table
        md += "## Metrics\n\n"
        md += "| Metric | Session A | Session B |\n"
        md += "|--------|-----------|----------|\n"
        md += "| Messages | \(messagesA.count) | \(messagesB.count) |\n"
        md += "| Model | \(sessionA.model.capitalized) | \(sessionB.model.capitalized) |\n"
        md += "| Status | \(sessionA.status.rawValue.capitalized) | \(sessionB.status.rawValue.capitalized) |\n"
        if let costA = sessionA.totalCostUSD, let costB = sessionB.totalCostUSD {
            md += "| Cost | $\(String(format: "%.4f", costA)) | $\(String(format: "%.4f", costB)) |\n"
        }
        md += "\n---\n\n"

        // Parallel message pairs
        md += "## Messages\n\n"
        let maxCount = max(messagesA.count, messagesB.count)
        for index in 0..<maxCount {
            md += "### Turn \(index + 1)\n\n"
            if index < messagesA.count {
                let msg = messagesA[index]
                let role = msg.role.rawValue.capitalized
                md += "**A — \(role):** \(msg.content)\n\n"
            } else {
                md += "**A:** _(no message)_\n\n"
            }
            if index < messagesB.count {
                let msg = messagesB[index]
                let role = msg.role.rawValue.capitalized
                md += "**B — \(role):** \(msg.content)\n\n"
            } else {
                md += "**B:** _(no message)_\n\n"
            }
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
