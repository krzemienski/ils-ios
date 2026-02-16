import Vapor
import Fluent
import ILSShared
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Controller for project management operations.
///
/// Routes:
/// - `GET /projects`: List all projects from `~/.claude/projects/`
/// - `POST /projects`: Create a new project record in the database
/// - `GET /projects/:id`: Get a specific project by deterministic ID
/// - `PUT /projects/:id`: Update project metadata
/// - `DELETE /projects/:id`: Delete a project record
/// - `GET /projects/:id/sessions`: Get sessions for a project
struct ProjectsController: RouteCollection {
    private let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        projects.get(use: index)
        projects.post(use: create)
        projects.get(":id", use: show)
        projects.put(":id", use: update)
        projects.delete(":id", use: deleteProject)
        projects.get(":id", "sessions", use: getSessions)
    }

    /// Create a deterministic UUID from a string using SHA256.
    /// Same input always produces the same UUID.
    private func deterministicID(from path: String) -> UUID {
        let hash = SHA256.hash(data: Data(path.utf8))
        var bytes = Array(hash.prefix(16))
        // Set UUID version 5 bits
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        // Set variant bits
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
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
    ///
    /// Supports pagination via query parameters:
    /// - `page`: Page number (1-based, default 1)
    /// - `limit`: Items per page (default 50, max 200)
    /// - `search`: Case-insensitive filter on project name
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with paginated list of Project objects
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<Project>> {
        var projects: [Project] = []
        let searchTerm = req.query[String.self, at: "search"]

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
                    id: deterministicID(from: projectPath),
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

            // Filter by search term if provided
            if let search = searchTerm?.lowercased(), !search.isEmpty {
                projects = projects.filter { $0.name.lowercased().contains(search) }
            }

            projects.sort { $0.lastAccessedAt > $1.lastAccessedAt }

        } catch {
            req.logger.error("Failed to scan Claude projects: \(error)")
        }

        // Apply pagination
        let pagination = PaginationParams(from: req)
        let result = pagination.apply(to: projects)

        return APIResponse(
            success: true,
            data: ListResponse(items: result.items, total: result.pagination.total)
        )
    }

    /// Get a specific project by deterministic ID (scans filesystem with early exit).
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with Project
    @Sendable
    func show(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let claudeProjectsDir = fileSystem.claudeProjectsPath

        guard FileManager.default.fileExists(atPath: claudeProjectsDir) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: claudeProjectsDir)

        for encodedDir in contents {
            let projectDirPath = "\(claudeProjectsDir)/\(encodedDir)"
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projectDirPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let indexPath = "\(projectDirPath)/sessions-index.json"
            guard FileManager.default.fileExists(atPath: indexPath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: indexPath)),
                  let index = try? JSONDecoder().decode(FileSystemService.SessionsIndex.self, from: data),
                  let firstEntry = index.entries.first else {
                continue
            }

            let projectPath = firstEntry.projectPath
            let candidateId = deterministicID(from: projectPath)

            // Early exit on match
            if candidateId == id {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                let createdDate = parseDate(firstEntry.created) ?? Date()
                let lastModified = index.entries.compactMap { self.parseDate($0.modified) }.max() ?? createdDate

                let project = Project(
                    id: id,
                    name: projectName,
                    path: projectPath,
                    defaultModel: "sonnet",
                    description: "Claude Code project",
                    createdAt: createdDate,
                    lastAccessedAt: lastModified,
                    sessionCount: index.entries.count,
                    encodedPath: encodedDir
                )

                return APIResponse(success: true, data: project)
            }
        }

        throw Abort(.notFound, reason: "Project not found. Projects are discovered from ~/.claude/projects/")
    }

    /// Get all sessions for a specific project (by deterministic ID).
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with list of ChatSession objects
    @Sendable
    func getSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        // Verify the project exists in filesystem
        let allProjects = try await index(req: req)
        guard allProjects.data?.items.contains(where: { $0.id == id }) == true else {
            throw Abort(.notFound, reason: "Project not found")
        }

        // Query sessions that reference this project ID
        let sessionModels = try await SessionModel.query(on: req.db)
            .filter(\.$project.$id == id)
            .sort(\.$lastActiveAt, .descending)
            .all()

        let sessions = sessionModels.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: sessions)
        )
    }

    // MARK: - CRUD Operations

    /// Create a new project record in the database.
    /// - Parameter req: Vapor Request with CreateProjectRequest body
    /// - Returns: APIResponse with created Project
    @Sendable
    func create(req: Request) async throws -> APIResponse<Project> {
        let input = try req.content.decode(CreateProjectRequest.self)

        // Validate inputs
        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateStringLength(input.path, maxLength: 1024, fieldName: "path")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 2000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.defaultModel, maxLength: 64, fieldName: "defaultModel")

        let project = ProjectModel(
            name: input.name,
            path: input.path,
            defaultModel: input.defaultModel ?? "sonnet",
            description: input.description
        )

        try await project.save(on: req.db)

        return APIResponse(
            success: true,
            data: project.toShared()
        )
    }

    /// Update project metadata (name, description, defaultModel).
    /// - Parameter req: Vapor Request with id parameter and UpdateProjectRequest body
    /// - Returns: APIResponse with updated Project
    @Sendable
    func update(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let input = try req.content.decode(UpdateProjectRequest.self)

        // Validate inputs
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 2000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.defaultModel, maxLength: 64, fieldName: "defaultModel")

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        if let name = input.name {
            project.name = name
        }
        if let description = input.description {
            project.description = description
        }
        if let defaultModel = input.defaultModel {
            project.defaultModel = defaultModel
        }

        try await project.save(on: req.db)

        return APIResponse(
            success: true,
            data: project.toShared()
        )
    }

    /// Delete a project record from the database.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func deleteProject(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        try await project.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }
}
