import SwiftUI
import ILSShared

// MARK: - Sessions View Mode

/// Persisted preference for sessions display mode.
enum SessionsViewMode: String, CaseIterable {
    case list
    case board
}

// MARK: - Sessions Container View

/// Wrapper view that provides a segmented control toggle between the session
/// list (``UnifiedSessionsView``) and the kanban board (``SessionKanbanBoardView``).
///
/// Uses `@AppStorage("sessionsViewMode")` to persist the user's display preference
/// across launches. The kanban view model is only created when board mode is active
/// to conserve resources.
struct SessionsContainerView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called when the user selects a session from either the list or board view.
    var onSessionSelected: ((TaggedSession) -> Void)?

    @AppStorage("sessionsViewMode") private var viewMode: String = SessionsViewMode.list.rawValue

    /// Kanban view model — only instantiated when board mode is active.
    @State private var kanbanViewModel: SessionKanbanViewModel?

    /// Resolved view mode from the persisted string.
    private var resolvedMode: SessionsViewMode {
        SessionsViewMode(rawValue: viewMode) ?? .list
    }

    var body: some View {
        VStack(spacing: 0) {
            // View mode toggle
            viewModePicker
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)

            // Content
            switch resolvedMode {
            case .list:
                UnifiedSessionsView(onSessionSelected: onSessionSelected)
            case .board:
                if let kanbanViewModel {
                    SessionKanbanBoardView(
                        viewModel: kanbanViewModel,
                        onSessionSelected: { item in
                            guard case .session(let tagged) = item else { return }
                            onSessionSelected?(tagged)
                        }
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("All Sessions")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .onChange(of: viewMode) { _, newValue in
            let mode = SessionsViewMode(rawValue: newValue) ?? .list
            if mode == .board {
                ensureKanbanViewModel()
            } else {
                tearDownKanbanViewModel()
            }
        }
        .onAppear {
            if resolvedMode == .board {
                ensureKanbanViewModel()
            }
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            Label("List", systemImage: "list.bullet")
                .tag(SessionsViewMode.list.rawValue)
            Label("Board", systemImage: "rectangle.split.3x1")
                .tag(SessionsViewMode.board.rawValue)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Sessions view mode")
    }

    // MARK: - Kanban Lifecycle

    private func ensureKanbanViewModel() {
        guard kanbanViewModel == nil else { return }
        kanbanViewModel = SessionKanbanViewModel()
    }

    private func tearDownKanbanViewModel() {
        kanbanViewModel?.stopPolling()
        kanbanViewModel = nil
    }
}
