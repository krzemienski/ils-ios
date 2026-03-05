import Foundation

// MARK: - Canvas Workflow Node Models (Visual Builder)
// These are local canvas models for the visual workflow builder.
// API/shared models are in ILSShared (Workflow, WorkflowNode, WorkflowConnection, WorkflowNodeType).

/// A node in the visual workflow builder canvas.
struct CanvasWorkflowNode: Identifiable, Equatable {
    let id: UUID
    var taskId: String?
    var title: String
    var type: CanvasNodeType
    var position: NodePosition
    var inputs: [String]
    var outputs: [String]
    var configuration: [String: String]
    var status: WorkflowNodeStatus
    var metadata: NodeMetadata?

    init(
        id: UUID = UUID(),
        taskId: String? = nil,
        title: String,
        type: CanvasNodeType,
        position: NodePosition = NodePosition(x: 0, y: 0),
        inputs: [String] = [],
        outputs: [String] = [],
        configuration: [String: String] = [:],
        status: WorkflowNodeStatus = .idle,
        metadata: NodeMetadata? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.type = type
        self.position = position
        self.inputs = inputs
        self.outputs = outputs
        self.configuration = configuration
        self.status = status
        self.metadata = metadata
    }

    static func == (lhs: CanvasWorkflowNode, rhs: CanvasWorkflowNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.taskId == rhs.taskId &&
        lhs.title == rhs.title &&
        lhs.type == rhs.type &&
        lhs.position == rhs.position &&
        lhs.inputs == rhs.inputs &&
        lhs.outputs == rhs.outputs &&
        lhs.configuration == rhs.configuration &&
        lhs.status == rhs.status &&
        lhs.metadata == rhs.metadata
    }
}

/// Type of canvas workflow node.
enum CanvasNodeType: String, Equatable {
    case createSession
    case sendMessage
    case waitForResponse
    case export
    case notify
    case condition
    case parallel
    case loop
    case agent
    case action
    case trigger
    case transform
}

/// Status of a workflow node during execution.
enum WorkflowNodeStatus: String, Equatable {
    case idle
    case pending
    case running
    case completed
    case failed
    case skipped
}

/// Position of a node in the visual builder canvas.
struct NodePosition: Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    static func == (lhs: NodePosition, rhs: NodePosition) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }
}

/// Additional metadata for a workflow node.
struct NodeMetadata: Equatable {
    var createdAt: Date?
    var updatedAt: Date?
    var description: String?
    var tags: [String]

    init(
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        description: String? = nil,
        tags: [String] = []
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.description = description
        self.tags = tags
    }

    static func == (lhs: NodeMetadata, rhs: NodeMetadata) -> Bool {
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.description == rhs.description &&
        lhs.tags == rhs.tags
    }
}

// MARK: - Canvas Workflow Connection

/// A connection between two canvas workflow nodes.
struct CanvasWorkflowConnection: Identifiable, Equatable {
    let id: UUID
    let sourceNodeId: UUID
    let targetNodeId: UUID
    var label: String?
    var condition: String?

    init(
        id: UUID = UUID(),
        sourceNodeId: UUID,
        targetNodeId: UUID,
        label: String? = nil,
        condition: String? = nil
    ) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.label = label
        self.condition = condition
    }

    static func == (lhs: CanvasWorkflowConnection, rhs: CanvasWorkflowConnection) -> Bool {
        lhs.id == rhs.id &&
        lhs.sourceNodeId == rhs.sourceNodeId &&
        lhs.targetNodeId == rhs.targetNodeId &&
        lhs.label == rhs.label &&
        lhs.condition == rhs.condition
    }
}

// MARK: - Canvas Workflow

/// A complete canvas workflow with nodes and connections (for visual builder).
struct CanvasWorkflow: Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var nodes: [CanvasWorkflowNode]
    var connections: [CanvasWorkflowConnection]
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        nodes: [CanvasWorkflowNode] = [],
        connections: [CanvasWorkflowConnection] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = nodes
        self.connections = connections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: CanvasWorkflow, rhs: CanvasWorkflow) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.nodes == rhs.nodes &&
        lhs.connections == rhs.connections &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
}
