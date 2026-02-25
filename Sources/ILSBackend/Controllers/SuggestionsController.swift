import Vapor
import Fluent
import ILSShared

/// Module-level singleton for tracking user suggestion interactions across requests.
let suggestionInteractionStore = SuggestionInteractionStore()

/// Controller for smart session and skill suggestion endpoints.
///
/// Routes:
/// - `GET /suggestions/sessions`: Get ranked session suggestions based on context
/// - `GET /suggestions/skills`: Get ranked skill suggestions based on project/context
/// - `POST /suggestions/feedback`: Record user interaction with a suggestion
struct SuggestionsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let suggestions = routes.grouped("suggestions")

        suggestions.get("sessions", use: sessions)
        suggestions.get("skills", use: skills)
        suggestions.post("feedback", use: feedback)
    }

    /// Return ranked session suggestions based on the current context.
    ///
    /// Query parameters:
    /// - `context`: Free-text context for keyword scoring (optional, default empty)
    /// - `projectName`: Boost sessions from the same project (optional)
    /// - `limit`: Max results to return (1–50, default 5)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of SessionSuggestion
    @Sendable
    func sessions(req: Request) async throws -> APIResponse<[SessionSuggestion]> {
        let context = req.query[String.self, at: "context"] ?? ""
        let projectName = req.query[String.self, at: "projectName"]
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 5, 1), 50)

        // 1. Load DB sessions
        let dbSessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .sort(\.$lastActiveAt, .descending)
            .all()
        let dbConverted: [ChatSession] = dbSessions.map { $0.toShared(projectName: $0.project?.name) }

        // 2. Load external sessions (deduplicated)
        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions(bypassCache: false)
        let dbClaudeIds = Set(dbSessions.compactMap(\.claudeSessionId))
        let uniqueExternal = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIds.contains(claudeId)
        }

        // 3. Merge all sessions
        var allSessions = dbConverted
        allSessions.append(contentsOf: uniqueExternal)

        // 4. Get interaction history and score
        let clickCounts = await suggestionInteractionStore.getCounts()
        let service = SuggestionService()
        let suggestions = service.suggestSessions(
            from: allSessions,
            context: context,
            projectName: projectName,
            limit: limit,
            clickCounts: clickCounts
        )

        return APIResponse(success: true, data: suggestions)
    }

    /// Return ranked skill suggestions based on the current project and context.
    ///
    /// Query parameters:
    /// - `projectName`: Project name for tag-based matching (optional)
    /// - `context`: Free-text context for keyword scoring (optional, default empty)
    /// - `limit`: Max results to return (1–50, default 5)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of SkillSuggestion
    @Sendable
    func skills(req: Request) async throws -> APIResponse<[SkillSuggestion]> {
        let projectName = req.query[String.self, at: "projectName"]
        let context = req.query[String.self, at: "context"] ?? ""
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 5, 1), 50)

        // Load all available skills
        let allSkills = try await fileSystem.listSkills(bypassCache: false)

        // Score and rank
        let service = SuggestionService()
        let suggestions = service.suggestSkills(
            from: allSkills,
            projectName: projectName,
            context: context,
            limit: limit
        )

        return APIResponse(success: true, data: suggestions)
    }

    /// Record user interaction with a suggestion for future relevance boosting.
    ///
    /// - Parameter req: Vapor Request with SuggestionFeedbackRequest body
    /// - Returns: APIResponse with AcknowledgedResponse
    @Sendable
    func feedback(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        let input = try req.content.decode(SuggestionFeedbackRequest.self)

        // Record click interactions (other actions are received but not currently tracked)
        if input.action == "click" {
            await suggestionInteractionStore.recordClick(targetId: input.targetId)
        }

        return APIResponse(success: true, data: AcknowledgedResponse())
    }
}
