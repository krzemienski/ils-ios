import Foundation

// MARK: - System Metrics Response

/// System metrics snapshot including CPU, memory, disk, and network statistics.
public struct SystemMetricsResponse: Codable, Sendable {
    /// CPU usage percentage (0-100).
    public let cpu: Double
    /// Memory usage details.
    public let memory: MemoryInfo
    /// Disk usage details.
    public let disk: DiskInfo
    /// Network byte counters.
    public let network: NetworkInfo
    /// System load averages (1, 5, 15 minutes).
    public let loadAverage: [Double]

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

    /// Memory usage breakdown.
    public struct MemoryInfo: Codable, Sendable {
        /// Used memory in bytes.
        public let used: UInt64
        /// Total physical memory in bytes.
        public let total: UInt64
        /// Usage percentage (0-100).
        public let percentage: Double

        public init(used: UInt64, total: UInt64, percentage: Double) {
            self.used = used
            self.total = total
            self.percentage = percentage
        }
    }

    /// Disk usage breakdown.
    public struct DiskInfo: Codable, Sendable {
        /// Used disk space in bytes.
        public let used: UInt64
        /// Total disk space in bytes.
        public let total: UInt64
        /// Usage percentage (0-100).
        public let percentage: Double

        public init(used: UInt64, total: UInt64, percentage: Double) {
            self.used = used
            self.total = total
            self.percentage = percentage
        }
    }

    /// Network traffic counters.
    public struct NetworkInfo: Codable, Sendable {
        /// Total bytes received.
        public let bytesIn: UInt64
        /// Total bytes sent.
        public let bytesOut: UInt64

        public init(bytesIn: UInt64, bytesOut: UInt64) {
            self.bytesIn = bytesIn
            self.bytesOut = bytesOut
        }
    }
}

// MARK: - Process Info Response

/// Information about a running system process.
public struct ProcessInfoResponse: Codable, Sendable {
    /// Process name (executable basename).
    public let name: String
    /// Process ID.
    public let pid: Int
    /// CPU usage percentage.
    public let cpuPercent: Double
    /// Resident memory in megabytes.
    public let memoryMB: Double

    public init(name: String, pid: Int, cpuPercent: Double, memoryMB: Double) {
        self.name = name
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
    }
}

// MARK: - File Entry Response

/// A single file or directory entry from a directory listing.
public struct FileEntryResponse: Codable, Sendable {
    /// File or directory name.
    public let name: String
    /// Whether this entry is a directory.
    public let isDirectory: Bool
    /// File size in bytes (0 for directories).
    public let size: UInt64
    /// Last modification date.
    public let modifiedDate: Date?

    public init(name: String, isDirectory: Bool, size: UInt64, modifiedDate: Date?) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
    }
}
