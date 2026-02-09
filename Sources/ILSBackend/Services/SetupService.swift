import Vapor
import ILSShared
import Foundation

actor SetupService {
    private let sshService: SSHService
    private var currentProgress: SetupProgress?

    init(sshService: SSHService) {
        self.sshService = sshService
    }

    func getCurrentProgress() -> SetupProgress? { currentProgress }

    func runSetup(
        backendPort: Int,
        repositoryURL: String?,
        progressCallback: @escaping @Sendable (SetupProgress) async -> Void
    ) async throws {
        let steps: [(SetupProgress.SetupStep, @Sendable () async throws -> Void)] = [
            (.detectPlatform, { [self] in try await self.detectAndValidatePlatform(progressCallback: progressCallback) }),
            (.installDependencies, { [self] in try await self.installDependencies(progressCallback: progressCallback) }),
            (.cloneRepository, { [self] in try await self.cloneRepository(url: repositoryURL, progressCallback: progressCallback) }),
            (.buildBackend, { [self] in try await self.buildBackend(progressCallback: progressCallback) }),
            (.startBackend, { [self] in try await self.startBackend(port: backendPort, progressCallback: progressCallback) }),
            (.healthCheck, { [self] in try await self.healthCheck(port: backendPort, progressCallback: progressCallback) })
        ]

        for (step, action) in steps {
            let inProgressMsg = SetupProgress(step: step, status: .inProgress, message: "Starting \(step.rawValue)...")
            currentProgress = inProgressMsg
            await progressCallback(inProgressMsg)
            do {
                try await action()
                let successMsg = SetupProgress(step: step, status: .success, message: "\(step.rawValue) complete")
                currentProgress = successMsg
                await progressCallback(successMsg)
            } catch {
                let failMsg = SetupProgress(step: step, status: .failure, message: error.localizedDescription)
                currentProgress = failMsg
                await progressCallback(failMsg)
                throw error
            }
        }
    }

    private func detectAndValidatePlatform(progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        let platform = try await sshService.detectPlatform()
        guard platform.isSupported else {
            throw Abort(.badRequest, reason: platform.rejectionReason ?? "Unsupported platform")
        }
    }

    private func installDependencies(progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        let platform = try await sshService.detectPlatform()
        let installCmd: String
        if platform.platform == "Darwin" {
            installCmd = "which swift || (curl -sL https://swift.org/install.sh | bash)"
        } else {
            installCmd = "which swift || (apt-get update -qq && apt-get install -y -qq swift 2>/dev/null || yum install -y swift 2>/dev/null || (curl -sL https://swift.org/install.sh | bash))"
        }
        let result = try await sshService.executeCommand(installCmd)
        if result.exitCode != 0 && !result.stdout.contains("swift") {
            throw Abort(.internalServerError, reason: "Failed to install Swift: \(result.stderr)")
        }
    }

    private func cloneRepository(url: String?, progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        guard let repoURL = url else {
            throw Abort(.badRequest, reason: "Repository URL is required for remote setup")
        }
        let result = try await sshService.executeCommand(
            "cd ~ && ([ -d ils-ios ] && cd ils-ios && git pull || git clone \(repoURL) ils-ios)"
        )
        guard result.exitCode == 0 else {
            throw Abort(.internalServerError, reason: "Clone failed: \(result.stderr)")
        }
    }

    private func buildBackend(progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        let result = try await sshService.executeCommand("cd ~/ils-ios && swift build --product ILSBackend 2>&1")
        guard result.exitCode == 0 else {
            throw Abort(.internalServerError, reason: "Build failed: \(result.stderr)")
        }
    }

    private func startBackend(port: Int, progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        _ = try await sshService.executeCommand(
            "cd ~/ils-ios && nohup PORT=\(port) swift run ILSBackend > ~/ils-backend.log 2>&1 &"
        )
        try await Task.sleep(nanoseconds: 3_000_000_000)
    }

    private func healthCheck(port: Int, progressCallback: @escaping @Sendable (SetupProgress) async -> Void) async throws {
        let result = try await sshService.executeCommand("curl -sf http://localhost:\(port)/health || echo 'FAIL'")
        guard !result.stdout.contains("FAIL") else {
            throw Abort(.internalServerError, reason: "Backend health check failed after startup")
        }
    }
}
