import Foundation
import Vapor
import ILSShared
import Logging

/// Actor responsible for executing workflows and tracking their execution state.
///
/// ## Execution Model
///
/// Workflows are executed node-by-node following the dependency graph defined by
/// connections. The engine:
/// - Validates the workflow graph before execution
/// - Executes nodes in topological order (respecting dependencies)
/// - Tracks execution progress and updates state
/// - Handles node-specific logic for each WorkflowNodeType
/// - Manages error handling, retry, and fallback logic
///
/// ## State Management
///
/// Active executions are tracked in memory. Execution state includes:
/// - `currentNodeId`: The node currently being executed
/// - `completedNodeIds`: All nodes that have completed successfully
/// - `progress`: Percentage complete (0.0 to 1.0)
/// - `status`: Current execution status (pending, running, paused, completed, failed, cancelled)
///
/// ## Node Types
///
/// Supported node types:
/// - `createSession`: Creates a new Claude Code session
/// - `sendMessage`: Sends a message to an existing session
/// - `waitForResponse`: Waits for a session response to complete
/// - `conditionalBranch`: Branches execution based on response content
/// - `export`: Exports session data
/// - `notify`: Sends a notification
/// - `retry`: Retry logic for error recovery
/// - `fallback`: Fallback logic for error recovery
actor WorkflowExecutionEngine {
    /// Structured logger for workflow execution
    private static let logger = Logger(label: "ils.workflow-executor")

    /// Active executions keyed by execution ID
    private var activeExecutions: [String: WorkflowExecution] = [:]

    /// Execution context data (session IDs, intermediate results) keyed by execution ID
    private var executionContexts: [String: [String: String]] = [:]

    /// JSON encoder for serializing workflow data
    private let jsonEncoder: JSONEncoder

    /// JSON decoder for parsing workflow data
    private let jsonDecoder: JSONDecoder

    init() {
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = .prettyPrinted
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Start executing a workflow.
    ///
    /// - Parameters:
    ///   - workflow: The workflow to execute
    ///   - parameters: Optional execution parameters
    /// - Returns: A WorkflowExecution instance tracking the execution state
    func startExecution(
        workflow: Workflow,
        parameters: [String: String]?
    ) async throws -> WorkflowExecution {
        Self.logger.info("Starting workflow execution", metadata: [
            "workflow_id": .string(workflow.id),
            "workflow_name": .string(workflow.name)
        ])

        // Validate workflow before execution
        try validateWorkflow(workflow)

        // Create execution record
        let execution = WorkflowExecution(
            id: UUID().uuidString,
            workflowId: workflow.id,
            status: .pending,
            currentNodeId: nil,
            completedNodeIds: [],
            error: nil,
            startedAt: nil,
            completedAt: nil,
            progress: 0.0
        )

        // Store execution and context
        activeExecutions[execution.id] = execution
        executionContexts[execution.id] = parameters ?? [:]

        // Begin execution asynchronously
        Task {
            await self.executeWorkflow(execution: execution, workflow: workflow)
        }

        return execution
    }

    /// Get the current state of an execution.
    ///
    /// - Parameter executionId: The execution ID
    /// - Returns: The current WorkflowExecution state, or nil if not found
    func getExecution(executionId: String) -> WorkflowExecution? {
        return activeExecutions[executionId]
    }

    /// Pause an active execution.
    ///
    /// - Parameter executionId: The execution ID
    /// - Returns: Updated WorkflowExecution
    func pauseExecution(executionId: String) throws -> WorkflowExecution {
        guard var execution = activeExecutions[executionId] else {
            throw WorkflowExecutionError.executionNotFound(executionId)
        }

        guard execution.status == .running else {
            throw WorkflowExecutionError.invalidState("Cannot pause execution in state: \(execution.status)")
        }

        execution.status = .paused
        activeExecutions[executionId] = execution

        Self.logger.info("Paused execution", metadata: ["execution_id": .string(executionId)])

        return execution
    }

    /// Resume a paused execution.
    ///
    /// - Parameter executionId: The execution ID
    /// - Returns: Updated WorkflowExecution
    func resumeExecution(executionId: String, workflow: Workflow) async throws -> WorkflowExecution {
        guard var execution = activeExecutions[executionId] else {
            throw WorkflowExecutionError.executionNotFound(executionId)
        }

        guard execution.status == .paused else {
            throw WorkflowExecutionError.invalidState("Cannot resume execution in state: \(execution.status)")
        }

        execution.status = .running
        activeExecutions[executionId] = execution

        Self.logger.info("Resumed execution", metadata: ["execution_id": .string(executionId)])

        // Continue execution
        Task {
            await self.executeWorkflow(execution: execution, workflow: workflow)
        }

        return execution
    }

    /// Cancel an active execution.
    ///
    /// - Parameter executionId: The execution ID
    /// - Returns: Updated WorkflowExecution
    func cancelExecution(executionId: String) throws -> WorkflowExecution {
        guard var execution = activeExecutions[executionId] else {
            throw WorkflowExecutionError.executionNotFound(executionId)
        }

        guard execution.status == .running || execution.status == .paused || execution.status == .pending else {
            throw WorkflowExecutionError.invalidState("Cannot cancel execution in state: \(execution.status)")
        }

        execution.status = .cancelled
        execution.completedAt = Date()
        activeExecutions[executionId] = execution

        Self.logger.info("Cancelled execution", metadata: ["execution_id": .string(executionId)])

        return execution
    }

    /// List all active executions.
    ///
    /// - Returns: Array of all tracked WorkflowExecution instances
    func listExecutions() -> [WorkflowExecution] {
        return Array(activeExecutions.values)
    }

    /// Clean up completed/failed/cancelled executions older than the specified date.
    ///
    /// - Parameter olderThan: Date threshold for cleanup
    func cleanupExecutions(olderThan: Date) {
        let before = activeExecutions.count
        activeExecutions = activeExecutions.filter { _, execution in
            // Keep running/paused executions
            if execution.status == .running || execution.status == .paused {
                return true
            }
            // Keep recent completions
            if let completedAt = execution.completedAt, completedAt > olderThan {
                return true
            }
            // Remove old completed/failed/cancelled
            return false
        }
        let after = activeExecutions.count
        if before != after {
            Self.logger.info("Cleaned up executions", metadata: [
                "removed": .stringConvertible(before - after),
                "remaining": .stringConvertible(after)
            ])
        }
    }

    // MARK: - Private Execution Logic

    /// Execute a workflow by processing nodes in dependency order.
    private func executeWorkflow(execution: WorkflowExecution, workflow: Workflow) async {
        var execution = execution

        Self.logger.debug("Beginning workflow execution", metadata: [
            "execution_id": .string(execution.id),
            "workflow_id": .string(workflow.id)
        ])

        // Mark as running
        execution.status = .running
        execution.startedAt = Date()
        activeExecutions[execution.id] = execution

        do {
            // Build dependency graph
            let nodeOrder = try topologicalSort(workflow: workflow)
            let totalNodes = nodeOrder.count

            Self.logger.debug("Execution order", metadata: [
                "node_count": .stringConvertible(totalNodes),
                "nodes": .string(nodeOrder.joined(separator: ", "))
            ])

            // Execute nodes in order
            for (index, nodeId) in nodeOrder.enumerated() {
                // Check for pause/cancel
                if let current = activeExecutions[execution.id], current.status != .running {
                    Self.logger.info("Execution interrupted", metadata: [
                        "execution_id": .string(execution.id),
                        "status": .string(String(describing: current.status))
                    ])
                    return
                }

                guard let node = workflow.nodes.first(where: { $0.id == nodeId }) else {
                    throw WorkflowExecutionError.nodeNotFound(nodeId)
                }

                // Update current node
                execution.currentNodeId = node.id
                execution.progress = Double(index) / Double(totalNodes)
                activeExecutions[execution.id] = execution

                // Execute the node
                try await executeNode(node: node, execution: execution, workflow: workflow)

                // Mark node as completed
                execution.completedNodeIds.append(node.id)
                activeExecutions[execution.id] = execution
            }

            // Mark as completed
            execution.status = .completed
            execution.currentNodeId = nil
            execution.progress = 1.0
            execution.completedAt = Date()
            activeExecutions[execution.id] = execution

            Self.logger.info("Workflow execution completed", metadata: [
                "execution_id": .string(execution.id),
                "duration_seconds": .stringConvertible(execution.completedAt!.timeIntervalSince(execution.startedAt ?? Date()))
            ])

        } catch {
            Self.logger.error("Workflow execution failed", metadata: [
                "execution_id": .string(execution.id),
                "error": .string(error.localizedDescription)
            ])

            execution.status = .failed
            execution.error = error.localizedDescription
            execution.completedAt = Date()
            activeExecutions[execution.id] = execution
        }
    }

    /// Execute a single workflow node.
    private func executeNode(node: WorkflowNode, execution: WorkflowExecution, workflow: Workflow) async throws {
        Self.logger.debug("Executing node", metadata: [
            "node_id": .string(node.id),
            "node_type": .string(node.type.rawValue),
            "label": .string(node.label)
        ])

        switch node.type {
        case .createSession:
            try await executeCreateSession(node: node, execution: execution)
        case .sendMessage:
            try await executeSendMessage(node: node, execution: execution)
        case .waitForResponse:
            try await executeWaitForResponse(node: node, execution: execution)
        case .conditionalBranch:
            try await executeConditionalBranch(node: node, execution: execution, workflow: workflow)
        case .export:
            try await executeExport(node: node, execution: execution)
        case .notify:
            try await executeNotify(node: node, execution: execution)
        case .retry:
            try await executeRetry(node: node, execution: execution, workflow: workflow)
        case .fallback:
            try await executeFallback(node: node, execution: execution, workflow: workflow)
        }
    }

    // MARK: - Node Type Handlers

    private func executeCreateSession(node: WorkflowNode, execution: WorkflowExecution) async throws {
        // Placeholder: In a real implementation, this would call SessionsController
        // to create a new session. For now, generate a mock session ID.
        let sessionId = UUID().uuidString
        executionContexts[execution.id]?["sessionId"] = sessionId

        Self.logger.debug("Created session", metadata: [
            "node_id": .string(node.id),
            "session_id": .string(sessionId)
        ])
    }

    private func executeSendMessage(node: WorkflowNode, execution: WorkflowExecution) async throws {
        guard let sessionId = executionContexts[execution.id]?["sessionId"] else {
            throw WorkflowExecutionError.missingContext("sessionId")
        }

        guard let message = node.configuration?["message"] else {
            throw WorkflowExecutionError.missingConfiguration("message")
        }

        // Placeholder: In a real implementation, this would call ChatController
        // to send a message to the session.
        Self.logger.debug("Sent message", metadata: [
            "node_id": .string(node.id),
            "session_id": .string(sessionId),
            "message_length": .stringConvertible(message.count)
        ])
    }

    private func executeWaitForResponse(node: WorkflowNode, execution: WorkflowExecution) async throws {
        guard let sessionId = executionContexts[execution.id]?["sessionId"] else {
            throw WorkflowExecutionError.missingContext("sessionId")
        }

        // Placeholder: In a real implementation, this would poll the session
        // until the Claude response is complete.
        Self.logger.debug("Waiting for response", metadata: [
            "node_id": .string(node.id),
            "session_id": .string(sessionId)
        ])

        // Simulate waiting
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }

    private func executeConditionalBranch(node: WorkflowNode, execution: WorkflowExecution, workflow: Workflow) async throws {
        // Placeholder: Evaluate condition from node configuration
        // In a real implementation, this would check response content and
        // determine which outgoing connection to follow.
        Self.logger.debug("Evaluating conditional branch", metadata: [
            "node_id": .string(node.id)
        ])
    }

    private func executeExport(node: WorkflowNode, execution: WorkflowExecution) async throws {
        guard let sessionId = executionContexts[execution.id]?["sessionId"] else {
            throw WorkflowExecutionError.missingContext("sessionId")
        }

        let format = node.configuration?["format"] ?? "json"

        // Placeholder: In a real implementation, this would call SessionsController
        // to export the session in the specified format.
        Self.logger.debug("Exported session", metadata: [
            "node_id": .string(node.id),
            "session_id": .string(sessionId),
            "format": .string(format)
        ])
    }

    private func executeNotify(node: WorkflowNode, execution: WorkflowExecution) async throws {
        guard let message = node.configuration?["message"] else {
            throw WorkflowExecutionError.missingConfiguration("message")
        }

        // Placeholder: In a real implementation, this would send a notification
        // (e.g., webhook, email, Slack message).
        Self.logger.debug("Sent notification", metadata: [
            "node_id": .string(node.id),
            "message": .string(message)
        ])
    }

    private func executeRetry(node: WorkflowNode, execution: WorkflowExecution, workflow: Workflow) async throws {
        // Placeholder: Retry logic for error recovery
        let maxRetries = Int(node.configuration?["maxRetries"] ?? "3") ?? 3

        Self.logger.debug("Retry node", metadata: [
            "node_id": .string(node.id),
            "max_retries": .stringConvertible(maxRetries)
        ])
    }

    private func executeFallback(node: WorkflowNode, execution: WorkflowExecution, workflow: Workflow) async throws {
        // Placeholder: Fallback logic for error recovery
        Self.logger.debug("Fallback node", metadata: [
            "node_id": .string(node.id)
        ])
    }

    // MARK: - Validation & Graph Analysis

    /// Validate workflow before execution.
    private func validateWorkflow(_ workflow: Workflow) throws {
        // Check for empty workflow
        guard !workflow.nodes.isEmpty else {
            throw WorkflowExecutionError.invalidWorkflow("Workflow has no nodes")
        }

        // Check for cycles (would cause infinite execution)
        _ = try topologicalSort(workflow: workflow)

        // Validate node IDs are unique
        let nodeIds = workflow.nodes.map { $0.id }
        let uniqueIds = Set(nodeIds)
        guard nodeIds.count == uniqueIds.count else {
            throw WorkflowExecutionError.invalidWorkflow("Duplicate node IDs found")
        }

        // Validate connections reference valid nodes
        for connection in workflow.connections {
            guard uniqueIds.contains(connection.fromNodeId) else {
                throw WorkflowExecutionError.invalidWorkflow("Connection references invalid fromNodeId: \(connection.fromNodeId)")
            }
            guard uniqueIds.contains(connection.toNodeId) else {
                throw WorkflowExecutionError.invalidWorkflow("Connection references invalid toNodeId: \(connection.toNodeId)")
            }
        }
    }

    /// Perform topological sort to determine node execution order.
    ///
    /// Uses Kahn's algorithm to detect cycles and produce a valid execution order.
    ///
    /// - Parameter workflow: The workflow to sort
    /// - Returns: Array of node IDs in execution order
    /// - Throws: WorkflowExecutionError if the graph contains a cycle
    private func topologicalSort(workflow: Workflow) throws -> [String] {
        var inDegree: [String: Int] = [:]
        var adjacency: [String: [String]] = [:]

        // Initialize
        for node in workflow.nodes {
            inDegree[node.id] = 0
            adjacency[node.id] = []
        }

        // Build graph
        for connection in workflow.connections {
            adjacency[connection.fromNodeId]?.append(connection.toNodeId)
            inDegree[connection.toNodeId, default: 0] += 1
        }

        // Find all nodes with no incoming edges
        var queue: [String] = []
        for (nodeId, degree) in inDegree where degree == 0 {
            queue.append(nodeId)
        }

        var sorted: [String] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            sorted.append(current)

            for neighbor in adjacency[current] ?? [] {
                inDegree[neighbor]! -= 1
                if inDegree[neighbor]! == 0 {
                    queue.append(neighbor)
                }
            }
        }

        // If sorted contains all nodes, no cycle exists
        guard sorted.count == workflow.nodes.count else {
            throw WorkflowExecutionError.invalidWorkflow("Workflow contains a cycle")
        }

        return sorted
    }
}

// MARK: - Errors

enum WorkflowExecutionError: Error, LocalizedError {
    case executionNotFound(String)
    case invalidWorkflow(String)
    case invalidState(String)
    case nodeNotFound(String)
    case missingContext(String)
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .executionNotFound(let id):
            return "Execution '\(id)' not found"
        case .invalidWorkflow(let reason):
            return "Invalid workflow: \(reason)"
        case .invalidState(let reason):
            return "Invalid state: \(reason)"
        case .nodeNotFound(let id):
            return "Node '\(id)' not found"
        case .missingContext(let key):
            return "Missing execution context: \(key)"
        case .missingConfiguration(let key):
            return "Missing node configuration: \(key)"
        }
    }
}
