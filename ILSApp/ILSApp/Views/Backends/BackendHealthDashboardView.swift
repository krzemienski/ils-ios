import SwiftUI
import ILSShared

/// Health dashboard showing all registered backends in a 2-column grid with status indicators.
///
/// Each card in the grid displays a large health-colored circle, the backend's name, truncated
/// URL, human-readable status label, and relative time since the last health check. When all
/// backends report a healthy status, an all-clear banner card appears at the top of the grid.
/// An empty state is shown with a link to ``BackendConnectionsView`` when no backends exist.
/// A refresh toolbar button triggers an immediate single poll via ``BackendConnectionsViewModel/pollNow()``.
///
/// ## Topics
/// ### View Components
/// - ``healthCard(_:lastChecked:)`` - Individual 2-column card for one backend
/// - ``allHealthyBanner`` - Green banner shown when every backend is healthy
/// - ``emptyState`` - Placeholder with navigation link when no backends are registered
///
/// ### Helpers
/// - ``healthColor(_:)`` - Maps ``BackendConnection/HealthStatus`` to a theme color
/// - ``statusLabel(_:)`` - Human-readable label for each health status case
/// - ``relativeTimeLabel(_:)`` - Relative timestamp string ('Just now', '2 min ago', etc.)
struct BackendHealthDashboardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = BackendConnectionsViewModel()
    /// Whether a manual refresh is currently in progress.
    @State private var isRefreshing = false
    /// Timestamp of the most recent completed health poll, used to render relative time labels.
    @State private var lastCheckedAt: Date?

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: theme.spacingMD) {
                if viewModel.backends.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    if allBackendsHealthy {
                        allHealthyBanner
                            .gridCellColumns(2)
                    }

                    ForEach(viewModel.backends) { backend in
                        healthCard(backend, lastChecked: lastCheckedAt)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(theme.accent)
                            .padding(.vertical, theme.spacingLG)
                            .gridCellColumns(2)
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
            .padding(.bottom, theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Health Dashboard")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .tint(theme.accent)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(theme.accent)
                    }
                }
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh health status")
            }
        }
        .task {
            await viewModel.loadBackends()
            await refresh()
            // Do NOT start/stop global health polling here; that is managed
            // exclusively by AppState.handleScenePhase to avoid lifecycle conflicts.
        }
    }

    // MARK: - Computed

    /// True when every registered backend has a `.healthy` status and the list is non-empty.
    private var allBackendsHealthy: Bool {
        !viewModel.backends.isEmpty
            && viewModel.backends.allSatisfy { $0.healthStatus == .healthy }
    }

    // MARK: - All-Healthy Banner

    /// Full-width banner shown when all backends are reporting healthy status.
    @ViewBuilder
    private var allHealthyBanner: some View {
        HStack(spacing: theme.spacingMD) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: theme.fontTitle1, weight: .semibold))
                .foregroundStyle(theme.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("All Systems Healthy")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("\(viewModel.backends.count) backend\(viewModel.backends.count == 1 ? "" : "s") online")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .background(theme.success.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.success.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityLabel("All \(viewModel.backends.count) backends are healthy")
    }

    // MARK: - Empty State

    /// Full-width empty state card shown when no backends have been registered.
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "server.rack")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                Text("No Backends Configured")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Add a backend connection to monitor its health status here.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink {
                BackendConnectionsView()
            } label: {
                Text("Add Backend")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Navigate to add a backend connection")
        }
        .padding(theme.spacingLG)
        .frame(maxWidth: .infinity)
        .modifier(GlassCard())
        .gridCellColumns(2)
    }

    // MARK: - Health Card

    /// Individual card cell in the 2-column grid showing one backend's health information.
    ///
    /// - Parameters:
    ///   - backend: The backend connection whose status is displayed.
    ///   - lastChecked: Optional timestamp of the most recent health poll.
    @ViewBuilder
    private func healthCard(_ backend: BackendConnection, lastChecked: Date?) -> some View {
        VStack(spacing: theme.spacingSM) {
            // Large health-colored circle indicator
            Circle()
                .fill(healthColor(backend.healthStatus))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(healthColor(backend.healthStatus).opacity(0.3), lineWidth: 3)
                        .scaleEffect(1.3)
                )
                .padding(.bottom, 2)

            // Backend name
            Text(backend.name)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            // URL (truncated)
            Text(verbatim: backend.url)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            // Status label
            Text(statusLabel(backend.healthStatus))
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(healthColor(backend.healthStatus))

            // Last checked relative time
            Text(relativeTimeLabel(lastChecked))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity)
        .modifier(GlassCard())
        .accessibilityLabel(
            "\(backend.name), \(statusLabel(backend.healthStatus)), last checked \(relativeTimeLabel(lastChecked))"
        )
    }

    // MARK: - Health Helpers

    /// Maps a ``BackendConnection/HealthStatus`` value to its corresponding theme color.
    private func healthColor(_ status: BackendConnection.HealthStatus) -> Color {
        switch status {
        case .healthy:     return theme.success
        case .degraded:    return theme.warning
        case .unreachable: return theme.error
        case .unknown:     return theme.textTertiary
        }
    }

    /// Returns a human-readable status label for display in the card.
    private func statusLabel(_ status: BackendConnection.HealthStatus) -> String {
        switch status {
        case .healthy:     return "Healthy"
        case .degraded:    return "Degraded"
        case .unreachable: return "Unreachable"
        case .unknown:     return "Unknown"
        }
    }

    /// Converts a timestamp into a concise relative time string.
    ///
    /// - Returns: "Just now" (< 60 s), "N min ago" (< 1 h), "N hr ago" (≥ 1 h),
    ///            or "Not checked" when `date` is `nil`.
    private func relativeTimeLabel(_ date: Date?) -> String {
        guard let date else { return "Not checked" }
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "Just now" }
        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = Int(elapsed / 3600)
        return "\(hours) hr ago"
    }

    // MARK: - Refresh

    /// Fires an immediate health poll on all backends and records the timestamp.
    private func refresh() async {
        isRefreshing = true
        HapticManager.impact(.light)
        await viewModel.pollNow()
        lastCheckedAt = Date()
        isRefreshing = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackendHealthDashboardView()
    }
}
