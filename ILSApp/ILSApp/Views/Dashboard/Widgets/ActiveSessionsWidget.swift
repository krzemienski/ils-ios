import SwiftUI
import ILSShared
import Observation

// MARK: - ActiveSessionsWidgetViewModel

/// View model for the Active Sessions dashboard widget.
///
/// Supplies the list of currently-running sessions and the total active count.
/// Data is sourced from a shared ``SessionsViewModel`` when available, and falls
/// back to a direct ``APIClient`` fetch when the widget runs standalone.
///
/// ## Topics
/// ### Configuration
/// - ``configure(sessionsVM:)`` - Bind to the shared sessions view model
/// - ``configure(client:)`` - Bind to a direct API client for standalone use
///
/// ### Data
/// - ``activeSessions`` - Up to three currently active sessions
/// - ``activeCount`` - Total number of active sessions (may exceed three)
@Observable
@MainActor
final class ActiveSessionsWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while the widget is fetching its initial or refreshed data.
    private(set) var isLoading = true
    /// True when the backend is unreachable.
    private(set) var isOffline = false

    // MARK: Data

    /// Active sessions shown in the widget (capped at three rows).
    private(set) var activeSessions: [ChatSession] = []
    /// Total number of active sessions; may exceed `activeSessions.count`.
    private(set) var activeCount: Int = 0

    // MARK: Private

    /// Shared sessions VM — preferred data source.
    private weak var sessionsVM: SessionsViewModel?
    /// Direct API client — fallback when `sessionsVM` is `nil`.
    private var client: APIClient?

    // MARK: Init

    init() {}

    // MARK: Configuration

    /// Bind this view model to the shared sessions view model.
    /// - Parameter sessionsVM: The shared ``SessionsViewModel`` owned by the root view.
    func configure(sessionsVM: SessionsViewModel) {
        self.sessionsVM = sessionsVM
    }

    /// Bind this view model to a direct API client for standalone use.
    /// - Parameter client: The ``APIClient`` for fetching sessions independently.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: DashboardWidgetViewModel

    /// Fetches active sessions from the shared view model or the API.
    func loadContent() async {
        isLoading = true
        isOffline = false

        if let vm = sessionsVM {
            // If the shared VM has not loaded yet, trigger a load first
            if vm.isLoading && vm.sessions.isEmpty {
                await vm.loadSessions()
            }
            updateFromSessionsVM(vm)
        } else if let client {
            await fetchFromAPI(client: client)
        } else {
            isLoading = false
        }
    }

    // MARK: Private Helpers

    /// Derive active sessions from an already-loaded sessions view model.
    private func updateFromSessionsVM(_ vm: SessionsViewModel) {
        let active = vm.sessions.filter { $0.status == .active }
        activeCount = active.count
        activeSessions = Array(active.prefix(3))
        isLoading = false
    }

    /// Fetch sessions directly from the API and filter for active ones.
    private func fetchFromAPI(client: APIClient) async {
        do {
            let response: APIResponse<PaginatedResponse<ChatSession>> =
                try await client.get("/sessions?page=1&limit=50")
            let all = response.data?.items ?? []
            let active = all.filter { $0.status == .active }
            activeCount = active.count
            activeSessions = Array(active.prefix(3))
            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "ActiveSessionsWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
        isLoading = false
    }
}

// MARK: - ActiveSessionsWidget

/// Dashboard widget that shows currently running Claude Code sessions.
///
/// Displays the active session count as a badge in the header, and lists up to
/// three running sessions — each with a green status dot and a trailing chevron
/// to signal tappability.  When more than three active sessions exist, an overflow
/// label such as "+2 more" is shown below the list.  While data loads, skeleton
/// rows shimmer as placeholders.  If no sessions are active, a centred empty-state
/// prompt is shown instead.
///
/// ## Usage
/// ```swift
/// ActiveSessionsWidget(viewModel: vm) { session in
///     navigateTo(session)
/// }
/// ```
struct ActiveSessionsWidget: View {
    /// View model supplying session data and loading state.
    let viewModel: ActiveSessionsWidgetViewModel
    /// Called when the user taps a session row.
    var onSessionSelected: ((ChatSession) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else if viewModel.activeSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.activeSessions.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.entitySession)
                .accessibilityHidden(true)

            Text("Active Sessions")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            if !viewModel.isLoading {
                countBadge
            }
        }
        .padding(.bottom, theme.spacingSM)
    }

    private var countBadge: some View {
        let hasActive = viewModel.activeCount > 0
        return Text("\(viewModel.activeCount)")
            .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(hasActive ? theme.success : theme.textTertiary)
            .clipShape(Capsule())
            .accessibilityLabel("\(viewModel.activeCount) active \(viewModel.activeCount == 1 ? "session" : "sessions")")
    }

    // MARK: - Session List

    private var sessionList: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.activeSessions, id: \.id) { session in
                sessionRow(session)
            }

            if viewModel.activeCount > 3 {
                Text("+\(viewModel.activeCount - 3) more")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, theme.spacingXS)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private func sessionRow(_ session: ChatSession) -> some View {
        Button {
            onSessionSelected?(session)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Active status indicator
                Circle()
                    .fill(theme.success)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(ClaudeModel.displayNameForID(session.model))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.entitySession)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.displayName), \(ClaudeModel.displayNameForID(session.model)), active")
        .accessibilityHint("Opens this session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Active Sessions")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("No active sessions")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonRow
            }
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonRow: some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(theme.bgTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 130, height: 13)

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 70, height: 10)
            }

            Spacer()
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    ActiveSessionsWidget(viewModel: ActiveSessionsWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 200)
        .glassCard()
        .padding()
}
