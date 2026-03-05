import Foundation

// MARK: - Process Monitor Info

/// Enhanced process information including resource usage, disk I/O, network activity, and session association.
///
/// Used by the process monitoring API to provide detailed metrics about Claude Code processes
/// and other related system processes. Extends basic process info with uptime tracking,
/// I/O statistics, and session context for multi-agent environments.
public struct ProcessMonitorInfo: Codable, Sendable, Identifiable {
    /// Process identifier (PID) on the host system.
    public let pid: Int
    /// Human-readable process name (e.g., `"claude"`, `"node"`, `"swift-frontend"`).
    public let name: String
    /// CPU utilization as a percentage (0–100, may exceed 100 on multi-core hosts).
    public let cpuPercent: Double
    /// Resident memory consumed by the process, in megabytes.
    public let memoryMB: Double
    /// Disk I/O statistics for this process.
    public let diskIO: DiskIOInfo
    /// Network activity statistics for this process.
    public let networkActivity: NetworkActivityInfo
    /// Process uptime in seconds since start.
    public let uptime: TimeInterval
    /// Associated Claude Code session ID, if applicable.
    public let sessionId: String?
    /// Full command-line string that launched the process, if available.
    public let command: String?

    /// Stable identifier — the process PID.
    public var id: Int { pid }

    /// Creates a new ``ProcessMonitorInfo``.
    /// - Parameters:
    ///   - pid: The system process identifier.
    ///   - name: Human-readable process name.
    ///   - cpuPercent: CPU utilization percentage.
    ///   - memoryMB: Resident memory usage in megabytes.
    ///   - diskIO: Disk I/O statistics.
    ///   - networkActivity: Network activity statistics.
    ///   - uptime: Process uptime in seconds.
    ///   - sessionId: Optional associated session ID.
    ///   - command: Full command-line string, if available.
    public init(
        pid: Int,
        name: String,
        cpuPercent: Double,
        memoryMB: Double,
        diskIO: DiskIOInfo,
        networkActivity: NetworkActivityInfo,
        uptime: TimeInterval,
        sessionId: String? = nil,
        command: String? = nil
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.diskIO = diskIO
        self.networkActivity = networkActivity
        self.uptime = uptime
        self.sessionId = sessionId
        self.command = command
    }

    /// Disk I/O statistics for a process.
    public struct DiskIOInfo: Codable, Sendable {
        /// Total bytes read from disk.
        public let bytesRead: UInt64
        /// Total bytes written to disk.
        public let bytesWritten: UInt64

        public init(bytesRead: UInt64, bytesWritten: UInt64) {
            self.bytesRead = bytesRead
            self.bytesWritten = bytesWritten
        }
    }

    /// Network activity statistics for a process.
    public struct NetworkActivityInfo: Codable, Sendable {
        /// Total bytes received.
        public let bytesIn: UInt64
        /// Total bytes sent.
        public let bytesOut: UInt64
        /// Number of active network connections.
        public let connections: Int

        public init(bytesIn: UInt64, bytesOut: UInt64, connections: Int) {
            self.bytesIn = bytesIn
            self.bytesOut = bytesOut
            self.connections = connections
        }
    }
}

// MARK: - Resource Limits

/// Resource limits configuration for a Claude Code session.
///
/// Defines CPU and memory thresholds for processes associated with a session.
/// When processes exceed these limits, alerts can be generated and auto-kill
/// policies can be enforced.
public struct ResourceLimitsResponse: Codable, Sendable {
    /// The session ID these limits apply to.
    public let sessionId: String
    /// Maximum CPU percentage allowed (0-100). Nil means no limit.
    public let maxCpuPercent: Double?
    /// Maximum memory in megabytes allowed. Nil means no limit.
    public let maxMemoryMB: Double?
    /// Whether auto-kill is enabled for processes exceeding limits.
    public let autoKillEnabled: Bool
    /// Duration in minutes a process can exceed limits before auto-kill.
    public let autoKillThresholdMinutes: Int

    /// Creates a new ``ResourceLimitsResponse``.
    /// - Parameters:
    ///   - sessionId: The session ID these limits apply to.
    ///   - maxCpuPercent: Maximum CPU percentage allowed.
    ///   - maxMemoryMB: Maximum memory in megabytes allowed.
    ///   - autoKillEnabled: Whether auto-kill is enabled.
    ///   - autoKillThresholdMinutes: Duration before auto-kill triggers.
    public init(
        sessionId: String,
        maxCpuPercent: Double? = nil,
        maxMemoryMB: Double? = nil,
        autoKillEnabled: Bool = false,
        autoKillThresholdMinutes: Int = 5
    ) {
        self.sessionId = sessionId
        self.maxCpuPercent = maxCpuPercent
        self.maxMemoryMB = maxMemoryMB
        self.autoKillEnabled = autoKillEnabled
        self.autoKillThresholdMinutes = autoKillThresholdMinutes
    }
}

/// Request body for updating resource limits.
public struct UpdateResourceLimitsRequest: Codable, Sendable {
    /// Maximum CPU percentage allowed (0-100). Nil means no limit.
    public let maxCpuPercent: Double?
    /// Maximum memory in megabytes allowed. Nil means no limit.
    public let maxMemoryMB: Double?
    /// Whether auto-kill is enabled for processes exceeding limits.
    public let autoKillEnabled: Bool?
    /// Duration in minutes a process can exceed limits before auto-kill.
    public let autoKillThresholdMinutes: Int?

    public init(
        maxCpuPercent: Double? = nil,
        maxMemoryMB: Double? = nil,
        autoKillEnabled: Bool? = nil,
        autoKillThresholdMinutes: Int? = nil
    ) {
        self.maxCpuPercent = maxCpuPercent
        self.maxMemoryMB = maxMemoryMB
        self.autoKillEnabled = autoKillEnabled
        self.autoKillThresholdMinutes = autoKillThresholdMinutes
    }
}

// MARK: - Resource Violation Alerts

/// Alert generated when a process exceeds configured resource limits.
///
/// Provides details about the violation including which threshold was exceeded,
/// current and limit values, and duration of the violation.
public struct ResourceViolationAlert: Codable, Sendable, Identifiable {
    /// Process ID of the violating process.
    public let processId: Int
    /// Name of the violating process.
    public let processName: String
    /// Associated session ID, if applicable.
    public let sessionId: String?
    /// Type of resource violation.
    public let violationType: ViolationType
    /// Current resource value at time of alert.
    public let currentValue: Double
    /// Configured limit value that was exceeded.
    public let limitValue: Double
    /// Duration in minutes the process has been in violation.
    public let durationMinutes: Int
    /// Timestamp when the alert was generated.
    public let timestamp: Date

    /// Stable identifier combining process ID and violation type.
    public var id: String { "\(processId)-\(violationType.rawValue)" }

    /// Types of resource violations that can trigger alerts.
    public enum ViolationType: String, Codable, Sendable {
        /// CPU usage exceeded the configured limit.
        case cpu
        /// Memory usage exceeded the configured limit.
        case memory

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized ViolationType: '\(raw)'. Expected: cpu, memory"
                    )
                )
            }
            self = value
        }
    }

    /// Creates a new ``ResourceViolationAlert``.
    /// - Parameters:
    ///   - processId: Process ID of the violating process.
    ///   - processName: Name of the violating process.
    ///   - sessionId: Associated session ID, if applicable.
    ///   - violationType: Type of resource violation.
    ///   - currentValue: Current resource value.
    ///   - limitValue: Configured limit that was exceeded.
    ///   - durationMinutes: Duration in minutes of the violation.
    ///   - timestamp: Timestamp when the alert was generated.
    public init(
        processId: Int,
        processName: String,
        sessionId: String? = nil,
        violationType: ViolationType,
        currentValue: Double,
        limitValue: Double,
        durationMinutes: Int,
        timestamp: Date = Date()
    ) {
        self.processId = processId
        self.processName = processName
        self.sessionId = sessionId
        self.violationType = violationType
        self.currentValue = currentValue
        self.limitValue = limitValue
        self.durationMinutes = durationMinutes
        self.timestamp = timestamp
    }
}

// MARK: - Process History

/// Historical record of a process lifecycle including start, stop, duration, and peak resource usage.
///
/// Used to track process history for audit and analysis purposes. Records when processes
/// started and stopped, their duration, and peak resource consumption during their lifetime.
public struct ProcessHistoryResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for this history record.
    public let id: UUID
    /// Process identifier (PID) on the host system.
    public let pid: Int
    /// Human-readable process name.
    public let name: String
    /// Associated Claude Code session ID, if applicable.
    public let sessionId: String?
    /// Timestamp when the process started.
    public let startTime: Date
    /// Timestamp when the process ended. Nil if still running.
    public let endTime: Date?
    /// Process duration in seconds. Nil if still running.
    public let duration: TimeInterval?
    /// Peak CPU utilization percentage during process lifetime.
    public let peakCpuPercent: Double
    /// Peak memory consumption in megabytes during process lifetime.
    public let peakMemoryMB: Double
    /// Full command-line string that launched the process, if available.
    public let command: String?

    /// Creates a new ``ProcessHistoryResponse``.
    /// - Parameters:
    ///   - id: Unique identifier for this history record.
    ///   - pid: Process identifier.
    ///   - name: Process name.
    ///   - sessionId: Associated session ID, if applicable.
    ///   - startTime: When the process started.
    ///   - endTime: When the process ended (nil if still running).
    ///   - duration: Process duration in seconds (nil if still running).
    ///   - peakCpuPercent: Peak CPU percentage during lifetime.
    ///   - peakMemoryMB: Peak memory in megabytes during lifetime.
    ///   - command: Full command-line string, if available.
    public init(
        id: UUID = UUID(),
        pid: Int,
        name: String,
        sessionId: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        peakCpuPercent: Double,
        peakMemoryMB: Double,
        command: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.name = name
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.peakCpuPercent = peakCpuPercent
        self.peakMemoryMB = peakMemoryMB
        self.command = command
    }
}

// MARK: - Process Kill Request

/// Request body for killing a process.
public struct KillProcessRequest: Codable, Sendable {
    /// Whether to force kill (SIGKILL) instead of graceful termination (SIGTERM).
    public let force: Bool
    /// Confirmation flag to prevent accidental kills.
    public let confirmed: Bool

    public init(force: Bool = false, confirmed: Bool = true) {
        self.force = force
        self.confirmed = confirmed
    }
}
