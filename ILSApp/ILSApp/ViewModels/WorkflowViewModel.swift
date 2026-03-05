import Foundation
import Observation
import ILSShared

/// View model for workflow automation management.
///
/// Manages workflow CRUD operations, execution control, and scheduling.
/// Supports creating, editing, executing workflows with visual node-based automation.
///
/// ## Topics
/// ### Properties
/// - ``workflows`` - Array of all loaded workflows
/// - ``selectedWorkflow`` - Currently selected workflow for detail view
/// - ``currentExecution`` - Current workflow execution, if any
/// - ``executions`` - Execution history for the selected workflow
/// - ``currentSchedule`` - Current schedule for the selected workflow
/// - ``isLoading`` - Whether data is currently loading
/// - ``error`` - Last error encountered
///
/// ### Workflow Operations
/// - ``loadWorkflows()`` - Load all workflows
/// - ``loadWorkflow(id:)`` - Load a specific workflow by ID
/// - ``createWorkflow(name:description:nodes:connections:)`` - Create a new workflow
/// - ``updateWorkflow(id:name:description:status:nodes:connections:)`` - Update an existing workflow
/// - ``deleteWorkflow(id:)`` - Delete a workflow
///
/// ### Execution Operations
/// - ``executeWorkflow(id:parameters:)`` - Execute a workflow with optional parameters
/// - ``cancelExecution(workflowId:executionId:)`` - Cancel a running execution
/// - ``loadExecutions(workflowId:)`` - Load execution history for a workflow
/// - ``loadExecution(workflowId:executionId:)`` - Load a specific execution status
///
/// ### Schedule Operations
/// - ``createSchedule(workflowId:cron:enabled:timezone:)`` - Create a schedule for a workflow
/// - ``updateSchedule(workflowId:cron:enabled:timezone:)`` - Update an existing schedule
/// - ``deleteSchedule(workflowId:)`` - Delete a workflow schedule
/// - ``loadSchedule(workflowId:)`` - Load the current schedule for a workflow
@Observable
@MainActor
class WorkflowViewModel: BaseViewModel {
    /// Array of all loaded workflows.
    var workflows: [Workflow] = []
    /// Currently selected workflow for detail view.
    var selectedWorkflow: Workflow?
    /// Current workflow execution, if any.
    var currentExecution: WorkflowExecution?
    /// Execution history for the selected workflow.
    var executions: [WorkflowExecution] = []
    /// Current schedule for the selected workflow.
    var currentSchedule: WorkflowSchedule?

    // MARK: - Workflow Management

    /// Load all workflows, sorted by most recently updated.
    func loadWorkflows() async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let response: APIResponse<[Workflow]> = try await client.get("/workflows")
            if response.success, let data = response.data {
                workflows = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load workflows"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Load a specific workflow by ID and set it as selectedWorkflow.
    ///
    /// - Parameter id: The workflow ID to load
    func loadWorkflow(id: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        error = nil
        do {
            let response: APIResponse<Workflow> = try await client.get("/workflows/\(id)")
            if response.success, let data = response.data {
                selectedWorkflow = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load workflow"])
            }
        } catch {
            self.error = error
        }
    }

    /// Create a new workflow.
    ///
    /// - Parameters:
    ///   - name: Workflow name
    ///   - description: Optional workflow description
    ///   - nodes: Initial nodes (defaults to empty array)
    ///   - connections: Initial connections (defaults to empty array)
    func createWorkflow(
        name: String,
        description: String? = nil,
        nodes: [WorkflowNode] = [],
        connections: [WorkflowConnection] = []
    ) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let request = CreateWorkflowRequest(
                name: name,
                description: description,
                nodes: nodes,
                connections: connections
            )
            let response: APIResponse<Workflow> = try await client.post("/workflows", body: request)
            if response.success, let data = response.data {
                selectedWorkflow = data
                await loadWorkflows() // Refresh list
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to create workflow"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Update an existing workflow.
    ///
    /// - Parameters:
    ///   - id: The workflow ID to update
    ///   - name: New workflow name (optional)
    ///   - description: New workflow description (optional)
    ///   - status: New workflow status (optional)
    ///   - nodes: Updated nodes (optional)
    ///   - connections: Updated connections (optional)
    func updateWorkflow(
        id: String,
        name: String? = nil,
        description: String? = nil,
        status: WorkflowStatus? = nil,
        nodes: [WorkflowNode]? = nil,
        connections: [WorkflowConnection]? = nil
    ) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let request = UpdateWorkflowRequest(
                name: name,
                description: description,
                status: status,
                nodes: nodes,
                connections: connections
            )
            let response: APIResponse<Workflow> = try await client.put("/workflows/\(id)", body: request)
            if response.success, let data = response.data {
                selectedWorkflow = data
                // Update in local array if present
                if let index = workflows.firstIndex(where: { $0.id == id }) {
                    workflows[index] = data
                }
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to update workflow"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Delete a workflow by ID.
    ///
    /// - Parameter id: The workflow ID to delete
    func deleteWorkflow(id: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let response: APIResponse<DeletedResponse> = try await client.delete("/workflows/\(id)")
            if response.success {
                // Remove from local array
                workflows.removeAll { $0.id == id }
                // Clear selection if deleted workflow was selected
                if selectedWorkflow?.id == id {
                    selectedWorkflow = nil
                }
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to delete workflow"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    // MARK: - Workflow Execution

    /// Execute a workflow with optional parameters.
    ///
    /// - Parameters:
    ///   - id: The workflow ID to execute
    ///   - parameters: Optional execution parameters
    func executeWorkflow(id: String, parameters: [String: String]? = nil) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let request = ExecuteWorkflowRequest(parameters: parameters)
            let response: APIResponse<WorkflowExecution> = try await client.post("/workflows/\(id)/execute", body: request)
            if response.success, let data = response.data {
                currentExecution = data
                // Refresh workflow to update lastExecutedAt
                await loadWorkflow(id: id)
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to execute workflow"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Cancel a running workflow execution.
    ///
    /// - Parameters:
    ///   - workflowId: The workflow ID
    ///   - executionId: The execution ID to cancel
    func cancelExecution(workflowId: String, executionId: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let response: APIResponse<WorkflowExecution> = try await client.post("/workflows/\(workflowId)/executions/\(executionId)/cancel", body: EmptyBody())
            if response.success, let data = response.data {
                currentExecution = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to cancel execution"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Load execution history for a workflow.
    ///
    /// - Parameter workflowId: The workflow ID to load executions for
    func loadExecutions(workflowId: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        error = nil
        do {
            let response: APIResponse<[WorkflowExecution]> = try await client.get("/workflows/\(workflowId)/executions")
            if response.success, let data = response.data {
                executions = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load executions"])
            }
        } catch {
            self.error = error
        }
    }

    /// Load the current execution status for a specific execution.
    ///
    /// - Parameters:
    ///   - workflowId: The workflow ID
    ///   - executionId: The execution ID to load
    func loadExecution(workflowId: String, executionId: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        error = nil
        do {
            let response: APIResponse<WorkflowExecution> = try await client.get("/workflows/\(workflowId)/executions/\(executionId)")
            if response.success, let data = response.data {
                currentExecution = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to load execution"])
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Workflow Scheduling

    /// Create a schedule for a workflow.
    ///
    /// - Parameters:
    ///   - workflowId: The workflow ID to schedule
    ///   - cron: Cron expression (e.g., "0 0 * * *" for daily at midnight)
    ///   - enabled: Whether the schedule should be enabled immediately (defaults to true)
    ///   - timezone: Optional timezone (defaults to UTC)
    func createSchedule(
        workflowId: String,
        cron: String,
        enabled: Bool = true,
        timezone: String? = nil
    ) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let request = CreateScheduleRequest(cron: cron, enabled: enabled, timezone: timezone)
            let response: APIResponse<WorkflowSchedule> = try await client.post("/workflows/\(workflowId)/schedule", body: request)
            if response.success, let data = response.data {
                currentSchedule = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to create schedule"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Update an existing workflow schedule.
    ///
    /// - Parameters:
    ///   - workflowId: The workflow ID
    ///   - cron: New cron expression (optional)
    ///   - enabled: New enabled state (optional)
    ///   - timezone: New timezone (optional)
    func updateSchedule(
        workflowId: String,
        cron: String? = nil,
        enabled: Bool? = nil,
        timezone: String? = nil
    ) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let request = UpdateScheduleRequest(cron: cron, enabled: enabled, timezone: timezone)
            let response: APIResponse<WorkflowSchedule> = try await client.put("/workflows/\(workflowId)/schedule", body: request)
            if response.success, let data = response.data {
                currentSchedule = data
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to update schedule"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Delete a workflow schedule.
    ///
    /// - Parameter workflowId: The workflow ID
    func deleteSchedule(workflowId: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        isLoading = true
        error = nil
        do {
            let response: APIResponse<DeletedResponse> = try await client.delete("/workflows/\(workflowId)/schedule")
            if response.success {
                currentSchedule = nil
            } else {
                error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: response.error?.message ?? "Failed to delete schedule"])
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Load the current schedule for a workflow.
    ///
    /// - Parameter workflowId: The workflow ID
    func loadSchedule(workflowId: String) async {
        guard let client = client else {
            error = NSError(domain: "WorkflowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "API client not configured"])
            return
        }

        error = nil
        do {
            let response: APIResponse<WorkflowSchedule> = try await client.get("/workflows/\(workflowId)/schedule")
            if response.success, let data = response.data {
                currentSchedule = data
            } else {
                // Schedule not found is not an error, just means no schedule exists
                currentSchedule = nil
            }
        } catch {
            // Schedule not found is not an error
            currentSchedule = nil
        }
    }
}
