import SwiftUI
import ILSShared

/// Multi-session split view container for iPad and Mac.
///
/// Shows 2–4 pinned sessions side-by-side in a responsive grid layout.
/// Layout shape is controlled by ``MultiSessionViewModel/selectedLayout``.
///
/// - Note: Full implementation is provided by phase-3-ipad-mac-split-view.
///   This file serves as the type declaration so that routing in ``SidebarRootView``
///   and ``MacContentView`` can reference it before the full implementation lands.
struct MultiSessionSplitView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var multiSessionVM: MultiSessionViewModel
    var sessionsVM: SessionsViewModel

    @State private var showLayoutPicker = false
    @State private var activePane: Int = 0

    var body: some View {
        let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)

        Group {
            if pinned.isEmpty {
                emptyState
            } else {
                panesLayout(for: pinned)
            }
        }
        .navigationTitle("Split View")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLayoutPicker = true
                } label: {
                    Label("Configure Layout", systemImage: "rectangle.split.2x2")
                }
            }
        }
        .sheet(isPresented: $showLayoutPicker) {
            SplitViewLayoutPicker(multiSessionVM: multiSessionVM, sessionsVM: sessionsVM)
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func panesLayout(for sessions: [ChatSession]) -> some View {
        let count = min(sessions.count, multiSessionVM.selectedLayout.paneCount)
        let visible = Array(sessions.prefix(count))

        switch count {
        case 2:
            HStack(spacing: 1) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                    SessionPaneView(
                        session: session,
                        isActive: activePane == index,
                        onUnpin: { multiSessionVM.unpinSession(session) }
                    )
                    .onTapGesture { activePane = index }
                }
            }
        case 3:
            HStack(spacing: 1) {
                SessionPaneView(
                    session: visible[0],
                    isActive: activePane == 0,
                    onUnpin: { multiSessionVM.unpinSession(visible[0]) }
                )
                .onTapGesture { activePane = 0 }
                VStack(spacing: 1) {
                    ForEach(Array(visible.dropFirst().enumerated()), id: \.element.id) { index, session in
                        SessionPaneView(
                            session: session,
                            isActive: activePane == index + 1,
                            onUnpin: { multiSessionVM.unpinSession(session) }
                        )
                        .onTapGesture { activePane = index + 1 }
                    }
                }
            }
        default:
            let columns = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                    SessionPaneView(
                        session: session,
                        isActive: activePane == index,
                        onUnpin: { multiSessionVM.unpinSession(session) }
                    )
                    .onTapGesture { activePane = index }
                }
            }
        }
    }

    // MARK: - Empty State

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
