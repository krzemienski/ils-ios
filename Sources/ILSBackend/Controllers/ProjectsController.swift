import Vapor
import Fluent
import ILSShared
import Foundation
import CryptoKit

/// Controller for project management operations.
///
/// Routes:
/// - `GET /projects`: List all projects from `~/.claude/projects/`
/// - `GET /projects/:id`: Get a specific project by deterministic ID
/// - `GET /projects/:id/sessions`: Get sessions for a project
struct ProjectsController: RouteCollection {
    private let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        projects.get(use: index)
        projects.get(":id", use: show)
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

            projects.sort { $0.lastAccessedAt > $1.lastAccessedAt }

        } catch {
            req.logger.error("Failed to scan Claude projects: \(error)")
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: projects)
        )
    }

    /// Get a specific project by deterministic ID (scans filesystem).
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with Project
    @Sendable
    func show(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        // Scan filesystem to find the project matching this deterministic ID
        let allProjects = try await index(req: req)
        guard let project = allProjects.data?.items.first(where: { $0.id == id }) else {
            throw Abort(.notFound, reason: "Project not found. Projects are discovered from ~/.claude/projects/")
        }

        return APIResponse(
            success: true,
            data: project
        )
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
}
