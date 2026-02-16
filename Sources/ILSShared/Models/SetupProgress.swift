import Foundation

/// Tracks progress of a remote host setup operation.
public struct SetupProgress: Codable, Hashable, Sendable {
    /// The current setup step being executed.
    public let step: SetupStep
    /// Status of the current step.
    public let status: StepStatus
    /// Human-readable progress message.
    public let message: String
    /// Optional progress percentage (0.0 to 1.0).
    public let progress: Double?

    /// Individual steps in the remote host setup process.
    public enum SetupStep: String, Codable, Sendable, CaseIterable {
        /// Establishing SSH connection to the remote host.
        case connectSSH = "connect_ssh"
        /// Detecting the remote platform (macOS, Linux, etc.).
        case detectPlatform = "detect_platform"
        /// Installing required dependencies on the remote host.
        case installDependencies = "install_dependencies"
        /// Cloning the ILS repository.
        case cloneRepository = "clone_repository"
        /// Building the ILS backend from source.
        case buildBackend = "build_backend"
        /// Starting the ILS backend service.
        case startBackend = "start_backend"
        /// Verifying the backend is responding to health checks.
        case healthCheck = "health_check"
        /// Setting up a tunnel for remote access.
        case setupTunnel = "setup_tunnel"
    }

    /// Status of an individual setup step.
    public enum StepStatus: String, Codable, Sendable {
        /// Step has not started yet.
        case pending
        /// Step is currently executing.
        case inProgress = "in_progress"
        /// Step completed successfully.
        case success
        /// Step failed with an error.
        case failure
        /// Step was skipped (not required).
        case skipped
    }

    /// Creates a new setup progress entry.
    /// - Parameters:
    ///   - step: The setup step being tracked.
    ///   - status: Current status of the step.
    ///   - message: Human-readable description of progress.
    ///   - progress: Optional progress percentage (0.0 to 1.0).
    public init(step: SetupStep, status: StepStatus, message: String, progress: Double? = nil) {
        self.step = step
        self.status = status
        self.message = message
        self.progress = progress
    }
}
