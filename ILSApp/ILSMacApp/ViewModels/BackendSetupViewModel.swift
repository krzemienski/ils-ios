import Foundation
import Observation
import SwiftUI

// MARK: - InstallPhase

/// State machine phases for the one-click backend install flow.
enum InstallPhase: Equatable {
    /// Awaiting user action (default).
    case idle
    /// User is browsing for the repo path via NSOpenPanel.
    case selectingPath
    /// `swift build -c release` is running.
    case buildingBinary
    /// Binary copied; writing and loading LaunchAgent plist.
    case installingAgent
    /// Installation finished successfully.
    case complete
}

// MARK: - BackendSetupViewModel

/// ViewModel for the macOS Settings > Backend panel.
///
/// Wraps `BackendLifecycleManager.shared` and surfaces all UI state needed by
/// `MacBackendSettingsView`: install phase, formatted display strings, action handlers,
/// and update/version info.
@MainActor
@Observable
final class BackendSetupViewModel {

    // MARK: - Dependencies

    private let manager = BackendLifecycleManager.shared

    // MARK: - Install Flow State

    /// Current phase of the install wizard.
    var installPhase: InstallPhase = .idle

    /// Most recent error message to surface in the UI (nil when none).
    var errorMessage: String?

    /// The repo path the user has typed or selected via Browse.
    var repoPathInput: String = ""

    // MARK: - Update State

    /// True when a newer version of the backend binary is available.
    var updateAvailable: Bool = false

    /// Version string fetched from the running backend's /health endpoint.
    var currentVersion: String?

    // MARK: - Mirrored from BackendLifecycleManager

    /// Current backend service status.
    var backendStatus: BackendStatus { manager.status }

    /// Last 200 log lines from /tmp/ils-backend.log.
    var logLines: [String] { manager.logLines }

    /// Backend CPU usage percentage.
    var cpuPercent: Double { manager.cpuPercent }

    /// Backend memory usage in megabytes.
    var memoryMB: Double { manager.memoryMB }

    /// Name of a conflicting process on port 9999, or nil.
    var portConflictProcess: String? { manager.portConflictProcess }

    // MARK: - Formatted Display Properties

    /// Human-readable memory string (e.g. "128 MB") or "—" when not available.
    var formattedMemory: String {
        memoryMB > 0 ? String(format: "%.0f MB", memoryMB) : "—"
    }

    /// Human-readable CPU string (e.g. "4.2%") or "—" when not available.
    var formattedCPU: String {
        cpuPercent > 0 ? String(format: "%.1f%%", cpuPercent) : "—"
    }

    /// Human-readable status label.
    var statusText: String {
        switch backendStatus {
        case .notInstalled:    return "Not Installed"
        case .installing:      return "Installing…"
        case .running:         return "Running"
        case .stopped:         return "Stopped"
        case .crashed:         return "Crashed"
        case .error(let msg):  return "Error: \(msg)"
        }
    }

    /// Traffic-light colour for the status indicator dot.
    var statusColor: Color {
        switch backendStatus {
        case .running:                      return .green
        case .stopped, .notInstalled:       return .secondary
        case .installing:                   return .yellow
        case .crashed, .error:             return .red
        }
    }

    /// True when Start should be enabled.
    var canStart: Bool {
        backendStatus == .stopped || backendStatus == .crashed
    }

    /// True when Stop should be enabled.
    var canStop: Bool {
        backendStatus == .running
    }

    /// True when Restart should be enabled.
    var canRestart: Bool {
        backendStatus == .running
    }

    /// True when the install flow wizard should be shown.
    var showInstallSection: Bool {
        backendStatus == .notInstalled
    }

    /// Dedicated URLSession for health/update checks with a 5-second timeout.
    private static let healthSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()

    // MARK: - Monitoring

    /// Start backend health monitoring if the backend is installed. Call from app/view startup.
    func startMonitoringIfInstalled() async {
        await manager.startMonitoringIfInstalled()
    }

    // MARK: - Actions

    /// Run the full install flow: build binary → copy → install LaunchAgent.
    func installBackend() async {
        guard !repoPathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please select or enter the ILS repo path."
            return
        }
        installPhase = .buildingBinary
        errorMessage = nil

        do {
            try await manager.installBackend(fromRepoPath: repoPathInput)
            installPhase = .complete
        } catch {
            errorMessage = error.localizedDescription
            installPhase = .idle
        }
    }

    /// Remove the LaunchAgent and wipe the installed binary.
    func uninstallBackend() {
        do {
            try manager.uninstallBackend()
            installPhase = .idle
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load (start) the backend via launchctl.
    func startBackend() {
        do {
            try manager.startBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Unload (stop) the backend via launchctl.
    func stopBackend() {
        do {
            try manager.stopBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stop then start the backend.
    func restartBackend() {
        do {
            try manager.restartBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reload log lines from disk.
    func refreshLogs() async {
        await manager.refreshLogs()
    }

    /// Copy all log lines to the system clipboard.
    func copyLogsToClipboard() {
        let text = logLines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Check whether the running backend reports a version newer than the installed binary.
    ///
    /// Queries `GET /health` for a version string. Sets `currentVersion` and
    /// `updateAvailable` accordingly. No-ops gracefully if the backend is not running.
    func checkForUpdates() async {
        guard backendStatus == .running,
              let url = URL(string: "http://localhost:9999/health") else {
            return
        }

        do {
            let request = URLRequest(url: url)
            let (data, _) = try await Self.healthSession.data(for: request)

            // Try to decode a version field from the health response.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = json["version"] as? String {
                currentVersion = version
                // Future: compare against a releases endpoint or bundled version manifest.
                // For now, surface the version and leave update detection as a future extension.
                updateAvailable = false
            }
        } catch {
            // Non-fatal — update check is best-effort.
        }
    }
}
