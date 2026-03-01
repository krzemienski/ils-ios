import Foundation
import Observation
import UserNotifications

// MARK: - BackendStatus

/// Status of the ILS backend service.
enum BackendStatus: Equatable {
    case notInstalled
    case installing
    case running
    case stopped
    case crashed
    case error(String)
}

// MARK: - BackendError

enum BackendError: LocalizedError {
    case binaryNotFound
    case notInstalled
    case buildFailed(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Backend binary not found after build"
        case .notInstalled:
            return "Backend is not installed. Please install it first."
        case .buildFailed(let output):
            return "Build failed: \(output)"
        case .processError(let message):
            return message
        }
    }
}

// MARK: - BackendLifecycleManager

/// Manages the ILS backend process lifecycle via launchctl on macOS.
///
/// Handles installation, removal, start/stop, health monitoring, crash detection,
/// and restart throttling of the ILS backend as a LaunchAgent.
///
/// Binary lives at `~/.ils/bin/ILSBackend`; plist at
/// `~/Library/LaunchAgents/com.ils.backend.plist`. `KeepAlive=false` — this class
/// manages crash restarts manually to enforce the 3-per-10-minutes throttle.
@MainActor
@Observable
final class BackendLifecycleManager {

    /// Shared singleton instance.
    static let shared = BackendLifecycleManager()

    // MARK: - Observable State

    /// Current status of the backend service.
    var status: BackendStatus = .notInstalled

    /// Path to the installed backend binary, if present.
    private(set) var installedBinaryPath: String?

    /// Repo path used during installation (stored for working-directory config).
    var repoPath: String?

    /// Last 200 lines from /tmp/ils-backend.log.
    var logLines: [String] = []

    /// Backend CPU usage as a percentage (from `ps`).
    var cpuPercent: Double = 0

    /// Backend resident memory in megabytes (from `ps`, RSS/1024).
    var memoryMB: Double = 0

    /// Name of a non-ILSBackend process occupying port 9999, or `nil` if clear.
    var portConflictProcess: String?

    // MARK: - Constants

    let serviceName = "com.ils.backend"

    private let healthPollIntervalNs: UInt64 = 30_000_000_000  // 30 seconds
    private let maxRestartsPerWindow = 3
    private let restartWindowSeconds: TimeInterval = 600        // 10 minutes
    private let logTailLines = 200

    // MARK: - Private State

    private var healthPollTask: Task<Void, Never>?
    /// Timestamps of automatic crash-restarts within the throttle window.
    private var restartTimestamps: [Date] = []

    // MARK: - Computed Paths

    /// Default binary install location: ~/.ils/bin/ILSBackend
    var standardInstallBinaryPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ils/bin/ILSBackend").path
    }

    /// LaunchAgent plist path: ~/Library/LaunchAgents/com.ils.backend.plist
    var plistPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(serviceName).plist").path
    }

    // MARK: - Init

    private init() {
        detectInstalledBackend()
    }

    // MARK: - Binary Discovery

    /// Probe for an already-installed backend binary and set status accordingly.
    private func detectInstalledBackend() {
        guard FileManager.default.isExecutableFile(atPath: standardInstallBinaryPath) else {
            status = .notInstalled
            return
        }
        installedBinaryPath = standardInstallBinaryPath
        if FileManager.default.fileExists(atPath: plistPath) {
            status = isServiceLoaded() ? .running : .stopped
        } else {
            status = .stopped
        }
    }

    /// Return the path of a built release binary inside `repoPath`, or `nil`.
    ///
    /// Checks common SPM output locations (universal, arm64, x86_64).
    func discoverBinary(atRepoPath repoPath: String) -> String? {
        let candidates = [
            "\(repoPath)/.build/release/ILSBackend",
            "\(repoPath)/.build/arm64-apple-macosx/release/ILSBackend",
            "\(repoPath)/.build/x86_64-apple-macosx/release/ILSBackend",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Install / Uninstall

    /// Build the release binary from source and install the LaunchAgent.
    ///
    /// Progress is reflected via `status` (`.installing` → `.stopped` on success).
    func installBackend(fromRepoPath repoPath: String) async throws {
        status = .installing
        self.repoPath = repoPath

        do {
            try await buildReleaseBinary(repoPath: repoPath)

            guard let builtBinary = discoverBinary(atRepoPath: repoPath) else {
                status = .error("Binary not found after build")
                throw BackendError.binaryNotFound
            }

            try copyBinary(from: builtBinary)
            try installLaunchAgent(binaryPath: standardInstallBinaryPath, workingDir: repoPath)

            installedBinaryPath = standardInstallBinaryPath
            status = .stopped
        } catch let err as BackendError {
            status = .error(err.errorDescription ?? "Installation failed")
            throw err
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    /// Unload the LaunchAgent and remove the plist and binary from disk.
    func uninstallBackend() throws {
        stopHealthPolling()
        if status == .running {
            try stopBackend()
        }
        unloadLaunchAgent()
        try? FileManager.default.removeItem(atPath: plistPath)
        try? FileManager.default.removeItem(atPath: standardInstallBinaryPath)
        installedBinaryPath = nil
        repoPath = nil
        restartTimestamps = []
        logLines = []
        cpuPercent = 0
        memoryMB = 0
        portConflictProcess = nil
        status = .notInstalled
    }

    // MARK: - Start / Stop

    /// Load (start) the backend LaunchAgent.
    func startBackend() throws {
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw BackendError.notInstalled
        }
        try runLaunchctl(["load", plistPath])
        status = .running
    }

    /// Unload (stop) the backend LaunchAgent.
    func stopBackend() throws {
        try runLaunchctl(["unload", plistPath])
        status = .stopped
    }

    /// Stop then start the backend LaunchAgent.
    func restartBackend() throws {
        try stopBackend()
        try startBackend()
    }

    // MARK: - Health Monitoring

    /// Start health monitoring if the backend is installed. Call from app startup.
    func startMonitoringIfInstalled() async {
        guard status != .notInstalled else { return }
        startHealthPolling()
        await refreshLogs()
        await refreshResourceUsage()
        await checkPortConflict()
    }

    /// Begin the 30-second health-poll loop.
    func startHealthPolling() {
        guard healthPollTask == nil else { return }
        healthPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.healthPollIntervalNs ?? 30_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await self.performHealthCheck()
            }
        }
    }

    /// Cancel the health-poll loop.
    func stopHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = nil
    }

    /// Fetch /health, update status, trigger crash recovery if needed.
    private func performHealthCheck() async {
        guard status == .running || status == .crashed else { return }

        let isHealthy = await pingHealthEndpoint()

        if isHealthy {
            if status == .crashed {
                status = .running
            }
        } else if status == .running {
            await handleCrash()
        }

        if status == .running {
            await refreshResourceUsage()
        }
        await refreshLogs()
        await checkPortConflict()
    }

    /// Return true if GET http://localhost:9999/health responds with HTTP 2xx.
    private func pingHealthEndpoint() async -> Bool {
        guard let url = URL(string: "http://localhost:9999/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Crash Detection & Restart Throttling

    /// Mark service as crashed and attempt an auto-restart unless throttle is hit.
    private func handleCrash() async {
        status = .crashed

        let now = Date()
        restartTimestamps = restartTimestamps.filter {
            now.timeIntervalSince($0) < restartWindowSeconds
        }

        if restartTimestamps.count < maxRestartsPerWindow {
            restartTimestamps.append(now)
            try? startBackend()
        } else {
            await postCrashThrottleNotification()
        }
    }

    /// Post a user notification when automatic restart has been disabled due to repeated crashes.
    private func postCrashThrottleNotification() async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "ILS Backend Stopped"
        content.body = "The backend crashed \(maxRestartsPerWindow) times in 10 minutes. Automatic restart is paused — check the logs."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "backend-crash-throttle",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    // MARK: - Log Reading

    /// Reload the last \(logTailLines) lines from /tmp/ils-backend.log.
    func refreshLogs() async {
        let logPath = "/tmp/ils-backend.log"
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        logLines = Array(lines.suffix(logTailLines))
    }

    // MARK: - Resource Monitoring

    /// Update `cpuPercent` and `memoryMB` from `ps` for the backend process.
    func refreshResourceUsage() async {
        guard let pid = getBackendPID() else {
            cpuPercent = 0
            memoryMB = 0
            return
        }

        // ps -o pid=,pcpu=,rss= -p <pid>  — rss is in KB
        guard let output = try? runProcessNonisolated(
            path: "/bin/ps",
            args: ["-o", "pid=,pcpu=,rss=", "-p", "\(pid)"]
        ) else {
            cpuPercent = 0
            memoryMB = 0
            return
        }

        let parts = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        if parts.count >= 3 {
            cpuPercent = Double(parts[1]) ?? 0
            memoryMB = (Double(parts[2]) ?? 0) / 1024.0
        }
    }

    /// Return the PID of the process listening on port 9999, or `nil`.
    private func getBackendPID() -> Int32? {
        guard let output = try? runProcessNonisolated(
            path: "/usr/sbin/lsof",
            args: ["-ti", ":9999", "-sTCP:LISTEN"]
        ) else { return nil }
        return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Port Conflict Detection

    /// Populate `portConflictProcess` if a non-ILSBackend process is using port 9999.
    func checkPortConflict() async {
        guard let output = try? runProcessNonisolated(
            path: "/usr/sbin/lsof",
            args: ["-i", ":9999", "-P", "-n", "-sTCP:LISTEN"]
        ) else {
            portConflictProcess = nil
            return
        }

        // Output: header line + one data line per process.
        // Columns: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
        let lines = output.components(separatedBy: "\n").dropFirst()
        for line in lines {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 2 else { continue }
            let command = String(columns[0])
            if command != "ILSBackend" {
                portConflictProcess = command
                return
            }
        }
        portConflictProcess = nil
    }

    // MARK: - LaunchAgent Plist

    /// Write ~/Library/LaunchAgents/com.ils.backend.plist.
    ///
    /// `KeepAlive` is intentionally `false` — the app handles crash restarts
    /// to enforce the 3-per-10-minute throttle.
    func installLaunchAgent(binaryPath: String, workingDir: String) throws {
        let launchAgentsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)

        unloadLaunchAgent()

        let xml = buildPlistXML(binaryPath: binaryPath, workingDir: workingDir)
        try xml.write(toFile: plistPath, atomically: true, encoding: .utf8)
    }

    private func unloadLaunchAgent() {
        try? runLaunchctl(["unload", plistPath])
    }

    private func buildPlistXML(binaryPath: String, workingDir: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(serviceName)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>
            <key>WorkingDirectory</key>
            <string>\(workingDir)</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PORT</key>
                <string>9999</string>
            </dict>
            <key>RunAtLoad</key>
            <false/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/tmp/ils-backend.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/ils-backend.error.log</string>
        </dict>
        </plist>
        """
    }

    // MARK: - Binary Installation

    /// Copy `sourcePath` to `~/.ils/bin/ILSBackend` with executable permissions.
    private func copyBinary(from sourcePath: String) throws {
        let destDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ils/bin")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appendingPathComponent("ILSBackend")
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destURL.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
        installedBinaryPath = destURL.path
    }

    // MARK: - Swift Build

    /// Build the SPM release binary at `repoPath` on a background thread.
    private func buildReleaseBinary(repoPath: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
                process.arguments = ["build", "-c", "release"]
                process.currentDirectoryURL = URL(fileURLWithPath: repoPath)

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let errOutput = String(
                            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8
                        ) ?? ""
                        continuation.resume(throwing: BackendError.buildFailed(errOutput))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Service Status

    /// Return true if launchctl reports the service as loaded.
    nonisolated func isServiceLoaded() -> Bool {
        (try? runProcessNonisolated(path: "/bin/launchctl", args: ["list", "com.ils.backend"])) != nil
    }

    // MARK: - Process Helpers

    @discardableResult
    private func runLaunchctl(_ args: [String]) throws -> String {
        try runProcessNonisolated(path: "/bin/launchctl", args: args)
    }

    /// Run a process synchronously and return stdout output.
    ///
    /// Marked `nonisolated` so it can be called from background tasks without
    /// a MainActor hop — all state access is local to the process.
    @discardableResult
    nonisolated func runProcessNonisolated(
        path: String,
        args: [String],
        workingDir: String? = nil
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        if let workingDir {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errOutput.isEmpty ? output : errOutput
            throw BackendError.processError(
                "Exit \(process.terminationStatus): \(message.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }

        return output
    }
}
