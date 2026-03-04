import Foundation
import Vapor
import ILSShared
import Logging

/// Actor managing embedded terminal shell process execution.
///
/// ## Architecture
///
/// Each command executes in a fresh `/bin/zsh -l -c` subprocess. Working directory
/// is tracked across commands using a sentinel-marker technique:
///
/// 1. The user's command is wrapped: `<command>; echo __ILS_TERMINAL_EXIT__:$?; pwd`
/// 2. `process.currentDirectoryURL` is set to the stored `currentWorkingDirectory`
/// 3. After execution, the exit code is parsed from the `__ILS_TERMINAL_EXIT__:N` line
///    and the following `pwd` output becomes the new `currentWorkingDirectory`
///
/// ### Working Directory Tracking
///
/// Since each command spawns a new shell process, `cd` changes only affect that
/// process's CWD. By capturing `pwd` output after every command, we persist the
/// updated directory for the next command, making multi-step workflows (e.g. `cd /tmp`
/// followed by `ls`) work correctly across separate invocations.
///
/// ### Timeout Protection
///
/// A 60-second watchdog timer kills runaway processes. Callers may override this on
/// a per-request basis via `TerminalExecuteRequest.timeout`.
///
/// ### Thread Safety
///
/// Actor isolation ensures `currentWorkingDirectory` updates are serialised.
/// Blocking stdout/stderr reads happen on `readQueue` (a private GCD queue),
/// matching the pattern used by `ClaudeExecutorService`.
actor TerminalService {
    /// Structured logger for terminal operations.
    private static let logger = Logger(label: "ils.terminal")

    /// Sentinel string appended to every wrapped command to delimit exit-code output.
    /// Deliberately obscure to minimise risk of conflicts with normal command output.
    private static let exitMarker = "__ILS_TERMINAL_EXIT__:"

    /// Default per-command execution timeout in seconds.
    private static let defaultTimeout: TimeInterval = 60

    /// Current working directory, persisted across sequential command executions.
    private var currentWorkingDirectory: String

    /// GCD queue for blocking stdout/stderr reads (avoids RunLoop dependency).
    /// Declared as `let` — nonisolated by default on actors, safe from nonisolated closures.
    private let readQueue = DispatchQueue(label: "ils.terminal-reader", qos: .userInitiated)

    /// Thread-safe boolean for sharing timeout state across GCD queues.
    /// Replaces a bare `var didTimeout` which would introduce data races between
    /// the timeout DispatchWorkItem (global queue) and the reader (readQueue).
    private final class AtomicBool: @unchecked Sendable {
        private var _value: Bool
        private let lock = NSLock()
        init(_ value: Bool) { _value = value }
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); defer { lock.unlock() }; _value = newValue }
        }
    }

    // MARK: - Lifecycle

    init() {
        self.currentWorkingDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    }

    // MARK: - Public API

    /// Execute a shell command and return combined output.
    ///
    /// Wraps the command with exit-code capture and `pwd` to track working-directory
    /// changes (e.g. `cd /tmp`). Applies a per-request or default 60-second timeout.
    ///
    /// - Parameters:
    ///   - command: Shell command string executed via `/bin/zsh -l -c`.
    ///   - workingDirectory: Override starting directory; `nil` uses `currentWorkingDirectory`.
    ///   - extraEnvironment: Additional env vars merged into the inherited environment.
    ///   - timeout: Per-command timeout in seconds; `nil` uses the 60-second default.
    /// - Returns: `TerminalExecuteResponse` with stdout, stderr, exitCode, duration, and CWD.
    /// - Throws: `TerminalError.timeout` if the command exceeds the timeout.
    ///           `TerminalError.launchFailed` if the subprocess cannot be started.
    func execute(
        command: String,
        workingDirectory: String? = nil,
        extraEnvironment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> TerminalExecuteResponse {
        let cwd = workingDirectory ?? currentWorkingDirectory
        let effectiveTimeout = timeout ?? Self.defaultTimeout
        let startTime = Date()

        // Wrap command: append exit-code capture + pwd so we can track CWD changes.
        // `$?` captures the exit code of the user command (evaluated before our echo).
        let wrappedCommand = "\(command); echo \(Self.exitMarker)$?; pwd"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", wrappedCommand]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        // Merge extra environment variables into the inherited environment, if provided.
        if let extra = extraEnvironment, !extra.isEmpty {
            var env = ProcessInfo.processInfo.environment
            env.merge(extra) { _, new in new }
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Close stdin immediately — terminal REST commands never read from stdin.
        let stdinPipe = Pipe()
        process.standardInput = stdinPipe
        stdinPipe.fileHandleForWriting.closeFile()

        do {
            try process.run()
            Self.logger.debug("Terminal process started (PID: \(process.processIdentifier)) cwd: \(cwd)")
        } catch {
            // MEM-FD: Close pipes to prevent file descriptor leaks on launch failure.
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            throw TerminalError.launchFailed(error)
        }

        // Watchdog: kill runaway processes after the effective timeout.
        let didTimeout = AtomicBool(false)
        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                didTimeout.value = true
                Self.logger.debug("Terminal timeout after \(effectiveTimeout)s — terminating PID \(process.processIdentifier)")
                process.terminate()
                // Closing the read end unblocks readDataToEndOfFile on the read queue.
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + effectiveTimeout, execute: timeoutWork)

        // Read output on readQueue to avoid blocking the actor executor.
        // NOTE: stdout is read first (blocks until process exits via EOF on write end),
        // then stderr is read after waitUntilExit(). This sequential approach is safe
        // for commands producing moderate output (< OS pipe buffer ~64 KB per stream).
        let (stdoutRaw, stderrText) = await withCheckedContinuation { (continuation: CheckedContinuation<(String, String), Never>) in
            self.readQueue.async {
                // MEM-FD: Ensure pipe FDs are closed when we exit, preventing leaks.
                defer {
                    stdoutPipe.fileHandleForReading.closeFile()
                    stderrPipe.fileHandleForReading.closeFile()
                }

                // Block until the process closes its stdout write end (normal exit or kill).
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

                // Process has exited by this point; read stderr (returns immediately).
                process.waitUntilExit()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let out = String(data: stdoutData, encoding: .utf8) ?? ""
                let err = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(returning: (out, err))
            }
        }

        timeoutWork.cancel()

        if didTimeout.value {
            Self.logger.debug("Terminal command timed out: \(command.prefix(100))")
            throw TerminalError.timeout(Int(effectiveTimeout))
        }

        let duration = Date().timeIntervalSince(startTime)

        // Parse exit code and updated working directory from the wrapped stdout output.
        let (stdout, exitCode, newWorkingDirectory) = Self.parseWrappedOutput(
            stdoutRaw,
            startingDirectory: cwd
        )

        // Persist the new working directory for subsequent commands when using actor CWD.
        // Do not update when the caller supplied an explicit workingDirectory override.
        if workingDirectory == nil {
            currentWorkingDirectory = newWorkingDirectory
        }

        Self.logger.debug("Terminal command completed: exit=\(exitCode) cwd=\(newWorkingDirectory) duration=\(String(format: "%.2f", duration))s")

        return TerminalExecuteResponse(
            stdout: stdout,
            stderr: stderrText,
            exitCode: exitCode,
            duration: duration,
            workingDirectory: newWorkingDirectory
        )
    }

    /// Returns the current working directory managed by this service.
    func getCurrentDirectory() -> String {
        currentWorkingDirectory
    }

    /// Returns the current terminal configuration for this service instance.
    func getConfig() -> TerminalConfig {
        TerminalConfig(
            shell: .zsh,
            historyLimit: 500,
            environment: [:],
            sourceProfile: true,
            defaultWorkingDirectory: currentWorkingDirectory
        )
    }

    /// Resets the working directory to the current user's home directory.
    func reset() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        currentWorkingDirectory = home
        Self.logger.debug("Terminal working directory reset to: \(home)")
    }

    // MARK: - Output Parsing

    /// Parse wrapped command output to extract stdout, exit code, and new working directory.
    ///
    /// The wrapper appends:
    /// ```
    /// echo __ILS_TERMINAL_EXIT__:$?
    /// pwd
    /// ```
    /// This method locates the marker line, extracts the integer exit code, and reads
    /// the following line as the new working directory. All lines before the marker
    /// constitute the real stdout content.
    ///
    /// - Parameters:
    ///   - raw: Raw stdout string from the wrapped command subprocess.
    ///   - startingDirectory: Fallback CWD if the marker or `pwd` line is not found.
    /// - Returns: Tuple of (stdout, exitCode, workingDirectory).
    private static func parseWrappedOutput(
        _ raw: String,
        startingDirectory: String
    ) -> (stdout: String, exitCode: Int, workingDirectory: String) {
        let lines = raw.components(separatedBy: "\n")
        var exitCode = 0
        var markerIndex: Int?

        // Locate the sentinel marker line and extract the exit code integer.
        for (i, line) in lines.enumerated() {
            if line.hasPrefix(exitMarker) {
                let codeStr = String(line.dropFirst(exitMarker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                exitCode = Int(codeStr) ?? 0
                markerIndex = i
                break
            }
        }

        // The line immediately after the marker is the `pwd` output (new CWD).
        var newCwd = startingDirectory
        if let idx = markerIndex, idx + 1 < lines.count {
            let pwdLine = lines[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !pwdLine.isEmpty {
                newCwd = pwdLine
            }
        }

        // Stdout is everything before the marker line.
        let stdoutLines = markerIndex.map { Array(lines.prefix($0)) } ?? lines
        let joined = stdoutLines.joined(separator: "\n")

        // Normalise: trim surrounding newlines, then add exactly one trailing newline
        // (preserving the convention that command output ends with a newline).
        let trimmed = joined.trimmingCharacters(in: .newlines)
        let finalStdout = trimmed.isEmpty ? "" : trimmed + "\n"

        return (finalStdout, exitCode, newCwd)
    }
}

// MARK: - TerminalError

/// Errors thrown by `TerminalService`.
enum TerminalError: Error, LocalizedError {
    /// The subprocess could not be launched (e.g. executable not found).
    case launchFailed(Error)
    /// The command exceeded the allowed execution time.
    case timeout(Int)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let underlying):
            return "Failed to launch shell: \(underlying.localizedDescription)"
        case .timeout(let seconds):
            return "Command timed out after \(seconds) seconds"
        }
    }
}
