import Foundation

/// Status of a workflow.
public enum WorkflowStatus: String, Codable, Sendable {
    /// Workflow is in draft state.
    case draft
    /// Workflow is active and can be executed.
    case active
    /// Workflow execution is paused.
    case paused
    /// Workflow has completed execution.
    case completed
    /// Workflow execution failed.
    case failed

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized WorkflowStatus: '\(raw)'. Expected: draft, active, paused, completed, failed"
                )
            )
        }
        self = value
    }
}

/// Type of workflow node.
public enum WorkflowNodeType: String, Codable, Sendable {
    /// Create a new session.
    case createSession
    /// Send a message to a session.
    case sendMessage
    /// Wait for a response from a session.
    case waitForResponse
    /// Conditional branch based on response.
    case conditionalBranch
    /// Export session data.
    case export
    /// Send notification.
    case notify
    /// Retry logic for error handling.
    case retry
    /// Fallback logic for error handling.
    case fallback

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized WorkflowNodeType: '\(raw)'. Expected: createSession, sendMessage, waitForResponse, conditionalBranch, export, notify, retry, fallback"
                )
            )
        }
        self = value
    }
}

/// A node in a workflow representing a single operation.
public struct WorkflowNode: Codable, Identifiable, Hashable, Sendable {
    /// Unique node identifier.
    public let id: String
    /// Type of node.
    public var type: WorkflowNodeType
    /// Display label for the node.
    public var label: String
    /// Visual position in workflow canvas (x, y).
    public var position: CGPoint?
    /// Node-specific configuration (JSON-encoded).
    public var configuration: [String: String]?

    public init(
        id: String = UUID().uuidString,
        type: WorkflowNodeType,
        label: String,
        position: CGPoint? = nil,
        configuration: [String: String]? = nil
    ) {
        precondition(!id.isEmpty, "WorkflowNode id must not be empty")
        precondition(!label.isEmpty, "WorkflowNode label must not be empty")
        self.id = id
        self.type = type
        self.label = label
        self.position = position
        self.configuration = configuration
    }

    public static func == (lhs: WorkflowNode, rhs: WorkflowNode) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A connection between two workflow nodes.
public struct WorkflowConnection: Codable, Identifiable, Hashable, Sendable {
    /// Unique connection identifier.
    public let id: String
    /// Source node ID.
    public var fromNodeId: String
    /// Target node ID.
    public var toNodeId: String
    /// Optional label for the connection (e.g., "success", "error").
    public var label: String?

    public init(
        id: String = UUID().uuidString,
        fromNodeId: String,
        toNodeId: String,
        label: String? = nil
    ) {
        precondition(!id.isEmpty, "WorkflowConnection id must not be empty")
        precondition(!fromNodeId.isEmpty, "fromNodeId must not be empty")
        precondition(!toNodeId.isEmpty, "toNodeId must not be empty")
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.label = label
    }

    public static func == (lhs: WorkflowConnection, rhs: WorkflowConnection) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a workflow automation pipeline.
public struct Workflow: Codable, Identifiable, Hashable, Sendable {
    /// Unique workflow identifier.
    public let id: String
    /// Workflow name.
    public var name: String
    /// Optional description.
    public var description: String?
    /// Current workflow status.
    public var status: WorkflowStatus
    /// Workflow nodes.
    public var nodes: [WorkflowNode]
    /// Connections between nodes.
    public var connections: [WorkflowConnection]
    /// When the workflow was created.
    public var createdAt: Date?
    /// When the workflow was last updated.
    public var updatedAt: Date?
    /// When the workflow was last executed.
    public var lastExecutedAt: Date?

    /// Creates a new workflow.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Workflow name. Must not be empty.
    ///   - description: Optional description.
    ///   - status: Current status.
    ///   - nodes: Workflow nodes.
    ///   - connections: Connections between nodes.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last update timestamp.
    ///   - lastExecutedAt: Last execution timestamp.
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        status: WorkflowStatus = .draft,
        nodes: [WorkflowNode] = [],
        connections: [WorkflowConnection] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        lastExecutedAt: Date? = nil
    ) {
        precondition(!id.isEmpty, "Workflow id must not be empty")
        precondition(!name.isEmpty, "Workflow name must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.nodes = nodes
        self.connections = connections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastExecutedAt = lastExecutedAt
    }

    public static func == (lhs: Workflow, rhs: Workflow) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
