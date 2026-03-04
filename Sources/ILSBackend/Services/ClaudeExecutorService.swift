import Foundation
import Vapor
import ILSShared
import Logging
import os

/// Actor managing Claude subprocess execution with streaming JSON output.
///
/// ## Architecture
///
/// Supports two execution backends:
/// 1. **Agent SDK** (default): Spawns `node scripts/sdk-wrapper.mjs` which calls the
///    `@anthropic-ai/claude-agent-sdk` npm package. The SDK calls the Anthropic API directly
///    — no `claude` subprocess — which avoids the hang that occurs when spawning `claude -p`
///    inside an active Claude Code session.
/// 2. **CLI fallback**: Spawns `claude -p --output-format stream-json` directly. Use this
///    when running the backend outside a Claude Code session (standalone).
///
/// Both backends produce NDJSON on stdout in the same format. The stdout reading, JSON
/// parsing, and StreamMessage conversion are shared.
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
/// Converts CLI/SDK JSON (snake_case) to ILSShared types (camelCase):
/// - `session_id` → `sessionId`
/// - `tool_use` → `toolUse`
/// - `total_cost_usd` → `totalCostUSD`
actor ClaudeExecutorService {
    /// Structured logger for ClaudeExecutor operations
    private static let logger = Logger(label: "ils.claude-executor")

    /// JSON decoder configured for CLI snake_case output
    private static let cliDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Active processes keyed by session ID for cancellation support
    private var activeProcesses: [String: Process] = [:]

    /// Active stdin handles keyed by session ID for permission response forwarding
    private var activeStdinHandles: [String: FileHandle] = [:]

    /// GCD queue for blocking stdout reads (avoids RunLoop dependency).
    /// `let` property — nonisolated by default on actors, safe to access from nonisolated methods.
    /// MUST be concurrent: each execute() call dispatches a blocking readStdout loop.
    /// A serial queue would cause starvation — one stuck process blocks all subsequent reads.
    private let readQueue = DispatchQueue(label: "ils.claude-stdout-reader", qos: .userInitiated, attributes: .concurrent)



    /// Resolve which execution backend to use for a given request.
    /// Explicit `.sdk` or `.cli` in options overrides auto-detection.
    /// Auto-detection: SDK if `CLAUDECODE` env var present, CLI otherwise.
    /// - Throws: `Abort(.serviceUnavailable)` if CLI mode is explicitly requested inside a CC session.
    private static func resolveBackend(options: ExecutionOptions) throws -> ExecutionBackend {
        if let explicit = options.backend, explicit != .auto {
            // Guard: explicit CLI mode inside a Claude Code session will hang indefinitely
            // because Claude CLI's nesting detection blocks subprocess execution.
            if explicit == .cli && ProcessInfo.processInfo.environment["CLAUDECODE"] != nil {
                throw Abort(.serviceUnavailable, reason: "CLI mode is unavailable inside a Claude Code session. The Claude CLI nesting detection blocks subprocess execution. Use backend: \"sdk\" or \"auto\" instead.")
            }
            return explicit
        }
        // Inside a Claude Code session → SDK (avoids CLI nesting hang)
        // Outside → CLI (richer streaming, permission forwarding)
        return ProcessInfo.processInfo.environment["CLAUDECODE"] != nil ? .sdk : .cli
    }

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
            // MEM-FD: Explicitly close pipe FDs — short-lived helpers rely on ARC otherwise.
            defer {
                pipe.fileHandleForReading.closeFile()
            }

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
        // MEM-FD: Explicitly close pipe FD — short-lived helper relies on ARC otherwise.
        defer {
            pipe.fileHandleForReading.closeFile()
        }

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    /// Execute a Claude query with streaming JSON output.
    ///
    /// Routes to SDK (Python wrapper) or CLI (`claude -p`) based on per-request
    /// `options.backend` field with auto-detection fallback.
    ///
    /// - Parameters:
    ///   - prompt: User prompt text
    ///   - workingDirectory: Optional working directory for project context
    ///   - options: Execution options (model, permissions, session ID, etc.)
    /// - Returns: AsyncThrowingStream yielding StreamMessage events
    nonisolated func execute(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        let backend: ExecutionBackend
        do {
            backend = try Self.resolveBackend(options: options)
        } catch {
            // Return a stream that immediately throws (e.g. 503 for CLI inside CC session)
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        Self.logger.debug("Using backend: \(backend.rawValue)")
        switch backend {
        case .sdk, .auto:
            return executeWithSDK(prompt: prompt, workingDirectory: workingDirectory, options: options)
        case .cli:
            return executeWithCLI(prompt: prompt, workingDirectory: workingDirectory, options: options)
        }
    }

    // MARK: - Agent SDK Execution

    /// Execute via Agent SDK (Python wrapper).
    ///
    /// Spawns `python3 scripts/sdk-wrapper.py '<json-config>'` where the prompt and all
    /// options are passed as a JSON argument. The SDK wraps Claude CLI internally,
    /// inheriting OAuth auth from `~/.claude/`.
    private nonisolated func executeWithSDK(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            // Build SDK configuration as JSON
            let sdkConfig = Self.buildSDKConfig(prompt: prompt, options: options, workingDirectory: workingDirectory)
            Self.logger.debug("SDK config: \(sdkConfig.prefix(200))")

            // Find the sdk-wrapper.py script relative to the backend working directory
            let projectRoot = workingDirectory ?? FileManager.default.currentDirectoryPath
            let wrapperPath = "\(projectRoot)/scripts/sdk-wrapper.py"

            // Build the python3 command
            let command = "python3 \(Self.shellEscape(wrapperPath)) \(Self.shellEscape(sdkConfig))"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Inline-strip CLAUDE* env vars that login shell may re-export from profile.
            let cleanCmd = "for v in $(env | grep ^CLAUDE | cut -d= -f1); do unset $v; done; \(command)"
            process.arguments = ["-l", "-c", cleanCmd]

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            // Also strip from Process environment (belt-and-suspenders).
            var env = ProcessInfo.processInfo.environment
            for key in env.keys where key.hasPrefix("CLAUDE") {
                env.removeValue(forKey: key)
            }
            process.environment = env

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // No stdin needed for SDK mode — prompt is in the JSON config
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            stdinPipe.fileHandleForWriting.closeFile()

            let sessionId = options.sessionId ?? UUID().uuidString
            Task { [weak self] in
                await self?.storeProcess(sessionId, process: process)
            }

            do {
                try process.run()
                Self.logger.debug("SDK process started (PID: \(process.processIdentifier))")
            } catch {
                Self.logger.debug("Failed to start SDK process: \(error)")
                // MEM-FD: Close pipes to prevent file descriptor leak on process launch failure.
                // readStdout (which normally closes them via defer) is never reached in this path.
                outputPipe.fileHandleForReading.closeFile()
                errorPipe.fileHandleForReading.closeFile()
                continuation.yield(.error(StreamError(
                    code: "LAUNCH_ERROR",
                    message: "Failed to launch Agent SDK wrapper: \(error.localizedDescription)"
                )))
                continuation.finish()
                return
            }

            // --- Timeout mechanism ---
            // CONC: OSAllocatedUnfairLock eliminates the data race between the timeout Tasks
            // (writing true) and the readQueue closure (reading the flag). Previously `var Bool`
            // was mutated from two concurrent GCD contexts without synchronisation.
            let didTimeout = OSAllocatedUnfairLock<Bool>(initialState: false)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                didTimeout.withLock { $0 = true }
                Self.logger.debug("TIMEOUT: No SDK data within 30s")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }

            let totalTimeoutTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { return }
                if process.isRunning {
                    didTimeout.withLock { $0 = true }
                    Self.logger.debug("TOTAL TIMEOUT: SDK process >5min")
                    process.terminate()
                    outputPipe.fileHandleForReading.closeFile()
                }
            }

            self.readQueue.async {
                Self.readStdout(
                    pipe: outputPipe,
                    errorPipe: errorPipe,
                    process: process,
                    sessionId: sessionId,
                    didTimeout: didTimeout,
                    timeoutTask: timeoutTask,
                    totalTimeoutTask: totalTimeoutTask,
                    continuation: continuation,
                    executor: self,
                    cleanupStdin: nil // No stdin to clean up in SDK mode
                )
            }
        }
    }

    // MARK: - CLI Execution (Fallback)

    /// Execute via `claude -p` CLI.
    ///
    /// Direct CLI invocation with stdin for prompt + permission forwarding.
    /// Use when running the backend outside an active Claude Code session.
    private nonisolated func executeWithCLI(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            let command = Self.buildCommand(options: options)
            Self.logger.debug("CLI command: \(command)")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Use login shell for PATH resolution, but inline-strip any CLAUDE*
            // env vars that ~/.zshrc re-exports (e.g. CLAUDE_CODE_MAX_OUTPUT_TOKENS).
            let cleanCmd = "for v in $(env | grep ^CLAUDE | cut -d= -f1); do unset $v; done; \(command)"
            process.arguments = ["-l", "-c", cleanCmd]

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            // Also strip from Process environment (belt-and-suspenders).
            var env = ProcessInfo.processInfo.environment
            for key in env.keys where key.hasPrefix("CLAUDE") {
                env.removeValue(forKey: key)
            }
            process.environment = env

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Send prompt via stdin, then close to signal EOF.
            // `claude -p` reads stdin until EOF when no positional prompt arg is given.
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let data = (prompt + "\n").data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()

            let sessionId = options.sessionId ?? UUID().uuidString
            let stdinHandle: FileHandle? = nil  // stdin already closed
            Task { [weak self] in
                await self?.storeProcess(sessionId, process: process)
                if let handle = stdinHandle {
                    await self?.storeStdinHandle(sessionId, handle: handle)
                }
            }

            do {
                try process.run()
                Self.logger.debug("CLI process started (PID: \(process.processIdentifier))")
            } catch {
                Self.logger.debug("Failed to start CLI process: \(error)")
                // MEM-FD: Close pipes to prevent file descriptor leak on process launch failure.
                // readStdout (which normally closes them via defer) is never reached in this path.
                outputPipe.fileHandleForReading.closeFile()
                errorPipe.fileHandleForReading.closeFile()
                continuation.yield(.error(StreamError(
                    code: "LAUNCH_ERROR",
                    message: "Failed to launch claude: \(error.localizedDescription)"
                )))
                continuation.finish()
                return
            }

            // CONC: OSAllocatedUnfairLock eliminates the data race between the timeout Tasks
            // (writing true) and the readQueue closure (reading the flag).
            let didTimeout = OSAllocatedUnfairLock<Bool>(initialState: false)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                didTimeout.withLock { $0 = true }
                Self.logger.debug("TIMEOUT: No CLI data within 30s")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }

            let totalTimeoutTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { return }
                if process.isRunning {
                    didTimeout.withLock { $0 = true }
                    Self.logger.debug("TOTAL TIMEOUT: CLI process >5min")
                    process.terminate()
                    outputPipe.fileHandleForReading.closeFile()
                }
            }

            self.readQueue.async {
                Self.readStdout(
                    pipe: outputPipe,
                    errorPipe: errorPipe,
                    process: process,
                    sessionId: sessionId,
                    didTimeout: didTimeout,
                    timeoutTask: timeoutTask,
                    totalTimeoutTask: totalTimeoutTask,
                    continuation: continuation,
                    executor: self,
                    cleanupStdin: stdinHandle
                )
            }
        }
    }

    // MARK: - Shared Stdout Reader

    /// Shared stdout reading logic for both SDK and CLI execution paths.
    private nonisolated static func readStdout(
        pipe: Pipe,
        errorPipe: Pipe,
        process: Process,
        sessionId: String,
        didTimeout: OSAllocatedUnfairLock<Bool>,
        timeoutTask: Task<Void, Never>,
        totalTimeoutTask: Task<Void, Never>,
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation,
        executor: ClaudeExecutorService,
        cleanupStdin: FileHandle?
    ) {
        // Ensure pipe fileHandles are closed when we exit, preventing descriptor leaks
        defer {
            pipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }

        let handle = pipe.fileHandleForReading
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }

            timeoutTask.cancel()
            buffer.append(chunk)

            guard let bufferString = String(data: buffer, encoding: .utf8) else {
                continue
            }

            let lines = bufferString.components(separatedBy: "\n")
            if lines.count > 1 {
                for i in 0..<(lines.count - 1) {
                    let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        processJsonLine(line, continuation: continuation)
                    }
                }
                let lastLine = lines[lines.count - 1]
                buffer = lastLine.data(using: .utf8) ?? Data()
            }
        }

        if let remaining = String(data: buffer, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !remaining.isEmpty {
            processJsonLine(remaining, continuation: continuation)
        }

        process.waitUntilExit()
        timeoutTask.cancel()
        totalTimeoutTask.cancel()

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            if didTimeout.withLock({ $0 }) {
                logger.debug("Process killed by timeout (exit \(exitCode))")
                continuation.yield(.error(StreamError(
                    code: "TIMEOUT",
                    message: "Claude timed out — the AI service may be busy. Please try again."
                )))
            } else {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                logger.debug("Process exited \(exitCode): \(errText.prefix(500))")
                if !errText.isEmpty {
                    continuation.yield(.error(StreamError(
                        code: "PROCESS_ERROR",
                        message: "Process exited with code \(exitCode): \(errText.prefix(200))"
                    )))
                }
            }
        } else {
            logger.debug("Process exited successfully")
        }

        continuation.finish()

        cleanupStdin?.closeFile()
        Task {
            await executor.removeProcess(sessionId)
            await executor.removeStdinHandle(sessionId)
        }
    }

    /// Cancel an active session's process.
    ///
    /// Sends SIGINT first for graceful shutdown, then SIGTERM after 2s if still running.
    /// Also closes the stdin handle to unblock the process if it's waiting for input.
    /// - Parameter sessionId: Session ID to cancel
    func cancel(sessionId: String) async {
        // Close stdin first to unblock any pending reads
        if let stdinHandle = activeStdinHandles[sessionId] {
            stdinHandle.closeFile()
        }
        activeStdinHandles.removeValue(forKey: sessionId)

        if let process = activeProcesses[sessionId], process.isRunning {
            Self.logger.debug("Cancelling process for session: \(sessionId)")
            // Send SIGINT first (graceful), then SIGTERM after 2s
            kill(process.processIdentifier, SIGINT)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if process.isRunning {
                process.terminate() // SIGTERM
            }
        }
        activeProcesses.removeValue(forKey: sessionId)
    }

    /// Send a permission response to a running Claude CLI process via stdin.
    ///
    /// Claude CLI in `delegate` mode reads permission responses from stdin as JSON lines.
    /// The format is: `{"type":"permission_response","id":"<requestId>","decision":"<allow|deny>"}`
    ///
    /// - Parameters:
    ///   - sessionId: Session ID whose process should receive the response
    ///   - requestId: Permission request ID to respond to
    ///   - decision: "allow" or "deny"
    /// - Returns: True if the response was written successfully, false if no handle found
    func sendPermissionResponse(sessionId: String, requestId: String, decision: String) -> Bool {
        guard let handle = activeStdinHandles[sessionId] else {
            Self.logger.debug("No stdin handle for session \(sessionId) — process may have exited")
            return false
        }

        let response = PermissionResponsePayload(type: "permission_response", id: requestId, decision: decision)

        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(response)
        } catch {
            Self.logger.error("Failed to encode permission response: \(error)")
            return false
        }

        guard var jsonString = String(data: jsonData, encoding: .utf8) else {
            Self.logger.error("Failed to convert permission response data to UTF-8 string")
            return false
        }

        jsonString += "\n"
        guard let data = jsonString.data(using: .utf8) else { return false }

        handle.write(data)
        Self.logger.debug("Sent permission response for \(requestId) to session \(sessionId): \(decision)")
        return true
    }

    // MARK: - Process Management

    private func storeProcess(_ sessionId: String, process: Process) {
        activeProcesses[sessionId] = process
    }

    private func removeProcess(_ sessionId: String) {
        activeProcesses.removeValue(forKey: sessionId)
    }

    // MARK: - Stdin Handle Management

    private func storeStdinHandle(_ sessionId: String, handle: FileHandle) {
        activeStdinHandles[sessionId] = handle
    }

    private func removeStdinHandle(_ sessionId: String) {
        activeStdinHandles.removeValue(forKey: sessionId)
    }

    // MARK: - SDK Config Building

    /// Build a JSON configuration object for the Agent SDK wrapper.
    ///
    /// The config includes the prompt and all options in a format that
    /// `sdk-wrapper.mjs` maps to the Agent SDK's `query()` function.
    private static func buildSDKConfig(
        prompt: String,
        options: ExecutionOptions,
        workingDirectory: String?
    ) -> String {
        let sdkOptions = SDKOptions(
            model: options.model,
            maxTurns: options.maxTurns,
            allowedTools: options.allowedTools,
            disallowedTools: options.disallowedTools,
            permissionMode: options.permissionMode?.rawValue,
            systemPrompt: (options.systemPrompt?.isEmpty == false) ? options.systemPrompt : nil,
            appendSystemPrompt: (options.appendSystemPrompt?.isEmpty == false) ? options.appendSystemPrompt : nil,
            resume: options.resume,
            continueConversation: options.continueConversation == true ? true : nil,
            forkSession: options.forkSession == true ? true : nil,
            sessionId: options.sessionId,
            cwd: workingDirectory,
            includePartialMessages: options.includePartialMessages == true ? true : nil
        )

        let config = SDKConfig(prompt: prompt, options: sdkOptions)

        do {
            let jsonData = try JSONEncoder().encode(config)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode SDK config: \(error)")
            // Fallback: encode just the prompt safely
            let fallback = SDKConfig(prompt: String(prompt.prefix(100)), options: SDKOptions())
            if let safeData = try? JSONEncoder().encode(fallback),
               let safeString = String(data: safeData, encoding: .utf8) {
                return safeString
            }
            return "{}"
        }
    }

    // MARK: - CLI Command Building

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

        // Always include partial messages for character-by-character streaming
        args.append("--include-partial-messages")

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

        // Permission mode: use specified mode or default to CLI's default (interactive permissions)
        if let mode = options.permissionMode {
            switch mode {
            case .bypassPermissions:
                args.append("--dangerously-skip-permissions")
            default:
                args.append("--permission-mode")
                args.append(mode.rawValue)
            }
        } else {
            args.append("--permission-mode")
            args.append(PermissionMode.default.rawValue)
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

        // Agent mode
        if let agent = options.agent, !agent.isEmpty {
            args.append("--agent")
            args.append(agent)
        }

        // Beta flags
        if let betas = options.betas, !betas.isEmpty {
            args.append("--betas")
            args.append(betas.joined(separator: ","))
        }

        // Debug mode
        if options.debug == true {
            args.append("--debug")
        }

        // Debug file
        if let debugFile = options.debugFile, !debugFile.isEmpty {
            args.append("--debug-file")
            args.append(debugFile)
        }

        // Disable slash commands
        if options.disableSlashCommands == true {
            args.append("--disable-slash-commands")
        }

        // System prompt file
        if let systemPromptFile = options.systemPromptFile, !systemPromptFile.isEmpty {
            args.append("--system-prompt-file")
            args.append(systemPromptFile)
        }

        // Append system prompt file
        if let appendSystemPromptFile = options.appendSystemPromptFile, !appendSystemPromptFile.isEmpty {
            args.append("--append-system-prompt-file")
            args.append(appendSystemPromptFile)
        }

        // Plugin directory
        if let pluginDir = options.pluginDir, !pluginDir.isEmpty {
            args.append("--plugin-dir")
            args.append(pluginDir)
        }

        // Strict MCP config
        if options.strictMcpConfig == true {
            args.append("--strict-mcp-config")
        }

        // Custom settings path
        if let settingsPath = options.settingsPath, !settingsPath.isEmpty {
            args.append("--settings")
            args.append(settingsPath)
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
    /// Decodes each NDJSON line as a CLIMessage using Codable, then converts
    /// to StreamMessage via CLIMessageConverter.
    private static func processJsonLine(
        _ line: String,
        continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
    ) {
        guard let data = line.data(using: .utf8) else {
            logger.debug("Failed to decode line as UTF-8")
            return
        }
        do {
            let cliMessage = try cliDecoder.decode(CLIMessage.self, from: data)
            if let streamMessage = CLIMessageConverter.convert(cliMessage) {
                continuation.yield(streamMessage)
                logger.debug("Yielded \(cliMessage) message")
            }
        } catch {
            logger.debug("Failed to decode CLI message: \(error.localizedDescription) — line: \(line.prefix(200))")
        }
    }

    // MARK: - Codable Payloads

    /// Codable struct for permission response JSON sent to Claude CLI stdin.
    private struct PermissionResponsePayload: Codable {
        let type: String
        let id: String
        let decision: String
    }

    /// Codable struct for Agent SDK wrapper configuration.
    private struct SDKConfig: Codable {
        let prompt: String
        let options: SDKOptions
    }

    /// Codable struct for SDK execution options passed to sdk-wrapper.mjs.
    /// All fields are optional; nil values are omitted from JSON output.
    private struct SDKOptions: Codable {
        var model: String?
        var maxTurns: Int?
        var allowedTools: [String]?
        var disallowedTools: [String]?
        var permissionMode: String?
        var systemPrompt: String?
        var appendSystemPrompt: String?
        var resume: String?
        var continueConversation: Bool?
        var forkSession: Bool?
        var sessionId: String?
        var cwd: String?
        var includePartialMessages: Bool?

        init(
            model: String? = nil,
            maxTurns: Int? = nil,
            allowedTools: [String]? = nil,
            disallowedTools: [String]? = nil,
            permissionMode: String? = nil,
            systemPrompt: String? = nil,
            appendSystemPrompt: String? = nil,
            resume: String? = nil,
            continueConversation: Bool? = nil,
            forkSession: Bool? = nil,
            sessionId: String? = nil,
            cwd: String? = nil,
            includePartialMessages: Bool? = nil
        ) {
            self.model = model
            self.maxTurns = maxTurns
            self.allowedTools = allowedTools
            self.disallowedTools = disallowedTools
            self.permissionMode = permissionMode
            self.systemPrompt = systemPrompt
            self.appendSystemPrompt = appendSystemPrompt
            self.resume = resume
            self.continueConversation = continueConversation
            self.forkSession = forkSession
            self.sessionId = sessionId
            self.cwd = cwd
            self.includePartialMessages = includePartialMessages
        }
    }
}

