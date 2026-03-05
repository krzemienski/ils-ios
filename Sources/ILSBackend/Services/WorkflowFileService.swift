import Foundation
import ILSShared

/// Actor responsible for reading/writing workflow files from the filesystem.
/// Follows the Claude Code file structure: ~/.claude/workflows/{id}.json
actor WorkflowFileService {
    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init() {
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = .prettyPrinted
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory Helpers

    private func workflowsBaseDir() -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/workflows"
    }

    private func workflowPath(id: String) -> String {
        "\(workflowsBaseDir())/\(id).json"
    }

    // MARK: - Validation

    private func validateId(_ id: String) throws {
        guard !id.isEmpty else {
            throw WorkflowFileServiceError.invalidId("Workflow id cannot be empty")
        }

        guard !id.contains("/") && !id.contains("..") else {
            throw WorkflowFileServiceError.invalidId("Workflow id cannot contain '/' or '..'")
        }
    }

    // MARK: - Workflow Operations

    func listWorkflows() throws -> [Workflow] {
        let workflowsDir = workflowsBaseDir()

        guard fileManager.fileExists(atPath: workflowsDir) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: workflowsDir)
        var workflows: [Workflow] = []

        for file in contents where file.hasSuffix(".json") {
            let filePath = "\(workflowsDir)/\(file)"
            if let workflow = try? getWorkflowByPath(path: filePath) {
                workflows.append(workflow)
            }
        }

        // Sort by updatedAt or createdAt descending
        return workflows.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

    func getWorkflow(id: String) throws -> Workflow? {
        try validateId(id)

        let path = workflowPath(id: id)

        guard fileManager.fileExists(atPath: path) else {
            return nil
        }

        return try getWorkflowByPath(path: path)
    }

    private func getWorkflowByPath(path: String) throws -> Workflow {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try jsonDecoder.decode(Workflow.self, from: data)
    }

    func createWorkflow(
        name: String,
        description: String?,
        nodes: [WorkflowNode],
        connections: [WorkflowConnection]
    ) throws -> Workflow {
        let workflowsDir = workflowsBaseDir()

        // Ensure workflows directory exists
        if !fileManager.fileExists(atPath: workflowsDir) {
            try fileManager.createDirectory(
                atPath: workflowsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let workflow = Workflow(
            id: UUID().uuidString,
            name: name,
            description: description,
            status: .draft,
            nodes: nodes,
            connections: connections,
            createdAt: Date(),
            updatedAt: Date(),
            lastExecutedAt: nil
        )

        try saveWorkflow(workflow)

        return workflow
    }

    func updateWorkflow(
        id: String,
        name: String?,
        description: String?,
        status: WorkflowStatus?,
        nodes: [WorkflowNode]?,
        connections: [WorkflowConnection]?
    ) throws -> Workflow {
        try validateId(id)

        guard var workflow = try getWorkflow(id: id) else {
            throw WorkflowFileServiceError.workflowNotFound(id)
        }

        // Update fields
        if let name = name {
            workflow.name = name
        }
        if let description = description {
            workflow.description = description
        }
        if let status = status {
            workflow.status = status
        }
        if let nodes = nodes {
            workflow.nodes = nodes
        }
        if let connections = connections {
            workflow.connections = connections
        }

        workflow.updatedAt = Date()

        try saveWorkflow(workflow)

        return workflow
    }

    func deleteWorkflow(id: String) throws {
        try validateId(id)

        let path = workflowPath(id: id)

        guard fileManager.fileExists(atPath: path) else {
            throw WorkflowFileServiceError.workflowNotFound(id)
        }

        try fileManager.removeItem(atPath: path)
    }

    func markExecuted(id: String) throws {
        try validateId(id)

        guard var workflow = try getWorkflow(id: id) else {
            throw WorkflowFileServiceError.workflowNotFound(id)
        }

        workflow.lastExecutedAt = Date()
        workflow.updatedAt = Date()

        try saveWorkflow(workflow)
    }

    // MARK: - Private Helpers

    private func saveWorkflow(_ workflow: Workflow) throws {
        let data = try jsonEncoder.encode(workflow)
        let path = workflowPath(id: workflow.id)
        try atomicWrite(data: data, to: path)
    }

    /// Write data atomically: write to temp file then rename to prevent partial writes on crash/concurrent access.
    private func atomicWrite(data: Data, to path: String) throws {
        let tempPath = path + ".tmp.\(UUID().uuidString)"
        let tempURL = URL(fileURLWithPath: tempPath)
        let targetURL = URL(fileURLWithPath: path)

        do {
            try data.write(to: tempURL, options: .atomic)
            // If target exists, remove before rename
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.moveItem(at: tempURL, to: targetURL)
        } catch {
            // Clean up temp file on failure
            try? fileManager.removeItem(at: tempURL)
            throw WorkflowFileServiceError.fileOperationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum WorkflowFileServiceError: Error, LocalizedError {
    case invalidId(String)
    case workflowNotFound(String)
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidId(let reason):
            return "Invalid workflow id: \(reason)"
        case .workflowNotFound(let id):
            return "Workflow '\(id)' not found"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}
