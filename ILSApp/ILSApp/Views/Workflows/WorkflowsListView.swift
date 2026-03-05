import SwiftUI
import ILSShared

/// List view displaying all saved workflows with navigation to workflow builder and execution.
///
/// Shows workflow cards in a scrollable list when workflows exist, or an empty-state prompt
/// when none have been created. A toolbar button opens a create workflow flow.
/// Coordinates with ``WorkflowViewModel`` to fetch and manage workflow data on appear.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model managing workflow data and API interactions
/// - ``showCreateSheet`` - Controls presentation of the create-workflow sheet
///
/// ### View Components
/// - ``emptyState`` - Placeholder shown when no workflows exist
/// - ``workflowCard(_:)`` - Card row for an individual workflow with status and metadata
struct WorkflowsListView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    /// View model managing workflow list loading and mutations.
    @State private var viewModel: WorkflowViewModel
    /// Whether the create-workflow sheet is currently presented.
    @State private var showCreateSheet = false

    init() {
        _viewModel = State(wrappedValue: WorkflowViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                if viewModel.workflows.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.workflows) { workflow in
                        workflowCard(workflow)
                    }
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Workflows")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateWorkflowView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadWorkflows()
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 64, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Workflows")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Create a workflow to automate repetitive Claude Code operations")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func workflowCard(_ workflow: Workflow) -> some View {
        NavigationLink(destination: WorkflowDetailView(workflowId: workflow.id)) {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text(workflow.name)
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    statusBadge(workflow.status)
                }

                if let description = workflow.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingMD) {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "circle.hexagongrid")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text("\(workflow.nodes.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)

                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text("\(workflow.connections.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)

                    if let lastExecutedAt = workflow.lastExecutedAt {
                        Spacer()
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "clock")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            Text(formattedDate(lastExecutedAt))
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ status: WorkflowStatus) -> some View {
        let (color, label) = statusInfo(status)
        return Text(label)
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func statusInfo(_ status: WorkflowStatus) -> (Color, String) {
        switch status {
        case .draft:
            return (Color.gray, "Draft")
        case .active:
            return (Color.green, "Active")
        case .paused:
            return (Color.orange, "Paused")
        case .completed:
            return (Color.blue, "Completed")
        case .failed:
            return (Color.red, "Failed")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Placeholder view for creating a new workflow.
///
/// This sheet allows users to enter a workflow name and description before
/// navigating to the visual workflow builder.
private struct CreateWorkflowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: WorkflowViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workflow Name", text: $name)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("New Workflow")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createWorkflow()
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createWorkflow() async {
        isCreating = true
        await viewModel.createWorkflow(
            name: name,
            description: description.isEmpty ? nil : description
        )
        isCreating = false

        if viewModel.error == nil {
            dismiss()
        }
    }
}

/// Placeholder detail view for a single workflow.
///
/// This view will eventually show the workflow builder canvas and execution controls.
/// For now, it serves as a navigation target from the workflows list.
private struct WorkflowDetailView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    let workflowId: String

    var body: some View {
        VStack {
            Text("Workflow Detail")
                .font(.system(size: theme.fontTitle2, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("ID: \(workflowId)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("Workflow")
        .inlineNavigationBarTitle()
    }
}
