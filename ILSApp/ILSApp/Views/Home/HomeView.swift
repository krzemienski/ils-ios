import SwiftUI
import ILSShared
import TipKit

/// The primary home dashboard displayed when the app launches or no session is active.
///
/// Hosts a configurable ``DashboardGridView`` which renders the user's chosen
/// ``DashboardLayout`` as a grid of widget tiles. A toolbar slider button opens
/// ``DashboardLayoutPickerView`` to switch or customise layouts. The ``DashboardLayoutStore``
/// is owned here as `@State` and injected into the layout-picker sheet via the environment.
/// Pull-to-refresh triggers a reload of the shared ``SessionsViewModel`` and the
/// refreshing banner is shown while the operation is in flight.
///
/// ## Topics
/// ### Sections
/// - ``welcomeSection`` - Greeting header showing the connected server URL
/// - ``refreshingBanner`` - Transient animated banner shown during pull-to-refresh
/// - ``connectionBanner`` - Warning banner with a Setup CTA when the server is unreachable
///
/// ### Actions
/// - ``onSessionSelected`` - Callback invoked when the user taps a session row in a widget
/// - ``onNavigate`` - Callback to push a named ``ActiveScreen`` onto the navigation stack
/// - ``onNavigateToBrowser`` - Callback to deep-link to a specific ``BrowserSegment``
///
/// ### Widget Operations
/// - ``removeWidget(_:)`` - Removes a widget from the active layout and persists the change
/// - ``reorderWidget(fromID:toID:)`` - Moves a dragged widget before the drop-target widget
struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Persists and manages all dashboard layouts, including the active layout selection.
    /// Injected from the app-level environment so a single store instance is shared app-wide.
    @Environment(DashboardLayoutStore.self) private var layoutStore
    /// Whether the dashboard grid is in edit mode (shows remove / reorder controls).
    @State private var isEditMode = false
    /// Whether a pull-to-refresh reload is currently in flight.
    @State private var isRefreshing = false
    /// Controls presentation of the ``DashboardLayoutPickerView`` sheet.
    @State private var showLayoutPicker = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let createSessionTip = CreateSessionTip()
    private let commandPaletteTip = CommandPaletteTip()

    /// Shared sessions view model owned by SidebarRootView.
    var sessionsVM: SessionsViewModel
    /// Called when the user selects a session row inside a widget.
    var onSessionSelected: ((ChatSession) -> Void)?
    /// Called to navigate to a top-level ``ActiveScreen`` from a widget action.
    var onNavigate: ((ActiveScreen) -> Void)?
    /// Called to navigate directly to a specific ``BrowserSegment`` (Skills, MCP, Plugins).
    var onNavigateToBrowser: ((BrowserSegment) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                refreshingBanner
                connectionBanner

                TipView(createSessionTip)
                    .tipBackground(theme.bgSecondary)

                TipView(commandPaletteTip)
                    .tipBackground(theme.bgSecondary)

                if let layout = layoutStore.activeLayout {
                    DashboardGridView(
                        layout: layout,
                        isEditMode: $isEditMode,
                        sessionsVM: sessionsVM,
                        apiClient: appState.apiClient,
                        onRemoveWidget: { widget in
                            removeWidget(widget)
                        },
                        onReorderWidget: { fromID, toID in
                            reorderWidget(fromID: fromID, toID: toID)
                        },
                        onSessionSelected: onSessionSelected,
                        onNavigate: onNavigate,
                        onNavigateToBrowser: onNavigateToBrowser
                    )
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
            .animation(.easeInOut(duration: 0.3), value: isRefreshing)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Home")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLayoutPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Dashboard Layout")
                .accessibilityHint("Opens the layout picker to customise your dashboard")
            }
            #else
            ToolbarItem {
                Button {
                    showLayoutPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Dashboard Layout")
                .accessibilityHint("Opens the layout picker to customise your dashboard")
            }
            #endif
        }
        .sheet(isPresented: $showLayoutPicker) {
            NavigationStack {
                DashboardLayoutPickerView()
            }
            .environment(layoutStore)
            .environment(\.theme, theme)
        }
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .refreshable {
            HapticManager.impact(.medium)
            isRefreshing = true
            await sessionsVM.loadSessions(refresh: true)  // Shared VM — updates both Home and Sidebar
            isRefreshing = false
        }
        .onChange(of: appState.isConnected) { _, connected in
            CreateSessionTip.isConnected = connected
        }
    }

    // MARK: - Welcome Section

    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Welcome back")
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if appState.isConnected {
                Text(appState.serverURL)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Refreshing Banner

    @ViewBuilder
    private var refreshingBanner: some View {
        if isRefreshing {
            HStack(spacing: theme.spacingSM) {
                if !reduceMotion {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(theme.textSecondary)
                }

                Text("Refreshing…")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
            .accessibilityLabel("Refreshing content")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !appState.isConnected {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Not Connected")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure your server to get started")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    appState.showOnboarding = true
                } label: {
                    Text("Setup")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Setup server connection")
                .accessibilityHint("Opens the server configuration wizard")
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Widget Operations

    /// Removes a widget from the active layout and persists the updated layout.
    ///
    /// After removal, row indices are renumbered starting from zero so
    /// ``DashboardGridView`` renders a contiguous sequence of rows.
    ///
    /// - Parameter widget: The widget tile to remove.
    private func removeWidget(_ widget: DashboardWidget) {
        guard var layout = layoutStore.activeLayout else { return }
        layout.widgets.removeAll { $0.id == widget.id }
        renumberRows(&layout.widgets)
        layoutStore.save(layout)
        layoutStore.setActiveLayout(layout)
    }

    /// Moves the dragged widget (`fromID`) to the position occupied by the
    /// drop-target widget (`toID`) and persists the updated layout.
    ///
    /// The dragged widget is removed from its original position and inserted
    /// immediately before (or after) the drop target, matching the visual
    /// expectation set by ``DashboardGridView``'s drag-and-drop handler.
    /// Row indices are renumbered after the move.
    ///
    /// - Parameters:
    ///   - fromID: Stable identity of the widget being dragged.
    ///   - toID: Stable identity of the widget acting as the drop target.
    private func reorderWidget(fromID: UUID, toID: UUID) {
        guard var layout = layoutStore.activeLayout,
              let fromIndex = layout.widgets.firstIndex(where: { $0.id == fromID }),
              let toIndex = layout.widgets.firstIndex(where: { $0.id == toID }) else { return }
        let widget = layout.widgets.remove(at: fromIndex)
        let insertIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        layout.widgets.insert(widget, at: insertIndex)
        renumberRows(&layout.widgets)
        layoutStore.save(layout)
        layoutStore.setActiveLayout(layout)
    }

    /// Rewrites each widget's `position.row` to its array index, keeping
    /// `position.col` at zero. Called after every structural mutation.
    private func renumberRows(_ widgets: inout [DashboardWidget]) {
        for idx in widgets.indices {
            widgets[idx].position.row = idx
            widgets[idx].position.col = 0
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(sessionsVM: SessionsViewModel())
            .environment(AppState())
            .environment(DashboardLayoutStore())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
