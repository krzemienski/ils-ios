import Foundation
import Darwin

/// Actor that collects system metrics: CPU, memory, disk, network, processes, and file listings.
///
/// Uses macOS system calls (`host_processor_info`, `host_statistics64`) for CPU and memory,
/// `FileManager` for disk, and `netstat -ib` for network statistics.
actor SystemMetricsService {
    private let fileManager = FileManager.default

    // MARK: - Data Structures

    struct SystemMetrics: Codable, Sendable {
        let cpu: Double
        let memory: MemoryMetrics
        let disk: DiskMetrics
        let network: NetworkMetrics
        let loadAverage: [Double]
    }

    struct MemoryMetrics: Codable, Sendable {
        let used: UInt64
        let total: UInt64
        let percentage: Double
    }

    struct DiskMetrics: Codable, Sendable {
        let used: UInt64
        let total: UInt64
        let percentage: Double
    }

    struct NetworkMetrics: Codable, Sendable {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    struct SystemProcessInfo: Codable, Sendable {
        let name: String
        let pid: Int
        let cpuPercent: Double
        let memoryMB: Double
    }

    struct SystemFileEntry: Codable, Sendable {
        let name: String
        let isDirectory: Bool
        let size: UInt64
        let modifiedDate: Date?
    }

    // MARK: - Public API

    /// Collect current system metrics (CPU, memory, disk, network, load average).
    func getMetrics() -> SystemMetrics {
        let cpu = getCPUUsage()
        let memory = getMemoryMetrics()
        let disk = getDiskMetrics()
        let network = getNetworkMetrics()
        let load = getLoadAverage()

        return SystemMetrics(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            loadAverage: load
        )
    }

    /// List running processes sorted by CPU or memory usage.
    func getProcesses() -> [SystemProcessInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return parseProcessOutput(output)
        } catch {
            return []
        }
    }

    /// List directory contents, restricted to user home directory.
    /// - Parameter path: Directory path (must be within home directory)
    /// - Returns: Array of file entries, or nil if path is outside home directory
    func listDirectory(path: String) -> [SystemFileEntry]? {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let resolved: String

        if path == "~" || path.hasPrefix("~/") {
            resolved = path.replacingOccurrences(of: "~", with: home, options: [], range: path.startIndex..<path.index(path.startIndex, offsetBy: 1))
        } else {
            resolved = path
        }

        // Normalize path to resolve symlinks and ..
        let normalizedPath = (resolved as NSString).standardizingPath
        let normalizedHome = (home as NSString).standardizingPath

        // Security check: must be within home directory
        guard normalizedPath.hasPrefix(normalizedHome) else {
            return nil
        }

        guard fileManager.fileExists(atPath: normalizedPath) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: normalizedPath)
            return contents.compactMap { name -> SystemFileEntry? in
                let fullPath = (normalizedPath as NSString).appendingPathComponent(name)
                guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath) else {
                    return nil
                }

                let fileType = attrs[.type] as? FileAttributeType
                let isDir = fileType == .typeDirectory
                let size = (attrs[.size] as? UInt64) ?? 0
                let modified = attrs[.modificationDate] as? Date

                return SystemFileEntry(
                    name: name,
                    isDirectory: isDir,
                    size: size,
                    modifiedDate: modified
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            return []
        }
    }

    // MARK: - Private Helpers

    /// Get CPU usage percentage via host_processor_info().
    private func getCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0.0
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])

            totalUser += user + nice
            totalSystem += system
            totalIdle += idle
        }

        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return 0.0 }

        let usage = ((totalUser + totalSystem) / total) * 100.0
        return (usage * 10).rounded() / 10 // Round to 1 decimal
    }

    /// Get memory usage via host_statistics64().
    private func getMemoryMetrics() -> MemoryMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics(used: 0, total: 0, percentage: 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        let activePages = UInt64(stats.active_count)
        let wiredPages = UInt64(stats.wire_count)
        let compressedPages = UInt64(stats.compressor_page_count)
        let usedMemory = (activePages + wiredPages + compressedPages) * pageSize

        let percentage = totalMemory > 0 ? (Double(usedMemory) / Double(totalMemory)) * 100.0 : 0.0

        return MemoryMetrics(
            used: usedMemory,
            total: totalMemory,
            percentage: (percentage * 10).rounded() / 10
        )
    }

    /// Get disk usage via FileManager.attributesOfFileSystem.
    private func getDiskMetrics() -> DiskMetrics {
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? UInt64) ?? 0
            let free = (attrs[.systemFreeSize] as? UInt64) ?? 0
            let used = total > free ? total - free : 0
            let percentage = total > 0 ? (Double(used) / Double(total)) * 100.0 : 0.0

            return DiskMetrics(
                used: used,
                total: total,
                percentage: (percentage * 10).rounded() / 10
            )
        } catch {
            return DiskMetrics(used: 0, total: 0, percentage: 0)
        }
    }

    /// Get network byte counters by parsing `netstat -ib` output.
    private func getNetworkMetrics() -> NetworkMetrics {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ib"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return NetworkMetrics(bytesIn: 0, bytesOut: 0)
            }

            return parseNetstatOutput(output)
        } catch {
            return NetworkMetrics(bytesIn: 0, bytesOut: 0)
        }
    }

    /// Get system load averages.
    private func getLoadAverage() -> [Double] {
        var loadavg = [Double](repeating: 0, count: 3)
        getloadavg(&loadavg, 3)
        return loadavg.map { ($0 * 100).rounded() / 100 }
    }

    /// Parse `ps aux` output into process info structs.
    private func parseProcessOutput(_ output: String) -> [SystemProcessInfo] {
        let lines = output.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }

        // Skip header line
        return lines.dropFirst().compactMap { line -> SystemProcessInfo? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            // ps aux columns: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
            let parts = trimmed.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            guard parts.count >= 11 else { return nil }

            guard let pid = Int(parts[1]),
                  let cpuPercent = Double(parts[2]),
                  let _ = Double(parts[3]) else {
                return nil
            }

            // RSS is in KB (column index 5)
            let rssKB = Double(parts[5]) ?? 0
            let memoryMB = (rssKB / 1024.0 * 10).rounded() / 10

            let command = String(parts[10])
            // Extract just the executable name from the path
            let name = (command as NSString).lastPathComponent

            return SystemProcessInfo(
                name: name,
                pid: pid,
                cpuPercent: cpuPercent,
                memoryMB: memoryMB
            )
        }
    }

    /// Parse `netstat -ib` output to sum bytes in/out across all interfaces.
    private func parseNetstatOutput(_ output: String) -> NetworkMetrics {
        let lines = output.components(separatedBy: "\n")
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        // Find header to determine column positions
        guard let headerLine = lines.first else {
            return NetworkMetrics(bytesIn: 0, bytesOut: 0)
        }

        let headerParts = headerLine.split(separator: " ", omittingEmptySubsequences: true)
        var ibytesIdx: Int?
        var obytesIdx: Int?

        for (i, col) in headerParts.enumerated() {
            if col == "Ibytes" { ibytesIdx = i }
            if col == "Obytes" { obytesIdx = i }
        }

        guard let inIdx = ibytesIdx, let outIdx = obytesIdx else {
            return NetworkMetrics(bytesIn: 0, bytesOut: 0)
        }

        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count > max(inIdx, outIdx) else { continue }

            // Skip loopback
            if parts[0].hasPrefix("lo") { continue }

            if let bytesIn = UInt64(parts[inIdx]) {
                totalBytesIn += bytesIn
            }
            if let bytesOut = UInt64(parts[outIdx]) {
                totalBytesOut += bytesOut
            }
        }

        return NetworkMetrics(bytesIn: totalBytesIn, bytesOut: totalBytesOut)
    }
}
