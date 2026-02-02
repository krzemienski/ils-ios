import Vapor
import ILSShared

struct SkillsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let skills = routes.grouped("skills")

        skills.get(use: list)
        skills.post(use: create)
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
}
