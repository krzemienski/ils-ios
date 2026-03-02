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
/// - `GET /suggestions/abandoned`: Get sessions inactive for 24+ hours worth resuming
/// - `GET /suggestions/continuation/:sessionId`: Get smart continuation summary for a session
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
        suggestions.get("abandoned", use: abandoned)
        suggestions.get("continuation", ":sessionId", use: continuation)
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
    /// - Returns: APIResponse with ListResponse of SessionSuggestion
    @Sendable
    func sessions(req: Request) async throws -> APIResponse<ListResponse<SessionSuggestion>> {
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

        return APIResponse(success: true, data: ListResponse(items: suggestions))
    }

    /// Return ranked skill suggestions based on the current project and context.
    ///
    /// Query parameters:
    /// - `projectName`: Project name for tag-based matching (optional)
    /// - `context`: Free-text context for keyword scoring (optional, default empty)
    /// - `limit`: Max results to return (1–50, default 5)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with ListResponse of SkillSuggestion
    @Sendable
    func skills(req: Request) async throws -> APIResponse<ListResponse<SkillSuggestion>> {
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

        return APIResponse(success: true, data: ListResponse(items: suggestions))
    }

    /// Return sessions that have been abandoned (inactive for 24+ hours) and are worth resuming.
    ///
    /// Query parameters:
    /// - `limit`: Max results to return (1–20, default 5)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with ListResponse of AbandonedSessionSuggestion
    @Sendable
    func abandoned(req: Request) async throws -> APIResponse<ListResponse<AbandonedSessionSuggestion>> {
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 5, 1), 20)

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

        // 4. Get dismissed IDs and score
        let dismissedIds = await suggestionInteractionStore.getDismissedIds()
        let service = SuggestionService()
        let suggestions = service.suggestAbandoned(
            from: allSessions,
            limit: limit,
            dismissedIds: dismissedIds
        )

        return APIResponse(success: true, data: ListResponse(items: suggestions))
    }

    /// Return a smart continuation summary for a specific session.
    ///
    /// Path parameters:
    /// - `sessionId`: UUID of the session to summarize
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with ContinuationSummary, or 404 if session not found
    @Sendable
    func continuation(req: Request) async throws -> APIResponse<ContinuationSummary> {
        guard let sessionId = req.parameters.get("sessionId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        // Load session from DB
        guard let sessionModel = try await SessionModel.query(on: req.db)
            .filter(\.$id == sessionId)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Load all messages for this session
        let messageModels = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .sort(\.$createdAt, .ascending)
            .all()

        let session = sessionModel.toShared(projectName: sessionModel.project?.name)
        let messages = messageModels.map { $0.toShared() }

        let service = SuggestionService()
        let summary = service.buildContinuationSummary(session: session, messages: messages)

        return APIResponse(success: true, data: summary)
    }

    /// Record user interaction with a suggestion for future relevance boosting.
    ///
    /// Supported actions:
    /// - `click`: Boosts the suggestion's relevance score in future rankings.
    /// - `dismiss`: Excludes the suggestion from future abandoned session results.
    ///
    /// - Parameter req: Vapor Request with SuggestionFeedbackRequest body
    /// - Returns: APIResponse with AcknowledgedResponse
    @Sendable
    func feedback(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        let input = try req.content.decode(SuggestionFeedbackRequest.self)

        switch input.action {
        case "click":
            await suggestionInteractionStore.recordClick(targetId: input.targetId)
        case "dismiss":
            await suggestionInteractionStore.recordDismissal(targetId: input.targetId)
        default:
            break
        }

        return APIResponse(success: true, data: AcknowledgedResponse())
    }
}
