import Foundation
import ILSShared

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var steps: [SetupProgress] = []
    @Published var isRunning = false
    @Published var isComplete = false
    @Published var error: String?
    @Published var tunnelURL: String?

    private let sshService = CitadelSSHService()

    // Raw GitHub URL for the bootstrap script
    private let bootstrapScriptURL = "https://raw.githubusercontent.com/krzemienski/ils-ios/master/scripts/bootstrap-remote.sh"

    func startSetup(request: StartSetupRequest) async {
        isRunning = true
        isComplete = false
        error = nil
        tunnelURL = nil

        // Initialize all steps as pending
        steps = SetupProgress.SetupStep.allCases.map {
            SetupProgress(step: $0, status: .pending, message: "Waiting...")
        }

        // ── Step 1: Connect SSH ─────────────────────────────────────────
        updateStep(.connectSSH, status: .inProgress, message: "Connecting to \(request.host)...")
        do {
            _ = try await sshService.connect(
                host: request.host,
                port: request.port,
                username: request.username,
                authMethod: request.authMethod,
                credential: request.credential
            )
            updateStep(.connectSSH, status: .success, message: "Connected to \(request.host)")
        } catch {
            updateStep(.connectSSH, status: .failure, message: "Connection failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isRunning = false
            return
        }

        // ── Steps 2-8: Execute Bootstrap Script ─────────────────────────
        // Download and run the bootstrap script via streaming SSH.
        // The script emits ILS_STEP: markers that we parse in real-time
        // to update the progress UI.
        do {
            var scriptArgs = "--port \(request.backendPort)"

            if let repoURL = request.repositoryURL {
                scriptArgs += " --repo \(repoURL)"
            }

            if request.tunnelType == nil {
                scriptArgs += " --no-tunnel"
            }

            // Use curl to download and pipe to bash with arguments
            let command = "curl -sSL '\(bootstrapScriptURL)' | bash -s -- \(scriptArgs)"

            let urlHolder = TunnelURLHolder()

            let result = try await sshService.executeStreamingCommand(command) { [weak self, urlHolder] chunk in
                // Parse each chunk for ILS_ markers
                let lines = chunk.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }

                    if trimmed.hasPrefix("ILS_STEP:") {
                        Self.parseStepMarker(trimmed, viewModel: self)
                    } else if trimmed.hasPrefix("ILS_TUNNEL_URL:") {
                        let url = String(trimmed.dropFirst("ILS_TUNNEL_URL:".count))
                        urlHolder.set(url)
                        Task { @MainActor in
                            self?.tunnelURL = url
                        }
                    } else if trimmed.hasPrefix("ILS_BACKEND_URL:") {
                        // Direct backend URL (no tunnel) — SSHSetupView handles
                        // fallback logic: tunnelURL ?? "http://host:port"
                    } else if trimmed.hasPrefix("ILS_ERROR:") {
                        let msg = String(trimmed.dropFirst("ILS_ERROR:".count))
                        Task { @MainActor in
                            self?.error = msg
                        }
                    }
                    // ILS_COMPLETE is handled by the script exiting with code 0
                }
            }

            // Script finished — check result
            if result.exitCode == 0 {
                // If we have a tunnel URL, great. If not, fallback handled by SSHSetupView.
                isComplete = true
            } else {
                // Script failed — error should already be set from ILS_ERROR marker
                if self.error == nil {
                    self.error = "Bootstrap script exited with code \(result.exitCode)"
                }
            }

        } catch {
            // SSH streaming failed entirely
            self.error = "Bootstrap failed: \(error.localizedDescription)"
        }

        isRunning = false
    }

    // MARK: - Marker Parsing

    /// Parses an ILS_STEP marker line and updates the corresponding step.
    /// Format: ILS_STEP:step_name:status:message
    /// This is nonisolated so it can be called from @Sendable streaming closures.
    nonisolated private static func parseStepMarker(_ line: String, viewModel: SetupViewModel?) {
        // ILS_STEP:detect_platform:success:Linux (x86_64)
        let parts = line.dropFirst("ILS_STEP:".count).components(separatedBy: ":")
        guard parts.count >= 3 else { return }

        let stepName = parts[0]
        let statusStr = parts[1]
        let message = parts.dropFirst(2).joined(separator: ":") // rejoin in case message has colons

        guard let step = SetupProgress.SetupStep(rawValue: stepName),
              let status = SetupProgress.StepStatus(rawValue: statusStr) else {
            return
        }

        Task { @MainActor in
            viewModel?.updateStep(step, status: status, message: message)
        }
    }

    private func updateStep(_ step: SetupProgress.SetupStep, status: SetupProgress.StepStatus, message: String) {
        if let idx = steps.firstIndex(where: { $0.step == step }) {
            steps[idx] = SetupProgress(step: step, status: status, message: message)
        }
    }
}

// MARK: - Thread-safe tunnel URL holder

/// A `Sendable` class for safely capturing the tunnel URL from a `@Sendable` closure.
/// Uses `NSLock` so it can be read/written from the streaming callback without
/// Swift 6 concurrency warnings on captured vars.
private final class TunnelURLHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var _url: String?

    var url: String? {
        lock.lock()
        defer { lock.unlock() }
        return _url
    }

    var hasURL: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _url != nil
    }

    func set(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        _url = value
    }
}
