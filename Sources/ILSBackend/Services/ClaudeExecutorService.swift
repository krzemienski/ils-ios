import Foundation
import Vapor
import ILSShared

/// Unbuffered stderr logging for debugging
private func debugLog(_ message: String) {
    let msg = "[EXECUTOR] " + message + "\n"
    if let data = msg.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

/// Service for executing Claude Code CLI commands directly via Process.
///
/// Bypasses ClaudeCodeSDK because the SDK's Combine publisher uses
/// FileHandle.readabilityHandler which requires a RunLoop. Vapor's NIO
/// event loops don't pump a RunLoop, so the publisher never emits.
///
/// Instead, this service runs `claude -p --output-format stream-json`
/// directly and reads stdout on a dedicated DispatchQueue.
actor ClaudeExecutorService {
    /// Active processes keyed by session ID for cancellation support
    private var activeProcesses: [String: Process] = [:]

    /// GCD queue for blocking stdout reads (avoids RunLoop dependency)
    private let readQueue = DispatchQueue(label: "ils.claude-stdout-reader", qos: .userInitiated)

    // MARK: - Public API

    /// Check if Claude CLI is available in PATH
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

    /// Get Claude CLI version
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

    /// Execute Claude CLI with streaming output via direct Process.
    ///
    /// Returns an AsyncThrowingStream of StreamMessage that yields messages
    /// as they arrive from the CLI's stream-json output.
    nonisolated func execute(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            // Build the full shell command
            let command = Self.buildCommand(options: options)
            debugLog("Command: \(command)")
            debugLog("Prompt: \(prompt.prefix(100))")
            debugLog("Working dir: \(workingDirectory ?? "nil")")

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
                debugLog("Process started (PID: \(process.processIdentifier))")
            } catch {
                debugLog("Failed to start process: \(error)")
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
                debugLog("TIMEOUT: No stdout data received within 30 seconds, terminating process")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            let totalTimeoutWork = DispatchWorkItem {
                if process.isRunning {
                    didTimeout = true
                    debugLog("TOTAL TIMEOUT: Process running for >5 minutes, terminating")
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
                        debugLog("Process killed by timeout (exit code \(exitCode))")
                        continuation.yield(.error(StreamError(
                            code: "TIMEOUT",
                            message: "Claude CLI timed out — the AI service may be busy. Please try again."
                        )))
                    } else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errText = String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        debugLog("Process exited with code \(exitCode): \(errText.prefix(500))")
                        if !errText.isEmpty {
                            continuation.yield(.error(StreamError(
                                code: "PROCESS_ERROR",
                                message: "claude exited with code \(exitCode): \(errText.prefix(200))"
                            )))
                        }
                    }
                } else {
                    debugLog("Process exited successfully")
                }

                continuation.finish()

                // Clean up process reference
                Task {
                    await self.removeProcess(sessionId)
                }
            }
        }
    }

    /// Cancel an active session's process
    func cancel(sessionId: String) async {
        if let process = activeProcesses[sessionId], process.isRunning {
            debugLog("Cancelling process for session: \(sessionId)")
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

    /// Build the full claude CLI command string.
    ///
    /// Replicates what ClaudeCodeSDK's HeadlessBackend does:
    /// `claude -p --verbose --output-format stream-json [options]`
    ///
    /// Prompt is sent via stdin (not as argument) to avoid shell escaping issues.
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

    /// Shell-escape a string by wrapping in single quotes
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
            debugLog("Failed to parse JSON line: \(line.prefix(200))")
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
            debugLog("Unknown message type: \(type)")
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

        debugLog("System message: subtype=\(subtype), sessionId=\(sessionId.prefix(20)), tools=\(tools?.count ?? 0)")

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
            debugLog("Assistant message missing message.content")
            return
        }

        var contentBlocks: [ContentBlock] = []

        for item in contentArray {
            guard let itemType = item["type"] as? String else { continue }

            switch itemType {
            case "text":
                if let text = item["text"] as? String {
                    contentBlocks.append(.text(TextBlock(text: text)))
                    debugLog("Text content: \(text.prefix(100))")
                }

            case "tool_use":
                if let id = item["id"] as? String,
                   let name = item["name"] as? String {
                    let input = item["input"] ?? [String: Any]()
                    contentBlocks.append(.toolUse(ToolUseBlock(
                        id: id,
                        name: name,
                        input: AnyCodable(input)
                    )))
                    debugLog("Tool use: \(name)")
                }

            case "tool_result":
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
                contentBlocks.append(.toolResult(ToolResultBlock(
                    toolUseId: toolUseId,
                    content: content,
                    isError: isError
                )))
                debugLog("Tool result: toolUseId=\(toolUseId.prefix(20)), isError=\(isError)")

            case "thinking":
                if let thinking = item["thinking"] as? String {
                    contentBlocks.append(.thinking(ThinkingBlock(thinking: thinking)))
                    debugLog("Thinking: \(thinking.prefix(50))")
                }

            default:
                // Gracefully handle unknown content block types (e.g. future CLI additions)
                debugLog("Unknown content type '\(itemType)' — forwarding as text note")
                contentBlocks.append(.text(TextBlock(text: "[unsupported block: \(itemType)]")))
            }
        }

        if !contentBlocks.isEmpty {
            let assistantMsg = AssistantMessage(content: contentBlocks)
            continuation.yield(.assistant(assistantMsg))
            debugLog("Yielded assistant message with \(contentBlocks.count) content blocks")
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

        debugLog("Result: subtype=\(subtype), sessionId=\(sessionId.prefix(20)), cost=\(totalCostUSD ?? 0), turns=\(numTurns ?? 0)")

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
            debugLog("Usage: input=\(inputTokens), output=\(outputTokens)")
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
}

// MARK: - Execution Options

/// Options for Claude CLI execution — mirrors ChatOptions from ILSShared
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
