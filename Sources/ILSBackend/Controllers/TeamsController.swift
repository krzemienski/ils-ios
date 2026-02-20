import Vapor
import ILSShared

struct TeamsController: RouteCollection {
    let fileService: TeamsFileService
    let executorService: TeamsExecutorService
    let templateService: TeamTemplateService

    init(fileService: TeamsFileService, executorService: TeamsExecutorService, templateService: TeamTemplateService) {
        self.fileService = fileService
        self.executorService = executorService
        self.templateService = templateService
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
        teams.get(":name", "metrics", use: metrics)

        // Template endpoints
        teams.get("templates", use: listTemplates)
        teams.post("templates", use: createTemplate)
        teams.get("templates", ":templateId", use: getTemplate)
        teams.put("templates", ":templateId", use: updateTemplate)
        teams.delete("templates", ":templateId", use: deleteTemplate)
        teams.post("templates", ":templateId", "apply", use: applyTemplate)
    }

    // MARK: - Teams Management

    @Sendable
    func list(req: Request) async throws -> APIResponse<[AgentTeam]> {
        let teams = try await fileService.listTeams()
        return APIResponse(success: true, data: teams)
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<AgentTeam> {
        let request = try req.content.decode(CreateTeamRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")

        let team = try await fileService.createTeam(name: request.name, description: request.description)
        return APIResponse(success: true, data: team)
    }

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

    // MARK: - Metrics

    @Sendable
    func metrics(req: Request) async throws -> APIResponse<TeamMetricsResponse> {
        guard let teamName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Team name is required")
        }

        guard var team = try await fileService.getTeam(name: teamName) else {
            throw Abort(.notFound, reason: "Team '\(teamName)' not found")
        }

        // Update member statuses from executor service
        for i in 0..<team.members.count {
            let status = await executorService.getMemberStatus(teamName: teamName, memberName: team.members[i].name)
            team.members[i].status = status
        }

        // Load tasks for this team
        let tasks = try await fileService.listTasks(team: teamName)

        // Calculate agent statistics
        let totalAgents = team.members.count
        let activeAgents = team.members.filter { $0.status == .active }.count
        let idleAgents = team.members.filter { $0.status == .idle }.count
        let erroredAgents = 0 // Currently no error status, could be added later

        let agentStats = TeamMetricsResponse.AgentStats(
            total: totalAgents,
            active: activeAgents,
            idle: idleAgents,
            errored: erroredAgents
        )

        // Calculate task statistics
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.status == .completed }.count
        let inProgressTasks = tasks.filter { $0.status == .inProgress }.count
        let pendingTasks = tasks.filter { $0.status == .pending }.count
        let failedTasks = 0 // Currently no failed status
        let successRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) * 100 : 0.0

        let taskStats = TeamMetricsResponse.TaskStats(
            total: totalTasks,
            completed: completedTasks,
            inProgress: inProgressTasks,
            pending: pendingTasks,
            failed: failedTasks,
            successRate: successRate
        )

        // Calculate performance metrics (simplified for now)
        let averageCompletionTime = 0.0 // Would require task timing data
        let averageResponseTime = 0.0 // Would require message timing data
        let throughput = 0.0 // Would require time-based task completion tracking
        let efficiencyScore = totalAgents > 0 ? (Double(activeAgents) / Double(totalAgents)) * 100 : 0.0
        let collaborationScore = 0.0 // Would require message/collaboration tracking

        let performance = TeamMetricsResponse.PerformanceMetrics(
            averageCompletionTime: averageCompletionTime,
            averageResponseTime: averageResponseTime,
            throughput: throughput,
            efficiencyScore: efficiencyScore,
            collaborationScore: collaborationScore
        )

        // Calculate workload distribution per agent
        let workloadDistribution: [TeamMetricsResponse.WorkloadDistribution] = team.members.map { member in
            let assignedTasks = tasks.filter { $0.owner == member.name }.count
            let completedTasksByMember = tasks.filter { $0.owner == member.name && $0.status == .completed }.count
            let workloadPercentage = totalTasks > 0 ? Double(assignedTasks) / Double(totalTasks) * 100 : 0.0
            let utilization = member.status == .active ? 100.0 : 0.0

            return TeamMetricsResponse.WorkloadDistribution(
                agentId: member.agentId ?? member.name,
                agentName: member.name,
                assignedTasks: assignedTasks,
                completedTasks: completedTasksByMember,
                workloadPercentage: workloadPercentage,
                utilization: utilization
            )
        }

        let metricsResponse = TeamMetricsResponse(
            teamId: teamName,
            teamName: teamName,
            agents: agentStats,
            tasks: taskStats,
            performance: performance,
            workloadDistribution: workloadDistribution,
            timestamp: Date()
        )

        return APIResponse(success: true, data: metricsResponse)
    }

    // MARK: - Template Management

    @Sendable
    func listTemplates(req: Request) async throws -> APIResponse<[TeamTemplate]> {
        let templates = try await templateService.listTemplates()
        return APIResponse(success: true, data: templates)
    }

    @Sendable
    func getTemplate(req: Request) async throws -> APIResponse<TeamTemplate> {
        guard let templateId = req.parameters.get("templateId") else {
            throw Abort(.badRequest, reason: "Template ID is required")
        }

        guard let template = try await templateService.getTemplate(id: templateId) else {
            throw Abort(.notFound, reason: "Template '\(templateId)' not found")
        }

        return APIResponse(success: true, data: template)
    }

    @Sendable
    func createTemplate(req: Request) async throws -> APIResponse<TeamTemplate> {
        let request = try req.content.decode(CreateTemplateRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(request.category, maxLength: 100, fieldName: "category")

        // Generate ID from name (lowercase, replace spaces with hyphens)
        let id = request.name.lowercased().replacingOccurrences(of: " ", with: "-")

        let template = try await templateService.createTemplate(
            id: id,
            name: request.name,
            description: request.description,
            category: request.category,
            members: request.members ?? [],
            tasks: request.tasks ?? []
        )

        return APIResponse(success: true, data: template)
    }

    @Sendable
    func updateTemplate(req: Request) async throws -> APIResponse<TeamTemplate> {
        guard let templateId = req.parameters.get("templateId") else {
            throw Abort(.badRequest, reason: "Template ID is required")
        }

        let request = try req.content.decode(UpdateTemplateRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(request.category, maxLength: 100, fieldName: "category")

        let template = try await templateService.updateTemplate(
            id: templateId,
            name: request.name,
            description: request.description,
            category: request.category,
            members: request.members,
            tasks: request.tasks
        )

        return APIResponse(success: true, data: template)
    }

    @Sendable
    func deleteTemplate(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let templateId = req.parameters.get("templateId") else {
            throw Abort(.badRequest, reason: "Template ID is required")
        }

        try await templateService.deleteTemplate(id: templateId)

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    @Sendable
    func applyTemplate(req: Request) async throws -> APIResponse<AgentTeam> {
        guard let templateId = req.parameters.get("templateId") else {
            throw Abort(.badRequest, reason: "Template ID is required")
        }

        guard let template = try await templateService.getTemplate(id: templateId) else {
            throw Abort(.notFound, reason: "Template '\(templateId)' not found")
        }

        let request = try req.content.decode(ApplyTemplateRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.teamName, maxLength: 255, fieldName: "teamName")
        try PathSanitizer.validateOptionalStringLength(request.teamDescription, maxLength: 1000, fieldName: "teamDescription")

        // Create team from template
        let team = try await fileService.createTeam(
            name: request.teamName,
            description: request.teamDescription ?? template.description
        )

        // Create tasks from template
        for templateTask in template.tasks {
            _ = try await fileService.createTask(
                team: request.teamName,
                subject: templateTask.subject,
                description: templateTask.description
            )
        }

        return APIResponse(success: true, data: team)
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
extension TeamTemplate: Content {}
extension CreateTemplateRequest: Content {}
extension UpdateTemplateRequest: Content {}
extension ApplyTemplateRequest: Content {}
extension TeamMetricsResponse: Content {}
