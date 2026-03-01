import Foundation
import Vapor
import ILSShared
import Logging

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

    /// Active processes keyed by session ID for cancellation support
    private var activeProcesses: [String: Process] = [:]

    /// Active stdin handles keyed by session ID for permission response forwarding
    private var activeStdinHandles: [String: FileHandle] = [:]

    /// GCD queue for blocking stdout reads (avoids RunLoop dependency).
    /// `let` property — nonisolated by default on actors, safe to access from nonisolated methods.
    private let readQueue = DispatchQueue(label: "ils.claude-stdout-reader", qos: .userInitiated)

    /// When true, uses the Agent SDK (via Node.js wrapper) instead of `claude -p`.
    /// The SDK calls the Anthropic API directly, avoiding the subprocess hang issue.
    /// Set to false to fall back to `claude -p` when running outside Claude Code.
    ///
    /// SWIFT6-01: `static let` — no runtime mutation exists in the codebase.
    /// Previously `nonisolated(unsafe) static var` but grep confirms zero write sites.
    static let useAgentSDK: Bool = true

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

    /// Execute a Claude query with streaming JSON output.
    ///
    /// Uses either the Agent SDK (Node.js wrapper) or direct `claude -p` CLI depending
    /// on the `useAgentSDK` flag. Both produce NDJSON on stdout in the same format.
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
        if Self.useAgentSDK {
            return executeWithSDK(prompt: prompt, workingDirectory: workingDirectory, options: options)
        } else {
            return executeWithCLI(prompt: prompt, workingDirectory: workingDirectory, options: options)
        }
    }

    // MARK: - Agent SDK Execution

    /// Execute via Agent SDK (Node.js wrapper).
    ///
    /// Spawns `node scripts/sdk-wrapper.mjs '<json-config>'` where the prompt and all
    /// options are passed as a JSON argument. The SDK calls the Anthropic API directly,
    /// avoiding subprocess conflicts with the parent Claude Code session.
    private nonisolated func executeWithSDK(
        prompt: String,
        workingDirectory: String?,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            // Build SDK configuration as JSON
            let sdkConfig = ClaudeCommandBuilder.buildSDKConfig(prompt: prompt, options: options, workingDirectory: workingDirectory)
            Self.logger.debug("SDK config: \(sdkConfig.prefix(200))")

            // Find the sdk-wrapper.mjs script relative to the backend working directory
            let projectRoot = workingDirectory ?? FileManager.default.currentDirectoryPath
            let wrapperPath = "\(projectRoot)/scripts/sdk-wrapper.mjs"

            // Build the node command
            let command = "node \(ClaudeCommandBuilder.shellEscape(wrapperPath)) \(ClaudeCommandBuilder.shellEscape(sdkConfig))"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            // Inherit environment — the Agent SDK uses Claude Code's auth (not ANTHROPIC_API_KEY)
            process.environment = ProcessInfo.processInfo.environment

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
                continuation.yield(.error(StreamError(
                    code: "LAUNCH_ERROR",
                    message: "Failed to launch Agent SDK wrapper: \(error.localizedDescription)"
                )))
                continuation.finish()
                return
            }

            // --- Timeout mechanism ---
            var didTimeout = false

            let timeoutWork = DispatchWorkItem {
                didTimeout = true
                Self.logger.debug("TIMEOUT: No SDK data within 30s")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            let totalTimeoutWork = DispatchWorkItem {
                if process.isRunning {
                    didTimeout = true
                    Self.logger.debug("TOTAL TIMEOUT: SDK process >5min")
                    process.terminate()
                    outputPipe.fileHandleForReading.closeFile()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: totalTimeoutWork)

            self.readQueue.async {
                ClaudeStreamReader.readStdout(
                    pipe: outputPipe,
                    errorPipe: errorPipe,
                    process: process,
                    sessionId: sessionId,
                    didTimeout: &didTimeout,
                    timeoutWork: timeoutWork,
                    totalTimeoutWork: totalTimeoutWork,
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
        AsyncThrowingStream { continuation in
            let command = ClaudeCommandBuilder.buildCommand(options: options)
            Self.logger.debug("CLI command: \(command)")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            process.environment = ProcessInfo.processInfo.environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Send prompt via stdin, keep open for permission forwarding
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let data = (prompt + "\n").data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }

            let sessionId = options.sessionId ?? UUID().uuidString
            let stdinHandle = stdinPipe.fileHandleForWriting
            Task { [weak self] in
                await self?.storeProcess(sessionId, process: process)
                await self?.storeStdinHandle(sessionId, handle: stdinHandle)
            }

            do {
                try process.run()
                Self.logger.debug("CLI process started (PID: \(process.processIdentifier))")
            } catch {
                Self.logger.debug("Failed to start CLI process: \(error)")
                continuation.yield(.error(StreamError(
                    code: "LAUNCH_ERROR",
                    message: "Failed to launch claude: \(error.localizedDescription)"
                )))
                continuation.finish()
                return
            }

            var didTimeout = false

            let timeoutWork = DispatchWorkItem {
                didTimeout = true
                Self.logger.debug("TIMEOUT: No CLI data within 30s")
                process.terminate()
                outputPipe.fileHandleForReading.closeFile()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            let totalTimeoutWork = DispatchWorkItem {
                if process.isRunning {
                    didTimeout = true
                    Self.logger.debug("TOTAL TIMEOUT: CLI process >5min")
                    process.terminate()
                    outputPipe.fileHandleForReading.closeFile()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: totalTimeoutWork)

            self.readQueue.async {
                ClaudeStreamReader.readStdout(
                    pipe: outputPipe,
                    errorPipe: errorPipe,
                    process: process,
                    sessionId: sessionId,
                    didTimeout: &didTimeout,
                    timeoutWork: timeoutWork,
                    totalTimeoutWork: totalTimeoutWork,
                    continuation: continuation,
                    executor: self,
                    cleanupStdin: stdinHandle
                )
            }
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

    func removeProcess(_ sessionId: String) {
        activeProcesses.removeValue(forKey: sessionId)
    }

    // MARK: - Stdin Handle Management

    private func storeStdinHandle(_ sessionId: String, handle: FileHandle) {
        activeStdinHandles[sessionId] = handle
    }

    func removeStdinHandle(_ sessionId: String) {
        activeStdinHandles.removeValue(forKey: sessionId)
    }

    // MARK: - Codable Payloads

    /// Codable struct for permission response JSON sent to Claude CLI stdin.
    private struct PermissionResponsePayload: Codable {
        let type: String
        let id: String
        let decision: String
    }
}

