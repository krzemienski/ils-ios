import Foundation
import Observation

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
/// Handles installation, removal, and start/stop of the ILS backend as a LaunchAgent.
/// Binary is installed to `~/.ils/bin/ILSBackend`; plist at
/// `~/Library/LaunchAgents/com.ils.backend.plist`. App manages restarts manually
/// (KeepAlive=false) to enforce the 3-restart-per-10-minutes crash throttle.
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

    // MARK: - Constants

    let serviceName = "com.ils.backend"

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
        if status == .running {
            try stopBackend()
        }
        unloadLaunchAgent()
        try? FileManager.default.removeItem(atPath: plistPath)
        try? FileManager.default.removeItem(atPath: standardInstallBinaryPath)
        installedBinaryPath = nil
        repoPath = nil
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

    // MARK: - LaunchAgent Plist

    /// Write ~/Library/LaunchAgents/com.ils.backend.plist.
    ///
    /// KeepAlive is intentionally `false` — the app handles crash restarts
    /// to enforce the 3-per-10-minute throttle (added in subtask-1-2).
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

    /// Run a process synchronously, returning combined stdout output.
    ///
    /// `nonisolated` so it can be called from health-monitoring background tasks (subtask-1-2)
    /// without a MainActor hop.
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
            throw BackendError.processError("Exit \(process.terminationStatus): \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return output
    }
}
