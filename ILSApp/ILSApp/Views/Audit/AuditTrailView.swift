import SwiftUI
import ILSShared

/// Displays the full AI action audit trail with timeline list, search, and type filtering.
///
/// Shows a horizontal filter-chip bar for ``AuditActionType`` selection, a searchable
/// scrollable list of ``AuditAction`` entries ordered newest-first, and a summary stat
/// bar showing total counts by category. Tapping a row opens ``AuditActionDetailSheet``
/// with full details and one-tap rollback. Supports pull-to-refresh and pagination via
/// an inline "Load More" button.
///
/// ## Topics
/// ### Navigation
/// - Accepts an optional `sessionId` to pre-filter actions to a single session.
struct AuditTrailView: View {
    /// When set, only audit actions from this session are shown.
    var sessionId: String? = nil

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState

    @State private var viewModel = AuditTrailViewModel()
    @State private var selectedAction: AuditAction? = nil

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.actions.isEmpty {
                loadingState
            } else if let errorMsg = viewModel.error?.localizedDescription, viewModel.actions.isEmpty {
                errorState(message: errorMsg)
            } else if viewModel.actions.isEmpty {
                emptyState
            } else {
                auditContent
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Audit Trail")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .refreshable {
            await viewModel.loadActions(sessionId: sessionId)
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            if let sessionId { viewModel.selectedSessionId = sessionId }
            await viewModel.loadActions(sessionId: sessionId)
        }
        .sheet(item: $selectedAction) { action in
            AuditActionDetailSheet(action: action) { actionToRollback in
                viewModel.requestRollback(action: actionToRollback)
            }
        }
        .alert("Rollback This Action?", isPresented: $viewModel.showRollbackConfirmation, presenting: viewModel.pendingRollbackAction) { action in
            Button("Rollback", role: .destructive) {
                Task { await viewModel.executeRollback() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelRollback()
            }
        } message: { action in
            Text(rollbackAlertMessage(for: action))
        }
        .alert("Rollback Failed", isPresented: Binding(
            get: { viewModel.rollbackError != nil },
            set: { if !$0 { viewModel.rollbackError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.rollbackError = nil }
        } message: {
            Text(viewModel.rollbackError?.localizedDescription ?? "An unknown error occurred.")
        }
    }

    // MARK: - Main Content

    private var auditContent: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                typeFilterBar
                statsBar
                actionsList
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search file, command, tool…")
        .refreshable {
            await viewModel.loadActions(sessionId: sessionId)
        }
    }

    // MARK: - Type Filter Bar

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                typeFilterChip(label: "All", type: nil)
                ForEach(AuditActionType.allCases, id: \.self) { actionType in
                    typeFilterChip(label: actionType.filterLabel, type: actionType)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func typeFilterChip(label: String, type: AuditActionType?) -> some View {
        let isSelected = viewModel.selectedActionType == type
        return Button {
            viewModel.selectedActionType = isSelected ? nil : type
            Task { await viewModel.loadActions(sessionId: sessionId) }
        } label: {
            HStack(spacing: 4) {
                if let type {
                    Image(systemName: type.filterIconName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                }
                Text(label)
                    .font(.system(size: theme.fontCaption, weight: isSelected ? .semibold : .regular, design: theme.fontDesign))
            }
            .foregroundStyle(isSelected ? .white : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? (type.map { $0.tintColor(theme: theme) } ?? theme.accent)
                    : theme.bgSecondary,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter\(isSelected ? ", selected" : "")")
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: theme.spacingSM) {
            statsChip(
                label: "Files",
                count: viewModel.actions.filter { [.fileWrite, .fileCreate, .fileDelete].contains($0.actionType) }.count,
                color: theme.accent
            )
            statsChip(
                label: "Commands",
                count: viewModel.actions.filter { $0.actionType == .bashCommand }.count,
                color: theme.warning
            )
            statsChip(
                label: "Rollbacks",
                count: viewModel.actions.filter { $0.actionType == .rollback }.count,
                color: theme.error
            )
            Spacer()
            Text("\(viewModel.totalCount) total")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func statsChip(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, 4)
        .background(color.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }

    // MARK: - Actions List

    private var actionsList: some View {
        VStack(spacing: theme.spacingXS) {
            if viewModel.filteredActions.isEmpty && !viewModel.searchText.isEmpty {
                noResultsState
            } else {
                ForEach(viewModel.filteredActions) { action in
                    Button {
                        selectedAction = action
                    } label: {
                        AuditActionRowView(action: action)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if action.id != viewModel.filteredActions.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }

                if viewModel.hasMore && viewModel.searchText.isEmpty {
                    loadMoreButton
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    private var loadMoreButton: some View {
        Button {
            Task { await viewModel.loadMoreActions() }
        } label: {
            if viewModel.isLoading {
                HStack(spacing: theme.spacingSM) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading…")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                Text("Load More")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
            }
        }
        .disabled(viewModel.isLoading)
        .padding(.top, theme.spacingSM)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty / Loading / Error States

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
            Text("Loading audit trail…")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(theme.textSecondary)

            Text("No Actions Recorded")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("AI actions will appear here as Claude modifies files, runs commands, and uses tools.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No results for \"\(viewModel.searchText)\"")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(theme.warning)

            Text("Failed to Load Audit Trail")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.loadActions(sessionId: sessionId) }
            }
            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func rollbackAlertMessage(for action: AuditAction) -> String {
        if let filePath = action.filePath, !filePath.isEmpty {
            let fileName = (filePath as NSString).lastPathComponent
            return "This will restore \"\(fileName)\" to its state before this action. The rollback will be recorded in the audit trail."
        }
        if let command = action.command, !command.isEmpty {
            let preview = String(command.prefix(60))
            return "This will attempt to reverse: \(preview). The rollback will be recorded in the audit trail."
        }
        return "This will attempt to reverse the action. The rollback will be recorded in the audit trail."
    }
}

// MARK: - AuditActionType Display Helpers

private extension AuditActionType {
    /// Short label used in filter chips.
    var filterLabel: String {
        switch self {
        case .fileWrite:          return "Write"
        case .fileCreate:         return "Create"
        case .fileDelete:         return "Delete"
        case .bashCommand:        return "Bash"
        case .toolUse:            return "Tool"
        case .permissionDecision: return "Permission"
        case .rollback:           return "Rollback"
        }
    }

    /// SF Symbol for the filter chip icon.
    var filterIconName: String {
        switch self {
        case .fileWrite:          return "pencil"
        case .fileCreate:         return "plus.square"
        case .fileDelete:         return "trash"
        case .bashCommand:        return "terminal"
        case .toolUse:            return "wrench.and.screwdriver"
        case .permissionDecision: return "lock.shield"
        case .rollback:           return "arrow.uturn.backward"
        }
    }

    /// Tint colour for filter chips.
    func tintColor(theme: ThemeSnapshot) -> Color {
        switch self {
        case .fileWrite:          return theme.accent
        case .fileCreate:         return theme.success
        case .fileDelete:         return theme.error
        case .bashCommand:        return theme.warning
        case .toolUse:            return theme.textSecondary
        case .permissionDecision: return theme.info
        case .rollback:           return theme.textSecondary
        }
    }
}
