import Vapor
import Fluent
import ILSShared

/// Module-level singleton for the error pattern store, shared across all requests.
let errorPatternStore = ErrorPatternStore()

/// Controller for AI-powered error pattern detection and auto-fix suggestion endpoints.
///
/// Routes:
/// - `GET /error-patterns`: Get top recurring error patterns for a project
/// - `GET /error-patterns/:id`: Get a single pattern with its suggested fixes
/// - `POST /error-patterns/record`: Record a new error occurrence from a session
/// - `POST /error-patterns/:id/resolve`: Mark an error pattern as resolved
/// - `POST /error-patterns/:id/apply-fix`: Record the outcome of applying a suggested fix
struct ErrorPatternsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let errorPatterns = routes.grouped("error-patterns")

        errorPatterns.get(use: list)
        errorPatterns.get(":id", use: show)
        errorPatterns.post("record", use: record)
        errorPatterns.post(":id", "resolve", use: resolve)
        errorPatterns.post(":id", "apply-fix", use: applyFix)
    }

    // MARK: - Route Handlers

    /// GET /error-patterns?projectName=&limit=
    ///
    /// Returns the top recurring error patterns for the given project, ordered by
    /// occurrence count descending.
    ///
    /// Query parameters:
    /// - `projectName`: The project to query (required)
    /// - `limit`: Maximum number of patterns to return (1–50, default 10)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with ErrorPatternListResponse
    @Sendable
    func list(req: Request) async throws -> APIResponse<ErrorPatternListResponse> {
        guard let projectName = req.query[String.self, at: "projectName"], !projectName.isEmpty else {
            throw Abort(.badRequest, reason: "projectName query parameter is required")
        }
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 10, 1), 50)

        let service = ErrorPatternService()
        let response = await service.listResponse(
            forProject: projectName,
            limit: limit,
            store: errorPatternStore
        )

        return APIResponse(success: true, data: response)
    }

    /// GET /error-patterns/:id
    ///
    /// Returns a single error pattern by ID, including all suggested fixes ranked by confidence.
    ///
    /// Path parameters:
    /// - `id`: UUID of the error pattern
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with ErrorPattern, or 404 if not found
    @Sendable
    func show(req: Request) async throws -> APIResponse<ErrorPattern> {
        guard let patternId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid pattern ID")
        }

        let service = ErrorPatternService()
        guard let pattern = await service.pattern(byId: patternId, store: errorPatternStore) else {
            throw Abort(.notFound, reason: "Error pattern not found")
        }

        return APIResponse(success: true, data: pattern)
    }

    /// POST /error-patterns/record
    ///
    /// Records a new error occurrence from a session. If a matching pattern already exists
    /// (by normalized signature), the occurrence count is incremented. Otherwise a new
    /// pattern is created.
    ///
    /// Request body: `RecordErrorRequest`
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with the upserted ErrorPattern
    @Sendable
    func record(req: Request) async throws -> APIResponse<ErrorPattern> {
        let body = try req.content.decode(RecordErrorRequest.self)

        let service = ErrorPatternService()

        // Build a minimal session so detectPatterns can record the occurrence
        let session = ChatSession(
            id: body.sessionId,
            projectName: body.projectName
        )

        let message = Message(
            sessionId: body.sessionId,
            role: .assistant,
            content: body.errorText
        )

        await service.detectPatterns(from: [message], session: session, store: errorPatternStore)

        // Return the pattern that was just upserted — look up by normalized signature
        let normalizedSig = service.normalizeSignature(body.errorText)
        let topPatterns = await service.topPatterns(
            forProject: body.projectName,
            limit: 100,
            store: errorPatternStore
        )
        let matchingPattern = topPatterns.first { $0.errorSignature == normalizedSig }
            ?? topPatterns.first

        guard let pattern = matchingPattern else {
            throw Abort(.internalServerError, reason: "Failed to record error pattern")
        }

        return APIResponse(success: true, data: pattern)
    }

    /// POST /error-patterns/:id/resolve
    ///
    /// Marks an error pattern as resolved. If a fix resolved it, records that outcome
    /// to improve future confidence scores.
    ///
    /// Path parameters:
    /// - `id`: UUID of the error pattern to mark resolved
    ///
    /// Request body: `MarkResolvedRequest`
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with updated ErrorPattern
    @Sendable
    func resolve(req: Request) async throws -> APIResponse<ErrorPattern> {
        guard let patternId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid pattern ID")
        }

        let body = try req.content.decode(MarkResolvedRequest.self)

        let service = ErrorPatternService()

        // If a specific fix resolved the pattern, record it as a success
        if let fixId = body.resolvedByFixId {
            await service.recordFixOutcome(
                patternId: patternId,
                fixId: fixId,
                success: true,
                store: errorPatternStore
            )
        }

        await service.markResolved(patternId: patternId, store: errorPatternStore)

        guard let pattern = await service.pattern(byId: patternId, store: errorPatternStore) else {
            throw Abort(.notFound, reason: "Error pattern not found")
        }

        return APIResponse(success: true, data: pattern)
    }

    /// POST /error-patterns/:id/apply-fix
    ///
    /// Records that a suggested fix was applied to a session. The fix outcome is
    /// initially recorded as an application attempt; use `/resolve` to record success.
    ///
    /// Path parameters:
    /// - `id`: UUID of the error pattern
    ///
    /// Request body: `ApplyFixRequest`
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with the current ErrorPattern (with updated fix counts)
    @Sendable
    func applyFix(req: Request) async throws -> APIResponse<ErrorPattern> {
        guard let patternId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid pattern ID")
        }

        let body = try req.content.decode(ApplyFixRequest.self)

        guard body.patternId == patternId else {
            throw Abort(.badRequest, reason: "Pattern ID in path does not match request body")
        }

        let service = ErrorPatternService()

        // Record an application attempt; outcome is confirmed via /resolve
        await service.recordFixOutcome(
            patternId: patternId,
            fixId: body.fixId,
            success: false,
            store: errorPatternStore
        )

        guard let pattern = await service.pattern(byId: patternId, store: errorPatternStore) else {
            throw Abort(.notFound, reason: "Error pattern not found")
        }

        return APIResponse(success: true, data: pattern)
    }
}

// MARK: - Request Types

/// Request body for recording a new error occurrence from a session.
struct RecordErrorRequest: Content {
    /// Name of the project where the error occurred.
    let projectName: String
    /// Raw error text (message, stack trace, or build output) to classify and record.
    let errorText: String
    /// UUID of the session in which the error occurred.
    let sessionId: UUID
}
