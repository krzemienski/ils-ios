import Foundation
import Vapor
import ILSShared
import ClaudeCodeSDK
import SwiftAnthropic
import Combine

/// Service for executing Claude Code CLI commands using ClaudeCodeSDK
actor ClaudeExecutorService {
    private var client: ClaudeCodeClient?
    private var cancellables = Set<AnyCancellable>()
    private var activeSessions: [String: AnyCancellable] = [:]

    init() {
        do {
            var config = ClaudeCodeConfiguration.default
            config.enableDebugLogging = true
            self.client = try ClaudeCodeClient(configuration: config)
        } catch {
            print("Failed to initialize ClaudeCodeClient: \(error)")
        }
    }

    /// Check if Claude CLI is available
    func isAvailable() async -> Bool {
        guard let client = client else { return false }
        do {
            return try await client.validateCommand("claude")
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

    /// Execute Claude CLI with streaming output
    nonisolated func execute(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.runWithSDK(
                    prompt: prompt,
                    workingDirectory: workingDirectory,
                    options: options,
                    continuation: continuation
                )
            }
        }
    }

    private func runWithSDK(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions,
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) async {
        guard let client = client else {
            continuation.yield(.error(StreamError(code: "CLIENT_ERROR", message: "ClaudeCodeClient not initialized")))
            continuation.finish()
            return
        }

        // Update working directory if specified
        if let dir = workingDirectory {
            var config = client.configuration
            config.workingDirectory = dir
            client.configuration = config
        }

        // Build options
        var sdkOptions = ClaudeCodeOptions()
        sdkOptions.maxTurns = options.maxTurns ?? 1

        if let model = options.model {
            sdkOptions.model = model
        }

        if let allowedTools = options.allowedTools {
            sdkOptions.allowedTools = allowedTools
        }

        if let disallowedTools = options.disallowedTools {
            sdkOptions.disallowedTools = disallowedTools
        }

        do {
            let result: ClaudeCodeResult

            // Resume or new session
            if let resume = options.resume {
                result = try await client.resumeConversation(
                    sessionId: resume,
                    prompt: prompt,
                    outputFormat: .streamJson,
                    options: sdkOptions
                )
            } else {
                result = try await client.runSinglePrompt(
                    prompt: prompt,
                    outputFormat: .streamJson,
                    options: sdkOptions
                )
            }

            // Handle result
            switch result {
            case .stream(let publisher):
                let sessionId = options.sessionId ?? UUID().uuidString

                let cancellable = publisher.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            continuation.finish()
                        case .failure(let error):
                            continuation.yield(.error(StreamError(code: "STREAM_ERROR", message: error.localizedDescription)))
                            continuation.finish()
                        }
                        Task {
                            await self.removeSession(sessionId)
                        }
                    },
                    receiveValue: { chunk in
                        // Convert SDK chunk to our StreamMessage
                        let message = self.convertChunk(chunk)
                        continuation.yield(message)
                    }
                )

                await storeSession(sessionId, cancellable: cancellable)

            case .text(let text):
                // Convert text result to assistant message
                let assistantMsg = AssistantMessage(content: [
                    .text(TextBlock(text: text))
                ])
                continuation.yield(.assistant(assistantMsg))
                continuation.finish()

            case .json(let resultMsg):
                // Convert JSON result
                let result = ResultMessage(
                    subtype: resultMsg.isError ? "error" : "success",
                    sessionId: resultMsg.sessionId,
                    durationMs: resultMsg.durationMs,
                    durationApiMs: resultMsg.durationApiMs,
                    isError: resultMsg.isError,
                    numTurns: resultMsg.numTurns,
                    totalCostUSD: resultMsg.totalCostUsd,
                    usage: nil
                )
                continuation.yield(.result(result))
                continuation.finish()
            }

        } catch {
            continuation.yield(.error(StreamError(code: "EXECUTION_ERROR", message: error.localizedDescription)))
            continuation.finish()
        }
    }

    // MARK: - Content Conversion Helpers

    /// Convert text content to ContentBlock
    nonisolated private func convertTextContent(_ text: String) -> ContentBlock {
        return .text(TextBlock(text: text))
    }

    /// Convert tool use content to ContentBlock
    nonisolated private func convertToolUseContent(_ toolUse: MessageResponse.Content.ToolUse) -> ContentBlock {
        return .toolUse(ToolUseBlock(
            id: toolUse.id,
            name: toolUse.name,
            input: AnyCodable(toolUse.input)
        ))
    }

    /// Convert tool result content to ContentBlock
    nonisolated private func convertToolResultContent(_ toolResult: MessageResponse.Content.ToolResult) -> ContentBlock {
        let resultContent: String
        switch toolResult.content {
        case .string(let text):
            resultContent = text
        case .items(let items):
            resultContent = items.compactMap { $0.text }.joined(separator: "\n")
        }
        return .toolResult(ToolResultBlock(
            toolUseId: toolResult.toolUseId ?? "",
            content: resultContent,
            isError: toolResult.isError ?? false
        ))
    }

    /// Convert thinking content to ContentBlock
    nonisolated private func convertThinkingContent(_ thinking: MessageResponse.Content.Thinking) -> ContentBlock {
        return .text(TextBlock(text: "[thinking] \(thinking.thinking)"))
    }

    /// Convert server tool use content to ContentBlock
    nonisolated private func convertServerToolUseContent(_ serverTool: MessageResponse.Content.ServerToolUse) -> ContentBlock {
        return .toolUse(ToolUseBlock(
            id: serverTool.id,
            name: serverTool.name,
            input: AnyCodable(serverTool.input)
        ))
    }

    /// Convert web search result content to ContentBlock
    nonisolated private func convertWebSearchResultContent(_ webResult: MessageResponse.Content.WebSearchToolResult) -> ContentBlock {
        let text = webResult.content.compactMap { $0.text }.joined(separator: "\n")
        return .toolResult(ToolResultBlock(
            toolUseId: webResult.toolUseId ?? "",
            content: text,
            isError: false
        ))
    }

    /// Convert code execution result content to ContentBlock
    nonisolated private func convertCodeExecutionResultContent(_ codeResult: MessageResponse.Content.CodeExecutionToolResult) -> ContentBlock {
        let text: String
        switch codeResult.content {
        case .string(let s): text = s
        default: text = "[code execution result]"
        }
        return .toolResult(ToolResultBlock(
            toolUseId: codeResult.toolUseId ?? "",
            content: text,
            isError: false
        ))
    }

    // MARK: - Chunk Conversion

    /// Convert SDK ResponseChunk to our StreamMessage
    nonisolated private func convertChunk(_ chunk: ResponseChunk) -> StreamMessage {
        switch chunk {
        case .initSystem(let msg):
            let systemData = SystemData(
                sessionId: msg.sessionId,
                plugins: nil,
                slashCommands: nil,
                tools: msg.tools
            )
            return .system(SystemMessage(subtype: "init", data: systemData))

        case .assistant(let msg):
            var contentBlocks: [ContentBlock] = []

            for content in msg.message.content {
                switch content {
                case .text(let text, _):
                    contentBlocks.append(convertTextContent(text))
                case .toolUse(let toolUse):
                    contentBlocks.append(convertToolUseContent(toolUse))
                case .toolResult(let toolResult):
                    contentBlocks.append(convertToolResultContent(toolResult))
                case .thinking(let thinking):
                    contentBlocks.append(convertThinkingContent(thinking))
                case .serverToolUse(let serverTool):
                    contentBlocks.append(convertServerToolUseContent(serverTool))
                case .webSearchToolResult(let webResult):
                    contentBlocks.append(convertWebSearchResultContent(webResult))
                case .codeExecutionToolResult(let codeResult):
                    contentBlocks.append(convertCodeExecutionResultContent(codeResult))
                }
            }

            return .assistant(ILSShared.AssistantMessage(content: contentBlocks))

        case .result(let msg):
            let result = ResultMessage(
                subtype: msg.isError ? "error" : "success",
                sessionId: msg.sessionId,
                durationMs: msg.durationMs,
                durationApiMs: msg.durationApiMs,
                isError: msg.isError,
                numTurns: msg.numTurns,
                totalCostUSD: msg.totalCostUsd,
                usage: nil
            )
            return .result(result)

        case .user:
            // User messages are echoed back, we can skip or include
            return .system(SystemMessage(
                subtype: "user_echo",
                data: SystemData(sessionId: chunk.sessionId)
            ))
        }
    }

    private func storeSession(_ sessionId: String, cancellable: AnyCancellable) async {
        activeSessions[sessionId] = cancellable
    }

    private func removeSession(_ sessionId: String) async {
        activeSessions.removeValue(forKey: sessionId)
    }

    /// Cancel an active session
    func cancel(sessionId: String) async {
        if let cancellable = activeSessions[sessionId] {
            cancellable.cancel()
            activeSessions.removeValue(forKey: sessionId)
        }
        client?.cancel()
    }
}

/// Options for Claude CLI execution
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

    init(from chatOptions: ChatOptions? = nil) {
        self.model = chatOptions?.model
        self.permissionMode = chatOptions?.permissionMode
        self.maxTurns = chatOptions?.maxTurns
        self.maxBudgetUSD = chatOptions?.maxBudgetUSD
        self.allowedTools = chatOptions?.allowedTools
        self.disallowedTools = chatOptions?.disallowedTools
        self.resume = chatOptions?.resume
        self.forkSession = chatOptions?.forkSession
    }
}
