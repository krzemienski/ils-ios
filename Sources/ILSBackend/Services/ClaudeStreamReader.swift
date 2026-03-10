// Sources/ILSBackend/Services/ClaudeStreamReader.swift

import Foundation
import ILSShared
import Logging

/// Thread-safe boolean flag for cross-queue timeout signaling.
/// Uses `os_unfair_lock` via `OSAllocatedUnfairLock` to synchronize reads/writes
/// across DispatchQueue.global() (timeout work items) and readQueue (stdout reader).
final class AtomicFlag: @unchecked Sendable {
    private var _value = false
    private let lock = NSLock()

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set() {
        lock.lock()
        _value = true
        lock.unlock()
    }
}

/// Reads and decodes NDJSON stdout from Claude CLI/SDK processes into StreamMessages.
///
/// Provides shared stdout reading logic used by both the Agent SDK and CLI execution
/// paths in `ClaudeExecutorService`. Handles line buffering, JSON decoding, timeout
/// reporting, and session cleanup after a process exits.
enum ClaudeStreamReader {

    private static let logger = Logger(label: "ils.claude-stream-reader")

    /// JSON decoder configured for CLI snake_case output.
    private static let cliDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Stdout Reader

    /// Read NDJSON lines from a process stdout pipe and yield parsed StreamMessages.
    ///
    /// Reads chunks of data from the pipe's read handle, accumulates them in a line
    /// buffer, and decodes each complete line as a `CLIMessage`. Handles process exit
    /// (including timeout and non-zero exit codes) and cleans up the session on finish.
    ///
    /// - Parameters:
    ///   - pipe: Stdout pipe attached to the Claude process
    ///   - errorPipe: Stderr pipe for reading error output on failure
    ///   - process: The running Claude subprocess
    ///   - sessionId: Session ID used for cleanup after exit
    ///   - didTimeout: Flag set by the timeout `DispatchWorkItem`; read here to detect kills
    ///   - timeoutWork: Initial 30s timeout work item — cancelled on first data receipt
    ///   - totalTimeoutWork: 5-minute hard timeout work item — cancelled on clean exit
    ///   - continuation: Async stream continuation to yield messages and finish on
    ///   - executor: Owning executor for session/stdin cleanup after exit
    ///   - cleanupStdin: Optional stdin `FileHandle` to close after the process exits (CLI only)
    static func readStdout(
        pipe: Pipe,
        errorPipe: Pipe,
        process: Process,
        sessionId: String,
        didTimeout: AtomicFlag,
        timeoutWork: DispatchWorkItem,
        totalTimeoutWork: DispatchWorkItem,
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

            timeoutWork.cancel()
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
        timeoutWork.cancel()
        totalTimeoutWork.cancel()

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            if didTimeout.value {
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

    // MARK: - JSON Line Parsing

    /// Decode a single NDJSON line and yield the resulting StreamMessage on the continuation.
    ///
    /// Decodes the line as a `CLIMessage` using the snake_case JSON decoder, then converts
    /// it to a `StreamMessage` via `CLIMessageConverter`. Lines that fail to decode are
    /// logged and silently dropped.
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
}
