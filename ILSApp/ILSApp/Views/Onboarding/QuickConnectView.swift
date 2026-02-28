import SwiftUI
import ILSShared

/// Quick connect view for joining an existing backend server without SSH setup.
///
/// Presents a segmented mode picker (Local / Remote / Tunnel) and renders
/// the appropriate input fields for each connection type. On connect it runs
/// a health-check via ``QuickConnectViewModel`` and shows step-by-step progress,
/// a success banner, or an error label. Recent connections are persisted and
/// listed below the form for one-tap reuse.
///
/// ## Topics
/// ### Connection Modes
/// - ``modePicker`` - Segmented control switching between Local, Remote, and Tunnel
/// - ``modeContent`` - Input fields rendered for the active ``ConnectionMode``
///
/// ### Feedback
/// - ``connectionStepsView`` - Live progress steps during the health check
/// - ``resultBanner(_:)`` - Success or failure banner shown after the attempt
/// - ``backendInfoCard(_:)`` - Connected-state card displaying backend metadata
///
/// ### Actions
/// - ``connectButton`` - Triggers the connection attempt via the view model
/// - ``recentSection`` - Scrollable list of recently used server URLs
struct QuickConnectView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = QuickConnectViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                modePicker

                modeContent

                if viewModel.showSteps {
                    connectionStepsView
                }

                if let result = viewModel.connectionResult, !viewModel.showSteps {
                    resultBanner(result)
                }

                if viewModel.showConnectedState, let info = viewModel.backendInfo {
                    backendInfoCard(info)
                }

                if !viewModel.showSteps && !viewModel.showConnectedState {
                    connectButton
                }

                if !viewModel.connectionHistory.isEmpty && !viewModel.showSteps && !viewModel.showConnectedState {
                    recentSection
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, theme.spacingXL)
            .padding(.top, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Quick Connect")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .onAppear {
            viewModel.loadHistory()
            if !appState.serverURL.isEmpty {
                viewModel.localURL = appState.serverURL
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ConnectionMode.allCases) { mode in
                Button {
                    viewModel.selectedMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, design: theme.fontDesign))
                        Text(mode.rawValue)
                            .font(.system(size: theme.fontCaption, weight: viewModel.selectedMode == mode ? .semibold : .regular, design: theme.fontDesign))
                    }
                    .foregroundStyle(viewModel.selectedMode == mode ? theme.textPrimary : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(viewModel.selectedMode == mode ? theme.accent.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .padding(.vertical, 4)
        .accessibilityLabel("Connection mode")
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch viewModel.selectedMode {
        case .local:
            localModeView
        case .remote:
            remoteModeView
        case .tunnel:
            tunnelModeView
        }
    }

    private var localModeView: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Local Server")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            Text("Connect to a backend running on this device or your local network.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            @Bindable var vm = viewModel
            TextField("Server URL", text: $vm.localURL)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityIdentifier("server-url-field")
                .accessibilityLabel("Server URL")
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    private var remoteModeView: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Remote Server")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            Text("Enter the hostname or IP address of your remote server.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            @Bindable var vm = viewModel
            HStack(spacing: 12) {
                TextField("Hostname / IP", text: $vm.remoteHost)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                    .accessibilityIdentifier("remote-host-field")
                    .accessibilityLabel("Remote hostname or IP address")

                TextField("Port", text: $vm.remotePort)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .frame(width: 80)
                    .accessibilityIdentifier("remote-port-field")
                    .accessibilityLabel("Port number")
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    private var tunnelModeView: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Cloudflare Tunnel")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            Text("Paste your Cloudflare tunnel URL (trycloudflare.com or custom domain).")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            @Bindable var vm = viewModel
            TextField("https://your-tunnel.trycloudflare.com", text: $vm.tunnelURL)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityIdentifier("tunnel-url-field")
                .accessibilityLabel("Cloudflare tunnel URL")

            if !viewModel.tunnelURL.isEmpty && !viewModel.isValidTunnelURL(viewModel.tunnelURL) {
                Label("Enter a valid URL (trycloudflare.com or https://)", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundColor(theme.warning)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Connection Steps View

    private var connectionStepsView: some View {
        ConnectionStepsView(steps: viewModel.connectionSteps)
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Result Banner

    private func resultBanner(_ result: ConnectionResult) -> some View {
        Group {
            switch result {
            case .success:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundColor(theme.success)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundColor(theme.error)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Backend Info Card

    private func backendInfoCard(_ info: BackendInfo) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(theme.success)

            Text("Connected")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            VStack(spacing: 6) {
                if !info.claudeVersion.isEmpty {
                    HStack {
                        Text("Claude CLI")
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text(info.claudeVersion)
                            .foregroundColor(theme.textPrimary)
                    }
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }

                HStack {
                    Text("Status")
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(info.status)
                        .foregroundColor(theme.success)
                }
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .padding(12)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        AccentButton("Connect", isLoading: viewModel.isConnecting) {
            Task {
                let success = await viewModel.connect(appState: appState)
                if success {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        }
        .disabled(!viewModel.isConnectEnabled)
        .accessibilityIdentifier("connect-button")
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Recent")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            ForEach(viewModel.connectionHistory, id: \.self) { url in
                Button {
                    viewModel.fillFromHistory(url)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(theme.textTertiary)
                            .font(.caption)
                        Text(url)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(theme.textTertiary)
                            .font(.caption)
                    }
                    .padding(.vertical, theme.spacingSM)
                    .padding(.horizontal, theme.spacingSM)
                    .background(theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
        }
    }
}
