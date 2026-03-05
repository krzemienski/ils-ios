import Foundation
import ILSShared
import Logging

/// Actor for managing resource limits and checking threshold violations per Claude Code session.
///
/// Maintains in-memory storage of CPU and memory limits for each session. Provides
/// methods to configure limits, retrieve current settings, and check if processes
/// exceed configured thresholds.
///
/// ## Thread Safety
///
/// Implemented as an actor to ensure thread-safe access to the limits dictionary
/// from multiple concurrent requests. All state mutations are serialized through
/// the actor's executor.
///
/// ## Storage
///
/// Currently stores limits in memory only. Future enhancement: persist to database
/// or configuration file for durability across backend restarts.
///
/// ## Usage
///
/// ```swift
/// let service = ResourceLimitService()
///
/// // Set limits for a session
/// await service.setLimits(
///     sessionId: "abc123",
///     maxCpuPercent: 80.0,
///     maxMemoryMB: 2048.0,
///     autoKillEnabled: true,
///     autoKillThresholdMinutes: 5
/// )
///
/// // Check if a process exceeds limits
/// let process = ProcessMonitorInfo(...)
/// if let violation = await service.checkViolation(process: process) {
///     print("Process \(violation.processId) exceeded \(violation.violationType) limit")
/// }
/// ```
actor ResourceLimitService {
    /// Structured logger for resource limit operations
    private static let logger = Logger(label: "ils.resource-limits")

    /// In-memory storage of resource limits per session.
    /// Key: sessionId, Value: ResourceLimitsResponse
    private var limits: [String: ResourceLimitsResponse] = [:]

    /// Cache tracking when violations started for duration calculation.
    /// Key: "\(processId)-\(violationType)", Value: Date when violation first detected
    private var violationStartTimes: [String: Date] = [:]

    /// Default limits applied when no session-specific limits are configured.
    private let defaultLimits = ResourceLimitsResponse(
        sessionId: "default",
        maxCpuPercent: nil,
        maxMemoryMB: nil,
        autoKillEnabled: false,
        autoKillThresholdMinutes: 5
    )

    // MARK: - Public API

    /// Set or update resource limits for a specific session.
    ///
    /// If limits already exist for the session, they will be replaced with the new values.
    /// Nil values for maxCpuPercent or maxMemoryMB indicate no limit for that resource.
    ///
    /// - Parameters:
    ///   - sessionId: The session ID to configure limits for
    ///   - maxCpuPercent: Maximum CPU percentage allowed (0-100). Nil means no limit.
    ///   - maxMemoryMB: Maximum memory in megabytes allowed. Nil means no limit.
    ///   - autoKillEnabled: Whether to automatically kill processes exceeding limits
    ///   - autoKillThresholdMinutes: Duration in minutes before auto-kill triggers
    /// - Returns: The updated ResourceLimitsResponse for the session
    func setLimits(
        sessionId: String,
        maxCpuPercent: Double?,
        maxMemoryMB: Double?,
        autoKillEnabled: Bool,
        autoKillThresholdMinutes: Int
    ) -> ResourceLimitsResponse {
        let limitsResponse = ResourceLimitsResponse(
            sessionId: sessionId,
            maxCpuPercent: maxCpuPercent,
            maxMemoryMB: maxMemoryMB,
            autoKillEnabled: autoKillEnabled,
            autoKillThresholdMinutes: autoKillThresholdMinutes
        )

        limits[sessionId] = limitsResponse

        Self.logger.info("Set resource limits for session \(sessionId): CPU=\(maxCpuPercent?.description ?? "unlimited"), Memory=\(maxMemoryMB?.description ?? "unlimited")MB, AutoKill=\(autoKillEnabled)")

        return limitsResponse
    }

    /// Update resource limits for a session using a request object.
    ///
    /// Only updates fields that are non-nil in the request. Existing values are
    /// preserved for fields not specified in the request.
    ///
    /// - Parameters:
    ///   - sessionId: The session ID to update limits for
    ///   - request: Request object with limit updates (nil fields are ignored)
    /// - Returns: The updated ResourceLimitsResponse for the session
    func updateLimits(sessionId: String, request: UpdateResourceLimitsRequest) -> ResourceLimitsResponse {
        // Get existing limits or use defaults
        let existing = limits[sessionId] ?? ResourceLimitsResponse(
            sessionId: sessionId,
            maxCpuPercent: nil,
            maxMemoryMB: nil,
            autoKillEnabled: false,
            autoKillThresholdMinutes: 5
        )

        // Apply updates (only update non-nil fields from request)
        let updated = ResourceLimitsResponse(
            sessionId: sessionId,
            maxCpuPercent: request.maxCpuPercent ?? existing.maxCpuPercent,
            maxMemoryMB: request.maxMemoryMB ?? existing.maxMemoryMB,
            autoKillEnabled: request.autoKillEnabled ?? existing.autoKillEnabled,
            autoKillThresholdMinutes: request.autoKillThresholdMinutes ?? existing.autoKillThresholdMinutes
        )

        limits[sessionId] = updated

        Self.logger.info("Updated resource limits for session \(sessionId)")

        return updated
    }

    /// Get resource limits for a specific session.
    ///
    /// Returns the configured limits for the session, or nil if no limits have been set.
    ///
    /// - Parameter sessionId: The session ID to retrieve limits for
    /// - Returns: ResourceLimitsResponse if limits are configured, nil otherwise
    func getLimits(sessionId: String) -> ResourceLimitsResponse? {
        return limits[sessionId]
    }

    /// Get resource limits for all sessions.
    ///
    /// Returns a dictionary mapping session IDs to their configured limits.
    /// Empty dictionary if no limits have been configured.
    ///
    /// - Returns: Dictionary of sessionId -> ResourceLimitsResponse
    func getAllLimits() -> [String: ResourceLimitsResponse] {
        return limits
    }

    /// Remove resource limits for a specific session.
    ///
    /// After removal, the session will have no resource limits applied.
    ///
    /// - Parameter sessionId: The session ID to remove limits for
    func removeLimits(sessionId: String) {
        limits.removeValue(forKey: sessionId)
        Self.logger.info("Removed resource limits for session \(sessionId)")
    }

    // MARK: - Violation Checking

    /// Check if a process exceeds its session's configured resource limits.
    ///
    /// Compares the process's current CPU and memory usage against the limits
    /// configured for its associated session. Returns a ResourceViolationAlert
    /// if any limit is exceeded, or nil if the process is within limits or has
    /// no session association.
    ///
    /// Tracks violation duration by recording when violations first occur and
    /// calculating elapsed time for ongoing violations. Clears violation tracking
    /// when processes return to within limits.
    ///
    /// - Parameter process: The process to check for violations
    /// - Returns: ResourceViolationAlert if limits are exceeded, nil otherwise
    func checkViolation(process: ProcessMonitorInfo) -> ResourceViolationAlert? {
        // Can't check violations without a session ID
        guard let sessionId = process.sessionId else {
            return nil
        }

        // Get limits for this session
        guard let sessionLimits = limits[sessionId] else {
            return nil
        }

        let now = Date()
        var violationDetected = false
        var alert: ResourceViolationAlert?

        // Check CPU limit
        if let maxCpu = sessionLimits.maxCpuPercent,
           process.cpuPercent > maxCpu {
            violationDetected = true
            let violationKey = "\(process.pid)-cpu"
            let duration = calculateViolationDuration(key: violationKey, now: now)

            alert = ResourceViolationAlert(
                processId: process.pid,
                processName: process.name,
                sessionId: sessionId,
                violationType: .cpu,
                currentValue: process.cpuPercent,
                limitValue: maxCpu,
                durationMinutes: duration,
                timestamp: now
            )

            Self.logger.debug("CPU violation detected for process \(process.pid): \(process.cpuPercent)% > \(maxCpu)% (duration: \(duration) min)")

            // Check if auto-kill should trigger
            if sessionLimits.autoKillEnabled && duration >= sessionLimits.autoKillThresholdMinutes {
                killProcess(
                    pid: process.pid,
                    processName: process.name,
                    sessionId: sessionId,
                    violationType: .cpu
                )
            }
        }
        // Check memory limit (only if CPU wasn't violated - CPU takes precedence)
        else if let maxMemory = sessionLimits.maxMemoryMB,
                process.memoryMB > maxMemory {
            violationDetected = true
            let violationKey = "\(process.pid)-memory"
            let duration = calculateViolationDuration(key: violationKey, now: now)

            alert = ResourceViolationAlert(
                processId: process.pid,
                processName: process.name,
                sessionId: sessionId,
                violationType: .memory,
                currentValue: process.memoryMB,
                limitValue: maxMemory,
                durationMinutes: duration,
                timestamp: now
            )

            Self.logger.debug("Memory violation detected for process \(process.pid): \(process.memoryMB)MB > \(maxMemory)MB (duration: \(duration) min)")

            // Check if auto-kill should trigger
            if sessionLimits.autoKillEnabled && duration >= sessionLimits.autoKillThresholdMinutes {
                killProcess(
                    pid: process.pid,
                    processName: process.name,
                    sessionId: sessionId,
                    violationType: .memory
                )
            }
        }

        // Clear violation tracking if no longer violating
        if !violationDetected {
            clearViolationTracking(processId: process.pid)
        }

        return alert
    }

    /// Check multiple processes for resource limit violations.
    ///
    /// Convenience method that checks a list of processes and returns only those
    /// that exceed their configured limits.
    ///
    /// - Parameter processes: Array of processes to check
    /// - Returns: Array of ResourceViolationAlert for processes exceeding limits
    func checkViolations(processes: [ProcessMonitorInfo]) -> [ResourceViolationAlert] {
        var violations: [ResourceViolationAlert] = []

        for process in processes {
            if let violation = checkViolation(process: process) {
                violations.append(violation)
            }
        }

        return violations
    }

    // MARK: - Duration Tracking Helpers

    /// Calculate violation duration in minutes, tracking start time if new violation.
    ///
    /// If this is a new violation, records the start time and returns 0.
    /// For ongoing violations, calculates elapsed time since first detection.
    ///
    /// - Parameters:
    ///   - key: Violation key in format "\(processId)-\(violationType)"
    ///   - now: Current timestamp
    /// - Returns: Duration in minutes (rounded down)
    private func calculateViolationDuration(key: String, now: Date) -> Int {
        if let startTime = violationStartTimes[key] {
            // Existing violation - calculate duration
            let elapsed = now.timeIntervalSince(startTime)
            return Int(elapsed / 60.0) // Convert to minutes
        } else {
            // New violation - record start time
            violationStartTimes[key] = now
            Self.logger.debug("Started tracking violation: \(key)")
            return 0
        }
    }

    /// Clear violation tracking for a specific process.
    ///
    /// Removes both CPU and memory violation tracking entries for the given process.
    /// Called when a process returns to within limits.
    ///
    /// - Parameter processId: The process ID to clear tracking for
    private func clearViolationTracking(processId: Int) {
        let cpuKey = "\(processId)-cpu"
        let memoryKey = "\(processId)-memory"

        let hadCpuViolation = violationStartTimes.removeValue(forKey: cpuKey) != nil
        let hadMemoryViolation = violationStartTimes.removeValue(forKey: memoryKey) != nil

        if hadCpuViolation || hadMemoryViolation {
            Self.logger.debug("Cleared violation tracking for process \(processId)")
        }
    }

    /// Remove violation tracking for a specific process.
    ///
    /// Public API to clear violation tracking, useful when a process terminates
    /// or a session ends.
    ///
    /// - Parameter processId: The process ID to remove from tracking
    func removeViolationTracking(processId: Int) {
        clearViolationTracking(processId: processId)
    }

    /// Clean up stale violation tracking entries.
    ///
    /// Removes violation tracking entries older than the specified age.
    /// Should be called periodically to prevent unbounded growth of the tracking cache.
    ///
    /// - Parameter maxAgeMinutes: Maximum age in minutes before entries are considered stale (default: 60)
    /// - Returns: Number of stale entries removed
    func cleanupStaleViolations(maxAgeMinutes: Int = 60) -> Int {
        let now = Date()
        let maxAge = TimeInterval(maxAgeMinutes * 60)
        var removedCount = 0

        for (key, startTime) in violationStartTimes {
            if now.timeIntervalSince(startTime) > maxAge {
                violationStartTimes.removeValue(forKey: key)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            Self.logger.info("Cleaned up \(removedCount) stale violation tracking entries")
        }

        return removedCount
    }

    // MARK: - Auto-Kill Functionality

    /// Kill a process that has exceeded resource limits beyond the threshold duration.
    ///
    /// Uses SIGTERM for graceful termination. Runs on a background queue to avoid
    /// blocking the actor. Logs success/failure for audit trail.
    ///
    /// - Parameters:
    ///   - pid: The process ID to kill
    ///   - processName: The process name (for logging)
    ///   - sessionId: The session ID (for logging)
    ///   - violationType: The type of violation that triggered the kill
    private func killProcess(pid: Int, processName: String, sessionId: String, violationType: ResourceViolationAlert.ViolationType) {
        // Dispatch to background queue to avoid blocking the actor
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/kill")
            // Use SIGTERM for graceful termination
            process.arguments = ["-TERM", "\(pid)"]

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
                    Self.logger.warning("Auto-killed process \(pid) (\(processName)) for session \(sessionId) due to \(violationType) violation exceeding threshold")
                } else {
                    let errorData = try? errorPipe.fileHandleForReading.readToEnd()
                    let errorMsg = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown error"
                    Self.logger.error("Failed to auto-kill process \(pid): \(errorMsg)")
                }
            } catch {
                Self.logger.error("Error auto-killing process \(pid): \(error)")
            }
        }
    }
}
