import Foundation
import Observation
import ILSShared

// MARK: - ErrorPatternsViewModel

/// View model for AI-powered error pattern detection and auto-fix suggestions.
///
/// Fetches recurring error patterns detected across sessions for a given project,
/// records new error occurrences, resolves patterns, and applies suggested fixes
/// by sending the fix prompt to a Claude session.
///
/// ## Usage
/// ```swift
/// let vm = ErrorPatternsViewModel()
/// vm.configure(client: apiClient)
/// await vm.loadPatterns()
/// await vm.applyFix(fix: fix, pattern: pattern, sessionId: sessionId)
/// ```
@MainActor
@Observable
class ErrorPatternsViewModel {
    /// Recurring error patterns for the selected project.
    var patterns: [ErrorPattern] = []
    /// Project name filter; nil loads patterns across all projects.
    var selectedProject: String?
    /// Whether patterns are currently loading.
    var isLoading = false
    /// Current error, if any.
    var error: Error?

    private var client: APIClient?

    init() {}

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed

    /// Empty state text for UI display.
    var emptyStateText: String {
        if isLoading {
            return "Analyzing error patterns..."
        }
        return patterns.isEmpty ? "No recurring error patterns detected" : ""
    }

    /// Number of unresolved patterns.
    var unresolvedCount: Int {
        patterns.filter { !$0.isResolved }.count
    }

    // MARK: - Load

    /// Load recurring error patterns, optionally filtered by project.
    func loadPatterns() async {
        guard let client else { return }
        isLoading = true
        error = nil

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "limit", value: "10")
        ]
        if let selectedProject {
            components.queryItems?.append(URLQueryItem(name: "projectName", value: selectedProject))
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        do {
            let response: APIResponse<ErrorPatternListResponse> = try await client.get("/error-patterns\(query)")
            if let data = response.data {
                patterns = data.patterns
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load error patterns: \(error.localizedDescription)",
                category: "error-patterns"
            )
        }

        isLoading = false
    }

    // MARK: - Record Error

    /// Record a new error occurrence for pattern detection.
    /// - Parameters:
    ///   - projectName: The project where the error occurred.
    ///   - errorType: Category of error (e.g. "compilation", "test_failure").
    ///   - errorMessage: The raw error message or stack trace excerpt.
    ///   - sessionId: Optional session ID where this error occurred.
    func recordError(
        projectName: String,
        errorType: String,
        errorMessage: String,
        sessionId: UUID? = nil
    ) async {
        guard let client else { return }
        let request = RecordErrorRequest(
            projectName: projectName,
            errorType: errorType,
            errorMessage: errorMessage,
            sessionId: sessionId
        )
        do {
            let _: APIResponse<ErrorPattern> = try await client.post("/error-patterns/record", body: request)
            await loadPatterns()
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to record error: \(error.localizedDescription)",
                category: "error-patterns"
            )
        }
    }

    // MARK: - Resolve Pattern

    /// Mark an error pattern as resolved.
    /// - Parameters:
    ///   - pattern: The error pattern to resolve.
    ///   - fixId: Optional fix ID that resolved the pattern.
    ///   - note: Optional note describing the resolution.
    func resolvePattern(
        _ pattern: ErrorPattern,
        fixId: UUID? = nil,
        note: String? = nil
    ) async {
        guard let client else { return }
        let request = MarkResolvedRequest(
            patternId: pattern.id,
            resolvedByFixId: fixId,
            resolutionNote: note
        )
        do {
            let _: APIResponse<ErrorPattern> = try await client.post(
                "/error-patterns/\(pattern.id.uuidString.lowercased())/resolve",
                body: request
            )
            await loadPatterns()
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to resolve error pattern: \(error.localizedDescription)",
                category: "error-patterns"
            )
        }
    }

    // MARK: - Apply Fix

    /// Apply a suggested fix by sending the fix prompt to a Claude session.
    /// - Parameters:
    ///   - fix: The suggested fix to apply.
    ///   - pattern: The error pattern the fix belongs to.
    ///   - sessionId: The session to send the fix prompt to.
    func applyFix(_ fix: ErrorFix, pattern: ErrorPattern, sessionId: UUID) async {
        guard let client else { return }
        let request = ApplyFixRequest(
            patternId: pattern.id,
            fixId: fix.id,
            sessionId: sessionId
        )
        do {
            let _: APIResponse<ErrorPattern> = try await client.post("/error-patterns/\(pattern.id.uuidString.lowercased())/apply-fix", body: request)
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to apply fix: \(error.localizedDescription)",
                category: "error-patterns"
            )
        }
    }

    /// Reload patterns (used for retry and project filter changes).
    func retryLoad() async {
        await loadPatterns()
    }
}
