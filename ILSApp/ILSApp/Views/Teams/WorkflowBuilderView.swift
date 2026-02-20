import SwiftUI
import ILSShared

struct WorkflowBuilderView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    @State private var viewModel: TeamsViewModel
    let teamName: String
    @State private var workflowNodes: [WorkflowNode] = []
    @State private var selectedNodeId: UUID?
    @State private var showAddNodeSheet = false

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
                workflowNodes.removeAll()
                selectedNodeId = nil
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
                // Save workflow action
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
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
            .disabled(workflowNodes.isEmpty)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
    }

    private var canvasSection: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                // Canvas background
                Rectangle()
                    .fill(theme.bgSecondary.opacity(0.3))
                    .frame(minWidth: 800, minHeight: 600)
                    .overlay(
                        // Grid pattern
                        GeometryReader { geometry in
                            Path { path in
                                let gridSize: CGFloat = 20
                                let width = geometry.size.width
                                let height = geometry.size.height

                                // Vertical lines
                                for x in stride(from: 0, through: width, by: gridSize) {
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: height))
                                }

                                // Horizontal lines
                                for y in stride(from: 0, through: height, by: gridSize) {
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: width, y: y))
                                }
                            }
                            .stroke(theme.textTertiary.opacity(0.1), lineWidth: 0.5)
                        }
                    )

                // Workflow nodes
                ForEach(workflowNodes) { node in
                    WorkflowNodeView(
                        node: node,
                        isSelected: selectedNodeId == node.id,
                        theme: theme
                    )
                    .position(x: node.position.x, y: node.position.y)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateNodePosition(node.id, to: value.location)
                            }
                    )
                    .onTapGesture {
                        selectedNodeId = node.id
                    }
                }

                // Empty state
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
}

// MARK: - Supporting Types
// WorkflowNode and WorkflowNodeType are now defined in Models/WorkflowNode.swift

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
    let theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: node.type.iconName)
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)

            Text(node.title)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 100)
        .background(theme.bgPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(isSelected ? theme.accent : theme.textTertiary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .shadow(color: theme.textPrimary.opacity(0.1), radius: 4, x: 0, y: 2)
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
