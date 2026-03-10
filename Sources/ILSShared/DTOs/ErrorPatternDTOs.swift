import Foundation

// MARK: - Error Pattern

/// A suggested fix for a recurring error pattern.
public struct ErrorFix: Codable, Sendable, Identifiable {
    /// Unique identifier for this fix.
    public let id: UUID
    /// Human-readable description of the fix.
    public let description: String
    /// The prompt text to send to Claude to apply this fix.
    public let fixPrompt: String
    /// Number of times this fix has been successfully applied.
    public let successCount: Int
    /// Number of times this fix was applied but did not resolve the issue.
    public let failureCount: Int
    /// Confidence score from 0.0 to 1.0, based on resolution success rate.
    public let confidence: Double

    public init(
        id: UUID = UUID(),
        description: String,
        fixPrompt: String,
        successCount: Int,
        failureCount: Int,
        confidence: Double
    ) {
        self.id = id
        self.description = description
        self.fixPrompt = fixPrompt
        self.successCount = successCount
        self.failureCount = failureCount
        self.confidence = confidence
    }
}

/// A recurring error pattern detected across sessions.
public struct ErrorPattern: Codable, Sendable, Identifiable {
    /// Unique identifier for this error pattern.
    public let id: UUID
    /// Project name this pattern was detected in.
    public let projectName: String
    /// Category of error (e.g., "compilation", "test_failure", "lint", "runtime").
    public let errorType: String
    /// Short summary of the error pattern.
    public let summary: String
    /// Representative error message or stack trace excerpt.
    public let errorSignature: String
    /// Number of times this pattern has occurred across sessions.
    public let occurrenceCount: Int
    /// Number of sessions that exhibited this error pattern.
    public let affectedSessionCount: Int
    /// ISO-8601 timestamp of the first occurrence.
    public let firstSeenAt: String
    /// ISO-8601 timestamp of the most recent occurrence.
    public let lastSeenAt: String
    /// Whether this pattern has been marked as resolved.
    public let isResolved: Bool
    /// Suggested fixes ranked by confidence descending.
    public let suggestedFixes: [ErrorFix]

    public init(
        id: UUID = UUID(),
        projectName: String,
        errorType: String,
        summary: String,
        errorSignature: String,
        occurrenceCount: Int,
        affectedSessionCount: Int,
        firstSeenAt: String,
        lastSeenAt: String,
        isResolved: Bool,
        suggestedFixes: [ErrorFix]
    ) {
        self.id = id
        self.projectName = projectName
        self.errorType = errorType
        self.summary = summary
        self.errorSignature = errorSignature
        self.occurrenceCount = occurrenceCount
        self.affectedSessionCount = affectedSessionCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isResolved = isResolved
        self.suggestedFixes = suggestedFixes
    }
}

// MARK: - Response Types

/// Response containing the top recurring error patterns for a project.
public struct ErrorPatternListResponse: Codable, Sendable {
    /// Project name these patterns belong to.
    public let projectName: String
    /// Recurring error patterns ordered by occurrence count descending.
    public let patterns: [ErrorPattern]
    /// Total number of error patterns detected for this project.
    public let total: Int
    /// Number of patterns that are unresolved.
    public let unresolvedCount: Int

    public init(
        projectName: String,
        patterns: [ErrorPattern],
        total: Int? = nil,
        unresolvedCount: Int
    ) {
        self.projectName = projectName
        self.patterns = patterns
        self.total = total ?? patterns.count
        self.unresolvedCount = unresolvedCount
    }
}

// MARK: - Request Types

/// Request to record an error occurrence for pattern detection.
public struct RecordErrorRequest: Codable, Sendable {
    /// The project name the error occurred in.
    public let projectName: String
    /// Category of error (e.g., "compilation", "test_failure", "lint", "runtime").
    public let errorType: String
    /// The raw error message or stack trace excerpt.
    public let errorMessage: String
    /// Optional session ID where this error occurred.
    public let sessionId: UUID?

    public init(
        projectName: String,
        errorType: String,
        errorMessage: String,
        sessionId: UUID? = nil
    ) {
        self.projectName = projectName
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.sessionId = sessionId
    }
}

/// Request to apply a suggested fix to a session.
public struct ApplyFixRequest: Codable, Sendable {
    /// The error pattern ID the fix belongs to.
    public let patternId: UUID
    /// The fix ID to apply.
    public let fixId: UUID
    /// The session ID to send the fix prompt to.
    public let sessionId: UUID

    public init(patternId: UUID, fixId: UUID, sessionId: UUID) {
        self.patternId = patternId
        self.fixId = fixId
        self.sessionId = sessionId
    }
}

/// Request to mark an error pattern as resolved.
public struct MarkResolvedRequest: Codable, Sendable {
    /// The error pattern ID to mark as resolved.
    public let patternId: UUID
    /// Optional fix ID that resolved the pattern, if a suggested fix was used.
    public let resolvedByFixId: UUID?
    /// Optional note describing how the pattern was resolved.
    public let resolutionNote: String?

    public init(
        patternId: UUID,
        resolvedByFixId: UUID? = nil,
        resolutionNote: String? = nil
    ) {
        self.patternId = patternId
        self.resolvedByFixId = resolvedByFixId
        self.resolutionNote = resolutionNote
    }
}
