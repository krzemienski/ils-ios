import SwiftUI
import ILSShared

/// Unified session list aggregating sessions from all configured backends.
///
/// Fetches sessions concurrently from every registered backend via
/// ``UnifiedSessionsViewModel``, displays them grouped by recency
/// (Today → Yesterday → This Week → Earlier), and annotates each row with a
/// color-coded backend source pill showing which backend the session came from.
///
/// A search bar filters across all backends simultaneously — typing a backend name
/// (e.g., "Work Mac") will narrow results to only sessions from that backend.
/// Backends that fail to load are surfaced in a warning banner below the search bar.
///
/// ## Topics
/// ### View Sections
/// - ``searchBar`` - Themed search field filtering all backends simultaneously
/// - ``backendErrorBanner`` - Compact warning bar listing unreachable backends
/// - ``timeGroup(label:sessions:)`` - Section header and rows for a time period
/// - ``unifiedSessionRow(_:)`` - Session row with status dot, metadata, and backend pill
/// - ``backendPill(_:)`` - Color-tinted backend source label
/// - ``loadingView`` - Shimmer skeleton shown while sessions are loading
/// - ``emptyView`` - Empty state with CTA to add a backend when none are configured
///
/// ### Callbacks
/// - ``onSessionSelected`` - Invoked when the user taps a session row; wired in the
///   integration phase (subtask 5-2)
///
/// Time groups are ordered: Today → Yesterday → This Week → Earlier.
struct UnifiedSessionsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called when the user selects a session. Wired by the parent navigation layer.
    var onSessionSelected: ((TaggedSession) -> Void)?

    @State private var viewModel = UnifiedSessionsViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with total count
            HStack {
                Text("ALL SESSIONS")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(viewModel.sessions.count)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Search bar — filters all backends simultaneously
            searchBar

            // Cache freshness indicator
            HStack {
                Spacer()
                CacheStatusView(lastUpdated: viewModel.lastUpdated)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Per-backend failure warning banner
            if !viewModel.backendErrors.isEmpty {
                backendErrorBanner
            }

            // Session list with time-grouped sections
            List {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    loadingView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else if viewModel.filteredSessions.isEmpty {
                    emptyView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
                } else {
                    ForEach(viewModel.groupedSessionsByTime, id: \.key) { label, sessions in
                        timeGroup(label: label, sessions: sessions)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .refreshable {
                HapticManager.impact(.medium)
                await viewModel.loadSessions(refresh: true)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("All Sessions")
        .inlineNavigationBarTitle()
        .task {
            await viewModel.loadSessions()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search all backends...", text: $viewModel.searchText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .accessibilityLabel("Search all sessions")
                .focused($isSearchFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: isSearchFocused, cornerRadius: theme.cornerRadiusSmall)
        .padding(.horizontal, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Backend Error Banner

    /// Compact warning bar shown when one or more backends fail to load sessions.
    private var backendErrorBanner: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.warning)
            let failedCount = viewModel.backendErrors.count
            Text(failedCount == 1 ? "1 backend unavailable" : "\(failedCount) backends unavailable")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.warning.opacity(0.08))
        .accessibilityLabel("\(viewModel.backendErrors.count) backends unavailable")
    }

    // MARK: - Time Group

    @ViewBuilder
    private func timeGroup(label: String, sessions: [TaggedSession]) -> some View {
        Section {
            ForEach(sessions) { tagged in
                unifiedSessionRow(tagged)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: theme.spacingSM, bottom: 0, trailing: theme.spacingSM))
            }
        } header: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "calendar")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text(label.uppercased())
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgPrimary)
        }
    }

    // MARK: - Unified Session Row

    /// Session row combining a status dot, name/project/time metadata, and a backend color pill.
    @ViewBuilder
    private func unifiedSessionRow(_ tagged: TaggedSession) -> some View {
        let session = tagged.session
        Button {
            HapticManager.selection()
            onSessionSelected?(tagged)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Status indicator dot
                Circle()
                    .fill(statusColor(for: session.status))
                    .frame(width: 6, height: 6)

                // Session metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let projectName = session.projectName, !projectName.isEmpty {
                        Text(projectName)
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Text(DateFormatters.relativeDateTime.localizedString(
                        for: session.lastActiveAt,
                        relativeTo: Date()
                    ))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                // Backend source pill
                backendPill(tagged)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("\(session.displayName), from \(tagged.backendName)")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Backend Pill

    /// Small rounded-rectangle badge showing the originating backend with its assigned color tint.
    ///
    /// Background uses the backend color at 20% opacity; foreground text uses full backend color.
    /// Backend name is capped at 10 characters to prevent overflow in narrow rows.
    private func backendPill(_ tagged: TaggedSession) -> some View {
        let pillColor = Color(hex: tagged.backendColorHex)
        return Text(String(tagged.backendName.prefix(10)))
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(pillColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    // MARK: - Loading State

    /// Shimmer skeleton placeholder shown while sessions are loading for the first time.
    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(theme.bgTertiary)
                        .frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 120, height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 70, height: 9)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.bgTertiary)
                        .frame(width: 50, height: 18)
                }
                .padding(.vertical, theme.spacingXS)
                .padding(.horizontal, theme.spacingSM)
            }
            .shimmer()
        }
        .padding(.vertical, theme.spacingSM)
    }

    // MARK: - Empty State

    /// Empty state shown when no sessions are available.
    ///
    /// When no backends are configured, displays ``EmptyEntityState`` with a "Add a Backend"
    /// call-to-action. Otherwise shows a simple "No sessions" message.
    private var emptyView: some View {
        Group {
            if !viewModel.isLoading && BackendManager.shared.backends.isEmpty {
                EmptyEntityState(
                    entityType: .sessions,
                    title: "No Backends",
                    description: "Add a backend connection to see sessions from your development machines.",
                    actionTitle: "Add a Backend"
                ) {
                    // Navigation to AddBackendView is wired in the integration phase (subtask 5-2)
                }
            } else {
                VStack(spacing: theme.spacingSM) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 24, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text(viewModel.searchText.isEmpty ? "No sessions found" : "No matching sessions")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingLG)
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:    return theme.entitySession
        case .completed: return theme.success
        case .cancelled: return theme.warning
        case .error:     return theme.error
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UnifiedSessionsView()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
