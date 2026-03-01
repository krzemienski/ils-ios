import SwiftUI
import ILSShared
import UniformTypeIdentifiers

// MARK: - DashboardGridView

/// Renders a ``DashboardLayout``'s widget tiles in a grid layout.
///
/// Widgets are arranged into rows based on their ``WidgetPosition/row`` index.
/// Within each row an `HStack` distributes the tiles horizontally:
///
/// | Size   | Columns | Height                          |
/// |--------|---------|---------------------------------|
/// | small  | 1       | 1 × cellHeight                  |
/// | medium | 2       | 1 × cellHeight                  |
/// | large  | 2       | 2 × cellHeight + spacingMD gap  |
///
/// Each widget slot is wrapped in a ``WidgetContainerView`` which provides
/// shimmer loading, offline, and edit-mode overlay states. The inner content
/// is resolved through a `@ViewBuilder` switch on ``DashboardWidgetType``.
///
/// ## Callbacks
/// - ``onSessionSelected`` — forwarded to ``ActiveSessionsWidget`` and ``RecentSessionsWidget``
/// - ``onNavigate`` — forwarded to ``QuickActionsWidget``
/// - ``onNavigateToBrowser`` — forwarded to ``QuickActionsWidget``
///
/// ## Edit Mode
/// A "Edit" / "Done" toolbar button (placed at `.navigationBarTrailing`) toggles
/// `isEditMode`. When active, each tile shows a remove (×) button and a drag
/// handle (≡). Widgets can be reordered by dragging; on drop the
/// `onReorderWidget` callback receives `(fromID, toID)` so the parent can
/// update positions in ``DashboardLayoutStore``. Reorders animate with a
/// spring effect.
///
/// ## Usage
/// ```swift
/// DashboardGridView(
///     layout: store.activeLayout,
///     isEditMode: $isEditMode,
///     sessionsVM: sessionsVM,
///     apiClient: appState.apiClient,
///     onRemoveWidget: { store.remove($0) },
///     onReorderWidget: { from, to in store.reorder(widgetID: from, before: to) },
///     onSessionSelected: onSessionSelected,
///     onNavigate: onNavigate,
///     onNavigateToBrowser: onNavigateToBrowser
/// )
/// ```
struct DashboardGridView: View {

    // MARK: - Properties

    /// The layout whose widget tiles should be rendered.
    let layout: DashboardLayout
    /// Bound to the parent's edit-mode state. Toggled by the built-in toolbar button.
    @Binding var isEditMode: Bool
    /// Shared sessions view model passed to session-aware widgets.
    var sessionsVM: SessionsViewModel
    /// API client used by widgets that fetch their own data.
    var apiClient: APIClient
    /// Called when the user taps the × button on a tile during edit mode.
    var onRemoveWidget: ((DashboardWidget) -> Void)?
    /// Called when the user drags one widget onto another to request a reorder.
    /// Receives `(fromID, toID)` where `fromID` is the dragged widget and `toID`
    /// is the drop target. The parent is responsible for updating positions.
    var onReorderWidget: ((UUID, UUID) -> Void)?
    /// Called when the user taps a session row inside a widget.
    var onSessionSelected: ((ChatSession) -> Void)?
    /// Called to push a top-level ``ActiveScreen`` onto the navigation stack.
    var onNavigate: ((ActiveScreen) -> Void)?
    /// Called to deep-link directly to a ``BrowserSegment``.
    var onNavigateToBrowser: ((BrowserSegment) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Tracks the widget being dragged so we can dim its tile.
    @State private var draggingWidgetID: UUID?

    // MARK: - Row Model

    /// A group of widgets sharing the same ``WidgetPosition/row`` index.
    private struct WidgetRow: Identifiable {
        /// Row index from ``WidgetPosition/row``; used as stable identity.
        let id: Int
        /// Widgets in this row, sorted by ``WidgetPosition/col`` ascending.
        let widgets: [DashboardWidget]
    }

    // MARK: - Computed Layout

    /// Widgets grouped by their `position.row` and sorted column-first within each row.
    private var widgetRows: [WidgetRow] {
        let sorted = layout.widgets.sorted {
            $0.position.row == $1.position.row
                ? $0.position.col < $1.position.col
                : $0.position.row < $1.position.row
        }

        var rowMap: [Int: [DashboardWidget]] = [:]
        for widget in sorted {
            rowMap[widget.position.row, default: []].append(widget)
        }

        return rowMap
            .sorted { $0.key < $1.key }
            .map { WidgetRow(id: $0.key, widgets: $0.value) }
    }

    // MARK: - Body

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: theme.spacingMD) {
            ForEach(widgetRows) { row in
                HStack(alignment: .top, spacing: theme.spacingMD) {
                    ForEach(row.widgets) { widget in
                        widgetSlot(for: widget)
                            .opacity(draggingWidgetID == widget.id ? 0.4 : 1.0)
                            #if os(iOS)
                            .onDrag {
                                guard isEditMode else { return NSItemProvider() }
                                draggingWidgetID = widget.id
                                return NSItemProvider(object: widget.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                                guard isEditMode else { return false }
                                providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                    guard let idString = item as? String,
                                          let fromID = UUID(uuidString: idString) else { return }
                                    DispatchQueue.main.async {
                                        withAnimation(.spring()) {
                                            onReorderWidget?(fromID, widget.id)
                                        }
                                        draggingWidgetID = nil
                                    }
                                }
                                return true
                            }
                            #endif
                    }
                }
            }
        }
        .animation(.spring(), value: layout.widgets.map(\.id))
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation(.spring()) {
                        isEditMode.toggle()
                    }
                }
            }
            #else
            ToolbarItem {
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation(.spring()) {
                        isEditMode.toggle()
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Widget Dispatch

    /// Resolves the concrete slot view for the given widget's type.
    ///
    /// Each case maps to a private slot view that holds the right typed view model
    /// as `@State`, avoiding existential overhead while keeping the conformance to
    /// `DashboardWidgetViewModel` fully concrete.
    @ViewBuilder
    private func widgetSlot(for widget: DashboardWidget) -> some View {
        switch widget.type {
        case .activeSessions:
            ActiveSessionsSlot(
                widget: widget,
                isEditMode: isEditMode,
                sessionsVM: sessionsVM,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) },
                onSessionSelected: onSessionSelected
            )
        case .recentSessions:
            RecentSessionsSlot(
                widget: widget,
                isEditMode: isEditMode,
                sessionsVM: sessionsVM,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) },
                onSessionSelected: onSessionSelected
            )
        case .systemMetrics:
            SystemMetricsSlot(
                widget: widget,
                isEditMode: isEditMode,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) }
            )
        case .teamActivity:
            TeamActivitySlot(
                widget: widget,
                isEditMode: isEditMode,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) }
            )
        case .usageStats:
            UsageStatsSlot(
                widget: widget,
                isEditMode: isEditMode,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) }
            )
        case .quickActions:
            QuickActionsSlot(
                widget: widget,
                isEditMode: isEditMode,
                onRemove: { onRemoveWidget?(widget) },
                onNavigate: onNavigate,
                onNavigateToBrowser: onNavigateToBrowser
            )
        case .favorites:
            FavoritesSlot(
                widget: widget,
                isEditMode: isEditMode,
                onRemove: { onRemoveWidget?(widget) }
            )
        case .projectStatus:
            ProjectStatusSlot(
                widget: widget,
                isEditMode: isEditMode,
                apiClient: apiClient,
                onRemove: { onRemoveWidget?(widget) }
            )
        }
    }
}

// MARK: - Private Slot Views
//
// Each slot view owns a single @State view model matched to its widget type.
// This avoids allocating all eight view models when only one is needed per slot,
// and satisfies WidgetContainerView's concrete generic constraint without
// existential overhead. Configuration is applied in .onAppear, which fires
// synchronously before WidgetContainerView's async .task { loadContent() }.

// MARK: ActiveSessionsSlot

private struct ActiveSessionsSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var sessionsVM: SessionsViewModel
    var apiClient: APIClient
    let onRemove: () -> Void
    var onSessionSelected: ((ChatSession) -> Void)?

    @State private var viewModel = ActiveSessionsWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            ActiveSessionsWidget(viewModel: viewModel, onSessionSelected: onSessionSelected)
        }
        .onAppear {
            viewModel.configure(sessionsVM: sessionsVM)
        }
    }
}

// MARK: RecentSessionsSlot

private struct RecentSessionsSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var sessionsVM: SessionsViewModel
    var apiClient: APIClient
    let onRemove: () -> Void
    var onSessionSelected: ((ChatSession) -> Void)?

    @State private var viewModel = RecentSessionsWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            RecentSessionsWidget(viewModel: viewModel, onSessionSelected: onSessionSelected)
        }
        .onAppear {
            viewModel.configure(sessionsVM: sessionsVM)
        }
    }
}

// MARK: SystemMetricsSlot

private struct SystemMetricsSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var apiClient: APIClient
    let onRemove: () -> Void

    @State private var viewModel = SystemMetricsWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            SystemMetricsWidget(viewModel: viewModel)
        }
        .onAppear {
            viewModel.configure(client: apiClient)
        }
    }
}

// MARK: TeamActivitySlot

private struct TeamActivitySlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var apiClient: APIClient
    let onRemove: () -> Void

    @State private var viewModel = TeamActivityWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            TeamActivityWidget(viewModel: viewModel)
        }
        .onAppear {
            viewModel.configure(client: apiClient)
        }
    }
}

// MARK: UsageStatsSlot

private struct UsageStatsSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var apiClient: APIClient
    let onRemove: () -> Void

    @State private var viewModel = UsageStatsWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            UsageStatsWidget(viewModel: viewModel)
        }
        .onAppear {
            viewModel.configure(client: apiClient)
        }
    }
}

// MARK: QuickActionsSlot

private struct QuickActionsSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    let onRemove: () -> Void
    var onNavigate: ((ActiveScreen) -> Void)?
    var onNavigateToBrowser: ((BrowserSegment) -> Void)?

    @State private var viewModel = QuickActionsWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            QuickActionsWidget(
                viewModel: viewModel,
                onNavigate: onNavigate,
                onNavigateToBrowser: onNavigateToBrowser
            )
        }
    }
}

// MARK: FavoritesSlot

private struct FavoritesSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    let onRemove: () -> Void

    @State private var viewModel = FavoritesWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            FavoritesWidget(viewModel: viewModel)
        }
    }
}

// MARK: ProjectStatusSlot

private struct ProjectStatusSlot: View {
    let widget: DashboardWidget
    let isEditMode: Bool
    var apiClient: APIClient
    let onRemove: () -> Void

    @State private var viewModel = ProjectStatusWidgetViewModel()

    var body: some View {
        WidgetContainerView(
            widget: widget,
            viewModel: viewModel,
            isEditMode: isEditMode,
            onRemove: onRemove
        ) {
            ProjectStatusWidget(viewModel: viewModel)
        }
        .onAppear {
            viewModel.configure(client: apiClient)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isEditMode = false

    let layout = DashboardLayout(name: "Developer", persona: .developer)

    NavigationStack {
        ScrollView {
            DashboardGridView(
                layout: layout,
                isEditMode: $isEditMode,
                sessionsVM: SessionsViewModel(),
                apiClient: APIClient(baseURL: "http://localhost:9999")
            )
            .padding()
        }
        .navigationTitle("Dashboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    .background(ThemeSnapshot(ObsidianTheme()).bgPrimary)
}
