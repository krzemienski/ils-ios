import Vapor
import Fluent
import ILSShared

struct ProjectsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        projects.get(use: list)
        projects.post(use: create)
        projects.get(":id", use: get)
        projects.put(":id", use: update)
        projects.delete(":id", use: delete)
        projects.get(":id", "sessions", use: getSessions)
    }

    /// GET /projects - List all projects from ~/.claude/projects/
    /// Scans the projects directory and reads sessions-index.json from each project folder
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Project>> {
        let fm = FileManager.default
        let projectsPath = fileSystem.claudeProjectsPath

        var projects: [Project] = []

        guard fm.fileExists(atPath: projectsPath),
              let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            return APIResponse(
                success: true,
                data: ListResponse(items: projects)
            )
        }

        for projectDir in projectDirs {
            let projectPath = "\(projectsPath)/\(projectDir)"
            var isDirectory: ObjCBool = false

            guard fm.fileExists(atPath: projectPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Read sessions-index.json for metadata
            let sessionsIndexPath = "\(projectPath)/sessions-index.json"
            var projectRealPath: String?
            var sessionCount = 0
            var lastModified: Date?
            var createdAt: Date?

            if let data = try? Data(contentsOf: URL(fileURLWithPath: sessionsIndexPath)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let entries = json["entries"] as? [[String: Any]] {

                sessionCount = entries.count

                // Get project path from first entry
                if let firstEntry = entries.first {
                    projectRealPath = firstEntry["projectPath"] as? String
                }

                // Find latest modified date
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                for entry in entries {
                    if let modifiedStr = entry["modified"] as? String,
                       let date = dateFormatter.date(from: modifiedStr) {
                        if lastModified == nil || date > lastModified! {
                            lastModified = date
                        }
                    }
                    if let createdStr = entry["created"] as? String,
                       let date = dateFormatter.date(from: createdStr) {
                        if createdAt == nil || date < createdAt! {
                            createdAt = date
                        }
                    }
                }
            }

            // If no sessions-index.json, count jsonl files directly
            if sessionCount == 0 {
                if let contents = try? fm.contentsOfDirectory(atPath: projectPath) {
                    sessionCount = contents.filter { $0.hasSuffix(".jsonl") }.count
                }
            }

            // Get folder attributes for dates if not found
            if lastModified == nil || createdAt == nil {
                if let attrs = try? fm.attributesOfItem(atPath: projectPath) {
                    if lastModified == nil {
                        lastModified = attrs[.modificationDate] as? Date
                    }
                    if createdAt == nil {
                        createdAt = attrs[.creationDate] as? Date
                    }
                }
            }

            // Convert directory name to readable project name
            // Format: -Users-nick-Desktop-project-name -> project-name
            let projectName = extractProjectName(from: projectDir, realPath: projectRealPath)

            // Generate a stable UUID from the directory name
            let projectId = stableUUID(from: projectDir)

            projects.append(Project(
                id: projectId,
                name: projectName,
                path: projectRealPath ?? projectDir,
                defaultModel: "sonnet",
                description: nil,
                createdAt: createdAt ?? Date(),
                lastAccessedAt: lastModified ?? Date(),
                sessionCount: sessionCount
            ))
        }

        // Sort by last accessed (most recent first)
        projects.sort { $0.lastAccessedAt > $1.lastAccessedAt }

        return APIResponse(
            success: true,
            data: ListResponse(items: projects)
        )
    }

    /// Extract a readable project name from directory or real path
    private func extractProjectName(from dirName: String, realPath: String?) -> String {
        if let path = realPath {
            // Use the last component of the real path
            return URL(fileURLWithPath: path).lastPathComponent
        }

        // Convert directory name format: -Users-nick-Desktop-project-name
        let parts = dirName.split(separator: "-")
        if parts.count > 3 {
            // Skip the first parts (Users, nick, Desktop, etc.) and join remaining
            return parts.suffix(from: min(4, parts.count)).joined(separator: "-")
        }
        return dirName
    }

    /// Generate a stable UUID from a string (deterministic)
    private func stableUUID(from string: String) -> UUID {
        var hash = string.utf8.reduce(0) { result, byte in
            result &+ UInt64(byte) &* 31
        }
        // Create a UUID from the hash
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: hash)
            hash >>= 8
        }
        // Second pass for remaining bytes
        hash = string.utf8.reversed().reduce(0) { result, byte in
            result &+ UInt64(byte) &* 37
        }
        for i in 8..<16 {
            bytes[i] = UInt8(truncatingIfNeeded: hash)
            hash >>= 8
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                          bytes[4], bytes[5], bytes[6], bytes[7],
                          bytes[8], bytes[9], bytes[10], bytes[11],
                          bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// POST /projects - Create a new project (creates directory in ~/.claude/projects/)
    @Sendable
    func create(req: Request) async throws -> APIResponse<Project> {
        let input = try req.content.decode(CreateProjectRequest.self)
        let fm = FileManager.default

        // Convert path to directory name format
        let dirName = input.path.replacingOccurrences(of: "/", with: "-")
        let projectPath = "\(fileSystem.claudeProjectsPath)/\(dirName)"

        // Create directory if it doesn't exist
        if !fm.fileExists(atPath: projectPath) {
            try fm.createDirectory(atPath: projectPath, withIntermediateDirectories: true)
        }

        // Create empty sessions-index.json
        let sessionsIndex: [String: Any] = [
            "version": 1,
            "entries": []
        ]
        let indexPath = "\(projectPath)/sessions-index.json"
        if !fm.fileExists(atPath: indexPath) {
            let data = try JSONSerialization.data(withJSONObject: sessionsIndex, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: indexPath))
        }

        let projectId = stableUUID(from: dirName)

        let project = Project(
            id: projectId,
            name: input.name,
            path: input.path,
            defaultModel: input.defaultModel ?? "sonnet",
            description: input.description,
            createdAt: Date(),
            lastAccessedAt: Date(),
            sessionCount: 0
        )

        return APIResponse(
            success: true,
            data: project
        )
    }

    /// GET /projects/:id - Get a single project by ID
    /// Searches ~/.claude/projects/ for matching project
    @Sendable
    func get(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        // Find project by matching UUID
        let fm = FileManager.default
        let projectsPath = fileSystem.claudeProjectsPath

        guard fm.fileExists(atPath: projectsPath),
              let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        for projectDir in projectDirs {
            let projectId = stableUUID(from: projectDir)
            if projectId == id {
                let projectPath = "\(projectsPath)/\(projectDir)"
                let sessionsIndexPath = "\(projectPath)/sessions-index.json"

                var projectRealPath: String?
                var sessionCount = 0
                var lastModified: Date?
                var createdAt: Date?

                if let data = try? Data(contentsOf: URL(fileURLWithPath: sessionsIndexPath)),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let entries = json["entries"] as? [[String: Any]] {

                    sessionCount = entries.count
                    if let firstEntry = entries.first {
                        projectRealPath = firstEntry["projectPath"] as? String
                    }

                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    for entry in entries {
                        if let modifiedStr = entry["modified"] as? String,
                           let date = dateFormatter.date(from: modifiedStr) {
                            if lastModified == nil || date > lastModified! {
                                lastModified = date
                            }
                        }
                        if let createdStr = entry["created"] as? String,
                           let date = dateFormatter.date(from: createdStr) {
                            if createdAt == nil || date < createdAt! {
                                createdAt = date
                            }
                        }
                    }
                }

                if let attrs = try? fm.attributesOfItem(atPath: projectPath) {
                    if lastModified == nil {
                        lastModified = attrs[.modificationDate] as? Date
                    }
                    if createdAt == nil {
                        createdAt = attrs[.creationDate] as? Date
                    }
                }

                let projectName = extractProjectName(from: projectDir, realPath: projectRealPath)

                return APIResponse(
                    success: true,
                    data: Project(
                        id: projectId,
                        name: projectName,
                        path: projectRealPath ?? projectDir,
                        defaultModel: "sonnet",
                        description: nil,
                        createdAt: createdAt ?? Date(),
                        lastAccessedAt: lastModified ?? Date(),
                        sessionCount: sessionCount
                    )
                )
            }
        }

        throw Abort(.notFound, reason: "Project not found")
    }

    /// PUT /projects/:id - Update a project (read-only for file-based projects)
    @Sendable
    func update(req: Request) async throws -> APIResponse<Project> {
        // File-based projects are read-only, just return the current state
        return try await get(req: req)
    }

    /// DELETE /projects/:id - Delete a project
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let fm = FileManager.default
        let projectsPath = fileSystem.claudeProjectsPath

        guard fm.fileExists(atPath: projectsPath),
              let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        for projectDir in projectDirs {
            let projectId = stableUUID(from: projectDir)
            if projectId == id {
                let projectPath = "\(projectsPath)/\(projectDir)"
                try fm.removeItem(atPath: projectPath)

                return APIResponse(
                    success: true,
                    data: DeletedResponse()
                )
            }
        }

        throw Abort(.notFound, reason: "Project not found")
    }

    /// GET /projects/:id/sessions - Get sessions for a project from sessions-index.json
    @Sendable
    func getSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let fm = FileManager.default
        let projectsPath = fileSystem.claudeProjectsPath

        guard fm.fileExists(atPath: projectsPath),
              let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        for projectDir in projectDirs {
            let projectId = stableUUID(from: projectDir)
            if projectId == id {
                let projectPath = "\(projectsPath)/\(projectDir)"
                let sessionsIndexPath = "\(projectPath)/sessions-index.json"

                var sessions: [ChatSession] = []

                if let data = try? Data(contentsOf: URL(fileURLWithPath: sessionsIndexPath)),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let entries = json["entries"] as? [[String: Any]] {

                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    for entry in entries {
                        let sessionId = entry["sessionId"] as? String ?? UUID().uuidString
                        let summary = entry["summary"] as? String
                        let messageCount = entry["messageCount"] as? Int ?? 0
                        let projectRealPath = entry["projectPath"] as? String

                        var createdAt = Date()
                        var modifiedAt = Date()

                        if let createdStr = entry["created"] as? String,
                           let date = dateFormatter.date(from: createdStr) {
                            createdAt = date
                        }
                        if let modifiedStr = entry["modified"] as? String,
                           let date = dateFormatter.date(from: modifiedStr) {
                            modifiedAt = date
                        }

                        let projectName = extractProjectName(from: projectDir, realPath: projectRealPath)

                        sessions.append(ChatSession(
                            id: UUID(uuidString: sessionId) ?? UUID(),
                            claudeSessionId: sessionId,
                            name: summary,
                            projectId: projectId,
                            projectName: projectName,
                            model: "sonnet",
                            permissionMode: .default,
                            status: .completed,
                            messageCount: messageCount,
                            totalCostUSD: nil,
                            source: .external,
                            forkedFrom: nil,
                            createdAt: createdAt,
                            lastActiveAt: modifiedAt
                        ))
                    }
                }

                // Sort by last active (most recent first)
                sessions.sort { $0.lastActiveAt > $1.lastActiveAt }

                return APIResponse(
                    success: true,
                    data: ListResponse(items: sessions)
                )
            }
        }

        throw Abort(.notFound, reason: "Project not found")
    }
}
