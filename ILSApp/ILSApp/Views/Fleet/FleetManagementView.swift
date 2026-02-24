import SwiftUI
import ILSShared

/// List view for managing fleet backend profiles with live health monitoring.
///
/// Displays all registered ``FleetHost`` entries as tappable rows that navigate to
/// ``FleetHostDetailView``. Each row shows a color-coded health badge that reflects
/// the host's current reachability status. Health polling starts automatically on
/// `onAppear` and stops on `onDisappear` to avoid unnecessary background network
/// activity when the view is not visible.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model managing the host list, active host, and health polling
///
/// ### View Components
/// - ``fleetHostRow(_:)`` - Card row showing host name, address, platform, health badge, and context menu
/// - ``healthBadge(_:)`` - Filled circle indicator colored by health status
/// - ``healthColor(_:)`` - Maps ``FleetHost/HealthStatus`` cases to theme colors
///
/// ### Health Status Colors
/// - `.healthy` → `theme.success` (green)
/// - `.degraded` → `theme.warning` (yellow)
/// - `.unreachable` → `theme.error` (red)
/// - `.unknown` → `theme.textTertiary` (gray)
///
/// ### Context Menu Actions
/// - **Activate** — sets the host as the active backend (hidden when already active)
/// - **Remove** — permanently deletes the host profile (destructive)
struct FleetManagementView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// View model driving host list data, active host selection, and periodic health polling.
    @State private var viewModel = FleetViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                ForEach(viewModel.hosts) { host in
                    NavigationLink {
                        FleetHostDetailView(host: host)
                    } label: {
                        fleetHostRow(host)
                    }
                    .buttonStyle(.plain)
                }

                if let error = viewModel.loadError {
                    VStack(spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(theme.error)
                        Text(error)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadHosts() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                    }
                    .padding(theme.spacingLG)
                }

                if viewModel.hosts.isEmpty && !viewModel.isLoading && viewModel.loadError == nil {
                    EmptyEntityState(
                        entityType: .system,
                        title: "No Backend Profiles",
                        description: "Add a backend profile to connect to a remote ILS host."
                    )
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(theme.accent)
                        .padding(.vertical, theme.spacingLG)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Backend Profiles")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SSHSetupView()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    SSHSetupView()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
            #endif
        }
        .task { await viewModel.loadHosts() }
        .onAppear { viewModel.startHealthPolling() }
        .onDisappear { viewModel.stopHealthPolling() }
    }

    // MARK: - Host Row

    /// Card row for a single fleet host showing its health badge, name, address, platform,
    /// active indicator, and a context menu with activate/remove actions.
    @ViewBuilder
    private func fleetHostRow(_ host: FleetHost) -> some View {
        HStack(spacing: theme.spacingMD) {
            healthBadge(host.healthStatus)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingSM) {
                    Text(host.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    if host.id == viewModel.activeHostId {
                        Text("Active")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(verbatim: "\(host.host):\(host.backendPort)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                if let platform = host.platform {
                    Text(platform)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            Menu {
                if host.id != viewModel.activeHostId {
                    Button { viewModel.activate(host.id) } label: {
                        Label("Activate", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) { viewModel.remove(host.id) } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityLabel("\(host.name), \(host.healthStatus.rawValue)")
    }

    /// Small filled circle indicator whose color reflects the host's current health status.
    @ViewBuilder
    private func healthBadge(_ status: FleetHost.HealthStatus) -> some View {
        Circle()
            .fill(healthColor(status))
            .frame(width: 12, height: 12)
    }

    /// Maps a ``FleetHost/HealthStatus`` value to its corresponding theme color.
    ///
    /// - `.healthy` → `theme.success`
    /// - `.degraded` → `theme.warning`
    /// - `.unreachable` → `theme.error`
    /// - `.unknown` → `theme.textTertiary`
    private func healthColor(_ status: FleetHost.HealthStatus) -> Color {
        switch status {
        case .healthy: return theme.success
        case .degraded: return theme.warning
        case .unreachable: return theme.error
        case .unknown: return theme.textTertiary
        }
    }
}
