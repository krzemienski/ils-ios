import SwiftUI
import ILSShared
import UniformTypeIdentifiers

// MARK: - SessionKanbanBoardView

/// Main kanban board view assembling filter bar and column layout.
///
/// Displays ``KanbanFilterBarView`` at the top followed by an adaptive board
/// area that adjusts based on the device's horizontal size class:
///
/// | Size Class | Layout                                                    |
/// |------------|-----------------------------------------------------------|
/// | Regular    | Horizontal `ScrollView` with fixed-width `KanbanColumnView` columns |
/// | Compact    | Vertical `ScrollView` with collapsible `DisclosureGroup` sections  |
///
/// ## Columns
/// Ordered: Active → Waiting for Approval → Queued → Paused → Completed → Failed.
///
/// ## Features
/// - Pull-to-refresh via `.refreshable`
/// - Loading skeleton while data loads
/// - Drag-and-drop between columns (iPad) via `NSItemProvider`
/// - Adaptive polling: starts on appear, stops on disappear
///
/// ## Callbacks
/// - ``onSessionSelected`` — forwarded when the user taps a session card
struct SessionKanbanBoardView: View {

    // MARK: - Properties

    /// View model owning all kanban board state.
    @Bindable var viewModel: SessionKanbanViewModel

    /// Called when the user taps a session card for navigation.
    var onSessionSelected: ((KanbanBoardItem) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Column display order as specified by the subtask.
    private static let columnOrder: [KanbanColumn] = [
        .active, .waitingForApproval, .queued, .paused, .completed, .failed
    ]

    /// Tracks which columns are expanded in compact layout.
    @State private var expandedColumns: Set<KanbanColumn> = [.active, .waitingForApproval, .queued]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            KanbanFilterBarView(viewModel: viewModel)

            Divider().overlay(theme.divider)

            if viewModel.isLoading && viewModel.allItems.isEmpty {
                loadingSkeleton
            } else if viewModel.allItems.isEmpty {
                emptyState
            } else {
                boardContent
            }
        }
        .background(theme.bgPrimary)
        .refreshable {
            HapticManager.impact(.medium)
            await viewModel.loadBoard()
        }
        .task {
            await viewModel.loadBoard()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Board Content

    @ViewBuilder
    private var boardContent: some View {
        if horizontalSizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Regular Layout (iPad / Landscape)

    /// Horizontal scrolling board with fixed-width columns side by side.
    private var regularLayout: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: theme.spacingSM) {
                ForEach(Self.columnOrder) { column in
                    KanbanColumnView(
                        column: column,
                        items: viewModel.items(for: column),
                        onCardTapped: { item in onSessionSelected?(item) },
                        onOpenChat: { item in onSessionSelected?(item) },
                        onApprovePermission: { item in onSessionSelected?(item) },
                        onViewDetails: { item in onSessionSelected?(item) },
                        onItemDropped: { itemId in
                            handleDrop(itemId: itemId, toColumn: column)
                        }
                    )
                }
            }
            .padding(theme.spacingMD)
        }
    }

    // MARK: - Compact Layout (iPhone Portrait)

    /// Vertical scrolling board with collapsible column sections.
    private var compactLayout: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: theme.spacingSM) {
                ForEach(Self.columnOrder) { column in
                    let items = viewModel.items(for: column)
                    compactColumnSection(column: column, items: items)
                }
            }
            .padding(theme.spacingMD)
        }
    }

    /// A collapsible section for a single column in compact layout.
    @ViewBuilder
    private func compactColumnSection(column: KanbanColumn, items: [KanbanBoardItem]) -> some View {
        let isExpanded = Binding<Bool>(
            get: { expandedColumns.contains(column) },
            set: { newValue in
                if newValue {
                    expandedColumns.insert(column)
                } else {
                    expandedColumns.remove(column)
                }
            }
        )

        DisclosureGroup(isExpanded: isExpanded) {
            if items.isEmpty {
                Text("No items")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            } else {
                LazyVStack(spacing: theme.spacingSM) {
                    ForEach(items) { item in
                        KanbanSessionCardView(
                            item: item,
                            column: column,
                            onTap: { onSessionSelected?(item) },
                            onOpenChat: { onSessionSelected?(item) },
                            onApprove: { onSessionSelected?(item) },
                            onViewDetails: { onSessionSelected?(item) }
                        )
                        #if os(iOS)
                        .onDrag {
                            NSItemProvider(object: item.id as NSString)
                        }
                        #endif
                    }
                }
            }
        } label: {
            compactColumnHeader(column: column, count: items.count)
        }
        .tint(column.color)
        #if os(iOS)
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { nsItem, _ in
                guard let idString = nsItem as? String else { return }
                DispatchQueue.main.async {
                    handleDrop(itemId: idString, toColumn: column)
                }
            }
            return true
        }
        #endif
    }

    /// Header label for a compact column section showing icon, title, and count badge.
    private func compactColumnHeader(column: KanbanColumn, count: Int) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: column.iconName)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(column.color)

            Text(column.displayTitle)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            Text("\(count)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(.white)
                .frame(minWidth: 22, minHeight: 22)
                .background(column.color)
                .clipShape(Circle())
        }
    }

    // MARK: - Drop Handling

    /// Resolves a dropped item ID and moves it to the target column.
    private func handleDrop(itemId: String, toColumn column: KanbanColumn) {
        guard let item = viewModel.filteredItems.first(where: { $0.id == itemId }) else { return }
        Task {
            await viewModel.moveItem(item: item, toColumn: column)
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            if horizontalSizeClass == .regular {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: theme.spacingSM) {
                        ForEach(0..<4, id: \.self) { _ in
                            skeletonColumn
                        }
                    }
                    .padding(theme.spacingMD)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: theme.spacingSM) {
                        ForEach(0..<3, id: \.self) { _ in
                            skeletonRow
                        }
                    }
                    .padding(theme.spacingMD)
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    /// A single skeleton column placeholder for regular layout.
    private var skeletonColumn: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header placeholder
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.bgTertiary)
                    .frame(width: 120, height: 20)
                Spacer()
                Circle()
                    .fill(theme.bgTertiary)
                    .frame(width: 22, height: 22)
            }

            Divider()

            // Card placeholders
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .fill(theme.bgSecondary)
                    .frame(height: 80)
            }
        }
        .padding(theme.spacingSM)
        .frame(width: 280)
        .background(theme.bgSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    /// A single skeleton row placeholder for compact layout.
    private var skeletonRow: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.bgTertiary)
                    .frame(width: 140, height: 20)
                Spacer()
                Circle()
                    .fill(theme.bgTertiary)
                    .frame(width: 22, height: 22)
            }

            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.bgSecondary)
                .frame(height: 60)
        }
        .padding(theme.spacingSM)
        .background(theme.bgSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()

            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text(viewModel.emptyStateText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingLG)
    }
}

// MARK: - Preview

#Preview("Kanban Board — Regular") {
    NavigationStack {
        SessionKanbanBoardView(
            viewModel: SessionKanbanViewModel(
                apiClient: APIClient(baseURL: "http://localhost:9999")
            )
        )
        .navigationTitle("Kanban Board")
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
