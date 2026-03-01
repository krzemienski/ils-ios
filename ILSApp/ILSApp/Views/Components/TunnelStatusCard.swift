import SwiftUI
import ILSShared

/// Compact dashboard card displaying Cloudflare tunnel status with a Start/Stop toggle.
///
/// Shows the tunnel's current connection state (connected, connecting, disconnected, error)
/// with a colour-coded status dot, the active tunnel URL (or a brief status subtitle), and
/// a single-tap Start/Stop button. Tapping the card body navigates to ``TunnelSettingsView``
/// for full configuration and monitoring details.
///
/// The card owns its own ``TunnelSettingsViewModel`` instance, starts status polling when
/// it appears, and stops polling when it disappears to avoid unnecessary background work.
///
/// ## Usage
/// Drop `TunnelStatusCard` into any view that lives inside a `NavigationStack` or
/// `NavigationSplitView`:
///
/// ```swift
/// TunnelStatusCard()
///     .environment(appState)
/// ```
struct TunnelStatusCard: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = TunnelSettingsViewModel()

    var body: some View {
        NavigationLink {
            TunnelSettingsView()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.fetchStatus()
            viewModel.startStatusPolling()
        }
        .onDisappear {
            viewModel.stopStatusPolling()
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: theme.spacingMD) {
            // Status icon
            Image(systemName: "network")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.info)
                .frame(width: 28, height: 28)
                .background(theme.info.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text("Remote Access")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusSubtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tunnel status: \(statusSubtitle)")
            }

            Spacer()

            // Start / Stop button — uses a plain button inside the NavigationLink label
            // to intercept the tap without triggering navigation.
            Button {
                Task {
                    if viewModel.isRunning {
                        await viewModel.stopTunnel()
                    } else {
                        await viewModel.startTunnel()
                    }
                }
            } label: {
                if viewModel.isToggling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .tint(theme.textSecondary)
                        .frame(width: 60, height: 28)
                } else {
                    Text(viewModel.isRunning ? "Stop" : "Start")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(viewModel.isRunning ? theme.error : theme.success)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            (viewModel.isRunning ? theme.error : theme.success).opacity(0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
            .accessibilityLabel(viewModel.isRunning ? "Stop tunnel" : "Start tunnel")
            .disabled(viewModel.isLoading || viewModel.isToggling)

            Image(systemName: "chevron.right")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return theme.success
        case .connecting, .reconnecting:
            return theme.warning
        case .disconnected:
            return theme.textTertiary
        case .error:
            return theme.error
        }
    }

    private var statusSubtitle: String {
        switch viewModel.connectionState {
        case .connected:
            return viewModel.tunnelURL ?? "Connected"
        case .connecting:
            return "Connecting…"
        case .reconnecting:
            return "Reconnecting…"
        case .disconnected:
            return "Not running"
        case .error:
            return viewModel.errorMessage ?? "Error"
        }
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 16) {
            TunnelStatusCard()
        }
        .padding()
    }
    .environment(AppState())
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
