import SwiftUI
import ILSShared

/// A self-contained session pane for use in ``MultiSessionSplitView``.
///
/// Renders a compact pane header (session name + ``SessionStatusBadge`` + unpin button)
/// above an embedded ``ChatView``. The pane owns its own ``ChatViewModel`` (``paneVM``)
/// to track streaming status for the header badge.
///
/// When ``isActive`` is `false`, the embedded chat view displays the last-loaded state.
/// Because SSE connections are only initiated on message send, inactive panes naturally
/// avoid establishing new streaming connections.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The session this pane represents
/// - ``isActive`` - Whether this is the focused pane in the split layout
/// - ``onUnpin`` - Called when the user taps the close button to remove the pane
struct SessionPaneView: View {

    // MARK: - Inputs

    /// The chat session this pane is presenting.
    let session: ChatSession
    /// Whether this pane is the currently focused pane in the split view.
    let isActive: Bool
    /// Closure invoked when the user taps the unpin (close) button.
    let onUnpin: () -> Void

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState

    // MARK: - State

    /// Owned view model used to track streaming status for the pane header badge.
    ///
    /// Configured with the session on first appear. SSE streaming is only initiated
    /// when the user sends a message through the embedded ``ChatView``, so this model
    /// remains passive for inactive panes (background mode shows last loaded state).
    @State private var paneVM = ChatViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            paneHeader

            Divider()
                .overlay(theme.divider)

            ChatView(session: session)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(
                    isActive ? theme.accent : theme.divider,
                    lineWidth: isActive ? 2 : 0.5
                )
        }
        .task {
            configurePane()
            await paneVM.loadMessageHistory()
        }
    }

    // MARK: - Subviews

    /// Compact header strip showing session identity, streaming status, and unpin control.
    private var paneHeader: some View {
        HStack(spacing: theme.spacingSM) {
            SessionStatusBadge(
                sessionStatus: session.status,
                isStreaming: paneVM.isStreaming,
                sizeMode: .compact
            )

            Text(session.displayName)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(isActive ? theme.textPrimary : theme.textSecondary)
                .lineLimit(1)

            Spacer()

            Button(action: onUnpin) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unpin session")
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(isActive ? theme.accent.opacity(0.1) : theme.bgSecondary)
    }

    // MARK: - Setup

    /// Configure ``paneVM`` with the current session and API clients.
    private func configurePane() {
        paneVM.configure(client: appState.apiClient, sseClient: appState.sseClient)
        paneVM.sessionId = session.id
        paneVM.encodedProjectPath = session.encodedProjectPath
        paneVM.claudeSessionId = session.claudeSessionId
        paneVM.isConnected = appState.isConnected
    }
}
