import Foundation
import ILSShared

// MARK: - Internal Storage Models

/// Internal mutable record for a stored fix, used within ErrorPatternStore.
fileprivate struct StoredFix {
    var id: UUID
    var description: String
    var fixPrompt: String
    var successCount: Int
    var failureCount: Int

    /// Confidence score based on historical success rate.
    /// Defaults to 0.5 when no outcomes have been recorded.
    var confidence: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0.5 }
        return Double(successCount) / Double(total)
    }

    /// Convert to the shared DTO for API responses.
    func toDTO() -> ErrorFix {
        ErrorFix(
            id: id,
            description: description,
            fixPrompt: fixPrompt,
            successCount: successCount,
            failureCount: failureCount,
            confidence: confidence
        )
    }
}

/// Internal mutable record for a stored error pattern, used within ErrorPatternStore.
fileprivate struct StoredPattern {
    var id: UUID
    var projectName: String
    var errorType: String
    var summary: String
    var errorSignature: String
    var occurrenceCount: Int
    var affectedSessionIds: Set<UUID>
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isResolved: Bool
    var fixes: [StoredFix]

    /// Convert to the shared DTO for API responses.
    func toDTO() -> ErrorPattern {
        let iso = ISO8601DateFormatter()
        let sortedFixes = fixes
            .sorted { $0.confidence > $1.confidence }
            .map { $0.toDTO() }

        return ErrorPattern(
            id: id,
            projectName: projectName,
            errorType: errorType,
            summary: summary,
            errorSignature: errorSignature,
            occurrenceCount: occurrenceCount,
            affectedSessionCount: affectedSessionIds.count,
            firstSeenAt: iso.string(from: firstSeenAt),
            lastSeenAt: iso.string(from: lastSeenAt),
            isResolved: isResolved,
            suggestedFixes: sortedFixes
        )
    }
}

// MARK: - Error Pattern Store

/// Actor-backed in-memory store for error patterns and fix outcome tracking.
///
/// Patterns are keyed by their normalized error signature. This actor owns all
/// mutable state and serialises access so callers never race on pattern records.
actor ErrorPatternStore {

    /// Patterns keyed by normalized signature (lowercased).
    private var patterns: [String: StoredPattern] = [:]

    // MARK: - Pattern Recording

    /// Record a single error occurrence, creating a new pattern or incrementing an existing one.
    /// - Parameters:
    ///   - signature: Normalized error signature used for deduplication.
    ///   - projectName: Project the error occurred in.
    ///   - errorType: Classified error category (compilation, test_failure, lint, runtime, unknown).
    ///   - summary: Short human-readable summary of the error.
    ///   - sessionId: Session in which the error appeared.
    ///   - date: Timestamp of the occurrence.
    func recordOccurrence(
        signature: String,
        projectName: String,
        errorType: String,
        summary: String,
        sessionId: UUID,
        at date: Date
    ) {
        if var existing = patterns[signature] {
            existing.occurrenceCount += 1
            existing.affectedSessionIds.insert(sessionId)
            existing.lastSeenAt = date
            patterns[signature] = existing
        } else {
            let newPattern = StoredPattern(
                id: UUID(),
                projectName: projectName,
                errorType: errorType,
                summary: summary,
                errorSignature: signature,
                occurrenceCount: 1,
                affectedSessionIds: [sessionId],
                firstSeenAt: date,
                lastSeenAt: date,
                isResolved: false,
                fixes: []
            )
            patterns[signature] = newPattern
        }
    }

    // MARK: - Fix Management

    /// Add a new suggested fix to an existing pattern.
    /// - Parameters:
    ///   - patternId: UUID of the pattern to add the fix to.
    ///   - description: Human-readable fix description.
    ///   - fixPrompt: The prompt text to send to Claude to apply this fix.
    /// - Returns: The new fix UUID, or `nil` if the pattern was not found.
    func addFix(toPatternId patternId: UUID, description: String, fixPrompt: String) -> UUID? {
        guard let key = patterns.first(where: { $0.value.id == patternId })?.key else {
            return nil
        }
        let fix = StoredFix(
            id: UUID(),
            description: description,
            fixPrompt: fixPrompt,
            successCount: 0,
            failureCount: 0
        )
        patterns[key]?.fixes.append(fix)
        return fix.id
    }

    /// Record whether a fix application succeeded or failed, updating its confidence score.
    /// - Parameters:
    ///   - patternId: UUID of the pattern the fix belongs to.
    ///   - fixId: UUID of the fix that was applied.
    ///   - success: `true` if the fix resolved the error, `false` otherwise.
    func recordFixOutcome(patternId: UUID, fixId: UUID, success: Bool) {
        guard let key = patterns.first(where: { $0.value.id == patternId })?.key else { return }
        guard let fixIndex = patterns[key]?.fixes.firstIndex(where: { $0.id == fixId }) else { return }
        if success {
            patterns[key]?.fixes[fixIndex].successCount += 1
        } else {
            patterns[key]?.fixes[fixIndex].failureCount += 1
        }
    }

    // MARK: - Resolution

    /// Mark a pattern as resolved so it no longer surfaces in the active error list.
    /// - Parameter patternId: UUID of the pattern to mark resolved.
    func markResolved(patternId: UUID) {
        guard let key = patterns.first(where: { $0.value.id == patternId })?.key else { return }
        patterns[key]?.isResolved = true
    }

    // MARK: - Queries

    /// Retrieve the top-N patterns for a project, ordered by occurrence count.
    /// When `projectName` is empty, returns patterns across all projects.
    /// - Parameters:
    ///   - projectName: The project to filter by. Pass an empty string to include all projects.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Sorted array of matching `StoredPattern` records.
    fileprivate func topPatterns(forProject projectName: String, limit: Int) -> [StoredPattern] {
        let base = projectName.isEmpty ? Array(patterns.values) : patterns.values.filter { $0.projectName == projectName }
        return Array(
            base
                .sorted { $0.occurrenceCount > $1.occurrenceCount }
                .prefix(limit)
        )
    }

    /// Retrieve all patterns for a project (including resolved ones).
    /// When `projectName` is empty, returns patterns across all projects.
    /// - Parameter projectName: The project to filter by. Pass an empty string for all projects.
    /// - Returns: Array of all matching `StoredPattern` records.
    fileprivate func allPatterns(forProject projectName: String) -> [StoredPattern] {
        projectName.isEmpty ? Array(patterns.values) : patterns.values.filter { $0.projectName == projectName }
    }

    /// Look up a pattern by its UUID.
    /// - Parameter id: The pattern UUID.
    /// - Returns: The matching `StoredPattern`, or `nil` if not found.
    fileprivate func pattern(byId id: UUID) -> StoredPattern? {
        patterns.values.first { $0.id == id }
    }
}

// MARK: - Error Pattern Service

/// Service that detects, groups, and ranks recurring error patterns from session messages.
///
/// Extraction pipeline:
/// 1. Scan messages for lines that contain known error indicators.
/// 2. Normalize each error text (strip paths, line numbers) to produce a stable signature.
/// 3. Classify the error into a category (compilation, test_failure, lint, runtime, unknown).
/// 4. Record the occurrence in the ``ErrorPatternStore``, deduplicating by signature.
/// 5. Surface top-10 patterns per project ordered by occurrence count.
struct ErrorPatternService {

    // MARK: - Error Classification Keywords

    /// Keywords that indicate a Swift / Xcode compilation error.
    private static let compilationKeywords: [String] = [
        "error:", "build failed", "compilation failed", "cannot find type",
        "cannot find", "value of type", "no such file or directory",
        "undefined symbol", "linker command failed", "module not found",
        "use of unresolved identifier", "expression is ambiguous",
        "ambiguous reference"
    ]

    /// Keywords that indicate a test failure.
    private static let testKeywords: [String] = [
        "test failed", "tests failed", "xctest", "failed -",
        "xctassert", "test suite", "assertion failed", "failed (expected"
    ]

    /// Keywords that indicate a linting warning or violation.
    private static let lintKeywords: [String] = [
        "swiftlint", "violation", "trailing whitespace",
        "line length", "function body length", "cyclomatic complexity"
    ]

    /// Keywords that indicate a runtime crash or fatal condition.
    private static let runtimeKeywords: [String] = [
        "fatal error", "exc_bad_access", "precondition failed",
        "assertion failed:", "crashed", "sigabrt", "sigsegv",
        "stack overflow", "nil found", "unexpectedly found nil"
    ]

    // MARK: - Error Classification

    /// Classify a raw error message into a category string.
    ///
    /// Precedence order: compilation → test_failure → runtime → lint → unknown.
    /// - Parameter text: Raw error message text.
    /// - Returns: One of `"compilation"`, `"test_failure"`, `"lint"`, `"runtime"`, `"unknown"`.
    func classifyErrorType(_ text: String) -> String {
        let lower = text.lowercased()

        for keyword in Self.compilationKeywords where lower.contains(keyword) {
            return "compilation"
        }
        for keyword in Self.testKeywords where lower.contains(keyword) {
            return "test_failure"
        }
        for keyword in Self.runtimeKeywords where lower.contains(keyword) {
            return "runtime"
        }
        for keyword in Self.lintKeywords where lower.contains(keyword) {
            return "lint"
        }
        return "unknown"
    }

    // MARK: - Pattern Normalisation

    /// Normalise an error message by stripping variable parts (paths, line numbers).
    ///
    /// Normalisation steps:
    /// 1. Replace absolute file paths with `<path>`.
    /// 2. Replace `line:column` location references with `<loc>`.
    /// 3. Replace bare `line N` phrases with `line <n>`.
    /// 4. Lowercase the result.
    /// 5. Truncate to 200 characters for stable storage keys.
    ///
    /// - Parameter text: Raw error message text.
    /// - Returns: Normalised, lowercase signature suitable for deduplication.
    func normalizeSignature(_ text: String) -> String {
        var normalized = text

        // Strip absolute paths (e.g. /Users/nick/project/Sources/Foo.swift)
        normalized = normalized.replacingOccurrences(
            of: #"(/[\w./\-]+\.\w+)"#,
            with: "<path>",
            options: .regularExpression
        )

        // Strip line:column references (e.g. :42:7)
        normalized = normalized.replacingOccurrences(
            of: #":\d+:\d+"#,
            with: ":<loc>",
            options: .regularExpression
        )

        // Strip bare line-number phrases (e.g. "line 42")
        normalized = normalized.replacingOccurrences(
            of: #"\bline \d+\b"#,
            with: "line <n>",
            options: .regularExpression
        )

        // Lowercase and trim whitespace
        normalized = normalized.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Truncate to 200 characters for a stable dedup key
        if normalized.count > 200 {
            normalized = String(normalized.prefix(200))
        }

        return normalized
    }

    /// Extract a concise human-readable summary from an error message.
    ///
    /// Returns the first non-empty line of the error text, trimmed and truncated to 120 chars.
    /// - Parameter text: Raw error message text.
    /// - Returns: Short summary string.
    func extractSummary(_ text: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(120))
    }

    // MARK: - Error Line Extraction

    /// Extract lines from a message that appear to contain error content.
    ///
    /// Strategy: scan for trigger lines, then accumulate up to 5 continuation lines to
    /// capture stack-trace context. Each flush yields one error fragment.
    ///
    /// - Parameter text: Full message text to scan.
    /// - Returns: Array of error text fragments (each may span multiple lines).
    private func extractErrorLines(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var errors: [String] = []
        var errorBuffer: [String] = []
        var inErrorBlock = false

        for line in lines {
            let lower = line.lowercased()
            let isTriggerLine = lower.contains("error:")
                || lower.contains("fatal error")
                || lower.contains("build failed")
                || lower.contains("compilation failed")
                || lower.contains("test failed")
                || lower.contains("tests failed")

            if isTriggerLine {
                // Flush any prior buffer before starting a new error block
                if !errorBuffer.isEmpty {
                    errors.append(errorBuffer.joined(separator: "\n"))
                    errorBuffer = []
                }
                errorBuffer.append(line)
                inErrorBlock = true
            } else if inErrorBlock && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Accumulate context lines for the current error block
                errorBuffer.append(line)
                if errorBuffer.count >= 5 {
                    errors.append(errorBuffer.joined(separator: "\n"))
                    errorBuffer = []
                    inErrorBlock = false
                }
            } else {
                // Blank or unrelated line — flush any accumulated buffer
                if !errorBuffer.isEmpty {
                    errors.append(errorBuffer.joined(separator: "\n"))
                    errorBuffer = []
                }
                inErrorBlock = false
            }
        }

        // Flush any remaining buffer
        if !errorBuffer.isEmpty {
            errors.append(errorBuffer.joined(separator: "\n"))
        }

        return errors
    }

    // MARK: - Pattern Detection

    /// Detect and record error patterns found in a session's messages.
    ///
    /// Each message is scanned for error trigger lines. Extracted errors are normalised
    /// and recorded in the store, deduplicating across sessions by signature.
    ///
    /// - Parameters:
    ///   - messages: All messages belonging to the session.
    ///   - session: The session the messages belong to.
    ///   - store: The actor-backed store to record occurrences into.
    func detectPatterns(
        from messages: [Message],
        session: ChatSession,
        store: ErrorPatternStore
    ) async {
        let projectName = session.projectName ?? "unknown"
        let now = Date()

        for message in messages {
            guard !message.content.isEmpty else { continue }

            let errorFragments = extractErrorLines(from: message.content)

            for fragment in errorFragments {
                let trimmed = fragment.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }

                let signature = normalizeSignature(trimmed)
                let errorType = classifyErrorType(trimmed)
                let summary = extractSummary(trimmed)

                await store.recordOccurrence(
                    signature: signature,
                    projectName: projectName,
                    errorType: errorType,
                    summary: summary,
                    sessionId: session.id,
                    at: now
                )
            }
        }
    }

    // MARK: - Fix Management

    /// Add a new suggested fix to an existing pattern.
    /// - Parameters:
    ///   - patternId: UUID of the pattern to add the fix to.
    ///   - description: Human-readable fix description.
    ///   - fixPrompt: The prompt to send to Claude to apply this fix.
    ///   - store: The error pattern store.
    /// - Returns: The new fix UUID, or `nil` if the pattern was not found.
    @discardableResult
    func addFix(
        toPattern patternId: UUID,
        description: String,
        fixPrompt: String,
        store: ErrorPatternStore
    ) async -> UUID? {
        await store.addFix(toPatternId: patternId, description: description, fixPrompt: fixPrompt)
    }

    /// Record the outcome of applying a suggested fix.
    /// - Parameters:
    ///   - patternId: UUID of the pattern the fix belongs to.
    ///   - fixId: UUID of the fix that was applied.
    ///   - success: `true` if the fix resolved the error, `false` otherwise.
    ///   - store: The error pattern store.
    func recordFixOutcome(
        patternId: UUID,
        fixId: UUID,
        success: Bool,
        store: ErrorPatternStore
    ) async {
        await store.recordFixOutcome(patternId: patternId, fixId: fixId, success: success)
    }

    /// Mark an error pattern as resolved so it no longer appears in the active list.
    /// - Parameters:
    ///   - patternId: UUID of the pattern to mark resolved.
    ///   - store: The error pattern store.
    func markResolved(patternId: UUID, store: ErrorPatternStore) async {
        await store.markResolved(patternId: patternId)
    }

    // MARK: - Queries

    /// Return the top-N error patterns for a project, ordered by occurrence count descending.
    /// - Parameters:
    ///   - projectName: The project to query.
    ///   - limit: Maximum number of patterns to return (default: 10).
    ///   - store: The error pattern store.
    /// - Returns: Array of `ErrorPattern` DTOs ordered by occurrence count descending.
    func topPatterns(
        forProject projectName: String,
        limit: Int = 10,
        store: ErrorPatternStore
    ) async -> [ErrorPattern] {
        let stored = await store.topPatterns(forProject: projectName, limit: limit)
        return stored.map { $0.toDTO() }
    }

    /// Retrieve a single pattern by its UUID.
    /// - Parameters:
    ///   - id: The pattern UUID.
    ///   - store: The error pattern store.
    /// - Returns: The `ErrorPattern` DTO if found, `nil` otherwise.
    func pattern(byId id: UUID, store: ErrorPatternStore) async -> ErrorPattern? {
        await store.pattern(byId: id)?.toDTO()
    }

    // MARK: - List Response

    /// Build a full list response for a project's error patterns.
    ///
    /// Returns the top-N patterns along with aggregate counts for the response envelope.
    /// - Parameters:
    ///   - projectName: The project to query.
    ///   - limit: Maximum number of patterns to include in the response (default: 10).
    ///   - store: The error pattern store.
    /// - Returns: `ErrorPatternListResponse` with sorted patterns and summary counts.
    func listResponse(
        forProject projectName: String,
        limit: Int = 10,
        store: ErrorPatternStore
    ) async -> ErrorPatternListResponse {
        let all = await store.allPatterns(forProject: projectName)
        let unresolvedCount = all.filter { !$0.isResolved }.count
        let topPatterns = Array(
            all
                .sorted { $0.occurrenceCount > $1.occurrenceCount }
                .prefix(limit)
        ).map { $0.toDTO() }

        return ErrorPatternListResponse(
            projectName: projectName,
            patterns: topPatterns,
            total: all.count,
            unresolvedCount: unresolvedCount
        )
    }
}
