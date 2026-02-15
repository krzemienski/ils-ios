import SwiftUI
import ILSShared

/// Quick Connect view for connecting to an existing backend server.
/// Extracted from the original ServerSetupSheet with connection mode picker,
/// URL entry, connection steps, health check, and recent connections.
struct QuickConnectView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: any AppTheme

    @State private var selectedMode: ConnectionMode = .local
    @State private var localURL = "http://localhost:9999"
    @State private var remoteHost = ""
    @State private var remotePort = "9999"
    @State private var tunnelURL = ""

    @State private var isConnecting = false
    @State private var connectionSteps: [ConnectionStep] = []
    @State private var showSteps = false
    @State private var connectionResult: ConnectionResult?
    @State private var backendInfo: BackendInfo?
    @State private var showConnectedState = false

    @State private var connectionHistory: [String] = []

    enum ConnectionResult {
        case success
        case failure(String)
    }

    struct BackendInfo {
        let claudeVersion: String
        let status: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                modePicker

                modeContent

                if showSteps {
                    connectionStepsView
                }

                if let result = connectionResult, !showSteps {
                    resultBanner(result)
                }

                if showConnectedState, let info = backendInfo {
                    backendInfoCard(info)
                }

                if !showSteps && !showConnectedState {
                    connectButton
                }

                if !connectionHistory.isEmpty && !showSteps && !showConnectedState {
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
            loadHistory()
            if !appState.serverURL.isEmpty {
                localURL = appState.serverURL
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ConnectionMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, design: theme.fontDesign))
                        Text(mode.rawValue)
                            .font(.system(size: theme.fontCaption, weight: selectedMode == mode ? .semibold : .regular, design: theme.fontDesign))
                    }
                    .foregroundStyle(selectedMode == mode ? theme.textPrimary : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(selectedMode == mode ? theme.accent.opacity(0.15) : Color.clear)
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
        switch selectedMode {
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

            TextField("Server URL", text: $localURL)
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

            HStack(spacing: 12) {
                TextField("Hostname / IP", text: $remoteHost)
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

                TextField("Port", text: $remotePort)
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

            TextField("https://your-tunnel.trycloudflare.com", text: $tunnelURL)
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

            if !tunnelURL.isEmpty && !isValidTunnelURL(tunnelURL) {
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
        ConnectionStepsView(steps: connectionSteps)
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
        Button {
            startConnection()
        } label: {
            if isConnecting {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            } else {
                Text("Connect")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
        .disabled(!isConnectEnabled || isConnecting)
        .accessibilityIdentifier("connect-button")
        .accessibilityLabel("Connect to server")
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Recent")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            ForEach(connectionHistory, id: \.self) { url in
                Button {
                    fillFromHistory(url)
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

    // MARK: - Helpers

    private var isConnectEnabled: Bool {
        switch selectedMode {
        case .local:
            return !localURL.isEmpty
        case .remote:
            return !remoteHost.isEmpty && !remotePort.isEmpty
        case .tunnel:
            return !tunnelURL.isEmpty && isValidTunnelURL(tunnelURL)
        }
    }

    private var resolvedURL: String {
        switch selectedMode {
        case .local:
            return localURL.trimmingCharacters(in: .whitespacesAndNewlines)
        case .remote:
            let host = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let port = remotePort.trimmingCharacters(in: .whitespacesAndNewlines)
            return "http://\(host):\(port)"
        case .tunnel:
            var url = tunnelURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                url = "https://\(url)"
            }
            if url.hasSuffix("/") {
                url = String(url.dropLast())
            }
            return url
        }
    }

    private func isValidTunnelURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("trycloudflare.com") { return true }
        if trimmed.hasPrefix("https://") { return true }
        if trimmed.contains(".") && !trimmed.contains(" ") { return true }

        return false
    }

    private func fillFromHistory(_ url: String) {
        if url.contains("trycloudflare.com") {
            selectedMode = .tunnel
            tunnelURL = url
        } else if url.starts(with: "http://localhost") || url.starts(with: "http://127.0.0.1") {
            selectedMode = .local
            localURL = url
        } else {
            if let urlObj = URL(string: url), let host = urlObj.host {
                selectedMode = .remote
                remoteHost = host
                if let port = urlObj.port {
                    remotePort = String(port)
                }
            } else {
                selectedMode = .local
                localURL = url
            }
        }
    }

    // MARK: - Connection Logic

    private func startConnection() {
        isConnecting = true
        showSteps = true
        connectionResult = nil
        backendInfo = nil
        showConnectedState = false

        connectionSteps = [
            ConnectionStep(id: 0, name: "DNS Resolve", icon: "network", status: .pending),
            ConnectionStep(id: 1, name: "TCP Connect", icon: "cable.connector", status: .pending),
            ConnectionStep(id: 2, name: "Health Check", icon: "heart.fill", status: .pending)
        ]

        Task {
            let url = resolvedURL

            connectionSteps[0].status = .inProgress
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard let urlObj = URL(string: url), urlObj.host != nil else {
                connectionSteps[0].status = .failure("Invalid URL")
                isConnecting = false
                return
            }
            connectionSteps[0].status = .success

            connectionSteps[1].status = .inProgress
            try? await Task.sleep(nanoseconds: 200_000_000)

            let client = APIClient(baseURL: url)
            do {
                _ = try await client.healthCheck()
                connectionSteps[1].status = .success
            } catch {
                connectionSteps[1].status = .failure("Cannot reach server")
                isConnecting = false
                HapticManager.notification(.error)
                return
            }

            connectionSteps[2].status = .inProgress
            try? await Task.sleep(nanoseconds: 200_000_000)

            do {
                let health = try await client.getHealth()
                connectionSteps[2].status = .success

                saveToHistory(url)

                try await appState.connectToServer(url: url)

                HapticManager.notification(.success)

                backendInfo = BackendInfo(
                    claudeVersion: health.claudeVersion ?? "Unknown",
                    status: health.status
                )

                isConnecting = false
                showSteps = false
                showConnectedState = true

                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()

            } catch {
                connectionSteps[2].status = .failure("Health check failed")
                isConnecting = false
                HapticManager.notification(.error)
            }
        }
    }

    // MARK: - History Persistence

    private func loadHistory() {
        connectionHistory = UserDefaults.standard.stringArray(forKey: "connectionHistory") ?? []
    }

    private func saveToHistory(_ url: String) {
        var history = UserDefaults.standard.stringArray(forKey: "connectionHistory") ?? []
        history.removeAll { $0 == url }
        history.insert(url, at: 0)
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        UserDefaults.standard.set(history, forKey: "connectionHistory")
        connectionHistory = history
    }
}
