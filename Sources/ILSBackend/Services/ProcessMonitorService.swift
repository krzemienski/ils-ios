import Foundation
import ILSShared
import Logging
import Fluent
import Vapor
#if canImport(Darwin)
import Darwin
#endif

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

    /// Active processes being tracked for lifecycle history (pid -> ProcessHistory UUID).
    /// Used to detect when processes start and stop.
    private var activeProcesses: [Int: UUID] = [:]

    /// Peak resource usage for active processes (pid -> (peakCPU, peakMemory)).
    /// Updated each time we scan processes to track maximum resource consumption.
    private var peakResources: [Int: (cpu: Double, memory: Double)] = [:]

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

        // Enrich processes in parallel for better performance
        return await withTaskGroup(of: ProcessMonitorInfo.self) { group in
            for process in claudeProcesses {
                group.addTask {
                    await self.enrichWithSessionInfo(process)
                }
            }

            var results: [ProcessMonitorInfo] = []
            for await enriched in group {
                results.append(enriched)
            }
            return results
        }
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
        return await enrichWithSessionInfo(process)
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

    /// Update process lifecycle tracking by detecting new and terminated processes.
    ///
    /// Scans current Claude Code processes and:
    /// - Creates ProcessHistory records for newly detected processes
    /// - Updates peak resource usage for active processes
    /// - Finalizes ProcessHistory records for terminated processes with duration and peak resources
    ///
    /// This method should be called periodically (e.g., from a scheduled task or API endpoint)
    /// to maintain accurate process history.
    ///
    /// - Parameter db: Database connection for persisting process history
    func updateProcessLifecycle(db: Database) async throws {
        let currentProcesses = await getClaudeProcesses()
        let currentPIDs = Set(currentProcesses.map { $0.pid })
        let activePIDs = Set(activeProcesses.keys)

        // 1. Detect new processes and create history records
        let newPIDs = currentPIDs.subtracting(activePIDs)
        for pid in newPIDs {
            guard let process = currentProcesses.first(where: { $0.pid == pid }) else { continue }

            let history = ProcessHistory(
                pid: process.pid,
                name: process.name,
                sessionId: process.sessionId,
                peakCpuPercent: process.cpuPercent,
                peakMemoryMB: process.memoryMB,
                command: process.command
            )

            try await history.save(on: db)

            if let historyId = history.id {
                activeProcesses[pid] = historyId
                peakResources[pid] = (cpu: process.cpuPercent, memory: process.memoryMB)
                Self.logger.info("Started tracking process \(pid) (\(process.name)) - session: \(process.sessionId ?? "none")")
            }
        }

        // 2. Update peak resources for active processes
        for process in currentProcesses {
            guard activeProcesses[process.pid] != nil else { continue }

            if let existing = peakResources[process.pid] {
                let newPeakCpu = max(existing.cpu, process.cpuPercent)
                let newPeakMem = max(existing.memory, process.memoryMB)
                peakResources[process.pid] = (cpu: newPeakCpu, memory: newPeakMem)
            } else {
                peakResources[process.pid] = (cpu: process.cpuPercent, memory: process.memoryMB)
            }
        }

        // 3. Detect terminated processes and finalize history records
        let terminatedPIDs = activePIDs.subtracting(currentPIDs)
        for pid in terminatedPIDs {
            guard let historyId = activeProcesses[pid] else { continue }

            // Load the history record
            if let history = try await ProcessHistory.find(historyId, on: db) {
                let endTime = Date()
                let duration = history.startTime.map { endTime.timeIntervalSince($0) }

                // Update with end time, duration, and peak resources
                history.endTime = endTime
                history.duration = duration

                if let peaks = peakResources[pid] {
                    history.peakCpuPercent = peaks.cpu
                    history.peakMemoryMB = peaks.memory
                }

                try await history.save(on: db)

                Self.logger.info("Process \(pid) (\(history.name)) terminated - duration: \(duration.map { String(format: "%.1fs", $0) } ?? "unknown"), peak CPU: \(history.peakCpuPercent)%, peak memory: \(String(format: "%.1f", history.peakMemoryMB))MB")
            }

            // Clean up tracking state
            activeProcesses.removeValue(forKey: pid)
            peakResources.removeValue(forKey: pid)
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
    /// Handles three common formats on macOS:
    /// - "12:34PM" or "1:23AM" - Process started today at the given time
    /// - "Mon12" or "Tue03" - Process started on the given weekday and day of month
    /// - "Jan01" or "Dec25" - Process started on the given month and day
    ///
    /// - Parameters:
    ///   - startedStr: The STARTED column value from ps output
    ///   - currentYear: The current year for date calculations
    /// - Returns: Estimated start time as a Date
    private static func parseStartTime(_ startedStr: String, currentYear: Int) -> Date {
        let now = Date()
        let calendar = Calendar.current

        // Format 1: Time today (e.g., "12:34PM", "1:23AM")
        // Contains "AM" or "PM"
        if startedStr.hasSuffix("AM") || startedStr.hasSuffix("PM") {
            let timeStr = String(startedStr.dropLast(2)) // Remove AM/PM
            let isPM = startedStr.hasSuffix("PM")

            let components = timeStr.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                return now.addingTimeInterval(-3600) // Fallback: 1 hour ago
            }

            // Convert to 24-hour format
            var hour24 = hour
            if isPM && hour != 12 {
                hour24 = hour + 12
            } else if !isPM && hour == 12 {
                hour24 = 0
            }

            // Create date for today with the given time
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            dateComponents.hour = hour24
            dateComponents.minute = minute
            dateComponents.second = 0

            if let startTime = calendar.date(from: dateComponents) {
                // If the time is in the future, it must have been yesterday
                if startTime > now {
                    return calendar.date(byAdding: .day, value: -1, to: startTime) ?? startTime
                }
                return startTime
            }
        }

        // Format 2: Weekday + day of month (e.g., "Mon12", "Tue03")
        // First 3 characters are weekday abbreviation
        let weekdayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if startedStr.count >= 4 {
            let weekdayPart = String(startedStr.prefix(3))
            if weekdayAbbreviations.contains(weekdayPart) {
                let dayPart = String(startedStr.dropFirst(3))
                guard let day = Int(dayPart) else {
                    return now.addingTimeInterval(-3600) // Fallback
                }

                // Find the most recent occurrence of this weekday + day
                // Try current month first, then previous month
                for monthOffset in 0...1 {
                    var searchComponents = calendar.dateComponents([.year, .month], from: now)
                    searchComponents.month = (searchComponents.month ?? 1) - monthOffset
                    searchComponents.day = day
                    searchComponents.hour = 0
                    searchComponents.minute = 0
                    searchComponents.second = 0

                    if let candidateDate = calendar.date(from: searchComponents),
                       candidateDate <= now {
                        return candidateDate
                    }
                }
            }
        }

        // Format 3: Month + day (e.g., "Jan01", "Dec25")
        let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if startedStr.count >= 4 {
            let monthPart = String(startedStr.prefix(3))
            if let monthIndex = monthAbbreviations.firstIndex(of: monthPart) {
                let dayPart = String(startedStr.dropFirst(3))
                guard let day = Int(dayPart) else {
                    return now.addingTimeInterval(-3600) // Fallback
                }

                let month = monthIndex + 1 // Convert to 1-based month

                // Try current year first, then previous year
                for yearOffset in 0...1 {
                    var dateComponents = DateComponents()
                    dateComponents.year = currentYear - yearOffset
                    dateComponents.month = month
                    dateComponents.day = day
                    dateComponents.hour = 0
                    dateComponents.minute = 0
                    dateComponents.second = 0

                    if let candidateDate = calendar.date(from: dateComponents),
                       candidateDate <= now {
                        return candidateDate
                    }
                }
            }
        }

        // Fallback: Unable to parse, assume started 1 hour ago
        return now.addingTimeInterval(-3600)
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

    /// Get disk I/O statistics for a process (macOS-specific).
    ///
    /// Uses `proc_pid_rusage()` from Darwin's libproc to get cumulative I/O statistics.
    /// Returns zero values on non-macOS platforms or if the syscall fails.
    ///
    /// - Parameter pid: The process ID
    /// - Returns: DiskIOInfo with bytes read and written
    private func getDiskIOStats(pid: Int) -> ProcessMonitorInfo.DiskIOInfo {
        #if os(macOS) || os(iOS)
        // Use rusage_info_current from libproc to get I/O stats
        var rusage = rusage_info_v4()
        var rusagePtr: rusage_info_t? = withUnsafeMutableBytes(of: &rusage) { $0.baseAddress }
        let result = withUnsafeMutablePointer(to: &rusagePtr) { ptr in
            proc_pid_rusage(Int32(pid), RUSAGE_INFO_V4, ptr)
        }

        if result == 0 {
            // rusage_info_v4 provides:
            // - ri_diskio_bytesread: bytes read from disk
            // - ri_diskio_byteswritten: bytes written to disk
            return ProcessMonitorInfo.DiskIOInfo(
                bytesRead: rusage.ri_diskio_bytesread,
                bytesWritten: rusage.ri_diskio_byteswritten
            )
        } else {
            // Failed to get rusage, return zeros
            return ProcessMonitorInfo.DiskIOInfo(bytesRead: 0, bytesWritten: 0)
        }
        #else
        // Non-macOS platform, return zeros
        return ProcessMonitorInfo.DiskIOInfo(bytesRead: 0, bytesWritten: 0)
        #endif
    }

    /// Get network activity statistics for a process (macOS-specific).
    ///
    /// Uses `lsof -p <pid> -a -i` to enumerate open network connections.
    /// Counts active connections and attempts to parse socket statistics.
    /// Returns zero values on non-macOS platforms or if lsof fails.
    ///
    /// Note: Getting per-process network bytes in/out requires reading /proc/net
    /// (Linux) or using dtrace/netstat aggregation (macOS). For simplicity, this
    /// implementation only counts connections. Bytes in/out are returned as zero.
    ///
    /// - Parameter pid: The process ID
    /// - Returns: NetworkActivityInfo with connection count (bytes always zero for now)
    private func getNetworkStats(pid: Int) async -> ProcessMonitorInfo.NetworkActivityInfo {
        #if os(macOS) || os(iOS)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hasResumed = false

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                // -p <pid>: filter by PID
                // -a: AND the selectors
                // -i: filter for internet connections only
                // -n: no hostname resolution (faster)
                // -P: no port name resolution (faster)
                process.arguments = ["-p", "\(pid)", "-a", "-i", "-n", "-P"]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                // 2-second timeout for lsof
                let timeoutItem = DispatchWorkItem {
                    process.terminate()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: ProcessMonitorInfo.NetworkActivityInfo(
                            bytesIn: 0,
                            bytesOut: 0,
                            connections: 0
                        ))
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: timeoutItem)

                do {
                    try process.run()

                    // Read stdout before waitUntilExit to prevent deadlock
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    _ = errPipe.fileHandleForReading.readDataToEndOfFile()

                    process.waitUntilExit()
                    timeoutItem.cancel()

                    guard !hasResumed else { return }
                    hasResumed = true

                    guard let output = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: ProcessMonitorInfo.NetworkActivityInfo(
                            bytesIn: 0,
                            bytesOut: 0,
                            connections: 0
                        ))
                        return
                    }

                    // Count lines (excluding header) to get connection count
                    let lines = output.split(separator: "\n")
                    // lsof header is typically 1 line, rest are connections
                    let connectionCount = max(0, lines.count - 1)

                    // Note: Getting actual bytes in/out per process on macOS requires
                    // complex dtrace scripting or netstat aggregation. For now, we
                    // only track connection count. Bytes could be added in a future
                    // enhancement using dtrace or periodic netstat polling.
                    continuation.resume(returning: ProcessMonitorInfo.NetworkActivityInfo(
                        bytesIn: 0,
                        bytesOut: 0,
                        connections: connectionCount
                    ))
                } catch {
                    timeoutItem.cancel()
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: ProcessMonitorInfo.NetworkActivityInfo(
                        bytesIn: 0,
                        bytesOut: 0,
                        connections: 0
                    ))
                }
            }
        }
        #else
        // Non-macOS platform, return zeros
        return ProcessMonitorInfo.NetworkActivityInfo(bytesIn: 0, bytesOut: 0, connections: 0)
        #endif
    }

    /// Enrich a raw process with session association and full monitoring info.
    /// - Parameter process: The raw process info
    /// - Returns: Full ProcessMonitorInfo with session ID and enhanced metrics
    private func enrichWithSessionInfo(_ process: RawProcessInfo) async -> ProcessMonitorInfo {
        // Try to associate with a session by matching working directory
        let sessionId = findSessionForProcess(process)

        // Calculate uptime
        let uptime = Date().timeIntervalSince(process.startTime)

        // Get disk I/O statistics (macOS-specific using proc_pid_rusage)
        let diskIO = getDiskIOStats(pid: process.pid)

        // Get network activity statistics (macOS-specific using lsof)
        let networkActivity = await getNetworkStats(pid: process.pid)

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
