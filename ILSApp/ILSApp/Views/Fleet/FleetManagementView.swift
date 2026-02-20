import SwiftUI
import ILSShared

struct FleetManagementView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = FleetViewModel()

    var body: some View {
        ScrollView {
            hostListContent
        }
        .background(theme.bgPrimary)
        .navigationTitle("Hosts")
        .inlineNavigationBarTitle()
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.startHealthPolling()
            } else {
                viewModel.stopHealthPolling()
            }
        }
    }

    @ViewBuilder
    private var hostListContent: some View {
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

            if let autoError = viewModel.autoRegisterError {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.warning)
                    Text(autoError)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }

            if viewModel.hosts.isEmpty && !viewModel.isLoading && viewModel.loadError == nil {
                EmptyEntityState(
                    entityType: .system,
                    title: "No Hosts",
                    description: "Register a remote host to get started."
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

    // MARK: - Host Row

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
                Text("\(host.host):\(String(host.backendPort))")
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

    @ViewBuilder
    private func healthBadge(_ status: FleetHost.HealthStatus) -> some View {
        Image(systemName: healthIcon(status))
            .font(.system(size: theme.fontCaption))
            .foregroundStyle(healthColor(status))
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
}
