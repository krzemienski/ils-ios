import SwiftUI
import ILSShared

struct HostProfilesView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel = HostProfilesViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                ForEach(viewModel.hosts) { host in
                    NavigationLink {
                        HostProfileDetailView(host: host)
                    } label: {
                        hostProfileRow(host)
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
                        title: "No Host Profiles",
                        description: "Add a host profile to connect to a remote ILS backend."
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
        .navigationTitle("Host Profiles")
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

    @ViewBuilder
    private func hostProfileRow(_ host: FleetHost) -> some View {
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

    @ViewBuilder
    private func healthBadge(_ status: FleetHost.HealthStatus) -> some View {
        Circle()
            .fill(healthColor(status))
            .frame(width: 12, height: 12)
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
