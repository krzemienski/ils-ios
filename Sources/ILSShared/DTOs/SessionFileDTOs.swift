import Foundation

// MARK: - File Change Type

/// The type of change made to a file during a Claude Code session.
public enum FileChangeType: String, Codable, Sendable, CaseIterable {
    /// File was created for the first time in this session.
    case created
    /// File was modified (edited) in this session.
    case modified
    /// File no longer exists on disk (deleted or moved).
    case deleted
}

// MARK: - Session File Change

/// Represents a single file that was created, modified, or deleted during a Claude Code session.
public struct SessionFileChange: Codable, Sendable, Identifiable {
    /// Unique identifier — equal to `path`.
    public let id: String
    /// Relative or absolute path of the file as recorded in the transcript.
    public let path: String
    /// Whether the file was created, modified, or deleted.
    public let changeType: FileChangeType
    /// Programming language inferred from the file extension (e.g. "swift", "python").
    public let language: String?
    /// Names of the Claude Code tools that touched this file (e.g. ["Write", "Edit"]).
    public let toolNames: [String]
    /// Whether the file currently exists on disk at the time of the API response.
    public let fileExists: Bool

    public init(
        id: String,
        path: String,
        changeType: FileChangeType,
        language: String?,
        toolNames: [String],
        fileExists: Bool
    ) {
        self.id = id
        self.path = path
        self.changeType = changeType
        self.language = language
        self.toolNames = toolNames
        self.fileExists = fileExists
    }
}

// MARK: - Session Files Response

/// Response containing all files touched during a Claude Code session.
public struct SessionFilesResponse: Codable, Sendable {
    /// All files that were created, modified, or deleted in the session.
    public let files: [SessionFileChange]
    /// Absolute path to the project root used to resolve relative file paths.
    public let projectPath: String?
    /// The Claude Code session identifier.
    public let sessionId: String

    public init(files: [SessionFileChange], projectPath: String?, sessionId: String) {
        self.files = files
        self.projectPath = projectPath
        self.sessionId = sessionId
    }
}
