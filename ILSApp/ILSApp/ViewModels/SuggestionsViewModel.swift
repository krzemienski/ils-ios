import Foundation
import Observation
import ILSShared

/// View model for AI-powered session and skill suggestions.
///
/// Fetches contextually relevant past sessions and skills from the backend
/// suggestion engine. Supports independent loading states for sessions and
/// skills so each can be displayed as soon as available.
///
/// ## Usage
/// ```swift
/// let vm = SuggestionsViewModel()
/// vm.configure(client: apiClient)
/// await vm.loadSessionSuggestions(context: "debugging crash", projectName: "MyApp")
/// await vm.loadSkillSuggestions(projectName: "MyApp", context: "iOS")
/// ```
@Observable
@MainActor
class SuggestionsViewModel {
    /// Suggested past sessions relevant to the current context.
    var sessionSuggestions: [SessionSuggestion] = []
    /// Suggested skills relevant to the current project or context.
    var skillSuggestions: [SkillSuggestion] = []
    /// Abandoned sessions suggested for resumption.
    var abandonedSessions: [AbandonedSessionSuggestion] = []
    /// Whether session suggestions are currently loading.
    var isLoadingSessions = false
    /// Whether skill suggestions are currently loading.
    var isLoadingSkills = false
    /// Whether abandoned sessions are currently loading.
    var isLoadingAbandoned = false
    /// Current error, if any.
    var error: Error?

    private var client: APIClient?

    init() {}

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Load Session Suggestions

    /// Fetch session suggestions from the backend based on the given context.
    /// - Parameters:
    ///   - context: Free-text context (e.g. session name or first prompt) used for scoring.
    ///   - projectName: Optional project name to narrow suggestions.
    ///   - limit: Maximum number of suggestions to return (default 5).
    func loadSessionSuggestions(context: String, projectName: String? = nil, limit: Int = 5) async {
        guard let client else { return }
        isLoadingSessions = true
        error = nil

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "context", value: context),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let projectName {
            components.queryItems?.append(URLQueryItem(name: "projectName", value: projectName))
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        do {
            let response: APIResponse<ListResponse<SessionSuggestion>> = try await client.get("/suggestions/sessions\(query)")
            if let data = response.data {
                sessionSuggestions = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load session suggestions: \(error.localizedDescription)", category: "suggestions")
        }

        isLoadingSessions = false
    }

    // MARK: - Load Skill Suggestions

    /// Fetch skill suggestions from the backend based on project and context.
    /// - Parameters:
    ///   - projectName: Optional project name to narrow suggestions.
    ///   - context: Free-text context used for scoring.
    ///   - limit: Maximum number of suggestions to return (default 5).
    func loadSkillSuggestions(projectName: String? = nil, context: String, limit: Int = 5) async {
        guard let client else { return }
        isLoadingSkills = true
        error = nil

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "context", value: context),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let projectName {
            components.queryItems?.append(URLQueryItem(name: "projectName", value: projectName))
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        do {
            let response: APIResponse<ListResponse<SkillSuggestion>> = try await client.get("/suggestions/skills\(query)")
            if let data = response.data {
                skillSuggestions = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load skill suggestions: \(error.localizedDescription)", category: "suggestions")
        }

        isLoadingSkills = false
    }

    // MARK: - Load Abandoned Sessions

    /// Fetch abandoned session suggestions from the backend.
    ///
    /// Returns sessions that have had no activity for 24+ hours and have
    /// meaningful work that may be worth resuming.
    /// - Parameter limit: Maximum number of suggestions to return (default 5).
    func loadAbandonedSessions(limit: Int = 5) async {
        guard let client else { return }
        isLoadingAbandoned = true
        error = nil

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        do {
            let response: APIResponse<ListResponse<AbandonedSessionSuggestion>> = try await client.get("/suggestions/abandoned\(query)")
            if let data = response.data {
                abandonedSessions = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load abandoned sessions: \(error.localizedDescription)", category: "suggestions")
        }

        isLoadingAbandoned = false
    }

    // MARK: - Load Continuation Summary

    /// Fetch a smart continuation summary for the given session.
    ///
    /// The summary captures what was accomplished, suggests a resume prompt,
    /// and extracts key topics so the user can pick up exactly where they left off.
    /// - Parameter sessionId: The UUID of the session to summarize.
    /// - Returns: A `ContinuationSummary` if found, or `nil` if unavailable.
    func loadContinuationSummary(sessionId: UUID) async -> ContinuationSummary? {
        guard let client else { return nil }
        do {
            let response: APIResponse<ContinuationSummary> = try await client.get("/suggestions/continuation/\(sessionId.uuidString.lowercased())")
            return response.data
        } catch {
            AppLogger.shared.error("Failed to load continuation summary: \(error.localizedDescription)", category: "suggestions")
            return nil
        }
    }

    // MARK: - Feedback

    /// Record user interaction with a suggestion for future ranking improvement.
    /// - Parameters:
    ///   - action: The user action taken (e.g. "click", "dismiss", "view").
    ///   - suggestionType: Type of suggestion (e.g. "session", "skill").
    ///   - targetId: Identifier of the suggested resource.
    ///   - sessionId: Optional current session context.
    func recordFeedback(
        action: String,
        suggestionType: String,
        targetId: String,
        sessionId: UUID? = nil
    ) async {
        guard let client else { return }
        let request = SuggestionFeedbackRequest(
            sessionId: sessionId,
            action: action,
            suggestionType: suggestionType,
            targetId: targetId
        )
        do {
            let _: APIResponse<AcknowledgedResponse> = try await client.post("/suggestions/feedback", body: request)
        } catch {
            AppLogger.shared.error("Failed to record suggestion feedback: \(error.localizedDescription)", category: "suggestions")
        }
    }

    // MARK: - Convenience

    /// Whether any loading is in progress.
    var isLoading: Bool {
        isLoadingSessions || isLoadingSkills || isLoadingAbandoned
    }
}
