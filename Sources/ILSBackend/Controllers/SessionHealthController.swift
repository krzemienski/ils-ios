import Vapor
import Fluent
import ILSShared

/// Controller for session health score operations.
///
/// Routes:
/// - `GET /sessions/health/summary`: Aggregate health scores for all sessions, sorted worst-first
/// - `GET /sessions/:id/health`: Health score for a specific session
/// - `GET /projects/health`: Per-project health summaries
struct SessionHealthController: RouteCollection {
    let fileSystem: FileSystemService
    private let healthService = SessionHealthService()

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let health = routes.grouped("sessions", "health")
        health.get("summary", use: summary)

        routes.get("sessions", ":id", "health", use: sessionHealth)
        routes.get("projects", "health", use: projectsHealth)
    }

    /// GET /sessions/health/summary — Aggregate health scores for all sessions, sorted score ascending (worst first).
    @Sendable
    func summary(req: Request) async throws -> APIResponse<[SessionHealthScore]> {
        let sessions = try await loadAllSessions(req: req)
        let scores = await computeScores(sessions: sessions)
        let sorted = scores.sorted { $0.score < $1.score }
        return APIResponse(success: true, data: sorted)
    }

    /// GET /sessions/:id/health — Health score for a specific session.
    @Sendable
    func sessionHealth(req: Request) async throws -> APIResponse<SessionHealthScore> {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid session id")
        }

        // Try DB first
        if let dbModel = try await SessionModel.find(id, on: req.db) {
            let session = dbModel.toShared(projectName: dbModel.project?.name)
            let score = await healthService.computeHealthScore(session: session)
            return APIResponse(success: true, data: score)
        }

        // Fall back to external sessions
        let externals = try await fileSystem.listExternalSessionsAsChatSessions()
        guard let session = externals.first(where: { $0.id == id }) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let score = await healthService.computeHealthScore(session: session)
        return APIResponse(success: true, data: score)
    }

    /// GET /projects/health — Per-project health summaries, sorted by average score ascending (worst first).
    @Sendable
    func projectsHealth(req: Request) async throws -> APIResponse<[ProjectHealthSummary]> {
        let sessions = try await loadAllSessions(req: req)

        // Group by project name
        var groups: [String: [ChatSession]] = [:]
        for session in sessions {
            let key = session.projectName ?? "Ungrouped"
            groups[key, default: []].append(session)
        }

        // Compute health for each project group
        var summaries: [ProjectHealthSummary] = []
        for (projectName, projectSessions) in groups {
            let summary = await healthService.computeProjectHealth(
                projectName: projectName,
                sessions: projectSessions
            )
            summaries.append(summary)
        }

        summaries.sort { $0.averageScore < $1.averageScore }
        return APIResponse(success: true, data: summaries)
    }

    // MARK: - Private Helpers

    /// Load all sessions (DB + deduplicated externals).
    private func loadAllSessions(req: Request) async throws -> [ChatSession] {
        let dbModels = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .all()
        var merged: [ChatSession] = dbModels.map { $0.toShared(projectName: $0.project?.name) }

        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions()
        let dbClaudeIds = Set(dbModels.compactMap(\.claudeSessionId))
        let uniqueExternal = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIds.contains(claudeId)
        }
        merged.append(contentsOf: uniqueExternal)
        return merged
    }

    /// Compute health scores concurrently using the actor service.
    private func computeScores(sessions: [ChatSession]) async -> [SessionHealthScore] {
        var scores: [SessionHealthScore] = []
        scores.reserveCapacity(sessions.count)
        for session in sessions {
            let score = await healthService.computeHealthScore(session: session)
            scores.append(score)
        }
        return scores
    }
}
