import Foundation
import ILSShared
import Logging

/// Actor that monitors Claude Code processes and associates them with sessions.
///
/// Identifies Claude CLI processes, Node.js SDK wrapper processes, and related build
/// processes (swift-frontend, swiftc, etc.) that are spawned by Claude Code sessions.
/// Associates processes with session IDs by matching working directories from the
/// process command line.
///
/// ## Process Identification
///
/// Detects the following process types:
/// - `claude`: Claude CLI processes spawned by ClaudeExecutorService
/// - `node`: Node.js processes running the SDK wrapper (scripts/sdk-wrapper.py)
/// - `python3`: Python processes running the SDK wrapper
/// - `swift-frontend`, `swiftc`: Swift compiler processes spawned during builds
/// - Other related processes that may be spawned by Claude Code operations
///
/// ## Session Association
///
/// Associates processes with sessions by:
/// 1. Parsing the full command line from `ps` output
/// 2. Extracting working directory paths from command arguments
/// 3. Matching working directories to known session working directories
/// 4. Tagging processes with the associated session ID
///
/// ## Architecture
///
/// Uses `ps auxww` to get full process details including command line. Runs on a
/// global DispatchQueue to avoid blocking the NIO event loop. Uses
/// `withCheckedContinuation` for async/await bridging. Includes timeout protection
/// to prevent hanging on stuck `ps` commands.
actor ProcessMonitorService {
    /// Structured logger for process monitoring operations
    private static let logger = Logger(label: "ils.process-monitor")

    /// Thread-safe boolean for sharing timeout state across GCD queues.
    private final class AtomicBool: @unchecked Sendable {
        private var _value: Bool
        private let lock = NSLock()
        init(_ value: Bool) { _value = value }
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); defer { lock.unlock() }; _value = newValue }
        }
    }

    /// Known session working directories for process association.
    /// Updated by registerSession() and unregisterSession().
    private var sessionWorkingDirs: [String: String] = [:] // sessionId -> workingDir

    /// Cache of process start times for uptime calculation (pid -> startTime).
    private var processStartTimes: [Int: Date] = [:]

    // MARK: - Public API

    /// Register a session's working directory for process association.
    /// - Parameters:
    ///   - sessionId: The session ID to register
    ///   - workingDirectory: The session's working directory path
    func registerSession(sessionId: String, workingDirectory: String) {
        sessionWorkingDirs[sessionId] = workingDirectory
        Self.logger.debug("Registered session \(sessionId) with working directory: \(workingDirectory)")
    }

    /// Unregister a session's working directory.
    /// - Parameter sessionId: The session ID to unregister
    func unregisterSession(sessionId: String) {
        sessionWorkingDirs.removeValue(forKey: sessionId)
        Self.logger.debug("Unregistered session \(sessionId)")
    }

    /// Get all Claude Code processes currently running on the system.
    ///
    /// Runs `ps auxww` to get full process details with command lines, then filters
    /// for Claude Code-related processes and associates them with registered sessions.
    ///
    /// - Returns: Array of ProcessMonitorInfo for Claude Code processes
    func getClaudeProcesses() async -> [ProcessMonitorInfo] {
        let allProcesses = await getAllProcesses()
        let claudeProcesses = allProcesses.filter { isClaudeCodeProcess($0) }
        return claudeProcesses.map { enrichWithSessionInfo($0) }
    }

    /// Get process information for a specific PID.
    /// - Parameter pid: The process ID to query
    /// - Returns: ProcessMonitorInfo if process exists and is a Claude Code process, nil otherwise
    func getProcess(pid: Int) async -> ProcessMonitorInfo? {
        let allProcesses = await getAllProcesses()
        guard let process = allProcesses.first(where: { $0.pid == pid }),
              isClaudeCodeProcess(process) else {
            return nil
        }
        return enrichWithSessionInfo(process)
    }

    /// Kill a process by PID.
    /// - Parameters:
    ///   - pid: The process ID to kill
    ///   - force: If true, use SIGKILL; if false, use SIGTERM
    /// - Returns: True if the kill signal was sent successfully
    func killProcess(pid: Int, force: Bool) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let signal = force ? "-KILL" : "-TERM"
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/kill")
                process.arguments = [signal, "\(pid)"]

                let errorPipe = Pipe()
                process.standardError = errorPipe
                defer {
                    try? errorPipe.fileHandleForReading.close()
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    let success = process.terminationStatus == 0

                    if success {
                        Self.logger.info("Killed process \(pid) with signal \(signal)")
                    } else {
                        let errorData = try? errorPipe.fileHandleForReading.readToEnd()
                        let errorMsg = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown error"
                        Self.logger.warning("Failed to kill process \(pid): \(errorMsg)")
                    }

                    continuation.resume(returning: success)
                } catch {
                    Self.logger.error("Error killing process \(pid): \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Internal process representation with raw ps output fields.
    private struct RawProcessInfo {
        let pid: Int
        let name: String
        let cpuPercent: Double
        let memoryMB: Double
        let command: String
        let startTime: Date
    }

    /// Get all processes from the system using `ps auxww`.
    ///
    /// Similar to SystemMetricsService.getProcesses() but includes full command line
    /// and start time for session association and uptime calculation.
    private func getAllProcesses() async -> [RawProcessInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hasResumed = false

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/ps")
                // auxww: all users, full format, unlimited width command line
                process.arguments = ["auxww"]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                // 5-second timeout to prevent hangs
                let timeoutItem = DispatchWorkItem {
                    process.terminate()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: [])
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutItem)

                do {
                    try process.run()

                    // CRITICAL: Read stdout before waitUntilExit to prevent pipe deadlock
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    _ = errPipe.fileHandleForReading.readDataToEndOfFile()

                    process.waitUntilExit()
                    timeoutItem.cancel()

                    guard !hasResumed else { return }
                    hasResumed = true

                    guard let output = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: [])
                        return
                    }

                    let results = Self.parseProcessOutput(output)
                    continuation.resume(returning: results)
                } catch {
                    timeoutItem.cancel()
                    guard !hasResumed else { return }
                    hasResumed = true
                    Self.logger.error("Error running ps command: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Parse ps auxww output into RawProcessInfo structs.
    ///
    /// Expected format:
    /// USER       PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
    /// nick      1234  5.0  2.5  12345678 123456  ??  S    12:34PM   0:01.23 /usr/bin/claude -p ...
    private static func parseProcessOutput(_ output: String) -> [RawProcessInfo] {
        let lines = output.split(separator: "\n")
        guard lines.count > 1 else { return [] }

        var results: [RawProcessInfo] = []
        let currentYear = Calendar.current.component(.year, from: Date())

        for line in lines.dropFirst() { // Skip header
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 11 else { continue }

            // Parse PID, CPU%, MEM
            guard let pid = Int(parts[1]),
                  let cpu = Double(parts[2]),
                  let mem = Double(parts[3]) else {
                continue
            }

            // Parse STARTED time (format: "12:34PM" or "Mon12" for older processes)
            let startedStr = String(parts[8])
            let startTime = parseStartTime(startedStr, currentYear: currentYear)

            // Command is everything from column 11 onward
            let commandStartIndex = parts[10].startIndex
            let fullLine = String(line)
            guard let commandStart = fullLine.range(of: String(parts[10]), options: .literal) else {
                continue
            }
            let command = String(fullLine[commandStart.lowerBound...]).trimmingCharacters(in: .whitespaces)

            // Extract process name from command (first component of path or command)
            let name = extractProcessName(from: command)

            // Calculate memory in MB (RSS is in KB on macOS)
            let memoryMB = Double(parts[5]) ?? 0.0 / 1024.0

            results.append(RawProcessInfo(
                pid: pid,
                name: name,
                cpuPercent: cpu,
                memoryMB: memoryMB,
                command: command,
                startTime: startTime
            ))
        }

        return results
    }

    /// Parse process start time from ps STARTED column.
    ///
    /// Formats:
    /// - "12:34PM" - started today
    /// - "Mon12" - started on Monday the 12th
    /// - Other variations depending on age
    private static func parseStartTime(_ startedStr: String, currentYear: Int) -> Date {
        // Simplified: assume processes started within the last hour for now
        // TODO: Proper parsing of ps STARTED time formats
        return Date().addingTimeInterval(-3600)
    }

    /// Extract process name from full command line.
    /// - Parameter command: Full command line string
    /// - Returns: Process name (e.g., "claude", "node", "swift-frontend")
    private static func extractProcessName(from command: String) -> String {
        // Handle absolute paths: /usr/bin/claude -> claude
        // Handle commands with arguments: claude -p ... -> claude
        let firstPart = command.split(separator: " ", maxSplits: 1).first ?? ""
        let pathComponents = firstPart.split(separator: "/")
        let name = pathComponents.last ?? firstPart
        return String(name)
    }

    /// Check if a process is a Claude Code-related process.
    /// - Parameter process: The raw process info
    /// - Returns: True if this is a Claude Code process
    private func isClaudeCodeProcess(_ process: RawProcessInfo) -> Bool {
        let name = process.name.lowercased()
        let command = process.command.lowercased()

        // Match Claude CLI processes
        if name == "claude" {
            return true
        }

        // Match Node.js SDK wrapper processes
        if name == "node" && command.contains("sdk-wrapper") {
            return true
        }

        // Match Python SDK wrapper processes
        if name == "python3" && command.contains("sdk-wrapper") {
            return true
        }

        // Match Swift compiler processes (spawned during builds)
        if name == "swift-frontend" || name == "swiftc" || name == "swift" {
            return true
        }

        // Match other build tools that might be spawned
        if name == "xcrun" || name == "xcodebuild" {
            return true
        }

        return false
    }

    /// Enrich a raw process with session association and full monitoring info.
    /// - Parameter process: The raw process info
    /// - Returns: Full ProcessMonitorInfo with session ID and enhanced metrics
    private func enrichWithSessionInfo(_ process: RawProcessInfo) -> ProcessMonitorInfo {
        // Try to associate with a session by matching working directory
        let sessionId = findSessionForProcess(process)

        // Calculate uptime
        let uptime = Date().timeIntervalSince(process.startTime)

        // TODO: Disk I/O and network activity require additional system calls
        // For now, return zero values (will be implemented in subtask-2-3)
        let diskIO = ProcessMonitorInfo.DiskIOInfo(bytesRead: 0, bytesWritten: 0)
        let networkActivity = ProcessMonitorInfo.NetworkActivityInfo(
            bytesIn: 0,
            bytesOut: 0,
            connections: 0
        )

        return ProcessMonitorInfo(
            pid: process.pid,
            name: process.name,
            cpuPercent: process.cpuPercent,
            memoryMB: process.memoryMB,
            diskIO: diskIO,
            networkActivity: networkActivity,
            uptime: uptime,
            sessionId: sessionId,
            command: process.command
        )
    }

    /// Find the session ID for a process by matching its working directory.
    /// - Parameter process: The raw process info
    /// - Returns: Session ID if found, nil otherwise
    private func findSessionForProcess(_ process: RawProcessInfo) -> String? {
        // Extract working directory from command line arguments
        // Common patterns:
        // - claude -p "prompt" /path/to/working/dir
        // - node scripts/sdk-wrapper.py (current dir is working dir)
        // - swift-frontend ... (parent process working dir)

        // For now, try to match any registered working directory that appears in the command
        for (sessionId, workingDir) in sessionWorkingDirs {
            if process.command.contains(workingDir) {
                return sessionId
            }
        }

        return nil
    }
}
