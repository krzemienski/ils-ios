import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Actor that collects system metrics: CPU, memory, disk, network, processes, and file listings.
///
/// Uses macOS system calls (`host_processor_info`, `host_statistics64`) for CPU and memory,
/// `FileManager` for disk, and `getifaddrs` for network statistics.
/// On Linux, CPU and memory use `/proc` filesystem; network returns empty metrics.
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

#if os(macOS) || os(iOS)
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

    /// Get network byte counters via `getifaddrs()` system call.
    private func getNetworkMetrics() -> NetworkMetrics {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return NetworkMetrics(bytesIn: 0, bytesOut: 0)
        }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)

            // Skip loopback interfaces
            if !name.hasPrefix("lo"),
               let ifaAddr = addr.pointee.ifa_addr,
               ifaAddr.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalBytesIn += UInt64(networkData.ifi_ibytes)
                totalBytesOut += UInt64(networkData.ifi_obytes)
            }

            cursor = addr.pointee.ifa_next
        }

        return NetworkMetrics(bytesIn: totalBytesIn, bytesOut: totalBytesOut)
    }

#else
    // MARK: - Linux Fallbacks

    /// Get CPU usage from /proc/stat on Linux.
    private func getCPUUsage() -> Double {
        guard let contents = try? String(contentsOfFile: "/proc/stat", encoding: .utf8) else {
            return 0.0
        }
        // Parse first "cpu " line: user nice system idle iowait irq softirq steal
        guard let cpuLine = contents.components(separatedBy: "\n").first(where: { $0.hasPrefix("cpu ") }) else {
            return 0.0
        }
        let parts = cpuLine.split(separator: " ").compactMap { Double($0) }
        guard parts.count >= 4 else { return 0.0 }

        let user = parts[0]
        let nice = parts[1]
        let system = parts[2]
        let idle = parts[3]
        let total = user + nice + system + idle
        guard total > 0 else { return 0.0 }

        let usage = ((user + nice + system) / total) * 100.0
        return (usage * 10).rounded() / 10
    }

    /// Get memory metrics from /proc/meminfo on Linux.
    private func getMemoryMetrics() -> MemoryMetrics {
        guard let contents = try? String(contentsOfFile: "/proc/meminfo", encoding: .utf8) else {
            return MemoryMetrics(used: 0, total: 0, percentage: 0)
        }

        var totalKB: UInt64 = 0
        var availableKB: UInt64 = 0

        for line in contents.components(separatedBy: "\n") {
            if line.hasPrefix("MemTotal:") {
                totalKB = parseMemInfoValue(line)
            } else if line.hasPrefix("MemAvailable:") {
                availableKB = parseMemInfoValue(line)
            }
        }

        let totalBytes = totalKB * 1024
        let usedBytes = totalBytes - (availableKB * 1024)
        let percentage = totalBytes > 0 ? (Double(usedBytes) / Double(totalBytes)) * 100.0 : 0.0

        return MemoryMetrics(
            used: usedBytes,
            total: totalBytes,
            percentage: (percentage * 10).rounded() / 10
        )
    }

    private func parseMemInfoValue(_ line: String) -> UInt64 {
        // Format: "MemTotal:       16384000 kB"
        let parts = line.split(separator: " ")
        guard parts.count >= 2, let value = UInt64(parts[1]) else { return 0 }
        return value
    }

    /// Network metrics stub on Linux (returns zeros).
    private func getNetworkMetrics() -> NetworkMetrics {
        return NetworkMetrics(bytesIn: 0, bytesOut: 0)
    }
#endif

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

}
