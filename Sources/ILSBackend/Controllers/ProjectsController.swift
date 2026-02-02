import Vapor
import Fluent
import ILSShared
import Foundation

/// Structure matching sessions-index.json format from ~/.claude/projects/
private struct SessionsIndex: Codable {
    let version: Int
    let entries: [SessionEntry]
}

private struct SessionEntry: Codable {
    let sessionId: String
    let projectPath: String
    let summary: String?
    let created: Date
    let modified: Date
}

struct ProjectsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        projects.get(use: index)
        projects.post(use: create)
        projects.get(":id", use: show)
        projects.put(":id", use: update)
        projects.delete(":id", use: delete)
        projects.get(":id", "sessions", use: getSessions)
    }

    /// GET /projects - List all projects from ~/.claude/projects/
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<Project>> {
        var projects: [Project] = []

        // Get Claude home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeProjectsDir = homeDir.appendingPathComponent(".claude/projects")

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            return APIResponse(
                success: true,
                data: ListResponse(items: projects)
            )
        }

        // Scan project directories
        do {
            let projectDirs = try FileManager.default.contentsOfDirectory(
                at: claudeProjectsDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for projectDir in projectDirs {
                // Check if it's a directory
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                // Read sessions-index.json
                let sessionsIndexPath = projectDir.appendingPathComponent("sessions-index.json")
                guard FileManager.default.fileExists(atPath: sessionsIndexPath.path) else {
                    continue
                }

                let data = try Data(contentsOf: sessionsIndexPath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let index = try decoder.decode(SessionsIndex.self, from: data)

                // Extract project info from first entry (all entries should have same projectPath)
                guard let firstEntry = index.entries.first else {
                    continue
                }

                let projectPath = firstEntry.projectPath
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                let sessionCount = index.entries.count

                // Get last modified date from entries
                let lastModified = index.entries.map { $0.modified }.max() ?? firstEntry.created

                // Create Project struct
                let project = Project(
                    id: UUID(), // Generate a deterministic UUID from path later if needed
                    name: projectName,
                    path: projectPath,
                    defaultModel: "sonnet",
                    description: "Claude Code project",
                    createdAt: firstEntry.created,
                    lastAccessedAt: lastModified,
                    sessionCount: sessionCount
                )

                projects.append(project)
            }

            // Sort by last accessed date (most recent first)
            projects.sort { $0.lastAccessedAt > $1.lastAccessedAt }

        } catch {
            req.logger.error("Failed to scan Claude projects: \(error)")
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: projects)
        )
    }

    /// POST /projects - Create a new project
    @Sendable
    func create(req: Request) async throws -> APIResponse<Project> {
        let input = try req.content.decode(CreateProjectRequest.self)

        // Check if project with same path already exists
        if let existing = try await ProjectModel.query(on: req.db)
            .filter(\.$path == input.path)
            .first() {
            // Return existing project instead of error
            return APIResponse(
                success: true,
                data: existing.toShared(sessionCount: 0)
            )
        }

        let project = ProjectModel(
            name: input.name,
            path: input.path,
            defaultModel: input.defaultModel ?? "sonnet",
            description: input.description
        )

        try await project.save(on: req.db)

        return APIResponse(
            success: true,
            data: project.toShared(sessionCount: 0)
        )
    }

    /// GET /projects/:id - Get a single project by ID
    @Sendable
    func show(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let sessionCount = try await project.$sessions.query(on: req.db).count()

        return APIResponse(
            success: true,
            data: project.toShared(sessionCount: sessionCount)
        )
    }

    /// PUT /projects/:id - Update an existing project
    @Sendable
    func update(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let input = try req.content.decode(UpdateProjectRequest.self)

        // Update only provided fields
        if let name = input.name {
            project.name = name
        }
        if let defaultModel = input.defaultModel {
            project.defaultModel = defaultModel
        }
        if let description = input.description {
            project.description = description
        }

        // Touch lastAccessedAt
        project.lastAccessedAt = Date()

        try await project.save(on: req.db)

        let sessionCount = try await project.$sessions.query(on: req.db).count()

        return APIResponse(
            success: true,
            data: project.toShared(sessionCount: sessionCount)
        )
    }

    /// DELETE /projects/:id - Delete a project
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        // Delete associated sessions first (cascade)
        try await project.$sessions.query(on: req.db).delete()

        // Delete the project
        try await project.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// GET /projects/:id/sessions - Get sessions for a project
    @Sendable
    func getSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let sessionModels = try await project.$sessions.query(on: req.db)
            .sort(\.$lastActiveAt, .descending)
            .all()

        let sessions = sessionModels.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: sessions)
        )
    }
}
