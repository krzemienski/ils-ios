import SwiftUI

// MARK: - WidgetContainerView

/// Generic wrapper that renders a dashboard widget tile with loading, offline,
/// and edit-mode states.
///
/// `WidgetContainerView` is size-aware: it derives its height from the widget's
/// ``WidgetSize`` and a caller-supplied `cellHeight` base unit. Width is left
/// unconstrained so the parent ``DashboardGridView`` controls it via grid column spans.
///
/// The generic `ViewModel` parameter must conform to ``DashboardWidgetViewModel``
/// (which requires `@Observable`), letting SwiftUI track `isLoading` and `isOffline`
/// changes without existential overhead.
///
/// ## States
/// - **Loading** — A shimmer gradient sweeps the card while `viewModel.isLoading`.
/// - **Offline** — An icon and label replace the content when `viewModel.isOffline`.
/// - **Edit mode** — A scrim and × button appear when `isEditMode` is `true`.
///
/// ## Usage
/// ```swift
/// WidgetContainerView(
///     widget: widget,
///     viewModel: vm,
///     isEditMode: isEditing,
///     onRemove: { store.remove(widget) }
/// ) {
///     ActiveSessionsWidgetView(viewModel: vm)
/// }
/// ```
struct WidgetContainerView<ViewModel: DashboardWidgetViewModel, Content: View>: View {

    // MARK: - Properties

    let widget: DashboardWidget
    let viewModel: ViewModel
    let isEditMode: Bool
    let onRemove: () -> Void

    /// Base height (in points) for a single grid row. Defaults to 160 pt.
    /// The actual frame height is `cellHeight × rowSpan + spacing × (rowSpan − 1)`.
    let cellHeight: CGFloat

    private let content: Content

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Init

    init(
        widget: DashboardWidget,
        viewModel: ViewModel,
        isEditMode: Bool,
        cellHeight: CGFloat = 160,
        onRemove: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.widget = widget
        self.viewModel = viewModel
        self.isEditMode = isEditMode
        self.cellHeight = cellHeight
        self.onRemove = onRemove
        self.content = content()
    }

    // MARK: - Computed

    private var frameHeight: CGFloat {
        let rows = CGFloat(widget.size.rowSpan)
        // Account for the inter-row spacing that the grid will place between rows
        return rows * cellHeight + max(0, rows - 1) * theme.spacingMD
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardLayer
            if isEditMode {
                editModeOverlay
            }
        }
        .task {
            await viewModel.loadContent()
        }
    }

    // MARK: - Sub-views

    /// Glass card containing main content and optional shimmer overlay.
    private var cardLayer: some View {
        ZStack {
            // Primary content or offline placeholder
            if viewModel.isOffline && !viewModel.isLoading {
                offlineStateView
            } else {
                content
            }

            // Shimmer overlay during loading — sits atop content so the sweep
            // is visible regardless of how much content is already rendered.
            if viewModel.isLoading {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.glassBackground)
                    .shimmer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: frameHeight)
        .glassCard(padding: 0)
    }

    /// Offline empty-state: wifi-slash icon and "Offline" label centred in the card.
    private var offlineStateView: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "wifi.slash")
                .font(.system(size: theme.fontTitle2))
                .foregroundStyle(theme.textSecondary)

            Text("Offline")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingMD)
    }

    /// Edit-mode overlay: translucent scrim + remove (×) button at top trailing.
    private var editModeOverlay: some View {
        ZStack(alignment: .topTrailing) {
            // Non-interactive scrim so the remove button remains tappable
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgPrimary.opacity(0.35))
                .allowsHitTesting(false)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.error)
                    // Circular backing shape for legibility on any widget background
                    .background(
                        Circle()
                            .fill(theme.bgPrimary)
                            .padding(3)
                    )
            }
            .padding(theme.spacingSM)
            .accessibilityLabel("Remove \(widget.type.displayName) widget")
        }
        .frame(maxWidth: .infinity)
        .frame(height: frameHeight)
    }
}
