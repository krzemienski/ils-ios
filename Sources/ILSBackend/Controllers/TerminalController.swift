import Vapor
import ILSShared

/// Controller for embedded terminal endpoints.
///
/// Routes (all under `/api/v1/terminal`):
/// - `POST /terminal/execute` — execute a shell command and return full output
/// - `GET  /terminal/config`  — retrieve current terminal configuration
/// - `POST /terminal/reset`   — reset working directory to home
/// - `WS   /terminal/stream`  — stream command output in real time
struct TerminalController: RouteCollection {
    /// Shared terminal service instance for working-directory state persistence across requests.
    let terminalService = TerminalService()

    func boot(routes: RoutesBuilder) throws {
        let terminal = routes.grouped("terminal")

        terminal.post("execute", use: self.execute)
        terminal.get("config", use: self.getConfig)
        terminal.post("reset", use: self.reset)
        terminal.webSocket("stream", onUpgrade: self.stream)
    }

    // MARK: - REST Endpoints

    /// POST /terminal/execute — execute a shell command and return full output.
    @Sendable
    func execute(req: Request) async throws -> Response {
        let body = try req.content.decode(TerminalExecuteRequest.self)

        do {
            let result = try await terminalService.execute(
                command: body.command,
                workingDirectory: body.workingDirectory,
                extraEnvironment: body.environment,
                timeout: body.timeout.map(TimeInterval.init)
            )
            return try encodeResponse(result, status: .ok)
        } catch TerminalError.timeout(let seconds) {
            let response = TerminalExecuteResponse(
                stdout: "",
                stderr: "Command timed out after \(seconds) seconds",
                exitCode: 124,
                duration: TimeInterval(seconds),
                workingDirectory: await terminalService.getCurrentDirectory()
            )
            return try encodeResponse(response, status: .ok)
        } catch TerminalError.launchFailed(let underlying) {
            throw Abort(.internalServerError, reason: "Failed to launch shell: \(underlying.localizedDescription)")
        }
    }

    /// GET /terminal/config — return current terminal configuration.
    @Sendable
    func getConfig(req: Request) async throws -> Response {
        let config = await terminalService.getConfig()
        return try encodeResponse(config, status: .ok)
    }

    /// POST /terminal/reset — reset working directory to the user's home directory.
    @Sendable
    func reset(req: Request) async throws -> Response {
        await terminalService.reset()
        let config = await terminalService.getConfig()
        return try encodeResponse(config, status: .ok)
    }

    // MARK: - WebSocket

    /// WS /terminal/stream — stream command output in real time.
    ///
    /// ## Protocol
    /// 1. Client sends a JSON text frame encoding a `TerminalExecuteRequest`.
    /// 2. Server streams `TerminalStreamMessage` JSON text frames:
    ///    - `type: "stdout"` — chunk of standard output
    ///    - `type: "stderr"` — chunk of standard error
    ///    - `type: "exit"`   — process finished; `exitCode` is populated
    /// 3. Multiple commands may be sent sequentially over the same connection.
    @Sendable
    func stream(req: Request, ws: WebSocket) async {
        let service = terminalService
        let cancellation = WebSocketCancellation()

        ws.onText { _, text in
            guard let data = text.data(using: .utf8),
                  let executeRequest = try? JSONDecoder().decode(TerminalExecuteRequest.self, from: data) else {
                return
            }

            Task {
                guard await !cancellation.isCancelled() else { return }
                await TerminalController.streamCommand(
                    request: executeRequest,
                    service: service,
                    ws: ws,
                    cancellation: cancellation
                )
            }
        }

        ws.onClose.whenComplete { _ in
            Task { await cancellation.cancel() }
        }

        // Hold the handler open until the client disconnects.
        try? await ws.onClose.get()
    }

    // MARK: - Private Streaming Helpers

    /// Execute a command and stream stdout/stderr chunks to the WebSocket in real time.
    ///
    /// Spawns a `/bin/zsh -l -c` subprocess and polls stdout/stderr every 50 ms using
    /// `availableData` (non-blocking). Each non-empty chunk is forwarded immediately as a
    /// `TerminalStreamMessage` text frame. After the process exits, remaining buffered
    /// output is drained and a final `exit` frame is sent.
    private static func streamCommand(
        request: TerminalExecuteRequest,
        service: TerminalService,
        ws: WebSocket,
        cancellation: WebSocketCancellation
    ) async {
        let effectiveCwd: String
        if let requested = request.workingDirectory {
            effectiveCwd = requested
        } else {
            effectiveCwd = await service.getCurrentDirectory()
        }

        let timeout = request.timeout.map(TimeInterval.init) ?? 60

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", request.command]
        process.currentDirectoryURL = URL(fileURLWithPath: effectiveCwd)

        if let extra = request.environment, !extra.isEmpty {
            var env = ProcessInfo.processInfo.environment
            env.merge(extra) { _, new in new }
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe
        stdinPipe.fileHandleForWriting.closeFile()

        do {
            try process.run()
        } catch {
            await sendStreamMessage(
                TerminalStreamMessage(type: .stderr, data: "Failed to launch shell: \(error.localizedDescription)"),
                to: ws
            )
            await sendStreamMessage(TerminalStreamMessage(type: .exit, data: "", exitCode: 1), to: ws)
            return
        }

        // Watchdog: terminate runaway processes after the effective timeout.
        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        // Poll stdout/stderr on a private GCD queue every 50 ms, forwarding chunks as
        // they arrive. Matches the DispatchQueue pattern used by ClaudeExecutorService.
        let readQueue = DispatchQueue(
            label: "ils.terminal-stream-\(UUID().uuidString.prefix(8))",
            qos: .userInitiated
        )

        let exitCode: Int = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            readQueue.async {
                defer {
                    stdoutPipe.fileHandleForReading.closeFile()
                    stderrPipe.fileHandleForReading.closeFile()
                }

                // Stream chunks while the process is alive.
                while process.isRunning {
                    let outChunk = stdoutPipe.fileHandleForReading.availableData
                    if !outChunk.isEmpty, let text = String(data: outChunk, encoding: .utf8) {
                        let msg = TerminalStreamMessage(type: .stdout, data: text)
                        Task { await Self.sendStreamMessage(msg, to: ws) }
                    }

                    let errChunk = stderrPipe.fileHandleForReading.availableData
                    if !errChunk.isEmpty, let text = String(data: errChunk, encoding: .utf8) {
                        let msg = TerminalStreamMessage(type: .stderr, data: text)
                        Task { await Self.sendStreamMessage(msg, to: ws) }
                    }

                    Thread.sleep(forTimeInterval: 0.05)
                }

                // Process has exited — drain any remaining buffered output.
                process.waitUntilExit()

                let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingOut.isEmpty, let text = String(data: remainingOut, encoding: .utf8) {
                    let msg = TerminalStreamMessage(type: .stdout, data: text)
                    Task { await Self.sendStreamMessage(msg, to: ws) }
                }

                let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingErr.isEmpty, let text = String(data: remainingErr, encoding: .utf8) {
                    let msg = TerminalStreamMessage(type: .stderr, data: text)
                    Task { await Self.sendStreamMessage(msg, to: ws) }
                }

                continuation.resume(returning: Int(process.terminationStatus))
            }
        }

        timeoutWork.cancel()

        // Brief pause to allow in-flight stdout/stderr Task sends to complete
        // before the exit frame is delivered to the client.
        try? await Task.sleep(nanoseconds: 50_000_000)

        await sendStreamMessage(TerminalStreamMessage(type: .exit, data: "", exitCode: exitCode), to: ws)
    }

    /// Encode and send a `TerminalStreamMessage` as a JSON text WebSocket frame.
    private static func sendStreamMessage(_ message: TerminalStreamMessage, to ws: WebSocket) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await ws.send(text)
    }

    /// Encode a `Codable` value as a JSON HTTP `Response`.
    private func encodeResponse<T: Encodable>(_ value: T, status: HTTPResponseStatus) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return Response(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }
}

// MARK: - Vapor Content Conformance

extension TerminalExecuteRequest: Content {}
extension TerminalExecuteResponse: Content {}
extension TerminalConfig: Content {}
extension TerminalStreamMessage: Content {}
