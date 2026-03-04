import Foundation

// MARK: - Terminal Requests

/// Request payload for executing a shell command in the embedded terminal.
public struct TerminalExecuteRequest: Codable, Sendable {
    /// Shell command to execute.
    public let command: String
    /// Working directory in which to run the command. `nil` uses the server's current directory.
    public let workingDirectory: String?
    /// Optional execution timeout in seconds. `nil` means no timeout is applied.
    public let timeout: Int?
    /// Additional environment variables to inject for this command only.
    public let environment: [String: String]?

    /// Creates a new terminal execute request.
    /// - Parameters:
    ///   - command: Shell command to execute.
    ///   - workingDirectory: Optional working directory for the command.
    ///   - timeout: Optional timeout in seconds before the command is terminated.
    ///   - environment: Optional additional environment variables for this execution.
    public init(
        command: String,
        workingDirectory: String? = nil,
        timeout: Int? = nil,
        environment: [String: String]? = nil
    ) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.timeout = timeout
        self.environment = environment
    }
}

// MARK: - Terminal Responses

/// Response containing the output of an executed terminal command.
public struct TerminalExecuteResponse: Codable, Sendable {
    /// Standard output produced by the command.
    public let stdout: String
    /// Standard error output produced by the command.
    public let stderr: String
    /// Exit code returned by the command (0 typically indicates success).
    public let exitCode: Int
    /// Duration in seconds that the command took to execute.
    public let duration: TimeInterval
    /// Working directory the command was executed in.
    public let workingDirectory: String

    /// Creates a new terminal execute response.
    /// - Parameters:
    ///   - stdout: Standard output from the command.
    ///   - stderr: Standard error output from the command.
    ///   - exitCode: Exit status code of the command.
    ///   - duration: Execution duration in seconds.
    ///   - workingDirectory: Directory the command was executed in.
    public init(
        stdout: String,
        stderr: String,
        exitCode: Int,
        duration: TimeInterval,
        workingDirectory: String
    ) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.duration = duration
        self.workingDirectory = workingDirectory
    }
}

// MARK: - Terminal Streaming

/// The output stream type for a terminal streaming message.
public enum TerminalStreamType: String, Codable, Sendable {
    /// Standard output data.
    case stdout
    /// Standard error data.
    case stderr
    /// Signals that the command has finished executing.
    case exit
}

/// A single streamed chunk of terminal output, used for real-time command output delivery.
public struct TerminalStreamMessage: Codable, Sendable {
    /// The type of stream this message originated from.
    public let type: TerminalStreamType
    /// The text content of this output chunk.
    public let data: String
    /// Exit code of the command; non-`nil` only when `type` is `.exit`.
    public let exitCode: Int?
    /// Timestamp when this chunk was produced.
    public let timestamp: Date

    /// Creates a new terminal stream message.
    /// - Parameters:
    ///   - type: The stream type (stdout, stderr, or exit).
    ///   - data: Text content of this output chunk.
    ///   - exitCode: Exit code; only populated for `.exit` type messages.
    ///   - timestamp: When this chunk was produced (default: now).
    public init(
        type: TerminalStreamType,
        data: String,
        exitCode: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.data = data
        self.exitCode = exitCode
        self.timestamp = timestamp
    }
}

// MARK: - Terminal History

/// A single entry in the terminal command history.
public struct TerminalHistoryEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for this history entry.
    public let id: UUID
    /// The command that was executed.
    public let command: String
    /// Working directory the command was executed in.
    public let workingDirectory: String
    /// Exit code returned by the command.
    public let exitCode: Int
    /// Timestamp when the command was executed.
    public let executedAt: Date
    /// Duration in seconds the command took to complete.
    public let duration: TimeInterval

    /// Creates a new terminal history entry.
    /// - Parameters:
    ///   - id: Unique identifier (default: new UUID).
    ///   - command: The command that was executed.
    ///   - workingDirectory: Directory the command ran in.
    ///   - exitCode: Exit status code of the command.
    ///   - executedAt: When the command was executed (default: now).
    ///   - duration: Execution duration in seconds.
    public init(
        id: UUID = UUID(),
        command: String,
        workingDirectory: String,
        exitCode: Int,
        executedAt: Date = Date(),
        duration: TimeInterval
    ) {
        self.id = id
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = exitCode
        self.executedAt = executedAt
        self.duration = duration
    }
}

// MARK: - Terminal Configuration

/// The preferred shell for the embedded terminal.
public enum TerminalShell: String, Codable, Sendable, CaseIterable {
    /// The Bourne-Again SHell.
    case bash = "/bin/bash"
    /// The Z Shell.
    case zsh = "/bin/zsh"
    /// The system default shell (reads from the user's shell preference).
    case `default` = "default"
}

/// Configuration for the embedded terminal, including shell selection and environment.
public struct TerminalConfig: Codable, Sendable {
    /// The shell to use for command execution.
    public let shell: TerminalShell
    /// Maximum number of history entries to retain.
    public let historyLimit: Int
    /// Additional environment variables to apply to every terminal command.
    public let environment: [String: String]
    /// Whether to source shell profile files (e.g., `.bashrc`, `.zshrc`) before executing commands.
    public let sourceProfile: Bool
    /// Default working directory for new terminal sessions. `nil` uses the backend's working directory.
    public let defaultWorkingDirectory: String?

    /// Creates a new terminal configuration.
    /// - Parameters:
    ///   - shell: The shell to use (default: `.default`).
    ///   - historyLimit: Maximum history entries to retain (default: 500).
    ///   - environment: Additional environment variables for all commands (default: empty).
    ///   - sourceProfile: Whether to source shell profile files (default: true).
    ///   - defaultWorkingDirectory: Optional default working directory for sessions.
    public init(
        shell: TerminalShell = .default,
        historyLimit: Int = 500,
        environment: [String: String] = [:],
        sourceProfile: Bool = true,
        defaultWorkingDirectory: String? = nil
    ) {
        self.shell = shell
        self.historyLimit = historyLimit
        self.environment = environment
        self.sourceProfile = sourceProfile
        self.defaultWorkingDirectory = defaultWorkingDirectory
    }
}
