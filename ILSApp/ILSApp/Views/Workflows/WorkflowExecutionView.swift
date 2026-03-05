import SwiftUI
import ILSShared

/// View for monitoring real-time workflow execution progress.
///
/// Displays a live progress visualization of the workflow execution, showing the status
/// of each node, overall progress percentage, and execution timeline. Supports cancellation
/// of active executions and viewing execution history.
/// Streams execution state updates via Server-Sent Events following the ChatView SSE pattern.
///
/// ## Topics
/// ### State
/// - ``workflow`` - The workflow being executed
/// - ``execution`` - Current or latest execution state
/// - ``viewModel`` - View model managing execution data and API calls
/// - ``sheets`` - Sheet presentation state
///
/// ### View Components
/// - ``mainContent`` - Top-level layout container
/// - ``executionHeader`` - Status banner and progress bar
/// - ``nodesList`` - Scrollable list of nodes with execution status
/// - ``bottomBar`` - Controls for cancellation and viewing history
///
/// ### Actions
/// - ``cancelExecution()`` - Cancel the currently running execution
/// - ``refreshExecution()`` - Manually refresh execution state
struct WorkflowExecutionView: View {
    /// The workflow being executed.
    let workflow: Workflow
    /// Optional initial execution to display.
    let execution: WorkflowExecution?
    /// Optional closure invoked when the user taps the back button.
    var onBack: (() -> Void)? = nil

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss

    /// View model managing execution state and streaming.
    @State private var viewModel: WorkflowViewModel
    /// Whether we're currently streaming execution updates.
    @State private var isStreamingProgress = false
    /// Current streaming task.
    @State private var streamTask: Task<Void, Never>?
    /// Timer for polling execution state.
    @State private var pollTimer: Timer?

    // MARK: - Grouped State

    /// Sheet and alert presentation state.
    struct SheetState {
        var showCancelConfirmation = false
        var showExecutionHistory = false
        var showErrorAlert = false
    }

    /// State controlling sheet and alert presentation.
    @State private var sheets = SheetState()

    init(workflow: Workflow, execution: WorkflowExecution? = nil, onBack: (() -> Void)? = nil) {
        self.workflow = workflow
        self.execution = execution
        self.onBack = onBack
        _viewModel = State(wrappedValue: WorkflowViewModel())
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle(workflow.name)
            .inlineNavigationBarTitle()
            .toolbar { toolbarContent }
            .task {
                await setupExecutionView()
            }
            .onDisappear {
                cleanupStreaming()
            }
            .alert("Cancel Execution", isPresented: $sheets.showCancelConfirmation) {
                Button("Cancel Execution", role: .destructive) {
                    Task {
                        await cancelExecution()
                    }
                }
                Button("Continue Running", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this workflow execution?")
            }
            .alert("Execution Error", isPresented: $sheets.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.currentExecution?.error {
                    Text(error)
                }
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            executionHeader

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    nodesList

                    if let exec = viewModel.currentExecution, exec.isFinished {
                        executionSummary(exec)
                    }
                }
                .padding(theme.spacingMD)
            }

            if let exec = viewModel.currentExecution, exec.isActive {
                bottomBar
            }
        }
    }

    // MARK: - Execution Header

    private var executionHeader: some View {
        VStack(spacing: theme.spacingSM) {
            HStack {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    if let exec = viewModel.currentExecution, let startedAt = exec.startedAt {
                        Text(executionTimeText(exec, startedAt: startedAt))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Spacer()

                if let exec = viewModel.currentExecution, let progress = exec.progress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }

            if let exec = viewModel.currentExecution, let progress = exec.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(theme.accent)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
    }

    private var statusIcon: some View {
        Group {
            if let exec = viewModel.currentExecution {
                switch exec.status {
                case .pending:
                    Image(systemName: "clock")
                        .foregroundStyle(Color.gray)
                case .running:
                    ProgressView()
                        .controlSize(.small)
                case .paused:
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(Color.orange)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.red)
                case .cancelled:
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(Color.gray)
                }
            } else {
                Image(systemName: "play.circle")
                    .foregroundStyle(Color.gray)
            }
        }
        .font(.system(size: 24, design: theme.fontDesign))
    }

    private var statusText: String {
        guard let exec = viewModel.currentExecution else {
            return "Ready to Execute"
        }
        switch exec.status {
        case .pending:
            return "Pending"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func executionTimeText(_ exec: WorkflowExecution, startedAt: Date) -> String {
        if let duration = exec.duration {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            return formatter.string(from: duration) ?? ""
        } else {
            return "Started \(formattedRelativeTime(startedAt))"
        }
    }

    // MARK: - Nodes List

    private var nodesList: some View {
        VStack(spacing: theme.spacingSM) {
            Text("Workflow Nodes")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(workflow.nodes, id: \.id) { node in
                nodeCard(node)
            }
        }
    }

    private func nodeCard(_ node: WorkflowNode) -> some View {
        let nodeStatus = getNodeStatus(for: node)
        let isCurrentNode = viewModel.currentExecution?.currentNodeId?.uuidString == node.id

        return HStack(spacing: theme.spacingMD) {
            nodeStatusIcon(nodeStatus, isCurrent: isCurrentNode)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.label)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(nodeTypeLabel(node.type))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if isCurrentNode {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentNode ? theme.accent : Color.clear, lineWidth: 2)
        )
    }

    private func nodeStatusIcon(_ status: WorkflowNodeStatus, isCurrent: Bool) -> some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle")
                    .foregroundStyle(Color.gray)
            case .pending:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(Color.orange)
            case .running:
                Image(systemName: "circle.fill")
                    .foregroundStyle(theme.accent)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.red)
            case .skipped:
                Image(systemName: "arrow.uturn.forward.circle")
                    .foregroundStyle(Color.gray)
            }
        }
        .font(.system(size: 20, design: theme.fontDesign))
    }

    private func nodeTypeLabel(_ type: WorkflowNodeType) -> String {
        switch type {
        case .createSession:
            return "Create Session"
        case .sendMessage:
            return "Send Message"
        case .waitForResponse:
            return "Wait for Response"
        case .conditionalBranch:
            return "Conditional Branch"
        case .export:
            return "Export"
        case .notify:
            return "Notify"
        case .retry:
            return "Retry"
        case .fallback:
            return "Fallback"
        }
    }

    private func getNodeStatus(for node: WorkflowNode) -> WorkflowNodeStatus {
        guard let exec = viewModel.currentExecution else {
            return .idle
        }

        // Check if node is completed
        if exec.completedNodeIds.contains(where: { $0.uuidString == node.id }) {
            return .completed
        }

        // Check if node is currently running
        if exec.currentNodeId?.uuidString == node.id {
            return .running
        }

        // If execution is active, pending nodes are those not yet executed
        if exec.isActive {
            return .pending
        }

        return .idle
    }

    // MARK: - Execution Summary

    private func executionSummary(_ exec: WorkflowExecution) -> some View {
        VStack(spacing: theme.spacingMD) {
            Text("Execution Summary")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: theme.spacingSM) {
                summaryRow(label: "Status", value: statusText)

                if let startedAt = exec.startedAt {
                    summaryRow(label: "Started", value: formattedAbsoluteTime(startedAt))
                }

                if let completedAt = exec.completedAt {
                    summaryRow(label: "Completed", value: formattedAbsoluteTime(completedAt))
                }

                if let duration = exec.duration {
                    summaryRow(label: "Duration", value: formattedDuration(duration))
                }

                summaryRow(label: "Nodes Completed", value: "\(exec.completedNodeIds.count) / \(workflow.nodes.count)")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: theme.spacingMD) {
            Button {
                sheets.showCancelConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Cancel")
                }
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                Task {
                    await refreshExecution()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if let onBack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(theme.accent)
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                sheets.showExecutionHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(theme.accent)
            }
        }
    }

    // MARK: - Actions

    private func setupExecutionView() async {
        // Set initial execution if provided
        if let execution {
            viewModel.currentExecution = execution
        }

        // Load the latest execution if none was provided
        if viewModel.currentExecution == nil {
            await viewModel.loadExecution(workflowId: workflow.id, executionId: "latest")
        }

        // Start streaming if execution is active
        if let exec = viewModel.currentExecution, exec.isActive {
            startStreamingProgress()
        }
    }

    private func startStreamingProgress() {
        isStreamingProgress = true

        // Use polling approach (simpler than SSE for now)
        // Poll every 500ms while execution is active
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                await refreshExecution()

                // Stop polling when execution finishes
                if let exec = viewModel.currentExecution, exec.isFinished {
                    cleanupStreaming()
                }
            }
        }
    }

    private func cleanupStreaming() {
        isStreamingProgress = false
        pollTimer?.invalidate()
        pollTimer = nil
        streamTask?.cancel()
        streamTask = nil
    }

    private func cancelExecution() async {
        guard let exec = viewModel.currentExecution else { return }

        await viewModel.cancelExecution(
            workflowId: workflow.id,
            executionId: exec.id.uuidString
        )

        cleanupStreaming()
    }

    private func refreshExecution() async {
        guard let exec = viewModel.currentExecution else { return }

        await viewModel.loadExecution(
            workflowId: workflow.id,
            executionId: exec.id.uuidString
        )
    }

    // MARK: - Helpers

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: duration) ?? ""
    }

    private func formattedRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedAbsoluteTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
