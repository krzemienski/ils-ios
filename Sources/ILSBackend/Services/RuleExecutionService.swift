import Foundation
import Vapor
import Fluent
import ILSShared

/// Service for executing automation rule actions.
///
/// Handles execution of all rule action types:
/// - `notify`: Prepares notification data for client delivery
/// - `pause`: Sets session status to cancelled
/// - `fork`: Creates a duplicate session with all messages
/// - `export`: Exports session to specified format (Markdown, JSON, or text)
/// - `sendMessage`: Sends an automated message to the session
/// - `switchModel`: Changes the session's Claude model
///
/// All executions are logged to `RuleExecutionLogModel` for auditing.
struct RuleExecutionService {

    // MARK: - Execute Rule Action

    /// Execute a rule's action for a given session and log the result.
    /// - Parameters:
    ///   - rule: The automation rule to execute.
    ///   - session: The session to execute the action on.
    ///   - db: The database connection.
    /// - Returns: A `RuleExecutionLog` with execution details.
    func executeAction(
        for rule: AutomationRule,
        session: ChatSession,
        on db: Database
    ) async throws -> RuleExecutionLog {
        var status: RuleExecutionStatus = .success
        var errorMessage: String?
        var details: String?

        do {
            // Execute the action based on type
            switch rule.actionType {
            case .notify:
                details = try await executeNotifyAction(rule: rule, session: session, on: db)

            case .pause:
                details = try await executePauseAction(session: session, on: db)

            case .fork:
                let forkedSessionId = try await executeForkAction(session: session, on: db)
                details = "Forked session to new session ID: \(forkedSessionId)"

            case .export:
                let exportPath = try await executeExportAction(rule: rule, session: session, on: db)
                details = "Exported session to: \(exportPath)"

            case .sendMessage:
                details = try await executeSendMessageAction(rule: rule, session: session, on: db)

            case .switchModel:
                details = try await executeSwitchModelAction(rule: rule, session: session, on: db)
            }
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
            details = "Action failed: \(error)"
        }

        // Create execution log
        let log = RuleExecutionLog(
            ruleId: rule.id,
            ruleName: rule.name,
            sessionId: session.id,
            sessionName: session.name,
            status: status,
            errorMessage: errorMessage,
            details: details
        )

        // Save to database
        let logModel = RuleExecutionLogModel.from(log)
        try await logModel.save(on: db)

        return log
    }

    // MARK: - Action Implementations

    /// Execute a notify action.
    /// Prepares notification data - actual delivery is handled by the client.
    private func executeNotifyAction(
        rule: AutomationRule,
        session: ChatSession,
        on db: Database
    ) async throws -> String {
        let message = rule.actionConfig.notificationMessage ?? "Rule '\(rule.name)' triggered for session '\(session.name ?? session.id.uuidString)'"
        return "Notification prepared: \(message)"
    }

    /// Execute a pause action by setting the session status to cancelled.
    private func executePauseAction(
        session: ChatSession,
        on db: Database
    ) async throws -> String {
        guard let sessionModel = try await SessionModel.query(on: db)
            .filter(\.$id == session.id)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        sessionModel.status = SessionStatus.cancelled.rawValue
        try await sessionModel.save(on: db)

        return "Session paused (status set to cancelled)"
    }

    /// Execute a fork action by creating a duplicate session.
    private func executeForkAction(
        session: ChatSession,
        on db: Database
    ) async throws -> UUID {
        guard let original = try await SessionModel.query(on: db)
            .filter(\.$id == session.id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Create forked session
        let forked = SessionModel(
            claudeSessionId: nil, // Forked sessions don't inherit claudeSessionId
            name: (original.name ?? "Unnamed") + " (Forked)",
            projectId: original.$project.id,
            model: original.model,
            permissionMode: PermissionMode(rawValue: original.permissionMode) ?? .default,
            status: .active,
            messageCount: 0, // Will be updated as messages are copied
            totalCostUSD: nil, // Forked session starts with zero cost
            source: .ils,
            forkedFrom: original.id
        )

        try await forked.save(on: db)

        // Copy all messages from original to forked session
        let messages = try await MessageModel.query(on: db)
            .filter(\.$session.$id == session.id)
            .sort(\.$createdAt, .ascending)
            .all()

        for message in messages {
            let forkedMessage = MessageModel(
                sessionId: forked.id!,
                role: MessageRole(rawValue: message.role) ?? .user,
                content: message.content,
                toolCalls: message.toolCalls,
                toolResults: message.toolResults
            )
            try await forkedMessage.save(on: db)
        }

        // Update message count
        forked.messageCount = messages.count
        try await forked.save(on: db)

        return forked.id!
    }

    /// Execute an export action by generating an export file.
    private func executeExportAction(
        rule: AutomationRule,
        session: ChatSession,
        on db: Database
    ) async throws -> String {
        let format = rule.actionConfig.exportFormat ?? "markdown"

        guard let sessionModel = try await SessionModel.query(on: db)
            .filter(\.$id == session.id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Fetch all messages for the session
        let messages = try await MessageModel.query(on: db)
            .filter(\.$session.$id == session.id)
            .sort(\.$createdAt, .ascending)
            .all()

        // Generate export content based on format
        let content: String
        let fileExtension: String

        switch format.lowercased() {
        case "json":
            content = try generateJSONExport(session: sessionModel, messages: messages)
            fileExtension = "json"

        case "text", "txt":
            content = generateTextExport(session: sessionModel, messages: messages)
            fileExtension = "txt"

        default: // markdown
            content = generateMarkdownExport(session: sessionModel, messages: messages)
            fileExtension = "md"
        }

        // Create exports directory if it doesn't exist
        let exportsDir = "./exports/automation-rules"
        try FileManager.default.createDirectory(
            atPath: exportsDir,
            withIntermediateDirectories: true
        )

        // Write export file
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(session.id.uuidString)_\(timestamp).\(fileExtension)"
        let exportPath = "\(exportsDir)/\(filename)"

        try content.write(toFile: exportPath, atomically: true, encoding: .utf8)

        return exportPath
    }

    /// Execute a send message action.
    private func executeSendMessageAction(
        rule: AutomationRule,
        session: ChatSession,
        on db: Database
    ) async throws -> String {
        let messageContent = rule.actionConfig.messageContent ?? "Automated message from rule '\(rule.name)'"

        // Create a new message in the session
        guard let sessionModel = try await SessionModel.query(on: db)
            .filter(\.$id == session.id)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let message = MessageModel(
            sessionId: session.id,
            role: .user,
            content: messageContent
        )

        try await message.save(on: db)

        // Update session message count
        sessionModel.messageCount += 1
        try await sessionModel.save(on: db)

        return "Message sent: \(messageContent)"
    }

    /// Execute a switch model action.
    private func executeSwitchModelAction(
        rule: AutomationRule,
        session: ChatSession,
        on db: Database
    ) async throws -> String {
        guard let targetModel = rule.actionConfig.targetModel else {
            throw Abort(.badRequest, reason: "No target model specified in action config")
        }

        guard let sessionModel = try await SessionModel.query(on: db)
            .filter(\.$id == session.id)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let previousModel = sessionModel.model
        sessionModel.model = targetModel
        try await sessionModel.save(on: db)

        return "Model switched from '\(previousModel)' to '\(targetModel)'"
    }

    // MARK: - Export Generators

    /// Generate JSON export of session and messages.
    private func generateJSONExport(
        session: SessionModel,
        messages: [MessageModel]
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData: [String: Any] = [
            "session": [
                "id": session.id?.uuidString ?? "",
                "name": session.name ?? "",
                "model": session.model,
                "status": session.status,
                "message_count": session.messageCount,
                "created_at": session.createdAt?.ISO8601Format() ?? "",
                "last_active_at": session.lastActiveAt?.ISO8601Format() ?? ""
            ],
            "messages": messages.map { message in
                [
                    "id": message.id?.uuidString ?? "",
                    "role": message.role,
                    "content": message.content,
                    "tool_calls": message.toolCalls ?? "",
                    "tool_results": message.toolResults ?? "",
                    "created_at": message.createdAt?.ISO8601Format() ?? ""
                ]
            }
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    /// Generate Markdown export of session and messages.
    private func generateMarkdownExport(
        session: SessionModel,
        messages: [MessageModel]
    ) -> String {
        var markdown = "# \(session.name ?? "Unnamed Session")\n\n"
        markdown += "**Session ID:** `\(session.id?.uuidString ?? "")`\n"
        markdown += "**Model:** \(session.model)\n"
        markdown += "**Status:** \(session.status)\n"
        markdown += "**Message Count:** \(session.messageCount)\n"
        markdown += "**Created:** \(session.createdAt?.ISO8601Format() ?? "")\n"
        markdown += "**Last Active:** \(session.lastActiveAt?.ISO8601Format() ?? "")\n\n"
        markdown += "---\n\n"
        markdown += "## Messages\n\n"

        for message in messages {
            let role = message.role.capitalized
            let timestamp = message.createdAt?.ISO8601Format() ?? ""
            markdown += "### \(role) - \(timestamp)\n\n"
            markdown += "\(message.content)\n\n"
            markdown += "---\n\n"
        }

        return markdown
    }

    /// Generate plain text export of session and messages.
    private func generateTextExport(
        session: SessionModel,
        messages: [MessageModel]
    ) -> String {
        var text = "Session: \(session.name ?? "Unnamed Session")\n"
        text += "ID: \(session.id?.uuidString ?? "")\n"
        text += "Model: \(session.model)\n"
        text += "Status: \(session.status)\n"
        text += "Messages: \(session.messageCount)\n"
        text += "Created: \(session.createdAt?.ISO8601Format() ?? "")\n"
        text += "Last Active: \(session.lastActiveAt?.ISO8601Format() ?? "")\n"
        text += "\n" + String(repeating: "=", count: 80) + "\n\n"

        for message in messages {
            let role = message.role.uppercased()
            let timestamp = message.createdAt?.ISO8601Format() ?? ""
            text += "[\(role)] \(timestamp)\n"
            text += String(repeating: "-", count: 80) + "\n"
            text += "\(message.content)\n\n"
        }

        return text
    }
}
