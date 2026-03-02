import SwiftUI
import ILSShared

// MARK: - Queue Filter

/// Segmented filter options for the agent task queue list.
private enum QueueFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case queued = "Queued"
    case running = "Running"
    case completed = "Completed"

    var id: String { rawValue }
}

// MARK: - AgentQueueView

/// Main Agent Queue screen displaying all background tasks with filtering,
/// drag-to-reorder, and global queue controls.
///
/// ## Overview
/// - A segmented filter picker (All / Queued / Running / Completed) scopes the visible rows.
/// - Drag-to-reorder is available in the "All" filter via Edit mode; moves call
///   ``AgentQueueViewModel/reorderItems(orderedIds:)`` to persist the new order.
/// - A floating action button opens ``AddQueueTaskView`` as a sheet.
/// - Toolbar buttons pause all running items or resume all paused items.
/// - Pull-to-refresh reloads the queue from the backend.
struct AgentQueueView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Shared view model owning all queue state.
    let viewModel: AgentQueueViewModel

    @State private var filter: QueueFilter = .all
    @State private var showAddTask = false
    @State private var isEditMode = false

    // MARK: - Filtered Items

    private var filteredItems: [AgentQueueItem] {
        switch filter {
        case .all:
            return viewModel.items
        case .queued:
            return viewModel.items.filter { $0.status == .queued }
        case .running:
            return viewModel.items.filter { $0.status == .running }
        case .completed:
            return viewModel.items.filter {
                $0.status == .completed || $0.status == .failed || $0.status == .cancelled
            }
        }
    }

    /// Drag-to-reorder is only enabled when viewing all items to avoid index mapping ambiguity.
    private var canReorder: Bool { filter == .all }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView
            fab
        }
        .background(theme.bgPrimary)
        .navigationTitle("Agent Queue")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                queueControlButtons
            }
        }
        .sheet(isPresented: $showAddTask) {
            NavigationStack {
                AddQueueTaskView(viewModel: viewModel)
            }
            .environment(appState)
            .environment(\.theme, theme)
        }
        .task {
            await viewModel.loadQueue()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            filterPicker
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)

            Divider().overlay(theme.divider)

            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingState
            } else if filteredItems.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        HStack(spacing: 0) {
            ForEach(QueueFilter.allCases) { f in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = f
                        isEditMode = false
                    }
                } label: {
                    Text(f.rawValue)
                        .font(.system(
                            size: theme.fontBody,
                            weight: filter == f ? .semibold : .regular,
                            design: theme.fontDesign
                        ))
                        .foregroundStyle(filter == f ? theme.textPrimary : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(filter == f ? theme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
        }
        .padding(4)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(filteredItems) { item in
                QueueTaskRow(item: item, viewModel: viewModel)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: theme.spacingXS,
                        leading: theme.spacingMD,
                        bottom: theme.spacingXS,
                        trailing: theme.spacingMD
                    ))
            }
            .onMove(perform: canReorder ? moveItems : nil)

            // Extra padding at the bottom so the FAB doesn't overlap the last row
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(theme.bgPrimary)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .refreshable {
            await viewModel.loadQueue()
        }
    }

    // MARK: - Drag Reorder

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = filteredItems
        reordered.move(fromOffsets: source, toOffset: destination)
        let orderedIds = reordered.map(\.id)
        Task { await viewModel.reorderItems(orderedIds: orderedIds) }
    }

    // MARK: - Queue Control Toolbar

    @ViewBuilder
    private var queueControlButtons: some View {
        if canReorder {
            Button(isEditMode ? "Done" : "Edit") {
                withAnimation { isEditMode.toggle() }
            }
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
        }

        if viewModel.items.contains(where: { $0.status == .running }) {
            Button {
                pauseAllRunning()
            } label: {
                Image(systemName: "pause.circle")
                    .font(.system(size: theme.fontBody, weight: .medium))
            }
            .accessibilityLabel("Pause all running tasks")
        }

        if viewModel.items.contains(where: { $0.status == .paused }) {
            Button {
                resumeAllPaused()
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: theme.fontBody, weight: .medium))
            }
            .accessibilityLabel("Resume all paused tasks")
        }
    }

    // MARK: - Pause / Resume All

    private func pauseAllRunning() {
        let ids = viewModel.items.filter { $0.status == .running }.map(\.id)
        Task {
            for id in ids {
                await viewModel.pauseItem(id: id)
            }
        }
    }

    private func resumeAllPaused() {
        let ids = viewModel.items.filter { $0.status == .paused }.map(\.id)
        Task {
            for id in ids {
                await viewModel.resumeItem(id: id)
            }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            showAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(theme.accent)
                .clipShape(Circle())
                .shadow(color: theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, theme.spacingMD)
        .padding(.bottom, theme.spacingLG)
        .accessibilityLabel("Add new task")
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            ProgressView()
                .tint(theme.accent)
            Text("Loading queue…")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                Text(emptyStateTitle)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(emptyStateMessage)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)
            }

            if filter == .all {
                Button {
                    #if os(iOS)
                    HapticManager.impact(.light)
                    #endif
                    showAddTask = true
                } label: {
                    Text("Add First Task")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacingLG)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .padding(.top, theme.spacingSM)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .refreshable {
            await viewModel.loadQueue()
        }
    }

    private var emptyStateIcon: String {
        switch filter {
        case .all:       return "tray"
        case .queued:    return "clock"
        case .running:   return "play.slash"
        case .completed: return "checkmark.circle"
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .all:       return "No tasks in queue"
        case .queued:    return "No queued tasks"
        case .running:   return "Nothing running"
        case .completed: return "No finished tasks"
        }
    }

    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "Tap + to queue a new task for Claude Code."
        case .queued:
            return "All tasks have been picked up or the queue is empty."
        case .running:
            return "No agents are currently executing a task."
        case .completed:
            return "Completed, failed, and cancelled tasks will appear here."
        }
    }
}
