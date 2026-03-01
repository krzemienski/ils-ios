import SwiftUI
import Observation

// MARK: - QuickActionsWidgetViewModel

/// View model for the Quick Actions dashboard widget.
///
/// Quick actions are static shortcut buttons that require no backend data,
/// so this view model is intentionally trivial — `isLoading` is always `false`
/// and `loadContent()` is a no-op.  The widget's navigation callbacks are held
/// on the view itself, not the view model.
///
/// ## Topics
/// ### DashboardWidgetViewModel
/// - ``isLoading`` - Always `false`; no backend data is required
/// - ``isOffline`` - Always `false`; actions are always available
/// - ``loadContent()`` - No-op; static content requires no fetch
@Observable
@MainActor
final class QuickActionsWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// Always `false`; quick actions need no backend data.
    private(set) var isLoading = false
    /// Always `false`; quick actions are always available.
    private(set) var isOffline = false

    // MARK: Init

    init() {}

    // MARK: DashboardWidgetViewModel

    /// No-op — quick actions are static and require no backend fetch.
    func loadContent() async {}
}

// MARK: - QuickActionsWidget

/// Dashboard widget displaying a size-adaptive grid of shortcut action cards.
///
/// Uses an adaptive ``LazyVGrid`` so that the grid fills as many columns as
/// fit in the available width.  On a small (1-column) tile the grid renders
/// two action columns; on a medium or large (2-column) tile it expands to
/// three columns.  The action set mirrors the Quick Actions section in
/// ``HomeView``, providing one-tap access to common tasks.
///
/// ## Usage
/// ```swift
/// QuickActionsWidget(viewModel: vm) {
///     showNewSessionSheet = true
/// } onNavigate: { screen in
///     navigate(to: screen)
/// } onNavigateToBrowser: { segment in
///     navigate(to: segment)
/// }
/// ```
struct QuickActionsWidget: View {

    // MARK: - Properties

    /// View model (trivial — no backend data required).
    let viewModel: QuickActionsWidgetViewModel
    /// Called when the user taps "New Session".
    var onNewSession: (() -> Void)?
    /// Called when the user taps a card that navigates to a top-level screen.
    var onNavigate: ((ActiveScreen) -> Void)?
    /// Called when the user taps a card that navigates to a browser segment.
    var onNavigateToBrowser: ((BrowserSegment) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            actionsGrid
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.quickActions.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            Text("Quick Actions")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Actions Grid

    /// Adaptive grid that fits as many columns as possible in the available width.
    ///
    /// A minimum card width of 72 pt results in two columns on a narrow (~160 pt)
    /// small widget and three columns on a wider (~320 pt) medium or large widget.
    private var actionsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: theme.spacingXS)],
            spacing: theme.spacingXS
        ) {
            quickActionCard(
                icon: "plus.bubble.fill",
                title: "New Session",
                color: theme.entitySession
            ) {
                onNewSession?()
            }

            quickActionCard(
                icon: "sparkles",
                title: "Discover Skills",
                color: theme.entitySkill
            ) {
                onNavigateToBrowser?(.skills)
            }

            quickActionCard(
                icon: "server.rack",
                title: "Configure MCP",
                color: theme.entityMCP
            ) {
                onNavigateToBrowser?(.mcp)
            }

            quickActionCard(
                icon: "puzzlepiece.extension.fill",
                title: "Browse Plugins",
                color: theme.entityPlugin
            ) {
                onNavigateToBrowser?(.plugins)
            }

            quickActionCard(
                icon: "gearshape.fill",
                title: "Settings",
                color: theme.textSecondary
            ) {
                onNavigate?(.settings)
            }

            quickActionCard(
                icon: "gauge.with.dots.needle.33percent",
                title: "System",
                color: theme.entityMCP
            ) {
                onNavigate?(.system)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Quick Action Card

    /// A single tappable action card styled to match the HomeView quick-action pattern.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name shown at the top of the card.
    ///   - title: Short label displayed below the icon.
    ///   - color: Tint colour applied to the icon.
    ///   - action: Closure executed when the card is tapped.
    @ViewBuilder
    private func quickActionCard(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to open \(title)")
    }
}

// MARK: - Preview

#Preview {
    QuickActionsWidget(viewModel: QuickActionsWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 220)
        .glassCard()
        .padding()
}
