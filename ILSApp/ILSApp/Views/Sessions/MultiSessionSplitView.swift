import SwiftUI
import ILSShared

/// Multi-session split view container for iPad and Mac.
///
/// Shows 2–4 pinned sessions side-by-side in a responsive grid layout.
/// Layout shape is controlled by ``MultiSessionViewModel/selectedLayout``:
///
/// - **2 panes**: Equal-width side-by-side `HStack`
/// - **3 panes**: Full-height left pane + right `VStack` of 2 stacked panes
/// - **4 panes**: 2×2 `LazyVGrid` with equal cell heights derived from `GeometryReader`
///
/// Tapping a pane sets it as the ``activePane``, highlighted with an accent border
/// from ``SessionPaneView``.
///
/// ## Topics
/// ### Inputs
/// - ``multiSessionVM`` - Manages pinned session IDs and selected layout
/// - ``sessionsVM`` - Provides the full session list for ID resolution
///
/// ### State
/// - ``activePane`` - Zero-based index of the currently focused pane
/// - ``showLayoutPicker`` - Whether the ``SplitViewLayoutPicker`` sheet is presented
struct MultiSessionSplitView: View {

    // MARK: - Inputs

    /// View model managing pinned session IDs, layout selection, and persistence.
    var multiSessionVM: MultiSessionViewModel
    /// View model providing the live session list for resolving pinned IDs.
    var sessionsVM: SessionsViewModel

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - State

    /// Whether the layout/session configuration sheet is presented.
    @State private var showLayoutPicker = false
    /// Zero-based index of the active (focused) pane. Highlighted with an accent border.
    @State private var activePane: Int = 0

    // MARK: - Body

    var body: some View {
        let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)

        GeometryReader { geometry in
            Group {
                if pinned.isEmpty {
                    emptyState
                } else {
                    panesLayout(for: pinned, size: geometry.size)
                }
            }
        }
        .navigationTitle("Split View")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Current layout displayed in the navigation bar title area.
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Split View")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(multiSessionVM.selectedLayout.displayName)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Split View, \(multiSessionVM.selectedLayout.displayName)")
            }

            // Configure Layout button opens the session pin sheet.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLayoutPicker = true
                } label: {
                    Label("Configure Layout", systemImage: "rectangle.split.2x2")
                }
                .accessibilityLabel("Configure split view layout")
            }
        }
        .sheet(isPresented: $showLayoutPicker) {
            SplitViewLayoutPicker(multiSessionVM: multiSessionVM, sessionsVM: sessionsVM)
        }
    }

    // MARK: - Pane Layouts

    /// Renders the appropriate pane arrangement based on the resolved session count and
    /// selected layout. `size` is provided by `GeometryReader` for height-aware sizing.
    @ViewBuilder
    private func panesLayout(for sessions: [ChatSession], size: CGSize) -> some View {
        let count = min(sessions.count, multiSessionVM.selectedLayout.paneCount)
        let visible = Array(sessions.prefix(count))
        let gap: CGFloat = 1

        switch count {
        case 2:
            // Side-by-side equal-width panes.
            HStack(spacing: gap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                    SessionPaneView(
                        session: session,
                        isActive: activePane == index,
                        onUnpin: { multiSessionVM.unpinSession(session) }
                    )
                    .onTapGesture { activePane = index }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Switch to session pane \(index + 1)")
                }
            }

        case 3:
            // One full-height left pane + two stacked right panes.
            HStack(spacing: gap) {
                SessionPaneView(
                    session: visible[0],
                    isActive: activePane == 0,
                    onUnpin: { multiSessionVM.unpinSession(visible[0]) }
                )
                .onTapGesture { activePane = 0 }
                .accessibilityAddTraits(.isButton)

                VStack(spacing: gap) {
                    ForEach(Array(visible.dropFirst().enumerated()), id: \.element.id) { index, session in
                        SessionPaneView(
                            session: session,
                            isActive: activePane == index + 1,
                            onUnpin: { multiSessionVM.unpinSession(session) }
                        )
                        .onTapGesture { activePane = index + 1 }
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }

        default:
            // 4-pane (or any overflow): 2×2 grid with equal cell heights.
            let columns = [
                GridItem(.flexible(), spacing: gap),
                GridItem(.flexible(), spacing: gap)
            ]
            let cellHeight = max(80, (size.height - gap) / 2)

            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                    SessionPaneView(
                        session: session,
                        isActive: activePane == index,
                        onUnpin: { multiSessionVM.unpinSession(session) }
                    )
                    .frame(height: cellHeight)
                    .onTapGesture { activePane = index }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Empty State

    /// Shown when no sessions are pinned. Prompts the user to configure the split view.
    private var emptyState: some View {
        VStack(spacing: theme.spacingLG) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Sessions Pinned")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Pin 2–4 sessions from the sidebar to monitor them simultaneously.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                showLayoutPicker = true
            } label: {
                Text("Configure")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configure split view sessions")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
