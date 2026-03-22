import SwiftUI
import ILSShared
import Observation

// MARK: - RecentSessionsWidgetViewModel

/// View model for the Recent Sessions dashboard widget.
///
/// Supplies the five most-recently-active sessions sorted by ``ChatSession/lastActiveAt``
/// descending.  Data is sourced from a shared ``SessionsViewModel`` when available, and
/// falls back to a direct ``APIClient`` fetch when the widget runs standalone.
///
/// ## Topics
/// ### Configuration
/// - ``configure(sessionsVM:)`` - Bind to the shared sessions view model
/// - ``configure(client:)`` - Bind to a direct API client for standalone use
///
/// ### Data
/// - ``recentSessions`` - Up to five most-recently-active sessions
@Observable
@MainActor
final class RecentSessionsWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while the widget is fetching its initial or refreshed data.
    private(set) var isLoading = true
    /// True when the backend is unreachable.
    private(set) var isOffline = false

    // MARK: Data

    /// Up to five sessions sorted by most-recently-active first.
    private(set) var recentSessions: [ChatSession] = []

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

    /// Fetches recent sessions from the shared view model or the API.
    func loadContent() async {
        isLoading = true
        isOffline = false

        if let vm = sessionsVM {
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

    /// Derive the five most-recently-active sessions from an already-loaded sessions VM.
    private func updateFromSessionsVM(_ vm: SessionsViewModel) {
        recentSessions = Array(
            vm.sessions
                .sorted { $0.lastActiveAt > $1.lastActiveAt }
                .prefix(5)
        )
        isLoading = false
    }

    /// Fetch sessions directly from the API and take the five most recent.
    private func fetchFromAPI(client: APIClient) async {
        do {
            let response: APIResponse<PaginatedResponse<ChatSession>> =
                try await client.get("/sessions?page=1&limit=20")
            let all = response.data?.items ?? []
            recentSessions = Array(
                all.sorted { $0.lastActiveAt > $1.lastActiveAt }.prefix(5)
            )
            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "RecentSessionsWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
        isLoading = false
    }
}

// MARK: - RecentSessionsWidget

/// Dashboard widget that lists the five most recently active Claude Code sessions.
///
/// Each row shows the session display name, the Claude model used, and the message count.
/// Sessions are sorted newest-first by their last-active timestamp.  While data loads,
/// skeleton rows shimmer as placeholders.  If no sessions exist, an empty-state prompt
/// encourages the user to start their first session.
///
/// ## Usage
/// ```swift
/// RecentSessionsWidget(viewModel: vm) { session in
///     navigateTo(session)
/// }
/// ```
struct RecentSessionsWidget: View {
    /// View model supplying session data and loading state.
    let viewModel: RecentSessionsWidgetViewModel
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
            } else if viewModel.recentSessions.isEmpty {
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
            Image(systemName: DashboardWidgetType.recentSessions.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.entitySession)
                .accessibilityHidden(true)

            Text("Recent Sessions")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Session List

    private var sessionList: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.recentSessions, id: \.id) { session in
                sessionRow(session)
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
                // Status indicator
                Circle()
                    .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        Text(ClaudeModel.displayNameForID(session.model))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.entitySession)

                        Text("·")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)

                        Text("\(session.messageCount) msgs")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
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
        .accessibilityLabel(
            "\(session.displayName), \(ClaudeModel.displayNameForID(session.model)), \(session.messageCount) messages"
        )
        .accessibilityHint("Opens this session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Recent Sessions")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("No recent sessions")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(0..<5, id: \.self) { _ in
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
                    .frame(width: 140, height: 13)

                HStack(spacing: theme.spacingXS) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 65, height: 10)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 45, height: 10)
                }
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
    RecentSessionsWidget(viewModel: RecentSessionsWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 260)
        .glassCard()
        .padding()
}
