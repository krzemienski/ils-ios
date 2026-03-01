import SwiftUI
import ILSShared

/// The cross-session activity feed timeline.
///
/// Presents all session events in reverse-chronological order, bucketed into Today /
/// Yesterday / Earlier sections. Rapid same-type/same-session bursts are collapsed by
/// ``ActivityFeedViewModel`` and rendered with a "+ N more" footer. A toolbar filter
/// button opens ``ActivityFeedFilterSheet``; a second toolbar button marks all events
/// read. Pull-to-refresh reloads via ``ActivityFeedViewModel/loadEvents(refresh:)``.
/// Polling starts on appear and stops on disappear.
///
/// ## Topics
/// ### Inputs
/// - ``viewModel`` - Shared view model providing event data, grouping, and filter state
/// - ``onSessionSelected`` - Callback invoked (with the session ID) when a row is tapped
///
/// ### View Sections
/// - ``feedContent`` - Grouped list of ``ActivityEventRow`` rows or skeleton placeholders
/// - ``emptyState`` - Shown when the filtered event list is empty
/// - ``loadingState`` - Spinner shown on first load
struct ActivityFeedView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// View model owning all event data and filter state.
    var viewModel: ActivityFeedViewModel
    /// Called when the user taps a row; receives the session ID of the event's origin.
    var onSessionSelected: ((String) -> Void)?

    @State private var showFilterSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                loadingState
            } else if viewModel.groupedEvents.isEmpty {
                emptyState
            } else {
                feedContent
            }
        }
        .navigationTitle("Activity")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Mark-all-read button
                Button {
                    HapticManager.impact(.light)
                    viewModel.markAllRead()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: theme.fontBody, weight: .medium))
                }
                .accessibilityLabel("Mark all events as read")
                .disabled(viewModel.unreadCount == 0)

                // Filter button with active-filter badge
                Button {
                    HapticManager.impact(.light)
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle\(viewModel.isFilterActive ? ".fill" : "")")
                        .font(.system(size: theme.fontBody, weight: .medium))
                        .foregroundStyle(viewModel.isFilterActive ? theme.accent : theme.textPrimary)
                }
                .accessibilityLabel(viewModel.isFilterActive ? "Filter active — tap to change filters" : "Filter events")
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            ActivityFeedFilterSheet(
                filter: viewModel.filter,
                hiddenEventTypes: viewModel.hiddenEventTypes
            ) { newFilter, newHidden in
                viewModel.filter = newFilter
                viewModel.hiddenEventTypes = newHidden
                Task { await viewModel.loadEvents(refresh: true) }
            }
            .environment(\.theme, theme)
        }
        .refreshable {
            HapticManager.impact(.medium)
            await viewModel.loadEvents(refresh: true)
        }
        .onAppear {
            viewModel.configure(client: appState.apiClient)
            viewModel.startPolling()
            viewModel.markAllRead()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Feed Content

    @ViewBuilder
    private var feedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.groupedEvents, id: \.label) { group in
                    Section {
                        ForEach(group.events) { event in
                            ActivityEventRow(event: event) {
                                onSessionSelected?(event.sessionId)
                            }
                            .padding(.horizontal, theme.spacingXS)

                            // Collapsed group indicator
                            if let groupSize = viewModel.collapsedGroupSizes[event.id], groupSize > 1 {
                                collapsedGroupBadge(count: groupSize - 1)
                                    .padding(.horizontal, theme.spacingMD)
                                    .padding(.bottom, theme.spacingXS)
                            }

                            Divider()
                                .overlay(theme.divider)
                                .padding(.leading, theme.spacingMD + 34 + theme.spacingSM)
                        }
                    } header: {
                        sectionHeader(group.label)
                    }
                }
            }
        }
        .background(theme.bgPrimary)
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgPrimary)
    }

    // MARK: - Collapsed Group Badge

    @ViewBuilder
    private func collapsedGroupBadge(count: Int) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "ellipsis")
                .font(.system(size: theme.fontCaption - 1, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Text("+ \(count) more similar events")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.leading, 34 + theme.spacingSM)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()

            Image(systemName: viewModel.isFilterActive ? "line.3.horizontal.decrease.circle" : "bell.slash")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                Text(viewModel.isFilterActive ? "No matching events" : "No activity yet")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(
                    viewModel.isFilterActive
                        ? "Try clearing the filter to see all events"
                        : "Events from your active sessions will appear here"
                )
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
            }

            if viewModel.isFilterActive {
                Button {
                    viewModel.filter = ActivityFeedFilter()
                    viewModel.hiddenEventTypes = []
                    Task { await viewModel.loadEvents(refresh: true) }
                } label: {
                    Text("Clear Filters")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingLG)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .accessibilityLabel("Clear all active filters")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(theme.bgPrimary)
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.textSecondary)
            Text("Loading activity…")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(theme.bgPrimary)
    }
}
