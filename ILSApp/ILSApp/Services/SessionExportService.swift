import Foundation
import ILSShared
#if os(iOS)
import PDFKit
import UIKit
#endif

/// Shared service for exporting chat sessions as Markdown or PDF.
///
/// Used by both ``ChatView`` and ``SessionInfoView`` to avoid
/// duplicating the session-to-Markdown/PDF conversion logic.
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

    // MARK: - PDF Export

#if os(iOS)
    /// Build a PDF export from a ``ChatSession`` and its local ``ChatMessage`` array.
    ///
    /// Renders a US-Letter PDF with a session header block followed by each message,
    /// formatted with colour-coded role labels. Long content flows across pages automatically.
    ///
    /// - Parameters:
    ///   - session: The session whose metadata appears in the header.
    ///   - messages: The ordered list of messages to render.
    /// - Returns: Raw PDF bytes suitable for sharing via `UIActivityViewController`.
    static func exportPDF(session: ChatSession, messages: [ChatMessage]) -> Data {
        let pageSize   = CGSize(width: 612, height: 792) // US Letter at 72 dpi
        let pageRect   = CGRect(origin: .zero, size: pageSize)
        let margin: CGFloat    = 48
        let contentWidth: CGFloat = pageSize.width - margin * 2
        let contentMaxY: CGFloat  = pageSize.height - margin

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // MARK: Layout helpers

            /// Measure the height required to render `text` in `attributes` within `contentWidth`.
            func measureHeight(_ text: String, _ attributes: [NSAttributedString.Key: Any]) -> CGFloat {
                ceil(text.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height)
            }

            /// Start a new PDF page if the remaining vertical space is insufficient.
            func ensureSpace(_ height: CGFloat) {
                if y + height > contentMaxY {
                    ctx.beginPage()
                    y = margin
                }
            }

            /// Draw `text` at the current cursor, advancing `y` by the rendered height.
            func drawText(_ text: String, attributes: [NSAttributedString.Key: Any]) {
                guard !text.isEmpty else { return }
                let h = measureHeight(text, attributes)
                ensureSpace(h)
                text.draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: h),
                    withAttributes: attributes
                )
                y += h
            }

            // MARK: Typography

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.label
            ]
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let userRoleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.systemBlue
            ]
            let assistantRoleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.systemGreen
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]

            // MARK: Session header

            drawText("Session: \(session.name ?? "Unnamed")", attributes: titleAttrs)
            y += 6

            drawText("Model: \(session.model.capitalized)", attributes: metaAttrs)
            drawText("Status: \(session.status.rawValue.capitalized)", attributes: metaAttrs)
            drawText("Created: \(session.createdAt.formatted())", attributes: metaAttrs)
            drawText("Last Active: \(session.lastActiveAt.formatted())", attributes: metaAttrs)
            if let cost = session.totalCostUSD {
                drawText("Cost: $\(String(format: "%.4f", cost))", attributes: metaAttrs)
            }

            // Hairline separator
            y += 12
            ensureSpace(4)
            if let cgCtx = UIGraphicsGetCurrentContext() {
                cgCtx.saveGState()
                cgCtx.setStrokeColor(UIColor.separator.cgColor)
                cgCtx.setLineWidth(0.5)
                cgCtx.move(to: CGPoint(x: margin, y: y))
                cgCtx.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
                cgCtx.strokePath()
                cgCtx.restoreGState()
            }
            y += 14

            // MARK: Messages

            for message in messages {
                let roleText  = message.isUser ? "User" : "Assistant"
                let roleAttrs = message.isUser ? userRoleAttrs : assistantRoleAttrs

                drawText(roleText, attributes: roleAttrs)
                y += 4
                drawText(message.text, attributes: bodyAttrs)
                y += 16
            }
        }
    }

#else
    /// PDF export is not supported on macOS; returns empty `Data`.
    static func exportPDF(session: ChatSession, messages: [ChatMessage]) -> Data {
        Data()
    }
#endif

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
