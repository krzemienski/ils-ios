import SwiftUI
import ILSShared

struct WorkflowBuilderView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    @State private var viewModel: TeamsViewModel
    let teamName: String
    @State private var workflowNodes: [WorkflowNode] = []
    @State private var connections: [WorkflowConnection] = []
    @State private var selectedNodeId: UUID?
    @State private var connectingFromNodeId: UUID?
    @State private var showAddNodeSheet = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var isConnectMode = false

    init(teamName: String, apiClient: APIClient) {
        self.teamName = teamName
        _viewModel = State(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            toolbarSection

            canvasSection
        }
        .background(theme.bgPrimary)
        .navigationTitle("Workflow Builder")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .sheet(isPresented: $showAddNodeSheet) {
            AddWorkflowNodeSheet(onAdd: addNode)
        }
        .task {
            await viewModel.loadTeamDetail(name: teamName)
            await viewModel.loadTasks(teamName: teamName)
            loadTasksAsNodes()
        }
        .overlay(alignment: .bottom) {
            if let message = saveMessage {
                Text(message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.success.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                    .padding(.bottom, theme.spacingLG)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: saveMessage != nil)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Design your team workflow")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingMD) {
                Label("\(workflowNodes.count) nodes", systemImage: "circle.hexagonpath")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Label("\(connections.count) deps", systemImage: "arrow.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                if isConnectMode {
                    Label("Connect mode", systemImage: "link")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                }

                if let selected = workflowNodes.first(where: { $0.id == selectedNodeId }) {
                    Label(selected.title, systemImage: "checkmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingSM)
    }

    private var toolbarSection: some View {
        HStack(spacing: theme.spacingSM) {
            Button {
                showAddNodeSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Step")
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)

            Button {
                isConnectMode.toggle()
                if !isConnectMode {
                    connectingFromNodeId = nil
                }
            } label: {
                HStack {
                    Image(systemName: isConnectMode ? "link.circle.fill" : "link")
                    Text("Link")
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(isConnectMode ? theme.warning : theme.info)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background((isConnectMode ? theme.warning : theme.info).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(workflowNodes.count < 2)

            Button {
                workflowNodes.removeAll()
                connections.removeAll()
                selectedNodeId = nil
                connectingFromNodeId = nil
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.error)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.error.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(workflowNodes.isEmpty)

            Spacer()

            Button {
                Task {
                    await saveWorkflow()
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Save")
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.success)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.success.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(workflowNodes.isEmpty || isSaving)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
    }

    private var canvasSection: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(theme.bgSecondary.opacity(0.3))
                    .frame(minWidth: 800, minHeight: 600)
                    .overlay(
                        GeometryReader { geometry in
                            Path { path in
                                let gridSize: CGFloat = 20
                                let width = geometry.size.width
                                let height = geometry.size.height

                                for x in stride(from: 0, through: width, by: gridSize) {
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: height))
                                }

                                for y in stride(from: 0, through: height, by: gridSize) {
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: width, y: y))
                                }
                            }
                            .stroke(theme.textTertiary.opacity(0.1), lineWidth: 0.5)
                        }
                    )

                connectionLines

                ForEach(workflowNodes) { node in
                    WorkflowNodeView(
                        node: node,
                        isSelected: selectedNodeId == node.id,
                        isConnectSource: connectingFromNodeId == node.id,
                        dependencyCount: incomingConnectionCount(for: node.id),
                        theme: theme
                    )
                    .position(x: node.position.x, y: node.position.y)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isConnectMode {
                                    updateNodePosition(node.id, to: value.location)
                                }
                            }
                    )
                    .onTapGesture {
                        handleNodeTap(node)
                    }
                }

                if workflowNodes.isEmpty {
                    VStack(spacing: theme.spacingMD) {
                        Image(systemName: "flowchart")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.textTertiary)

                        Text("No workflow steps yet")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        Text("Click 'Add Step' to start building")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 800, minHeight: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Draws arrow lines for each connection between nodes.
    private var connectionLines: some View {
        ForEach(connections) { connection in
            if let sourceNode = workflowNodes.first(where: { $0.id == connection.sourceNodeId }),
               let targetNode = workflowNodes.first(where: { $0.id == connection.targetNodeId }) {
                ConnectionLineView(
                    from: CGPoint(x: sourceNode.position.x, y: sourceNode.position.y + 55),
                    to: CGPoint(x: targetNode.position.x, y: targetNode.position.y - 55),
                    color: theme.accent
                )
            }
        }
    }

    // MARK: - Actions

    private func handleNodeTap(_ node: WorkflowNode) {
        if isConnectMode {
            if let fromId = connectingFromNodeId {
                if fromId != node.id {
                    let alreadyExists = connections.contains {
                        $0.sourceNodeId == fromId && $0.targetNodeId == node.id
                    }
                    if !alreadyExists {
                        let newConnection = WorkflowConnection(
                            sourceNodeId: fromId,
                            targetNodeId: node.id
                        )
                        connections.append(newConnection)
                    }
                }
                connectingFromNodeId = nil
            } else {
                connectingFromNodeId = node.id
            }
        } else {
            if selectedNodeId == node.id {
                removeConnectionsForSelectedNode(node.id)
            } else {
                selectedNodeId = node.id
            }
        }
    }

    private func removeConnectionsForSelectedNode(_ nodeId: UUID) {
        connections.removeAll { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId }
        selectedNodeId = nil
    }

    private func incomingConnectionCount(for nodeId: UUID) -> Int {
        connections.filter { $0.targetNodeId == nodeId }.count
    }

    private func loadTasksAsNodes() {
        let tasks = viewModel.tasks
        guard !tasks.isEmpty else { return }

        workflowNodes = tasks.enumerated().map { index, task in
            let col = index % 3
            let row = index / 3
            let x = Double(160 + col * 220)
            let y = Double(120 + row * 160)

            var nodeStatus: WorkflowNodeStatus = .idle
            switch task.status {
            case .pending: nodeStatus = .pending
            case .inProgress: nodeStatus = .running
            case .completed: nodeStatus = .completed
            case .deleted: nodeStatus = .skipped
            }

            return WorkflowNode(
                taskId: task.id,
                title: task.subject,
                type: .action,
                position: NodePosition(x: x, y: y),
                status: nodeStatus
            )
        }

        loadExistingConnections()
    }

    /// Rebuild connections from the existing blockedBy relationships on tasks.
    private func loadExistingConnections() {
        connections.removeAll()
        let tasks = viewModel.tasks
        for task in tasks {
            guard let blockedBy = task.blockedBy, !blockedBy.isEmpty else { continue }
            let targetNode = workflowNodes.first { $0.taskId == task.id }
            guard let targetId = targetNode?.id else { continue }

            for blockingTaskId in blockedBy {
                let sourceNode = workflowNodes.first { $0.taskId == blockingTaskId }
                guard let sourceId = sourceNode?.id else { continue }
                let connection = WorkflowConnection(
                    sourceNodeId: sourceId,
                    targetNodeId: targetId
                )
                connections.append(connection)
            }
        }
    }

    private func addNode(type: WorkflowNodeType, name: String) {
        let newNode = WorkflowNode(
            title: name,
            type: type,
            position: NodePosition(x: 200, y: 200 + Double(workflowNodes.count * 100))
        )
        workflowNodes.append(newNode)
    }

    private func updateNodePosition(_ id: UUID, to position: CGPoint) {
        if let index = workflowNodes.firstIndex(where: { $0.id == id }) {
            workflowNodes[index].position = NodePosition(x: Double(position.x), y: Double(position.y))
        }
    }

    private func saveWorkflow() async {
        isSaving = true
        defer { isSaving = false }

        let sortedNodes = workflowNodes.sorted { $0.position.y < $1.position.y }

        for (index, node) in sortedNodes.enumerated() {
            guard let taskId = node.taskId else { continue }

            let incomingConnections = connections.filter { $0.targetNodeId == node.id }
            let blockedByIds: [String] = incomingConnections.compactMap { conn in
                workflowNodes.first(where: { $0.id == conn.sourceNodeId })?.taskId
            }

            await viewModel.updateTask(
                teamName: teamName,
                id: taskId,
                executionOrder: index + 1,
                visualPosition: index,
                blockedBy: blockedByIds
            )
        }

        showSaveMessage("Workflow saved with \(connections.count) dependencies")
    }

    private func showSaveMessage(_ message: String) {
        saveMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2500))
            saveMessage = nil
        }
    }
}

// MARK: - Connection Line View

struct ConnectionLineView: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: from)

            let midY = (from.y + to.y) / 2
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x, y: midY),
                control2: CGPoint(x: to.x, y: midY)
            )
        }
        .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        arrowHead
    }

    private var arrowHead: some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        return Path { path in
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowAngle),
                y: to.y - arrowLength * sin(angle - arrowAngle)
            ))
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowAngle),
                y: to.y - arrowLength * sin(angle + arrowAngle)
            ))
        }
        .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

// MARK: - Supporting Types

extension WorkflowNodeType {
    var iconName: String {
        switch self {
        case .agent: return "person.circle"
        case .action: return "checkmark.circle"
        case .condition: return "arrow.triangle.branch"
        case .parallel: return "arrow.triangle.merge"
        case .trigger: return "bolt.circle"
        case .transform: return "arrow.triangle.2.circlepath"
        case .loop: return "arrow.circlepath"
        }
    }

    var displayName: String {
        switch self {
        case .agent: return "Agent"
        case .action: return "Action"
        case .condition: return "Condition"
        case .parallel: return "Parallel"
        case .trigger: return "Trigger"
        case .transform: return "Transform"
        case .loop: return "Loop"
        }
    }
}

// MARK: - Workflow Node View

struct WorkflowNodeView: View {
    let node: WorkflowNode
    let isSelected: Bool
    var isConnectSource: Bool = false
    var dependencyCount: Int = 0
    let theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: node.type.iconName)
                .font(.system(size: 24))
                .foregroundStyle(statusColor)

            Text(node.title)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                if let taskId = node.taskId {
                    Text("#\(taskId)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                if dependencyCount > 0 {
                    Text("\(dependencyCount) dep\(dependencyCount == 1 ? "" : "s")")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.info)
                }
            }
        }
        .frame(width: 120, height: 110)
        .background(isConnectSource ? theme.warning.opacity(0.1) : theme.bgPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(borderColor, lineWidth: (isSelected || isConnectSource) ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .shadow(color: theme.textPrimary.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var borderColor: Color {
        if isConnectSource { return theme.warning }
        if isSelected { return theme.accent }
        return theme.textTertiary.opacity(0.3)
    }

    private var statusColor: Color {
        switch node.status {
        case .idle: return theme.accent
        case .pending: return theme.warning
        case .running: return theme.info
        case .completed: return theme.success
        case .failed: return theme.error
        case .skipped: return theme.textTertiary
        }
    }
}

// MARK: - Add Node Sheet

struct AddWorkflowNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var selectedType: WorkflowNodeType = .agent
    @State private var nodeName = ""

    let onAdd: (WorkflowNodeType, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach([WorkflowNodeType.agent, .action, .condition, .parallel], id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }

                    TextField("Name", text: $nodeName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }

                Section {
                    Button("Add to Workflow") {
                        onAdd(selectedType, nodeName.isEmpty ? selectedType.displayName : nodeName)
                        dismiss()
                    }
                    .disabled(nodeName.isEmpty)
                }
            }
            .navigationTitle("Add Workflow Step")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
