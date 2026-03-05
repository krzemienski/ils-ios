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
    /// Note: This method only checks current values. Duration tracking for
    /// auto-kill functionality is handled separately by the alert generation
    /// system in subtask 3-2.
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

        // Check CPU limit
        if let maxCpu = sessionLimits.maxCpuPercent,
           process.cpuPercent > maxCpu {
            return ResourceViolationAlert(
                processId: process.pid,
                processName: process.name,
                sessionId: sessionId,
                violationType: .cpu,
                currentValue: process.cpuPercent,
                limitValue: maxCpu,
                durationMinutes: 0, // Duration tracking added in subtask 3-2
                timestamp: Date()
            )
        }

        // Check memory limit
        if let maxMemory = sessionLimits.maxMemoryMB,
           process.memoryMB > maxMemory {
            return ResourceViolationAlert(
                processId: process.pid,
                processName: process.name,
                sessionId: sessionId,
                violationType: .memory,
                currentValue: process.memoryMB,
                limitValue: maxMemory,
                durationMinutes: 0, // Duration tracking added in subtask 3-2
                timestamp: Date()
            )
        }

        // No violations
        return nil
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
}
