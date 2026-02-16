import Vapor
import ILSShared

/// Controller for Claude Code skill management operations.
///
/// Manages custom workflows and commands in Claude Code through the skills system.
/// Skills can be local user-created files or installed from GitHub repositories.
///
/// Routes:
/// - `GET /skills`: List all skills (local, plugin-provided, and built-in)
/// - `GET /skills/search`: Search GitHub for skill repositories
/// - `POST /skills`: Create a new local skill
/// - `POST /skills/install`: Install a skill from a GitHub repository
/// - `GET /skills/:name`: Get a specific skill by name
/// - `PUT /skills/:name`: Update an existing skill's content
/// - `DELETE /skills/:name`: Delete a local skill
struct SkillsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let skills = routes.grouped("skills")

        skills.get(use: list)
        skills.get("search", use: search)
        skills.post(use: create)
        skills.post("install", use: install)
        skills.get(":name", use: get)
        skills.put(":name", use: update)
        skills.delete(":name", use: delete)
    }

    /// List all available skills from `~/.claude/skills/` and plugin directories.
    ///
    /// Query parameters:
    /// - `refresh`: If "true", bypasses the file system cache
    /// - `search`: Filter by name, description, or tags (case-insensitive)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of Skill objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Skill>> {
        let bypassCache = req.query[Bool.self, at: "refresh"] ?? false
        let searchTerm = req.query[String.self, at: "search"]

        var skills = try await fileSystem.listSkills(bypassCache: bypassCache)

        // Filter by search term if provided (searches name, description, and tags)
        if let search = searchTerm?.lowercased(), !search.isEmpty {
            skills = skills.filter { skill in
                skill.name.lowercased().contains(search) ||
                (skill.description?.lowercased().contains(search) ?? false) ||
                skill.tags.contains { $0.lowercased().contains(search) }
            }
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: skills)
        )
    }

    /// Create a new skill in `~/.claude/skills/`.
    ///
    /// - Parameter req: Vapor Request with CreateSkillRequest body
    /// - Returns: APIResponse with created Skill
    @Sendable
    func create(req: Request) async throws -> APIResponse<Skill> {
        let input = try req.content.decode(CreateSkillRequest.self)

        // Validate input
        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateComponent(input.name)
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateStringLength(input.content, maxLength: 1_000_000, fieldName: "content")

        // Build content with frontmatter if description provided
        var content = input.content
        if let description = input.description, !content.hasPrefix("---") {
            content = """
            ---
            name: \(input.name)
            description: \(description)
            ---
            \(content)
            """
        }

        let skill = try fileSystem.createSkill(name: input.name, content: content)

        return APIResponse(
            success: true,
            data: skill
        )
    }

    /// Get a specific skill by name.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with Skill
    /// - Throws: Abort(.notFound) if skill doesn't exist
    @Sendable
    func get(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        // Validate name to prevent path traversal
        try PathSanitizer.validateComponent(name)

        guard let skill = try fileSystem.getSkill(name: name) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        return APIResponse(
            success: true,
            data: skill
        )
    }

    /// Update an existing skill's content.
    ///
    /// - Parameter req: Vapor Request with name parameter and UpdateSkillRequest body
    /// - Returns: APIResponse with updated Skill
    @Sendable
    func update(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        // Validate inputs
        try PathSanitizer.validateComponent(name)
        let input = try req.content.decode(UpdateSkillRequest.self)
        try PathSanitizer.validateStringLength(input.content, maxLength: 1_000_000, fieldName: "content")

        let skill = try fileSystem.updateSkill(name: name, content: input.content)

        return APIResponse(
            success: true,
            data: skill
        )
    }

    /// Delete a local skill from the filesystem.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        // Validate name to prevent path traversal
        try PathSanitizer.validateComponent(name)

        try fileSystem.deleteSkill(name: name)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// Search GitHub for skill repositories.
    ///
    /// Query parameters:
    /// - `q`: Search query (required)
    /// - `page`: Page number (default 1)
    /// - `per_page`: Results per page (default 20)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of GitHubSearchResult objects
    @Sendable
    func search(req: Request) async throws -> APIResponse<ListResponse<GitHubSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Query parameter 'q' is required")
        }

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per_page"] ?? 20

        let results = try await req.application.githubService.searchSkills(query: query, page: page, perPage: perPage)

        return APIResponse(
            success: true,
            data: ListResponse(items: results)
        )
    }

    /// Install a skill from a GitHub repository.
    ///
    /// Fetches the skill content from GitHub and saves it to `~/.claude/skills/{repo}/SKILL.md`.
    ///
    /// - Parameter req: Vapor Request with SkillInstallRequest body
    /// - Returns: APIResponse with installed Skill
    @Sendable
    func install(req: Request) async throws -> APIResponse<Skill> {
        let installRequest = try req.content.decode(SkillInstallRequest.self)

        // Parse owner/repo from repository string
        let parts = installRequest.repository.split(separator: "/")
        guard parts.count == 2 else {
            throw Abort(.badRequest, reason: "Repository must be in 'owner/repo' format")
        }
        let owner = String(parts[0])
        let repo = String(parts[1])

        // Determine skill path
        let skillPath = installRequest.skillPath ?? "SKILL.md"

        // Fetch raw content from GitHub
        let content = try await req.application.githubService.fetchRawContent(owner: owner, repo: repo, path: skillPath)

        // Determine skill name from repo name
        let skillName = repo

        // Write to ~/.claude/skills/{name}/SKILL.md
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser
        let skillDir = homeDir.appendingPathComponent(".claude/skills/\(skillName)")

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let skillFilePath = skillDir.appendingPathComponent("SKILL.md")
        try content.write(to: skillFilePath, atomically: true, encoding: .utf8)

        // Invalidate cache so the new skill shows up
        await fileSystem.invalidateSkillsCache()

        // Return the installed skill
        let skill = Skill(
            name: skillName,
            description: "Installed from \(installRequest.repository)",
            path: skillFilePath.path,
            source: .github,
            content: content,
            rawContent: content,
            stars: nil,
            author: owner
        )

        return APIResponse(
            success: true,
            data: skill
        )
    }
}
