import Vapor
import Fluent
import ILSShared

/// Built-in queue task template for common batch operations.
struct QueueItemTemplate: Codable, Content, Sendable {
    let id: String
    let title: String
    let description: String
    let prompt: String
    let tags: [String]
}

/// Request to bulk-delete agent queue items by ID array.
private struct BulkDeleteQueueItemsRequest: Codable, Sendable {
    let ids: [UUID]
}

/// Controller for agent task queue management.
///
/// Routes:
/// - `GET /queue`: List all queue items with counts
/// - `POST /queue`: Enqueue a new task
/// - `GET /queue/templates`: List built-in task templates
/// - `POST /queue/bulk-delete`: Delete multiple items by ID array
/// - `POST /queue/reorder`: Reorder items by specifying desired ID sequence
/// - `GET /queue/:id`: Get a specific queue item
/// - `PUT /queue/:id`: Update a queue item's mutable fields
/// - `DELETE /queue/:id`: Delete a queue item
/// - `POST /queue/:id/pause`: Pause a running queue item
/// - `POST /queue/:id/resume`: Resume a paused queue item
/// - `POST /queue/:id/cancel`: Cancel a queue item
struct AgentQueueController: RouteCollection {
    let queueService: AgentQueueService

    init(queueService: AgentQueueService) {
        self.queueService = queueService
    }

    func boot(routes: RoutesBuilder) throws {
        let queue = routes.grouped("queue")

        // Static routes first to avoid conflicts with :id parameter
        queue.get(use: list)
        queue.post(use: create)
        queue.get("templates", use: templates)
        queue.post("bulk-delete", use: bulkDelete)
        queue.post("reorder", use: reorder)

        // Parameterised item routes
        queue.get(":id", use: get)
        queue.put(":id", use: update)
        queue.delete(":id", use: delete)
        queue.post(":id", "pause", use: pause)
        queue.post(":id", "resume", use: resume)
        queue.post(":id", "cancel", use: cancel)
    }

    // MARK: - Queue-level

    /// List all queue items and return an `AgentQueue` snapshot.
    ///
    /// Query parameters:
    /// - `status`: Filter items to those with this status (e.g. `queued`, `running`)
    /// - `projectId`: Filter items belonging to a specific project UUID
    @Sendable
    func list(req: Request) async throws -> APIResponse<AgentQueue> {
        let statusFilter = req.query[String.self, at: "status"]
        let projectIdFilter = req.query[UUID.self, at: "projectId"]

        var query = AgentQueueItemModel.query(on: req.db)
            .sort(\.$priority, .ascending)
            .sort(\.$position, .ascending)

        if let status = statusFilter {
            query = query.filter(\.$status == status)
        }

        if let projectId = projectIdFilter {
            query = query.filter(\.$projectId == projectId)
        }

        let items = try await query.all()
        let shared = items.map { $0.toShared() }

        let totalCount = shared.count
        let runningCount = shared.filter { $0.status == .running }.count
        let pendingCount = shared.filter { $0.status == .queued }.count

        // Derive the queue-level execution mode from items; fall back to sequential
        let executionMode = items.first.flatMap {
            QueueExecutionMode(rawValue: $0.executionMode)
        } ?? .sequential

        let agentQueue = AgentQueue(
            items: shared,
            executionMode: executionMode,
            isPaused: false,
            totalCount: totalCount,
            runningCount: runningCount,
            pendingCount: pendingCount
        )

        return APIResponse(success: true, data: agentQueue)
    }

    /// Enqueue a new task.
    ///
    /// - Parameter req: Vapor Request with `CreateQueueItemRequest` body
    /// - Returns: APIResponse with the newly created `AgentQueueItem`
    @Sendable
    func create(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let input = try req.content.decode(CreateQueueItemRequest.self)

        try PathSanitizer.validateStringLength(input.title, maxLength: 255, fieldName: "title")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 10_000, fieldName: "description")

        let projectId = input.projectId.flatMap { UUID(uuidString: $0) }
        let priority = input.priority ?? 0

        // Compute the next position (append to end)
        let topItem = try await AgentQueueItemModel.query(on: req.db)
            .sort(\.$position, .descending)
            .first()
        let maxPosition: Int = topItem?.position ?? -1

        var dependsOnStr: String? = nil
        if let deps = input.dependsOn, !deps.isEmpty,
           let data = try? JSONEncoder().encode(deps),
           let str = String(data: data, encoding: .utf8) {
            dependsOnStr = str
        }

        let model = AgentQueueItemModel(
            title: input.title,
            prompt: input.description,
            projectId: projectId,
            priority: priority,
            position: maxPosition + 1,
            executionMode: input.executionMode ?? .sequential,
            dependsOn: dependsOnStr
        )

        try await model.save(on: req.db)

        // Attempt to dispatch if the queue is active
        await queueService.startNextTask()

        return APIResponse(success: true, data: model.toShared())
    }

    // MARK: - Item-level CRUD

    /// Get a specific queue item by ID.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter (UUID)
    /// - Returns: APIResponse with the `AgentQueueItem`
    @Sendable
    func get(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let model = try await requireQueueItem(from: req)
        return APIResponse(success: true, data: model.toShared())
    }

    /// Update mutable fields of a queue item (title, description, priority, dependsOn).
    ///
    /// Only provided (non-nil) fields are changed. Items that are currently running
    /// cannot have their priority or dependencies changed.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter and `UpdateQueueItemRequest` body
    /// - Returns: APIResponse with the updated `AgentQueueItem`
    @Sendable
    func update(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let model = try await requireQueueItem(from: req)
        let input = try req.content.decode(UpdateQueueItemRequest.self)

        if let title = input.title {
            try PathSanitizer.validateStringLength(title, maxLength: 255, fieldName: "title")
            model.title = title
        }

        if let description = input.description {
            try PathSanitizer.validateOptionalStringLength(description, maxLength: 10_000, fieldName: "description")
            model.prompt = description
        }

        if let priority = input.priority {
            model.priority = priority
        }

        if let deps = input.dependsOn {
            if deps.isEmpty {
                model.dependsOn = nil
            } else if let data = try? JSONEncoder().encode(deps),
                      let str = String(data: data, encoding: .utf8) {
                model.dependsOn = str
            }
        }

        try await model.update(on: req.db)
        return APIResponse(success: true, data: model.toShared())
    }

    /// Delete a queue item.
    ///
    /// Running items are cancelled before deletion.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter (UUID)
    /// - Returns: APIResponse with `DeletedResponse`
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        let model = try await requireQueueItem(from: req)

        // Cancel if running
        if model.status == AgentQueueStatus.running.rawValue,
           let id = model.id {
            try await queueService.cancelTask(id: id)
        }

        try await model.delete(on: req.db)
        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    // MARK: - Bulk Operations

    /// Delete multiple queue items by UUID array.
    ///
    /// - Parameter req: Vapor Request with `BulkDeleteQueueItemsRequest` body
    /// - Returns: APIResponse with `DeletedResponse`
    @Sendable
    func bulkDelete(req: Request) async throws -> APIResponse<DeletedResponse> {
        let input = try req.content.decode(BulkDeleteQueueItemsRequest.self)

        guard !input.ids.isEmpty else {
            throw Abort(.badRequest, reason: "ids array must not be empty")
        }

        // Cancel any running items in the set
        let runningItems = try await AgentQueueItemModel.query(on: req.db)
            .filter(\.$id ~~ input.ids)
            .filter(\.$status == AgentQueueStatus.running.rawValue)
            .all()

        for item in runningItems {
            if let id = item.id {
                try await queueService.cancelTask(id: id)
            }
        }

        // Delete all matched items
        try await AgentQueueItemModel.query(on: req.db)
            .filter(\.$id ~~ input.ids)
            .delete()

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    /// Reorder queue items by providing the desired ID sequence.
    ///
    /// Assigns new `position` values (0-based) according to the supplied order.
    /// IDs not present in the request are moved to the end, preserving relative order.
    ///
    /// - Parameter req: Vapor Request with `ReorderQueueRequest` body
    /// - Returns: APIResponse with the reordered `AgentQueue` snapshot
    @Sendable
    func reorder(req: Request) async throws -> APIResponse<AgentQueue> {
        let input = try req.content.decode(ReorderQueueRequest.self)

        guard !input.orderedIds.isEmpty else {
            throw Abort(.badRequest, reason: "orderedIds must not be empty")
        }

        let orderedUUIDs = input.orderedIds.compactMap { UUID(uuidString: $0) }
        guard orderedUUIDs.count == input.orderedIds.count else {
            throw Abort(.badRequest, reason: "orderedIds contains invalid UUID values")
        }

        // Load all non-terminal items
        let allItems = try await AgentQueueItemModel.query(on: req.db)
            .filter(\.$status == AgentQueueStatus.queued.rawValue)
            .all()

        // Build a lookup map
        var modelMap: [UUID: AgentQueueItemModel] = [:]
        for item in allItems {
            if let id = item.id { modelMap[id] = item }
        }

        // Assign positions based on orderedIds, then append any missing items
        var position = 0
        var processed = Set<UUID>()

        for uuid in orderedUUIDs {
            if let model = modelMap[uuid] {
                model.position = position
                try await model.update(on: req.db)
                processed.insert(uuid)
                position += 1
            }
        }

        // Append items not in orderedIds at the end
        let remaining = allItems.filter { item in
            guard let id = item.id else { return false }
            return !processed.contains(id)
        }
        for model in remaining {
            model.position = position
            try await model.update(on: req.db)
            position += 1
        }

        // Return updated queue snapshot (all items, not just queued)
        let updatedItems = try await AgentQueueItemModel.query(on: req.db)
            .sort(\.$priority, .ascending)
            .sort(\.$position, .ascending)
            .all()

        let shared = updatedItems.map { $0.toShared() }
        let executionMode = updatedItems.first.flatMap {
            QueueExecutionMode(rawValue: $0.executionMode)
        } ?? .sequential

        let agentQueue = AgentQueue(
            items: shared,
            executionMode: executionMode,
            isPaused: false,
            totalCount: shared.count,
            runningCount: shared.filter { $0.status == .running }.count,
            pendingCount: shared.filter { $0.status == .queued }.count
        )

        return APIResponse(success: true, data: agentQueue)
    }

    // MARK: - Item Control

    /// Pause a currently running queue item.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter (UUID)
    /// - Returns: APIResponse with the updated `AgentQueueItem`
    @Sendable
    func pause(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let id = try requireUUID(from: req)
        try await queueService.pauseTask(id: id)
        let model = try await requireQueueItemById(id: id, on: req.db)
        return APIResponse(success: true, data: model.toShared())
    }

    /// Resume a paused queue item, re-queuing it for execution.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter (UUID)
    /// - Returns: APIResponse with the updated `AgentQueueItem`
    @Sendable
    func resume(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let id = try requireUUID(from: req)
        try await queueService.resumeTask(id: id)
        let model = try await requireQueueItemById(id: id, on: req.db)
        return APIResponse(success: true, data: model.toShared())
    }

    /// Cancel a queue item, stopping execution if running.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter (UUID)
    /// - Returns: APIResponse with the updated `AgentQueueItem`
    @Sendable
    func cancel(req: Request) async throws -> APIResponse<AgentQueueItem> {
        let id = try requireUUID(from: req)
        try await queueService.cancelTask(id: id)
        let model = try await requireQueueItemById(id: id, on: req.db)
        return APIResponse(success: true, data: model.toShared())
    }

    // MARK: - Templates

    /// Return the list of built-in queue task templates.
    ///
    /// Templates provide quick-start prompts for common batch operations.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of `QueueItemTemplate`
    @Sendable
    func templates(req: Request) async throws -> APIResponse<[QueueItemTemplate]> {
        let builtIn: [QueueItemTemplate] = [
            QueueItemTemplate(
                id: "run-all-tests",
                title: "Run All Tests",
                description: "Execute the full test suite and report any failures",
                prompt: "Run all tests in this project. Report which tests passed and which failed. If any tests fail, provide a brief explanation of what went wrong.",
                tags: ["testing", "ci"]
            ),
            QueueItemTemplate(
                id: "code-review",
                title: "Code Review",
                description: "Review all uncommitted changes for quality and correctness",
                prompt: "Review all uncommitted changes in this project. Look for potential bugs, code quality issues, security concerns, and missing error handling. Summarize your findings.",
                tags: ["review", "quality"]
            ),
            QueueItemTemplate(
                id: "fix-lint",
                title: "Fix Linting Issues",
                description: "Automatically fix all linting and formatting issues",
                prompt: "Find and fix all linting, formatting, and style issues in this project. Run the linter after fixing to confirm everything passes.",
                tags: ["lint", "formatting"]
            ),
            QueueItemTemplate(
                id: "update-dependencies",
                title: "Update Dependencies",
                description: "Update all package dependencies to their latest compatible versions",
                prompt: "Update all package dependencies to their latest compatible versions. Check for breaking changes and update the code if necessary. Run tests afterwards to confirm everything still works.",
                tags: ["dependencies", "maintenance"]
            ),
            QueueItemTemplate(
                id: "generate-docs",
                title: "Generate Documentation",
                description: "Generate or update documentation for all public APIs",
                prompt: "Generate or update documentation comments for all public APIs, functions, and types in this project. Follow the existing documentation style.",
                tags: ["docs", "documentation"]
            ),
            QueueItemTemplate(
                id: "security-audit",
                title: "Security Audit",
                description: "Scan the codebase for common security vulnerabilities",
                prompt: "Perform a security audit of this codebase. Check for common vulnerabilities such as injection flaws, insecure dependencies, hardcoded credentials, and improper error handling. Report findings with severity levels.",
                tags: ["security", "audit"]
            )
        ]

        return APIResponse(success: true, data: builtIn)
    }

    // MARK: - Private Helpers

    /// Extract and validate the `:id` UUID route parameter.
    private func requireUUID(from req: Request) throws -> UUID {
        guard let idString = req.parameters.get("id"),
              let uuid = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid or missing queue item ID")
        }
        return uuid
    }

    /// Fetch the `AgentQueueItemModel` for the `:id` route parameter or throw 404.
    private func requireQueueItem(from req: Request) async throws -> AgentQueueItemModel {
        let id = try requireUUID(from: req)
        return try await requireQueueItemById(id: id, on: req.db)
    }

    /// Fetch an `AgentQueueItemModel` by UUID or throw 404.
    private func requireQueueItemById(id: UUID, on db: Database) async throws -> AgentQueueItemModel {
        guard let model = try await AgentQueueItemModel.find(id, on: db) else {
            throw Abort(.notFound, reason: "Queue item \(id) not found")
        }
        return model
    }
}
