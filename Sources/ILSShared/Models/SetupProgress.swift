import Foundation

public struct SetupProgress: Codable, Sendable {
    public let step: SetupStep
    public let status: StepStatus
    public let message: String
    public let progress: Double?

    public enum SetupStep: String, Codable, Sendable, CaseIterable {
        case connectSSH = "connect_ssh"
        case detectPlatform = "detect_platform"
        case installDependencies = "install_dependencies"
        case cloneRepository = "clone_repository"
        case buildBackend = "build_backend"
        case startBackend = "start_backend"
        case healthCheck = "health_check"
    }

    public enum StepStatus: String, Codable, Sendable {
        case pending
        case inProgress = "in_progress"
        case success
        case failure
        case skipped
    }

    public init(step: SetupStep, status: StepStatus, message: String, progress: Double? = nil) {
        self.step = step
        self.status = status
        self.message = message
        self.progress = progress
    }
}
