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
        let totalTokens = messages.reduce(0) { $0 + $1.tokenCount }
        var md = header(for: session, totalTokens: totalTokens > 0 ? totalTokens : nil)

        for message in messages {
            let role = message.isUser ? "User" : "Assistant"
            md += "## \(role)\n\n\(message.text)\n\n"

            // Append tool calls as a bullet list under assistant messages
            if !message.isUser && !message.toolCalls.isEmpty {
                md += "**Tool Calls:**\n\n"
                for toolCall in message.toolCalls {
                    md += "- `\(toolCall.name)`\n"
                }
                md += "\n"
            }
        }

        return md
    }

    /// Build a Markdown export from a ``ChatSession`` and its local ``ChatMessage`` array,
    /// optionally limited to a range of message indices.
    ///
    /// - Parameters:
    ///   - session: The session whose metadata appears in the header.
    ///   - messages: The full ordered list of messages.
    ///   - range: An optional closed range of message indices to export. When `nil`, all messages are exported.
    /// - Returns: A Markdown string representing the exported session.
    static func exportMarkdown(session: ChatSession, messages: [ChatMessage], range: ClosedRange<Int>?) -> String {
        let sliced = sliceMessages(messages, range: range)
        return exportMarkdown(session: session, messages: sliced)
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

                    // Append tool calls if present on assistant messages
                    if message.role == .assistant, let toolCallsJSON = message.toolCalls,
                       !toolCallsJSON.isEmpty {
                        let toolNames = parseToolNames(from: toolCallsJSON)
                        if !toolNames.isEmpty {
                            md += "**Tool Calls:**\n\n"
                            for name in toolNames {
                                md += "- `\(name)`\n"
                            }
                            md += "\n"
                        }
                    }
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

    /// ILS accent colour used for branding elements in PDF exports.
    private static let ilsAccentColor = UIColor(red: 0.35, green: 0.47, blue: 1.0, alpha: 1.0)

#if os(iOS)
    /// Build a PDF export from a ``ChatSession`` and its local ``ChatMessage`` array.
    ///
    /// Renders a US-Letter PDF with ILS branding header, accent color bar, session metadata
    /// table, syntax-aware message rendering (monospace code blocks, grey tool-call sections),
    /// and page numbers in the footer. Long content flows across pages automatically.
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
        let footerHeight: CGFloat = 30
        let contentMaxY: CGFloat  = pageSize.height - margin - footerHeight

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            var pageNumber = 1
            var y: CGFloat = margin

            // MARK: Layout helpers

            /// Measure the height required to render `text` in `attributes` within a given width.
            func measureHeight(_ text: String, _ attributes: [NSAttributedString.Key: Any], width: CGFloat = contentWidth) -> CGFloat {
                ceil(text.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height)
            }

            /// Draw page number in the footer area of the current page.
            func drawFooter() {
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                let footerText = "Page \(pageNumber)"
                let footerSize = footerText.size(withAttributes: footerAttrs)
                let footerX = (pageSize.width - footerSize.width) / 2
                let footerY = pageSize.height - margin
                footerText.draw(at: CGPoint(x: footerX, y: footerY), withAttributes: footerAttrs)
            }

            /// Start a new PDF page if the remaining vertical space is insufficient.
            func ensureSpace(_ height: CGFloat) {
                if y + height > contentMaxY {
                    drawFooter()
                    ctx.beginPage()
                    pageNumber += 1
                    y = margin
                }
            }

            /// Draw `text` at the current cursor, advancing `y` by the rendered height.
            func drawText(_ text: String, attributes: [NSAttributedString.Key: Any], inset: CGFloat = 0) {
                guard !text.isEmpty else { return }
                let drawWidth = contentWidth - inset * 2
                let h = measureHeight(text, attributes, width: drawWidth)
                ensureSpace(h)
                text.draw(
                    in: CGRect(x: margin + inset, y: y, width: drawWidth, height: h),
                    withAttributes: attributes
                )
                y += h
            }

            /// Draw a filled rectangle behind a text block (e.g. for code blocks or tool calls).
            func drawBackgroundRect(height: CGFloat, color: UIColor, inset: CGFloat = 0, cornerRadius: CGFloat = 4) {
                let bgRect = CGRect(x: margin + inset, y: y, width: contentWidth - inset * 2, height: height)
                let path = UIBezierPath(roundedRect: bgRect, cornerRadius: cornerRadius)
                color.setFill()
                path.fill()
            }

            // MARK: Typography

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.label
            ]
            let metaLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let metaValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.label
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
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            let codeLangAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let toolCallAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let toolCallLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]

            // Start first page
            ctx.beginPage()

            // MARK: ILS Branding Header

            // Accent color bar at the top of the first page
            if let cgCtx = UIGraphicsGetCurrentContext() {
                cgCtx.saveGState()
                cgCtx.setFillColor(ilsAccentColor.cgColor)
                cgCtx.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: 4))
                cgCtx.restoreGState()
            }

            // App name
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: ilsAccentColor
            ]
            drawText("ILS — Intelligent Local Server", attributes: brandAttrs)
            y += 4

            // Session title
            drawText(session.name ?? "Unnamed Session", attributes: titleAttrs)
            y += 10

            // MARK: Session Metadata Table

            // Compute metadata rows for a two-column table layout
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            let duration = session.lastActiveAt.timeIntervalSince(session.createdAt)

            var metadataRows: [(String, String)] = [
                ("Model", session.model.capitalized),
                ("Status", session.status.rawValue.capitalized),
                ("Created", dateFormatter.string(from: session.createdAt)),
                ("Last Active", dateFormatter.string(from: session.lastActiveAt))
            ]
            if duration > 0 {
                metadataRows.append(("Duration", formattedDuration(duration)))
            }
            metadataRows.append(("Messages", "\(messages.count)"))

            let totalTokens = messages.reduce(0) { $0 + $1.tokenCount }
            if totalTokens > 0 {
                metadataRows.append(("Tokens", "\(totalTokens)"))
            }
            if let cost = session.totalCostUSD {
                metadataRows.append(("Cost", "$\(String(format: "%.4f", cost))"))
            }

            // Draw metadata table with light background
            let tableRowHeight: CGFloat = 18
            let tablePadding: CGFloat = 8
            let tableHeight = CGFloat(metadataRows.count) * tableRowHeight + tablePadding * 2
            let labelColumnWidth: CGFloat = 90

            ensureSpace(tableHeight)

            // Table background
            let tableRect = CGRect(x: margin, y: y, width: contentWidth, height: tableHeight)
            let tablePath = UIBezierPath(roundedRect: tableRect, cornerRadius: 6)
            UIColor.secondarySystemBackground.setFill()
            tablePath.fill()

            y += tablePadding
            for (label, value) in metadataRows {
                let labelRect = CGRect(x: margin + 12, y: y, width: labelColumnWidth, height: tableRowHeight)
                let valueRect = CGRect(x: margin + 12 + labelColumnWidth, y: y, width: contentWidth - labelColumnWidth - 24, height: tableRowHeight)
                label.draw(in: labelRect, withAttributes: metaLabelAttrs)
                value.draw(in: valueRect, withAttributes: metaValueAttrs)
                y += tableRowHeight
            }
            y += tablePadding

            // Hairline separator after metadata
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

                // Parse message text for code blocks using MarkdownParser
                let segments = MarkdownParser.parse(message.text)

                for segment in segments {
                    switch segment {
                    case .plainText(let text):
                        drawText(text, attributes: bodyAttrs)

                    case .codeBlock(let block):
                        let codePadding: CGFloat = 8
                        let codeInset: CGFloat = 6
                        let codeDrawWidth = contentWidth - (codeInset + codePadding) * 2
                        let codeHeight = measureHeight(block.code, codeAttrs, width: codeDrawWidth)
                        let langHeight: CGFloat = block.language != nil ? 16 : 0
                        let totalBlockHeight = codeHeight + codePadding * 2 + langHeight

                        ensureSpace(totalBlockHeight)

                        // Code block background
                        drawBackgroundRect(height: totalBlockHeight, color: UIColor.secondarySystemBackground, inset: codeInset, cornerRadius: 6)

                        y += codePadding

                        // Language label
                        if let lang = block.language {
                            let langText = lang.uppercased()
                            langText.draw(
                                at: CGPoint(x: margin + codeInset + codePadding, y: y),
                                withAttributes: codeLangAttrs
                            )
                            y += langHeight
                        }

                        // Code content in monospace
                        block.code.draw(
                            in: CGRect(x: margin + codeInset + codePadding, y: y, width: codeDrawWidth, height: codeHeight),
                            withAttributes: codeAttrs
                        )
                        y += codeHeight + codePadding

                    case .inlineCode(let code):
                        // Render inline code with monospace font inline
                        let inlineAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                            .foregroundColor: UIColor.label,
                            .backgroundColor: UIColor.secondarySystemBackground
                        ]
                        drawText(code, attributes: inlineAttrs)
                    }
                }

                // Tool calls section with grey background
                if !message.isUser && !message.toolCalls.isEmpty {
                    y += 6
                    let toolPadding: CGFloat = 8
                    let toolInset: CGFloat = 6

                    // Calculate total height for tool call block
                    let toolLabelHeight = measureHeight("Tool Calls", toolCallLabelAttrs, width: contentWidth - (toolInset + toolPadding) * 2)
                    var toolContentHeight: CGFloat = 0
                    for toolCall in message.toolCalls {
                        toolContentHeight += measureHeight("• \(toolCall.name)", toolCallAttrs, width: contentWidth - (toolInset + toolPadding) * 2) + 2
                    }
                    let totalToolHeight = toolLabelHeight + toolContentHeight + toolPadding * 2 + 4

                    ensureSpace(totalToolHeight)

                    // Grey background for tool calls
                    drawBackgroundRect(height: totalToolHeight, color: UIColor.tertiarySystemBackground, inset: toolInset, cornerRadius: 6)

                    y += toolPadding

                    // "Tool Calls" label
                    "Tool Calls".draw(
                        at: CGPoint(x: margin + toolInset + toolPadding, y: y),
                        withAttributes: toolCallLabelAttrs
                    )
                    y += toolLabelHeight + 4

                    // Individual tool names
                    let toolDrawWidth = contentWidth - (toolInset + toolPadding) * 2
                    for toolCall in message.toolCalls {
                        let toolText = "• \(toolCall.name)"
                        let h = measureHeight(toolText, toolCallAttrs, width: toolDrawWidth)
                        toolText.draw(
                            in: CGRect(x: margin + toolInset + toolPadding, y: y, width: toolDrawWidth, height: h),
                            withAttributes: toolCallAttrs
                        )
                        y += h + 2
                    }
                    y += toolPadding
                }

                y += 16
            }

            // Draw footer on the last page
            drawFooter()
        }
    }

    /// Build a PDF export from a ``ChatSession`` and its local ``ChatMessage`` array,
    /// optionally limited to a range of message indices.
    ///
    /// - Parameters:
    ///   - session: The session whose metadata appears in the header.
    ///   - messages: The full ordered list of messages.
    ///   - range: An optional closed range of message indices to export. When `nil`, all messages are exported.
    /// - Returns: Raw PDF bytes suitable for sharing via `UIActivityViewController`.
    static func exportPDF(session: ChatSession, messages: [ChatMessage], range: ClosedRange<Int>?) -> Data {
        let sliced = sliceMessages(messages, range: range)
        return exportPDF(session: session, messages: sliced)
    }

#else
    /// PDF export is not supported on macOS; returns empty `Data`.
    static func exportPDF(session: ChatSession, messages: [ChatMessage]) -> Data {
        Data()
    }

    /// Range-based PDF export is not supported on macOS; returns empty `Data`.
    static func exportPDF(session: ChatSession, messages: [ChatMessage], range: ClosedRange<Int>?) -> Data {
        Data()
    }
#endif

    // MARK: - Private

    /// Slice a message array to the given range, clamping to valid bounds.
    ///
    /// Returns the full array when `range` is `nil`.
    private static func sliceMessages(_ messages: [ChatMessage], range: ClosedRange<Int>?) -> [ChatMessage] {
        guard let range = range else { return messages }
        let lower = max(range.lowerBound, 0)
        let upper = min(range.upperBound, messages.count - 1)
        guard lower <= upper, lower < messages.count else { return [] }
        return Array(messages[lower...upper])
    }

    private static func header(for session: ChatSession, totalTokens: Int? = nil) -> String {
        var md = "# Session: \(session.name ?? "Unnamed")\n\n"
        md += "Model: \(session.model.capitalized)\n"
        md += "Status: \(session.status.rawValue.capitalized)\n"
        md += "Created: \(session.createdAt.formatted())\n"
        md += "Last Active: \(session.lastActiveAt.formatted())\n"

        // Session duration derived from creation and last-active timestamps
        let duration = session.lastActiveAt.timeIntervalSince(session.createdAt)
        if duration > 0 {
            md += "Duration: \(formattedDuration(duration))\n"
        }

        if let tokens = totalTokens, tokens > 0 {
            md += "Total Tokens: \(tokens)\n"
        }
        if let cost = session.totalCostUSD {
            md += "Cost: $\(String(format: "%.4f", cost))\n"
        }
        md += "\n---\n\n"
        return md
    }

    /// Format a time interval as a human-readable duration string.
    private static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Extract tool names from a JSON-encoded tool-calls string.
    ///
    /// The JSON is expected to be an array of objects, each with a `"name"` key.
    /// Returns an empty array if the string cannot be parsed.
    private static func parseToolNames(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { $0["name"] as? String }
    }
}
