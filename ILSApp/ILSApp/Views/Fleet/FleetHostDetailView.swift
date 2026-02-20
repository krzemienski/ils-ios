import SwiftUI
import ILSShared

struct FleetHostDetailView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    let host: FleetHost

    @State private var logs: [String] = []
    @State private var isLoadingLogs = false
    @State private var actionError: String?

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
                infoRow("Address", value: "\(host.host):\(String(host.port))")
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
                Image(systemName: healthIcon(host.healthStatus))
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(healthColor(host.healthStatus))
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
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if logs.isEmpty {
                        Text("No logs available")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.vertical, theme.spacingSM)
                    } else {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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

    private func healthIcon(_ status: FleetHost.HealthStatus) -> String {
        switch status {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unreachable: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
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
        do {
            let _: LifecycleResponse = try await appState.apiClient.post("/fleet/\(host.id)/lifecycle", body: request)
            actionError = nil
        } catch {
            AppLogger.shared.error("Lifecycle \(action) failed for \(host.name): \(error)", category: "hosts")
            actionError = "Lifecycle action failed: \(error.localizedDescription)"
        }
    }

    private func loadLogs() async {
        isLoadingLogs = true
        defer { isLoadingLogs = false }
        do {
            let response: RemoteLogsResponse = try await appState.apiClient.get("/fleet/\(host.id)/logs")
            logs = response.lines
        } catch {
            AppLogger.shared.error("Failed to load logs for \(host.name): \(error)", category: "hosts")
            actionError = "Failed to load logs: \(error.localizedDescription)"
        }
    }
}
