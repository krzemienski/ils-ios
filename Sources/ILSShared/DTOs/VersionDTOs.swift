import Foundation

// MARK: - Current Version Response

/// Current Claude Code CLI version information.
public struct CurrentVersionResponse: Codable, Sendable {
    /// Semantic version string (e.g., "1.2.3").
    public let version: String
    /// Installation method detected (npm, brew, manual, unknown).
    public let installMethod: String
    /// Full path to the CLI binary.
    public let binaryPath: String?
    /// Timestamp when version was last detected.
    public let detectedAt: Date

    public init(
        version: String,
        installMethod: String,
        binaryPath: String? = nil,
        detectedAt: Date
    ) {
        self.version = version
        self.installMethod = installMethod
        self.binaryPath = binaryPath
        self.detectedAt = detectedAt
    }
}

// MARK: - Version History

/// Single entry in version history tracking when a version was detected.
public struct VersionHistoryEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for the history entry.
    public let id: UUID
    /// Semantic version string.
    public let version: String
    /// Installation method at time of detection.
    public let installMethod: String
    /// Timestamp when this version was first detected.
    public let detectedAt: Date
    /// Whether this was an automatic or manual detection.
    public let wasAutoDetected: Bool

    public init(
        id: UUID = UUID(),
        version: String,
        installMethod: String,
        detectedAt: Date,
        wasAutoDetected: Bool = true
    ) {
        self.id = id
        self.version = version
        self.installMethod = installMethod
        self.detectedAt = detectedAt
        self.wasAutoDetected = wasAutoDetected
    }
}

/// Response containing version history records.
public struct VersionHistoryResponse: Codable, Sendable {
    /// Array of version history entries, ordered by detection date (newest first).
    public let entries: [VersionHistoryEntry]
    /// Total number of version changes detected.
    public let totalCount: Int

    public init(entries: [VersionHistoryEntry], totalCount: Int) {
        self.entries = entries
        self.totalCount = totalCount
    }
}

// MARK: - Update Check Response

/// Information about available Claude Code CLI updates.
public struct UpdateCheckResponse: Codable, Sendable {
    /// Current installed version.
    public let currentVersion: String
    /// Latest available version from GitHub.
    public let latestVersion: String
    /// Whether an update is available.
    public let updateAvailable: Bool
    /// Release notes/changelog for the latest version.
    public let changelog: String?
    /// URL to the GitHub release page.
    public let releaseUrl: String?
    /// Whether the update contains breaking changes.
    public let hasBreakingChanges: Bool
    /// Timestamp of the latest release.
    public let releasedAt: Date?
    /// Timestamp when this check was performed.
    public let checkedAt: Date

    public init(
        currentVersion: String,
        latestVersion: String,
        updateAvailable: Bool,
        changelog: String? = nil,
        releaseUrl: String? = nil,
        hasBreakingChanges: Bool = false,
        releasedAt: Date? = nil,
        checkedAt: Date
    ) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.updateAvailable = updateAvailable
        self.changelog = changelog
        self.releaseUrl = releaseUrl
        self.hasBreakingChanges = hasBreakingChanges
        self.releasedAt = releasedAt
        self.checkedAt = checkedAt
    }
}

// MARK: - Compatibility Check Response

/// Compatibility status between ILS version and Claude Code CLI version.
public struct CompatibilityCheckResponse: Codable, Sendable {
    /// Current ILS app version.
    public let ilsVersion: String
    /// Current Claude Code CLI version.
    public let cliVersion: String
    /// Whether versions are compatible.
    public let isCompatible: Bool
    /// Compatibility status level.
    public let status: CompatibilityStatus
    /// Human-readable message about compatibility.
    public let message: String
    /// Recommended CLI version range for current ILS version.
    public let recommendedCliVersionRange: String?

    public init(
        ilsVersion: String,
        cliVersion: String,
        isCompatible: Bool,
        status: CompatibilityStatus,
        message: String,
        recommendedCliVersionRange: String? = nil
    ) {
        self.ilsVersion = ilsVersion
        self.cliVersion = cliVersion
        self.isCompatible = isCompatible
        self.status = status
        self.message = message
        self.recommendedCliVersionRange = recommendedCliVersionRange
    }

    /// Compatibility status levels.
    public enum CompatibilityStatus: String, Codable, Sendable {
        /// Fully compatible, no issues expected.
        case compatible
        /// Compatible with minor warnings.
        case warning
        /// Known incompatibility, may cause issues.
        case incompatible
        /// Compatibility status unknown.
        case unknown
    }
}

// MARK: - Update Instructions Response

/// Installation-specific update instructions for Claude Code CLI.
public struct UpdateInstructionsResponse: Codable, Sendable {
    /// Installation method detected.
    public let installMethod: String
    /// Command to run for update.
    public let updateCommand: String
    /// Additional instructions or notes.
    public let instructions: String
    /// URL to official update documentation.
    public let documentationUrl: String?

    public init(
        installMethod: String,
        updateCommand: String,
        instructions: String,
        documentationUrl: String? = nil
    ) {
        self.installMethod = installMethod
        self.updateCommand = updateCommand
        self.instructions = instructions
        self.documentationUrl = documentationUrl
    }
}
