import Vapor
import Fluent
import ILSShared

/// Controller for session health score operations.
///
/// Routes:
/// - `GET /sessions/health/summary`: Aggregate health scores for all sessions, sorted worst-first
/// - `GET /sessions/:id/health`: Health score for a specific session
/// - `GET /projects/health`: Per-project health summaries
/// - `GET /sessions/health/export`: Download full health report as a JSON file
struct SessionHealthController: RouteCollection {
    let fileSystem: FileSystemService
    private let healthService = SessionHealthService()

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let health = routes.grouped("sessions", "health")
        health.get("summary", use: summary)
        health.get("export", use: exportReport)

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

    /// GET /sessions/health/export — Download the full health report as a JSON file.
    ///
    /// Returns all session health scores (sorted worst-first) as a downloadable
    /// JSON attachment. Clients receive a `Content-Disposition: attachment` header
    /// so browsers/API clients treat the response as a file download.
    ///
    /// The response format mirrors `/sessions/health/summary` wrapped in
    /// an `APIResponse` envelope, making it easy to import into analysis tools.
    @Sendable
    func exportReport(req: Request) async throws -> Response {
        let sessions = try await loadAllSessions(req: req)
        let scores = await computeScores(sessions: sessions)
        let sorted = scores.sorted { $0.score < $1.score }
        let payload = APIResponse(success: true, data: sorted)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(payload)

        // Format filename with today's date for easy identification.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let filename = "health-report-\(dateString).json"

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")

        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
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
