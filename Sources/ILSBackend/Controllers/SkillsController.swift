import Vapor
import ILSShared

struct SkillsController: RouteCollection {
    let fileSystem = FileSystemService()

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

    /// GET /skills - List all skills
    /// Query params: ?refresh=true to bypass cache, ?search=term to filter by name/tags
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

    /// POST /skills - Create a new skill
    @Sendable
    func create(req: Request) async throws -> APIResponse<Skill> {
        let input = try req.content.decode(CreateSkillRequest.self)

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

    /// GET /skills/:name - Get a single skill
    @Sendable
    func get(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        guard let skill = try fileSystem.getSkill(name: name) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        return APIResponse(
            success: true,
            data: skill
        )
    }

    /// PUT /skills/:name - Update a skill
    @Sendable
    func update(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        let input = try req.content.decode(UpdateSkillRequest.self)

        let skill = try fileSystem.updateSkill(name: name, content: input.content)

        return APIResponse(
            success: true,
            data: skill
        )
    }

    /// DELETE /skills/:name - Delete a skill
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid skill name")
        }

        try fileSystem.deleteSkill(name: name)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// GET /skills/search?q={query} - Search GitHub for skills
    @Sendable
    func search(req: Request) async throws -> APIResponse<ListResponse<GitHubSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Query parameter 'q' is required")
        }

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per_page"] ?? 20

        let github = GitHubService(client: req.client)
        let results = try await github.searchSkills(query: query, page: page, perPage: perPage)

        return APIResponse(
            success: true,
            data: ListResponse(items: results)
        )
    }

    /// POST /skills/install - Install a skill from GitHub
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
        let github = GitHubService(client: req.client)
        let content = try await github.fetchRawContent(owner: owner, repo: repo, path: skillPath)

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
