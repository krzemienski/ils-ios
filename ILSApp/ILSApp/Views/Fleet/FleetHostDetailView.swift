import SwiftUI
import ILSShared

/// Detail view for an individual fleet host, presenting a four-section scrollable layout.
///
/// Displays comprehensive information about a remote ``FleetHost`` including connection details,
/// live health status, lifecycle controls, and a scrollable log viewer. Lifecycle operations
/// (start, stop, restart) are dispatched as async POST requests to the fleet API. Log lines
/// are fetched on appearance and can be manually refreshed via the refresh button in the log
/// section header. Optional fields — SSH username, platform, and auth method — are shown
/// conditionally when present on the host model.
///
/// ## Topics
/// ### State
/// - ``host`` - The fleet host being presented
/// - ``logs`` - Log lines fetched from the remote host
/// - ``isLoadingLogs`` - Whether a log fetch is in progress
///
/// ### View Sections
/// - ``hostInfoSection`` - Address, backend port, and optional SSH username/platform/auth
/// - ``healthSection`` - Color-coded health status with last-check timestamp
/// - ``lifecycleSection`` - Start, stop, and restart buttons wired to async API calls
/// - ``logSection`` - Scrollable log viewer with inline refresh control
///
/// ### Actions
/// - ``performLifecycle(_:)`` - POSTs a ``LifecycleRequest`` to `/fleet/{id}/lifecycle`
/// - ``loadLogs()`` - GETs log lines from `/fleet/{id}/logs` and populates ``logs``
struct FleetHostDetailView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// The fleet host whose details this view presents.
    let host: FleetHost

    /// Log lines fetched from the remote host's log endpoint.
    @State private var logs: [String] = []
    /// Whether a log fetch request is currently in flight.
    @State private var isLoadingLogs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                hostInfoSection
                healthSection
                lifecycleSection
                logSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle(host.name)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task { await loadLogs() }
    }

    // MARK: - Host Info Section

    @ViewBuilder
    private var hostInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Host Info")
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                infoRow("Address", value: "\(host.host):\(host.port)")
                infoRow("Backend Port", value: String(host.backendPort))
                if let username = host.username {
                    infoRow("SSH User", value: username)
                }
                if let platform = host.platform {
                    infoRow("Platform", value: platform)
                }
                if let authMethod = host.authMethod {
                    infoRow("Auth", value: authMethod.rawValue)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Health Section

    @ViewBuilder
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Health")
            HStack {
                Circle()
                    .fill(healthColor(host.healthStatus))
                    .frame(width: 12, height: 12)
                Text(host.healthStatus.rawValue.capitalized)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if let lastCheck = host.lastHealthCheck {
                    Text("Last: \(lastCheck, style: .relative)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Lifecycle Section

    @ViewBuilder
    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Lifecycle")
            HStack(spacing: theme.spacingSM) {
                lifecycleButton("Start", icon: "play.fill", color: theme.success, action: .start)
                lifecycleButton("Stop", icon: "stop.fill", color: theme.error, action: .stop)
                lifecycleButton("Restart", icon: "arrow.clockwise", color: theme.warning, action: .restart)
            }
        }
    }

    @ViewBuilder
    private func lifecycleButton(_ title: String, icon: String, color: Color, action: LifecycleRequest.LifecycleAction) -> some View {
        Button {
            Task { await performLifecycle(action) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, design: theme.fontDesign))
                Text(title)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) backend on \(host.name)")
    }

    // MARK: - Log Section

    @ViewBuilder
    private var logSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Logs")
                Spacer()
                if isLoadingLogs {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.accent)
                }
                Button {
                    Task { await loadLogs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Refresh logs")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if logs.isEmpty {
                        Text("No logs available")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.vertical, theme.spacingSM)
                    } else {
                        // SPERF-MED-6: Use indices for stable ForEach identity.
                        ForEach(logs.indices, id: \.self) { index in
                            Text(logs[index])
                                .font(.system(size: 11, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }

    @ViewBuilder
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func healthColor(_ status: FleetHost.HealthStatus) -> Color {
        switch status {
        case .healthy: return theme.success
        case .degraded: return theme.warning
        case .unreachable: return theme.error
        case .unknown: return theme.textTertiary
        }
    }

    private func performLifecycle(_ action: LifecycleRequest.LifecycleAction) async {
        let request = LifecycleRequest(action: action, hostId: host.id)
        let _: LifecycleResponse? = try? await appState.apiClient.post("/fleet/\(host.id)/lifecycle", body: request)
    }

    private func loadLogs() async {
        isLoadingLogs = true
        defer { isLoadingLogs = false }
        if let response: RemoteLogsResponse = try? await appState.apiClient.get("/fleet/\(host.id)/logs") {
            logs = response.lines
        }
    }
}
