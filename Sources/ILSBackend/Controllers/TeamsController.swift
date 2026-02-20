import Vapor
import ILSShared

/// Controller for agent team management operations.
///
/// Routes:
/// - `GET /teams`: List all teams
/// - `POST /teams`: Create a new team
/// - `GET /teams/:name`: Get a specific team by name
/// - `DELETE /teams/:name`: Delete a team and shut down all its members
/// - `POST /teams/:name/spawn`: Spawn a new teammate in the team
/// - `POST /teams/:name/shutdown`: Shut down one or all teammates in the team
/// - `GET /teams/:name/tasks`: List tasks for a team
/// - `POST /teams/:name/tasks`: Create a new task for a team
/// - `PUT /teams/:name/tasks/:taskId`: Update an existing task
/// - `GET /teams/:name/messages`: List messages for a team
/// - `POST /teams/:name/messages`: Send a message to a team
/// - `DELETE /teams/:name/members/:memberName`: Remove a member from a team
struct TeamsController: RouteCollection {
    let fileService: TeamsFileService
    let executorService: TeamsExecutorService

    init(fileService: TeamsFileService, executorService: TeamsExecutorService) {
        self.fileService = fileService
        self.executorService = executorService
    }

    func boot(routes: RoutesBuilder) throws {
        let teams = routes.grouped("teams")
        teams.get(use: list)
        teams.post(use: create)
        teams.get(":name", use: detail)
        teams.delete(":name", use: remove)
        teams.post(":name", "spawn", use: spawn)
        teams.post(":name", "shutdown", use: shutdown)
        teams.get(":name", "tasks", use: listTasks)
        teams.post(":name", "tasks", use: createTask)
        teams.put(":name", "tasks", ":taskId", use: updateTask)
        teams.get(":name", "messages", use: listMessages)
        teams.post(":name", "messages", use: sendMessage)
        teams.delete(":name", "members", ":memberName", use: removeMember)
    }

    // MARK: - Teams Management

    /// List all agent teams.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of AgentTeam objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<[AgentTeam]> {
        let teams = try await fileService.listTeams()
        return APIResponse(success: true, data: teams)
    }

    /// Create a new agent team with the given name and optional description.
    ///
    /// - Parameter req: Vapor Request with CreateTeamRequest body (name, description)
    /// - Returns: APIResponse with the newly created AgentTeam
    @Sendable
    func create(req: Request) async throws -> APIResponse<AgentTeam> {
        let request = try req.content.decode(CreateTeamRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")

        let team = try await fileService.createTeam(name: request.name, description: request.description)
        return APIResponse(success: true, data: team)
    }

    /// Get a specific team by name, with live member statuses from the executor service.
    ///
    /// - Parameter req: Vapor Request with name route parameter
    /// - Returns: APIResponse with the AgentTeam including current member statuses
    @Sendable
    func detail(req: Request) async throws -> APIResponse<AgentTeam> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        guard var team = try await fileService.getTeam(name: name) else {
            throw Abort(.notFound, reason: "Team '\(name)' not found")
        }

        // Update member statuses from executor service
        for i in 0..<team.members.count {
            let status = await executorService.getMemberStatus(teamName: name, memberName: team.members[i].name)
            team.members[i].status = status
        }

        return APIResponse(success: true, data: team)
    }

    /// Delete a team by name, shutting down all active teammates before removing team files.
    ///
    /// - Parameter req: Vapor Request with name route parameter
    /// - Returns: APIResponse with DeletedResponse confirming deletion
    @Sendable
    func remove(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        // Shutdown all teammates first
        await executorService.shutdownAll(teamName: name)

        // Delete team files
        try await fileService.deleteTeam(name: name)

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    // MARK: - Member Management

    /// Spawn a new teammate in the specified team using the executor service.
    ///
    /// - Parameter req: Vapor Request with name route parameter and SpawnTeammateRequest body (name, agentType, model, prompt)
    /// - Returns: APIResponse with the newly spawned TeamMember including its initial status
    @Sendable
    func spawn(req: Request) async throws -> APIResponse<TeamMember> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let request = try req.content.decode(SpawnTeammateRequest.self)
        let member = try await executorService.spawnTeammate(
            teamName: teamName,
            name: request.name,
            agentType: request.agentType,
            model: request.model,
            prompt: request.prompt
        )

        return APIResponse(success: true, data: member)
    }

    /// Shut down one or all teammates in the specified team.
    ///
    /// If a `memberName` is provided in the request body, only that member is shut down.
    /// If no body or no `memberName` is provided, all members in the team are shut down.
    ///
    /// - Parameter req: Vapor Request with name route parameter and optional ShutdownTeammateRequest body (memberName)
    /// - Returns: APIResponse with AcknowledgedResponse confirming the shutdown was initiated
    @Sendable
    func shutdown(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let request = try? req.content.decode(ShutdownTeammateRequest.self)

        if let memberName = request?.memberName {
            // Shutdown specific member
            await executorService.shutdownTeammate(teamName: teamName, memberName: memberName)
        } else {
            // Shutdown all members
            await executorService.shutdownAll(teamName: teamName)
        }

        return APIResponse(success: true, data: AcknowledgedResponse(acknowledged: true))
    }

    /// Remove a specific member from a team, shutting them down before removal.
    ///
    /// - Parameter req: Vapor Request with name and memberName route parameters
    /// - Returns: APIResponse with DeletedResponse confirming the member was removed
    @Sendable
    func removeMember(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        guard let memberName = req.parameters.get("memberName") else {
            throw Abort(.badRequest, reason: "Member name is required")
        }

        await executorService.shutdownTeammate(teamName: teamName, memberName: memberName)

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    // MARK: - Task Management

    @Sendable
    func listTasks(req: Request) async throws -> APIResponse<[TeamTask]> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let tasks = try await fileService.listTasks(team: teamName)
        return APIResponse(success: true, data: tasks)
    }

    @Sendable
    func createTask(req: Request) async throws -> APIResponse<TeamTask> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let request = try req.content.decode(CreateTeamTaskRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.subject, maxLength: 500, fieldName: "subject")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 10_000, fieldName: "description")

        let task = try await fileService.createTask(
            team: teamName,
            subject: request.subject,
            description: request.description
        )

        return APIResponse(success: true, data: task)
    }

    @Sendable
    func updateTask(req: Request) async throws -> APIResponse<TeamTask> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        guard let taskId = req.parameters.get("taskId") else {
            throw Abort(.badRequest, reason: "Task ID is required")
        }

        let request = try req.content.decode(UpdateTeamTaskRequest.self)
        let task = try await fileService.updateTask(
            team: teamName,
            id: taskId,
            status: request.status,
            owner: request.owner
        )

        return APIResponse(success: true, data: task)
    }

    // MARK: - Message Management

    @Sendable
    func listMessages(req: Request) async throws -> APIResponse<[TeamMessage]> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let messages = try await fileService.listMessages(team: teamName)
        return APIResponse(success: true, data: messages)
    }

    @Sendable
    func sendMessage(req: Request) async throws -> APIResponse<TeamMessage> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        let request = try req.content.decode(SendTeamMessageRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.content, maxLength: 100_000, fieldName: "content")
        try PathSanitizer.validateOptionalStringLength(request.from, maxLength: 255, fieldName: "from")
        try PathSanitizer.validateOptionalStringLength(request.to, maxLength: 255, fieldName: "to")

        let message = TeamMessage(
            from: request.from ?? "unknown",
            to: request.to,
            content: request.content,
            timestamp: Date()
        )

        try await fileService.sendMessage(team: teamName, message: message)

        return APIResponse(success: true, data: message)
    }
}

// MARK: - Content Conformances

extension AgentTeam: Content {}
extension TeamMember: Content {}
extension TeamTask: Content {}
extension TeamMessage: Content {}
extension CreateTeamRequest: Content {}
extension SpawnTeammateRequest: Content {}
extension SendTeamMessageRequest: Content {}
extension CreateTeamTaskRequest: Content {}
extension UpdateTeamTaskRequest: Content {}
extension ShutdownTeammateRequest: Content {}
