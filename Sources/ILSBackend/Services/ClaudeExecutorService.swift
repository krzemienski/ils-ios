import Foundation
import Vapor
import ILSShared
import Logging

/// Actor managing Claude CLI subprocess execution with streaming JSON output.
///
/// ## Architecture
///
/// This service wraps the Claude CLI (`claude -p --output-format stream-json`) as a subprocess
/// and converts its JSON output to `ILSShared.StreamMessage` types for the iOS app.
///
/// ### Why Not Use ClaudeCodeSDK?
///
/// The official SDK uses `FileHandle.readabilityHandler` + Combine's `PassthroughSubject`,
/// which requires a RunLoop. Vapor's NIO event loops don't pump a RunLoop, so the publisher
/// never emits data. This service uses direct `Process` execution with `DispatchQueue` for
/// stdout reads instead.
///
/// ### Session Management
///
/// Active processes are tracked in `activeProcesses` dictionary keyed by session ID.
/// This enables cancellation support for multi-session scenarios.
///
/// ### Timeout Protection
///
/// Two-tier timeout system:
/// - 30s initial timeout: triggers if no stdout data received (detects stuck CLI)
/// - 5min total timeout: kills long-running processes (prevents runaway execution)
///
/// ### Message Conversion
///
/// Converts Claude CLI JSON (snake_case) to ILSShared types (camelCase):
/// - `session_id` → `sessionId`
/// - `tool_use` → `toolUse`
/// - `total_cost_usd` → `totalCostUSD`
actor ClaudeExecutorService {
    /// Structured logger for ClaudeExecutor operations
    private static let logger = Logger(label: "ils.claude-executor")

    /// Active processes keyed by session ID for cancellation support
    private var activeProcesses: [String: Process] = [:]

    /// GCD queue for blocking stdout reads (avoids RunLoop dependency)
    private let readQueue = DispatchQueue(label: "ils.claude-stdout-reader", qos: .userInitiated)

    // MARK: - Public API

    /// Check if Claude CLI is available in PATH.
    /// - Returns: True if `claude` command is found
    func isAvailable() async -> Bool {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which claude"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try process.run()
            process.waitUntilExit()

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Get Claude CLI version string.
    /// - Returns: Version string (e.g., "claude 1.2.3") or "unknown" on failure
    func getVersion() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "claude --version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    /// Execute Claude CLI with streaming JSON output.
    ///
    /// Spawns `claude -p --output-format stream-json` as a subprocess and streams
    /// parsed messages as they arrive. Includes timeout protection (30s initial, 5min total).
    ///
    /// - Parameters:
    ///   - prompt: User prompt text (sent via stdin)
    ///   - workingDirectory: Optional working directory for project context
    ///   - options: Execution options (model, permissions, session ID, etc.)
    /// - Returns: AsyncThrowingStream yielding StreamMessage events
    nonisolated func execute(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            // Build the full shell command
            let command = Self.buildCommand(options: options)
            Self.logger.debug("Command: \(command)")
            Self.logger.debug("Prompt: \(prompt.prefix(100))")
            Self.logger.debug("Working dir: \(workingDirectory ?? "nil")")

            // Configure process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            // Inherit environment for PATH (claude needs to be findable)
            process.environment = ProcessInfo.processInfo.environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Send prompt via stdin (avoids shell escaping issues)
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let data = prompt.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
                stdinPipe.fileHandleForWriting.closeFile()
            }

            // Store process for cancellation
            let sessionId = options.sessionId ?? UUID().uuidString
            Task {
                await self.storeProcess(sessionId, process: process)
            }

            // Start process
            do {
                try process.run()
                Self.logger.debug("Process started (PID: \(process.processIdentifier))")
            } catch {
                Self.logger.debug("Failed to start process: \(error)")
                continuation.yield(.error(StreamError(
                    code: "LAUNCH_ERROR",
                    message: "Failed to launch claude: \(error.localizedDescription)"
                )))
                continuation.finish()
                return
            }

            // --- Timeout mechanism ---
            // Two-tier: 30s initial (no data at all) + 5min total (process runs too long)
            var didTimeout = false

            let timeoutWork = DispatchWorkItem {
                didTimeout = true
                Self.logger.debug("TIMEOUT: No stdout data received within 30 seconds, terminating process")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            let totalTimeoutWork = DispatchWorkItem {
                if process.isRunning {
                    didTimeout = true
                    Self.logger.debug("TOTAL TIMEOUT: Process running for >5 minutes, terminating")
                    process.terminate()
                    outputPipe.fileHandleForReading.closeFile()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: totalTimeoutWork)

            // Read stdout on dedicated GCD queue (no RunLoop needed)
            self.readQueue.async {
                let handle = outputPipe.fileHandleForReading
                var buffer = Data()

                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break } // EOF - process closed stdout

                    // Cancel the initial 30s timeout — data is flowing
                    timeoutWork.cancel()

                    buffer.append(chunk)

                    // Try to extract complete lines
                    guard let bufferString = String(data: buffer, encoding: .utf8) else {
                        continue
                    }

                    let lines = bufferString.components(separatedBy: "\n")

                    // Process all complete lines (everything except last which may be incomplete)
                    if lines.count > 1 {
                        for i in 0..<(lines.count - 1) {
                            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !line.isEmpty {
                                Self.processJsonLine(line, continuation: continuation)
                            }
                        }

                        // Keep last (potentially incomplete) line in buffer
                        let lastLine = lines[lines.count - 1]
                        buffer = lastLine.data(using: .utf8) ?? Data()
                    }
                }

                // Process any remaining data in buffer
                if let remaining = String(data: buffer, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !remaining.isEmpty {
                    Self.processJsonLine(remaining, continuation: continuation)
                }

                // Wait for process to fully exit before checking status
                process.waitUntilExit()

                // Cancel both timeouts (process finished normally)
                timeoutWork.cancel()
                totalTimeoutWork.cancel()

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    if didTimeout {
                        Self.logger.debug("Process killed by timeout (exit code \(exitCode))")
                        continuation.yield(.error(StreamError(
                            code: "TIMEOUT",
                            message: "Claude CLI timed out — the AI service may be busy. Please try again."
                        )))
                    } else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errText = String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        Self.logger.debug("Process exited with code \(exitCode): \(errText.prefix(500))")
                        if !errText.isEmpty {
                            continuation.yield(.error(StreamError(
                                code: "PROCESS_ERROR",
                                message: "claude exited with code \(exitCode): \(errText.prefix(200))"
                            )))
                        }
                    }
                } else {
                    Self.logger.debug("Process exited successfully")
                }

                continuation.finish()

                // Clean up process reference
                Task {
                    await self.removeProcess(sessionId)
                }
            }
        }
    }

    /// Cancel an active session's process.
    /// - Parameter sessionId: Session ID to cancel
    func cancel(sessionId: String) async {
        if let process = activeProcesses[sessionId], process.isRunning {
            Self.logger.debug("Cancelling process for session: \(sessionId)")
            process.terminate()
        }
        activeProcesses.removeValue(forKey: sessionId)
    }

    // MARK: - Process Management

    private func storeProcess(_ sessionId: String, process: Process) {
        activeProcesses[sessionId] = process
    }

    private func removeProcess(_ sessionId: String) {
        activeProcesses.removeValue(forKey: sessionId)
    }

    // MARK: - Command Building

    /// Build the full Claude CLI command string from execution options.
    ///
    /// Constructs a command like: `claude -p --verbose --output-format stream-json [options]`
    ///
    /// - Parameter options: Execution options to convert to CLI arguments
    /// - Returns: Shell command string (prompt sent via stdin separately)
    private static func buildCommand(options: ExecutionOptions) -> String {
        var args: [String] = ["claude", "-p", "--verbose"]

        // Output format: always stream-json for structured streaming
        args.append("--output-format")
        args.append("stream-json")

        // Max turns
        if let maxTurns = options.maxTurns {
            args.append("--max-turns")
            args.append("\(maxTurns)")
        } else {
            args.append("--max-turns")
            args.append("1")
        }

        // Model
        if let model = options.model {
            args.append("--model")
            args.append(model)
        }

        // Fallback model
        if let fallbackModel = options.fallbackModel {
            args.append("--fallback-model")
            args.append(fallbackModel)
        }

        // Setting sources: skip user settings for backend (faster startup)
        args.append("--setting-sources")
        args.append("project,local")

        // Permission mode: use specified mode or default to bypass for non-interactive
        if let mode = options.permissionMode {
            switch mode {
            case .bypassPermissions:
                args.append("--dangerously-skip-permissions")
            default:
                args.append("--permission-mode")
                args.append(mode.rawValue)
            }
        } else {
            args.append("--dangerously-skip-permissions")
        }

        // Resume existing session
        if let resume = options.resume {
            args.append("--resume")
            args.append(resume)
        }

        // Continue conversation (resume most recent)
        if options.continueConversation == true {
            args.append("--continue")
        }

        // Fork session
        if options.forkSession == true {
            args.append("--fork-session")
        }

        // Session ID (specific UUID)
        if let sessionId = options.sessionId {
            args.append("--session-id")
            args.append(sessionId)
        }

        // System prompt
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            args.append("--system-prompt")
            args.append(shellEscape(systemPrompt))
        }

        // Append system prompt
        if let appendSystemPrompt = options.appendSystemPrompt, !appendSystemPrompt.isEmpty {
            args.append("--append-system-prompt")
            args.append(shellEscape(appendSystemPrompt))
        }

        // Max budget
        if let maxBudget = options.maxBudgetUSD {
            args.append("--max-budget-usd")
            args.append(String(format: "%.2f", maxBudget))
        }

        // Include partial messages (character-by-character streaming)
        if options.includePartialMessages == true {
            args.append("--include-partial-messages")
        }

        // No session persistence
        if options.noSessionPersistence == true {
            args.append("--no-session-persistence")
        }

        // Additional directories
        if let addDirs = options.addDirs, !addDirs.isEmpty {
            for dir in addDirs {
                args.append("--add-dir")
                args.append(dir)
            }
        }

        // Allowed tools
        if let allowedTools = options.allowedTools, !allowedTools.isEmpty {
            args.append("--allowedTools")
            args.append("\"\(allowedTools.joined(separator: ","))\"")
        }

        // Disallowed tools
        if let disallowedTools = options.disallowedTools, !disallowedTools.isEmpty {
            args.append("--disallowedTools")
            args.append("\"\(disallowedTools.joined(separator: ","))\"")
        }

        // Tools (built-in tool list)
        if let tools = options.tools, !tools.isEmpty {
            args.append("--tools")
            args.append("\"\(tools.joined(separator: ","))\"")
        }

        // JSON schema for structured output
        if let jsonSchema = options.jsonSchema, !jsonSchema.isEmpty {
            args.append("--json-schema")
            args.append(shellEscape(jsonSchema))
        }

        // MCP config file
        if let mcpConfig = options.mcpConfig, !mcpConfig.isEmpty {
            args.append("--mcp-config")
            args.append(mcpConfig)
        }

        // Custom agents JSON
        if let customAgents = options.customAgents, !customAgents.isEmpty {
            args.append("--agents")
            args.append(shellEscape(customAgents))
        }

        // Input format
        if let inputFormat = options.inputFormat, !inputFormat.isEmpty {
            args.append("--input-format")
            args.append(inputFormat)
        }

        return args.joined(separator: " ")
    }

    /// Shell-escape a string by wrapping in single quotes and escaping internal quotes.
    /// - Parameter value: String to escape
    /// - Returns: Shell-safe quoted string
    private static func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    // MARK: - JSON Line Processing

    /// Process a single JSON line from Claude CLI's stream-json output.
    ///
    /// Each line is a complete JSON object with a "type" field:
    /// - "system" (subtype "init"): session initialization with tools
    /// - "assistant": response content (text, tool_use, tool_result, thinking)
    /// - "result": completion with cost/duration/session info
    ///
    /// Maps CLI JSON (snake_case) to ILSShared StreamMessage types (camelCase).
    private static func processJsonLine(
        _ line: String,
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            Self.logger.debug("Failed to parse JSON line: \(line.prefix(200))")
            return
        }

        switch type {
        case "system":
            processSystemMessage(json, continuation: continuation)

        case "assistant":
            processAssistantMessage(json, continuation: continuation)

        case "result":
            processResultMessage(json, continuation: continuation)

        default:
            Self.logger.debug("Unknown message type: \(type)")
        }
    }

    /// Parse system message from CLI JSON.
    ///
    /// Handles subtypes: "init" (session start with tools), "completion" (token usage updates)
    private static func processSystemMessage(
        _ json: [String: Any],
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) {
        let subtype = json["subtype"] as? String ?? "init"
        let sessionId = json["session_id"] as? String ?? ""
        let tools = json["tools"] as? [String]

        Self.logger.debug("System message: subtype=\(subtype), sessionId=\(sessionId.prefix(20)), tools=\(tools?.count ?? 0)")

        // Handle all known subtypes — init, completion, etc.
        let systemData = SystemData(
            sessionId: sessionId,
            tools: tools
        )
        let message = SystemMessage(subtype: subtype, data: systemData)
        continuation.yield(.system(message))
    }

    /// Parse assistant message from CLI JSON.
    ///
    /// CLI format: {"type":"assistant","session_id":"...","message":{"role":"assistant","content":[...]}}
    /// ILSShared format: AssistantMessage(content: [ContentBlock])
    private static func processAssistantMessage(
        _ json: [String: Any],
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) {
        // Extract content from nested message object
        guard let messageObj = json["message"] as? [String: Any],
              let contentArray = messageObj["content"] as? [[String: Any]] else {
            Self.logger.debug("Assistant message missing message.content")
            return
        }

        var contentBlocks: [ContentBlock] = []

        for item in contentArray {
            if let block = convertContentBlock(item) {
                contentBlocks.append(block)
            }
        }

        if !contentBlocks.isEmpty {
            let assistantMsg = AssistantMessage(content: contentBlocks)
            continuation.yield(.assistant(assistantMsg))
            Self.logger.debug("Yielded assistant message with \(contentBlocks.count) content blocks")
        }
    }

    /// Parse result message from CLI JSON.
    ///
    /// CLI format uses snake_case: session_id, total_cost_usd, duration_ms, etc.
    /// ILSShared uses camelCase: sessionId, totalCostUSD, durationMs, etc.
    private static func processResultMessage(
        _ json: [String: Any],
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) {
        let subtype = json["subtype"] as? String ?? "success"
        let sessionId = json["session_id"] as? String ?? ""
        let durationMs = json["duration_ms"] as? Int
        let durationApiMs = json["duration_api_ms"] as? Int
        let isError = json["is_error"] as? Bool ?? false
        let numTurns = json["num_turns"] as? Int
        let totalCostUSD = json["total_cost_usd"] as? Double

        Self.logger.debug("Result: subtype=\(subtype), sessionId=\(sessionId.prefix(20)), cost=\(totalCostUSD ?? 0), turns=\(numTurns ?? 0)")

        // Parse usage stats if present
        var usageInfo: UsageInfo?
        if let usage = json["usage"] as? [String: Any],
           let inputTokens = usage["input_tokens"] as? Int,
           let outputTokens = usage["output_tokens"] as? Int {
            let cacheRead = usage["cache_read_input_tokens"] as? Int
            let cacheCreation = usage["cache_creation_input_tokens"] as? Int
            usageInfo = UsageInfo(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadInputTokens: cacheRead,
                cacheCreationInputTokens: cacheCreation
            )
            Self.logger.debug("Usage: input=\(inputTokens), output=\(outputTokens)")
        }

        let result = ResultMessage(
            subtype: subtype,
            sessionId: sessionId,
            durationMs: durationMs,
            durationApiMs: durationApiMs,
            isError: isError,
            numTurns: numTurns,
            totalCostUSD: totalCostUSD,
            usage: usageInfo
        )
        continuation.yield(.result(result))
    }

    // MARK: - Content Block Conversion Helpers

    /// Convert a JSON content item to a ContentBlock.
    ///
    /// Reduces nesting depth in processAssistantMessage by extracting switch logic.
    private static func convertContentBlock(_ item: [String: Any]) -> ContentBlock? {
        guard let itemType = item["type"] as? String else { return nil }

        switch itemType {
        case "text":
            return convertTextBlock(item)
        case "tool_use":
            return convertToolUseBlock(item)
        case "tool_result":
            return convertToolResultBlock(item)
        case "thinking":
            return convertThinkingBlock(item)
        default:
            return convertUnknownBlock(itemType)
        }
    }

    /// Convert text content block.
    private static func convertTextBlock(_ item: [String: Any]) -> ContentBlock? {
        guard let text = item["text"] as? String else { return nil }
        Self.logger.debug("Text content: \(text.prefix(100))")
        return .text(TextBlock(text: text))
    }

    /// Convert tool_use content block.
    private static func convertToolUseBlock(_ item: [String: Any]) -> ContentBlock? {
        guard let id = item["id"] as? String,
              let name = item["name"] as? String else { return nil }
        let input = item["input"] ?? [String: Any]()
        Self.logger.debug("Tool use: \(name)")
        return .toolUse(ToolUseBlock(
            id: id,
            name: name,
            input: AnyCodable(input)
        ))
    }

    /// Convert tool_result content block.
    private static func convertToolResultBlock(_ item: [String: Any]) -> ContentBlock? {
        let toolUseId = item["tool_use_id"] as? String ?? ""
        let isError = item["is_error"] as? Bool ?? false
        let content: String
        if let str = item["content"] as? String {
            content = str
        } else if let items = item["content"] as? [[String: Any]] {
            content = items.compactMap { $0["text"] as? String }.joined(separator: "\n")
        } else {
            content = ""
        }
        Self.logger.debug("Tool result: toolUseId=\(toolUseId.prefix(20)), isError=\(isError)")
        return .toolResult(ToolResultBlock(
            toolUseId: toolUseId,
            content: content,
            isError: isError
        ))
    }

    /// Convert thinking content block.
    private static func convertThinkingBlock(_ item: [String: Any]) -> ContentBlock? {
        guard let thinking = item["thinking"] as? String else { return nil }
        Self.logger.debug("Thinking: \(thinking.prefix(50))")
        return .thinking(ThinkingBlock(thinking: thinking))
    }

    /// Convert unknown content block type (forward compatibility).
    private static func convertUnknownBlock(_ itemType: String) -> ContentBlock? {
        Self.logger.debug("Unknown content type '\(itemType)' — forwarding as text note")
        return .text(TextBlock(text: "[unsupported block: \(itemType)]"))
    }
}

// MARK: - Execution Options

/// Options for Claude CLI execution, mirroring ChatOptions from ILSShared.
///
/// Supports all Claude CLI flags including session management, model selection,
/// permissions, tool control, and output formatting.
struct ExecutionOptions {
    var sessionId: String?
    var model: String?
    var permissionMode: ILSShared.PermissionMode?
    var maxTurns: Int?
    var maxBudgetUSD: Double?
    var allowedTools: [String]?
    var disallowedTools: [String]?
    var resume: String?
    var forkSession: Bool?

    // Claude Code CLI parity fields
    var systemPrompt: String?
    var appendSystemPrompt: String?
    var addDirs: [String]?
    var continueConversation: Bool?
    var includePartialMessages: Bool?
    var fallbackModel: String?
    var jsonSchema: String?
    var mcpConfig: String?
    var customAgents: String?
    var tools: [String]?
    var noSessionPersistence: Bool?
    var inputFormat: String?

    init(from chatOptions: ChatOptions? = nil) {
        self.model = chatOptions?.model
        self.permissionMode = chatOptions?.permissionMode
        self.maxTurns = chatOptions?.maxTurns
        self.maxBudgetUSD = chatOptions?.maxBudgetUSD
        self.allowedTools = chatOptions?.allowedTools
        self.disallowedTools = chatOptions?.disallowedTools
        self.resume = chatOptions?.resume
        self.forkSession = chatOptions?.forkSession
        self.systemPrompt = chatOptions?.systemPrompt
        self.appendSystemPrompt = chatOptions?.appendSystemPrompt
        self.addDirs = chatOptions?.addDirs
        self.continueConversation = chatOptions?.continueConversation
        self.includePartialMessages = chatOptions?.includePartialMessages
        self.fallbackModel = chatOptions?.fallbackModel
        self.jsonSchema = chatOptions?.jsonSchema
        self.mcpConfig = chatOptions?.mcpConfig
        self.customAgents = chatOptions?.customAgents
        self.sessionId = chatOptions?.sessionId
        self.tools = chatOptions?.tools
        self.noSessionPersistence = chatOptions?.noSessionPersistence
        self.inputFormat = chatOptions?.inputFormat
    }
}
