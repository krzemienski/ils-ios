import Foundation

// MARK: - System Metrics Response

/// System metrics snapshot including CPU, memory, disk, and network statistics.
///
/// Provides a comprehensive view of system resource utilization at a point in time.
/// Used by the system monitoring API (`GET /api/v1/system/metrics`) to expose real-time
/// performance data to ILS clients for dashboard displays and alert thresholds.
///
/// ## API Versioning
/// - **Introduced:** v1.0 (API Version 1.0)
/// - **Last Modified:** v1.0
/// - **Breaking Changes:** None
/// - **Deprecations:** None
/// - **Stability:** Stable - part of the v1 public API contract
///
/// ## Usage Context
/// This DTO serves both iOS and macOS clients through the unified backend API.
/// All measurements are point-in-time snapshots; clients should poll at their
/// desired refresh interval. Load averages follow UNIX conventions (1, 5, 15 minutes).
public struct SystemMetricsResponse: Codable, Sendable {
    /// CPU usage percentage (0-100, may exceed 100 on multi-core systems).
    public let cpu: Double
    /// Memory usage breakdown including used, total, and percentage.
    public let memory: MemoryInfo
    /// Disk usage breakdown including used, total, and percentage.
    public let disk: DiskInfo
    /// Network traffic counters (cumulative since system boot).
    public let network: NetworkInfo
    /// System load averages: [1-minute, 5-minute, 15-minute].
    public let loadAverage: [Double]

    /// Creates a new ``SystemMetricsResponse``.
    /// - Parameters:
    ///   - cpu: CPU usage percentage (0-100).
    ///   - memory: Memory usage details.
    ///   - disk: Disk usage details.
    ///   - network: Network byte counters.
    ///   - loadAverage: System load averages [1min, 5min, 15min].
    public init(
        cpu: Double,
        memory: MemoryInfo,
        disk: DiskInfo,
        network: NetworkInfo,
        loadAverage: [Double]
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.loadAverage = loadAverage
    }

    /// Memory usage breakdown with byte-level precision.
    ///
    /// Reports physical RAM utilization. Excludes swap/virtual memory.
    /// Percentage is calculated as `(used / total) * 100`.
    public struct MemoryInfo: Codable, Sendable {
        /// Used memory in bytes (RSS + caches + buffers).
        public let used: UInt64
        /// Total physical memory in bytes.
        public let total: UInt64
        /// Usage percentage (0-100).
        public let percentage: Double

        /// Creates a new ``MemoryInfo``.
        /// - Parameters:
        ///   - used: Used memory in bytes.
        ///   - total: Total physical memory in bytes.
        ///   - percentage: Usage percentage.
        public init(used: UInt64, total: UInt64, percentage: Double) {
            self.used = used
            self.total = total
            self.percentage = percentage
        }
    }

    /// Disk usage breakdown for the primary volume.
    ///
    /// Reports utilization of the root filesystem where the ILS backend runs.
    /// Does not include external or network volumes.
    public struct DiskInfo: Codable, Sendable {
        /// Used disk space in bytes.
        public let used: UInt64
        /// Total disk space in bytes.
        public let total: UInt64
        /// Usage percentage (0-100).
        public let percentage: Double

        /// Creates a new ``DiskInfo``.
        /// - Parameters:
        ///   - used: Used disk space in bytes.
        ///   - total: Total disk space in bytes.
        ///   - percentage: Usage percentage.
        public init(used: UInt64, total: UInt64, percentage: Double) {
            self.used = used
            self.total = total
            self.percentage = percentage
        }
    }

    /// Network traffic counters (cumulative since boot).
    ///
    /// Tracks total bytes sent and received across all network interfaces.
    /// Counters are cumulative and reset only on system reboot. Clients should
    /// calculate deltas to determine current throughput rates.
    public struct NetworkInfo: Codable, Sendable {
        /// Total bytes received since boot.
        public let bytesIn: UInt64
        /// Total bytes sent since boot.
        public let bytesOut: UInt64

        /// Creates a new ``NetworkInfo``.
        /// - Parameters:
        ///   - bytesIn: Total bytes received.
        ///   - bytesOut: Total bytes sent.
        public init(bytesIn: UInt64, bytesOut: UInt64) {
            self.bytesIn = bytesIn
            self.bytesOut = bytesOut
        }
    }
}

// MARK: - Process Info Response

/// Information about a running system process.
///
/// Provides basic resource utilization metrics for individual processes.
/// Used by the legacy system process listing endpoint (`GET /api/v1/system/processes`).
///
/// ## API Versioning
/// - **Introduced:** v1.0 (API Version 1.0)
/// - **Last Modified:** v1.0
/// - **Deprecation Notice:** Consider using ``ProcessMonitorInfo`` from `ProcessMonitorDTOs.swift`
///   for enhanced functionality including disk I/O, network activity, and session association.
///   This DTO remains stable for backward compatibility but will not receive new features.
///
/// ## Migration Path
/// For new integrations requiring detailed process monitoring, prefer the
/// `/api/v1/process-monitor/*` endpoints with ``ProcessMonitorInfo``.
public struct ProcessInfoResponse: Codable, Sendable {
    /// Process name (executable basename, e.g., `"claude"`, `"node"`).
    public let name: String
    /// Process identifier (PID) on the host system.
    public let pid: Int
    /// CPU usage percentage (0-100, may exceed 100 on multi-core systems).
    public let cpuPercent: Double
    /// Resident memory consumed by the process, in megabytes.
    public let memoryMB: Double

    /// Creates a new ``ProcessInfoResponse``.
    /// - Parameters:
    ///   - name: Process name (executable basename).
    ///   - pid: Process identifier.
    ///   - cpuPercent: CPU usage percentage.
    ///   - memoryMB: Resident memory in megabytes.
    public init(name: String, pid: Int, cpuPercent: Double, memoryMB: Double) {
        self.name = name
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
    }
}

// MARK: - File Entry Response

/// A single file or directory entry from a directory listing.
///
/// Represents filesystem metadata for files and directories returned by the
/// file browser endpoints (`GET /api/v1/system/files`). Provides essential
/// information for building remote file explorers in the iOS/macOS clients.
///
/// ## API Versioning
/// - **Introduced:** v1.0 (API Version 1.0)
/// - **Last Modified:** v1.0
/// - **Breaking Changes:** None
/// - **Deprecations:** None
/// - **Stability:** Stable - part of the v1 public API contract
///
/// ## Implementation Notes
/// - Directory entries always report `size: 0` for consistency across platforms
/// - `modifiedDate` may be `nil` if filesystem metadata is unavailable or inaccessible
/// - Entries are sorted by the backend before transmission (directories first, then files)
/// - Hidden files (`.` prefix) and system files may be filtered by backend policy
public struct FileEntryResponse: Codable, Sendable, Equatable {
    /// File or directory name (basename only, no path components).
    public let name: String
    /// Whether this entry represents a directory (`true`) or file (`false`).
    public let isDirectory: Bool
    /// File size in bytes. Always 0 for directories.
    public let size: UInt64
    /// Last modification timestamp. Nil if metadata is unavailable.
    public let modifiedDate: Date?

    /// Creates a new ``FileEntryResponse``.
    /// - Parameters:
    ///   - name: File or directory name.
    ///   - isDirectory: Whether this is a directory.
    ///   - size: File size in bytes (0 for directories).
    ///   - modifiedDate: Last modification date, if available.
    public init(name: String, isDirectory: Bool, size: UInt64, modifiedDate: Date?) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
    }
}
