import Vapor
import ILSShared
import Foundation

actor RemoteMetricsService {
    private let sshService: SSHService

    init(sshService: SSHService) {
        self.sshService = sshService
    }

    func getMetrics() async throws -> SystemMetricsResponse {
        let status = await sshService.getStatus()
        let platform = status.platform ?? "Linux"
        let cpu = try await getCPU(platform: platform)
        let memory = try await getMemory(platform: platform)
        let disk = try await getDisk(platform: platform)
        let network = try await getNetwork(platform: platform)
        let load = try await getLoadAverage()

        return SystemMetricsResponse(
            cpu: cpu, memory: memory, disk: disk, network: network, loadAverage: load
        )
    }

    private func getCPU(platform: String) async throws -> Double {
        let cmd = platform == "Darwin"
            ? "top -l 1 -s 0 | grep 'CPU usage' | awk '{print $3}' | tr -d '%'"
            : "top -bn1 | grep '%Cpu' | awk '{print $2}'"
        let result = try await sshService.executeCommand(cmd)
        return Double(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func getMemory(platform: String) async throws -> SystemMetricsResponse.MemoryInfo {
        if platform == "Darwin" {
            let memsize = try await sshService.executeCommand("sysctl -n hw.memsize")
            let total = UInt64(memsize.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let vmstat = try await sshService.executeCommand("vm_stat | head -5")
            // Parse page size and free pages from vm_stat
            let lines = vmstat.stdout.components(separatedBy: "\n")
            var pageSize: UInt64 = 16384
            var freePages: UInt64 = 0
            for line in lines {
                if line.contains("page size of") {
                    let parts = line.components(separatedBy: " ")
                    if let sizeStr = parts.last, let size = UInt64(sizeStr) { pageSize = size }
                }
                if line.contains("Pages free") {
                    let parts = line.components(separatedBy: ":")
                    if let numStr = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "") {
                        freePages = UInt64(numStr) ?? 0
                    }
                }
            }
            let freeBytes = freePages * pageSize
            let used = total > freeBytes ? total - freeBytes : 0
            let pct = total > 0 ? Double(used) / Double(total) * 100 : 0
            return .init(used: used, total: total, percentage: pct)
        } else {
            let result = try await sshService.executeCommand("free -b | awk 'NR==2{print $2,$3}'")
            let parts = result.stdout.split(separator: " ")
            let total = UInt64(parts.first ?? "0") ?? 0
            let used = UInt64(parts.last ?? "0") ?? 0
            let pct = total > 0 ? Double(used) / Double(total) * 100 : 0
            return .init(used: used, total: total, percentage: pct)
        }
    }

    private func getDisk(platform: String) async throws -> SystemMetricsResponse.DiskInfo {
        let cmd = platform == "Darwin"
            ? "df -k / | awk 'NR==2{print $2,$3}'"
            : "df -B1 / | awk 'NR==2{print $2,$3}'"
        let result = try await sshService.executeCommand(cmd)
        let parts = result.stdout.split(separator: " ")
        let total = UInt64(parts.first ?? "0") ?? 0
        let used = UInt64(parts.last ?? "0") ?? 0
        let multiplier: UInt64 = platform == "Darwin" ? 1024 : 1
        let pct = total > 0 ? Double(used) / Double(total) * 100 : 0
        return .init(used: used * multiplier, total: total * multiplier, percentage: pct)
    }

    private func getNetwork(platform: String) async throws -> SystemMetricsResponse.NetworkInfo {
        if platform == "Darwin" {
            let result = try await sshService.executeCommand("netstat -ib | head -20")
            var totalIn: UInt64 = 0
            var totalOut: UInt64 = 0
            let lines = result.stdout.components(separatedBy: "\n")
            for line in lines.dropFirst() {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 10, let bytesIn = UInt64(parts[6]), let bytesOut = UInt64(parts[9]) {
                    totalIn += bytesIn
                    totalOut += bytesOut
                }
            }
            return .init(bytesIn: totalIn, bytesOut: totalOut)
        } else {
            let result = try await sshService.executeCommand(
                "cat /proc/net/dev | awk 'NR>2{rx+=$2;tx+=$10}END{print rx,tx}'"
            )
            let parts = result.stdout.split(separator: " ")
            let rx = UInt64(parts.first ?? "0") ?? 0
            let tx = UInt64(parts.last ?? "0") ?? 0
            return .init(bytesIn: rx, bytesOut: tx)
        }
    }

    private func getLoadAverage() async throws -> [Double] {
        let result = try await sshService.executeCommand("cat /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg")
        let parts = result.stdout.split(separator: " ")
        return parts.prefix(3).compactMap { Double($0.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))) }
    }

    func getProcesses(highlight: Bool = true) async throws -> [RemoteProcessInfo] {
        let result = try await sshService.executeCommand("ps aux")
        let lines = result.stdout.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }

        return lines.dropFirst().compactMap { line -> RemoteProcessInfo? in
            let parts = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            guard parts.count >= 11 else { return nil }
            guard let pid = Int(parts[1]),
                  let cpu = Double(parts[2]) else { return nil }
            let rss = Double(parts[5]) ?? 0
            let memMB = (rss / 1024.0 * 10).rounded() / 10
            let command = String(parts[10])
            let name = URL(fileURLWithPath: command).lastPathComponent

            let highlightType: RemoteProcessInfo.ProcessHighlightType? = highlight
                ? classifyProcess(name: name, command: command)
                : nil

            return RemoteProcessInfo(
                pid: pid, name: name, cpuPercent: cpu, memoryMB: memMB,
                command: command, highlightType: highlightType
            )
        }
    }

    private func classifyProcess(name: String, command: String) -> RemoteProcessInfo.ProcessHighlightType {
        let lower = name.lowercased()
        let cmdLower = command.lowercased()
        if lower.contains("claude") || cmdLower.contains("claude") { return .claude }
        if lower.contains("ilsbackend") || cmdLower.contains("ilsbackend") { return .ilsBackend }
        if lower == "swift" || lower.contains("vapor") || cmdLower.contains("swift build") { return .swift }
        return .none
    }
}
