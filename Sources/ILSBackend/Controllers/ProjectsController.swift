import Vapor
import Fluent
import ILSShared
import Foundation

/// Controller for project management operations.
///
/// Routes:
/// - `GET /projects`: List all projects from `~/.claude/projects/`
/// - `POST /projects`: Create a new project
/// - `GET /projects/:id`: Get a specific project
/// - `PUT /projects/:id`: Update a project
/// - `DELETE /projects/:id`: Delete a project and its sessions
/// - `GET /projects/:id/sessions`: Get sessions for a project
struct ProjectsController: RouteCollection {
    private let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        projects.get(use: index)
        projects.post(use: create)
        projects.get(":id", use: show)
        projects.put(":id", use: update)
        projects.delete(":id", use: delete)
        projects.get(":id", "sessions", use: getSessions)
    }

    /// Flexible ISO8601 date parsers for fractional seconds
    private static let flexibleISO8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackISO8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ s: String) -> Date? {
        Self.flexibleISO8601.date(from: s) ?? Self.fallbackISO8601.date(from: s)
    }

    /// List all projects discovered from `~/.claude/projects/` sessions-index files.
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of Project objects
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<Project>> {
        var projects: [Project] = []

        let claudeProjectsDir = fileSystem.claudeProjectsPath

        guard FileManager.default.fileExists(atPath: claudeProjectsDir) else {
            return APIResponse(
                success: true,
                data: ListResponse(items: projects)
            )
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: claudeProjectsDir)

            for encodedDir in contents {
                let projectDirPath = "\(claudeProjectsDir)/\(encodedDir)"
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: projectDirPath, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                let indexPath = "\(projectDirPath)/sessions-index.json"
                guard FileManager.default.fileExists(atPath: indexPath) else {
                    continue
                }

                guard let data = try? Data(contentsOf: URL(fileURLWithPath: indexPath)) else {
                    continue
                }
                guard let index: FileSystemService.SessionsIndex = try? JSONDecoder().decode(FileSystemService.SessionsIndex.self, from: data) else {
                    continue
                }

                guard let firstEntry = index.entries.first else {
                    continue
                }

                let projectPath = firstEntry.projectPath
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                let sessionCount = index.entries.count

                // Parse dates with fractional seconds support
                let createdDate = parseDate(firstEntry.created) ?? Date()
                let lastModified = index.entries.compactMap { parseDate($0.modified) }.max() ?? createdDate

                let project = Project(
                    id: UUID(),
                    name: projectName,
                    path: projectPath,
                    defaultModel: "sonnet",
                    description: "Claude Code project",
                    createdAt: createdDate,
                    lastAccessedAt: lastModified,
                    sessionCount: sessionCount,
                    encodedPath: encodedDir
                )

                projects.append(project)
            }

            projects.sort { $0.lastAccessedAt > $1.lastAccessedAt }

        } catch {
            req.logger.error("Failed to scan Claude projects: \(error)")
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: projects)
        )
    }

    /// Create a new project (or return existing if path matches).
    /// - Parameter req: Vapor Request with CreateProjectRequest body
    /// - Returns: APIResponse with created or existing Project
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

    /// Get a specific project by ID.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with Project including session count
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

    /// Update a project's metadata (name, model, description).
    /// - Parameter req: Vapor Request with id parameter and UpdateProjectRequest body
    /// - Returns: APIResponse with updated Project
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

    /// Delete a project and all its associated sessions.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with deletion confirmation
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

    /// Get all sessions for a specific project.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with list of ChatSession objects
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
