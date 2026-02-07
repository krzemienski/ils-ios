import SwiftUI
import ILSShared

// MARK: - Connection Mode

enum ConnectionMode: String, CaseIterable, Identifiable {
    case local = "Local"
    case remote = "Remote"
    case tunnel = "Tunnel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .local: return "desktopcomputer"
        case .remote: return "network"
        case .tunnel: return "globe"
        }
    }
}

// MARK: - ServerSetupSheet

struct ServerSetupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: ConnectionMode = .local
    @State private var localURL = "http://localhost:9090"
    @State private var remoteHost = ""
    @State private var remotePort = "9090"
    @State private var tunnelURL = ""

    @State private var isConnecting = false
    @State private var connectionSteps: [ConnectionStep] = []
    @State private var showSteps = false
    @State private var connectionResult: ConnectionResult?
    @State private var backendInfo: BackendInfo?
    @State private var showConnectedState = false

    // Connection history
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    brandingHeader

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
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(ILSTheme.background)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            loadHistory()
            if !appState.serverURL.isEmpty {
                localURL = appState.serverURL
            }
        }
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(ILSTheme.largeTitleFont) // Decorative icon, Dynamic Type compatible
                .foregroundStyle(
                    LinearGradient(
                        colors: [ILSTheme.accent, ILSTheme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Welcome to ILS")
                .font(ILSTheme.title2Font)
                .foregroundColor(ILSTheme.primaryText)

            Text("Connect to your backend server to get started.")
                .font(ILSTheme.bodyFont)
                .foregroundColor(ILSTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Connection Mode", selection: $selectedMode) {
            ForEach(ConnectionMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Local Server")
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.primaryText)

            Text("Connect to a backend running on this device or your local network.")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)

            TextField("Server URL", text: $localURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("server-url-field")
        }
        .padding(16)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusMedium)
    }

    private var remoteModeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remote Server")
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.primaryText)

            Text("Enter the hostname or IP address of your remote server.")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)

            HStack(spacing: 12) {
                TextField("Hostname / IP", text: $remoteHost)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("remote-host-field")

                TextField("Port", text: $remotePort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .accessibilityIdentifier("remote-port-field")
            }
        }
        .padding(16)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusMedium)
    }

    private var tunnelModeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cloudflare Tunnel")
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.primaryText)

            Text("Paste your Cloudflare tunnel URL (trycloudflare.com or custom domain).")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)

            TextField("https://your-tunnel.trycloudflare.com", text: $tunnelURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("tunnel-url-field")

            if !tunnelURL.isEmpty && !isValidTunnelURL(tunnelURL) {
                Label("Enter a valid URL (trycloudflare.com or https://)", systemImage: "exclamationmark.triangle.fill")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.warning)
            }
        }
        .padding(16)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusMedium)
    }

    // MARK: - Connection Steps View

    private var connectionStepsView: some View {
        ConnectionStepsView(steps: connectionSteps)
            .padding(16)
            .background(ILSTheme.secondaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusMedium)
    }

    // MARK: - Result Banner

    private func resultBanner(_ result: ConnectionResult) -> some View {
        Group {
            switch result {
            case .success:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundColor(ILSTheme.success)
                    .font(ILSTheme.bodyFont)
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundColor(ILSTheme.error)
                    .font(ILSTheme.captionFont)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Backend Info Card

    private func backendInfoCard(_ info: BackendInfo) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(ILSTheme.largeTitleFont) // Decorative icon, Dynamic Type compatible
                .foregroundColor(ILSTheme.success)

            Text("Connected")
                .font(ILSTheme.title3Font)
                .foregroundColor(ILSTheme.primaryText)

            VStack(spacing: 6) {
                if !info.claudeVersion.isEmpty {
                    HStack {
                        Text("Claude CLI")
                            .foregroundColor(ILSTheme.secondaryText)
                        Spacer()
                        Text(info.claudeVersion)
                            .foregroundColor(ILSTheme.primaryText)
                    }
                    .font(ILSTheme.captionFont)
                }

                HStack {
                    Text("Status")
                        .foregroundColor(ILSTheme.secondaryText)
                    Spacer()
                    Text(info.status)
                        .foregroundColor(ILSTheme.success)
                }
                .font(ILSTheme.captionFont)
            }
            .padding(12)
            .background(ILSTheme.tertiaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusSmall)
        }
        .padding(16)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusMedium)
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
                    .font(ILSTheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(ILSTheme.accent)
        .disabled(!isConnectEnabled || isConnecting)
        .accessibilityIdentifier("connect-button")
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(ILSTheme.headlineFont)
                .foregroundColor(ILSTheme.secondaryText)

            ForEach(connectionHistory, id: \.self) { url in
                Button {
                    fillFromHistory(url)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(ILSTheme.tertiaryText)
                            .font(.caption)
                        Text(url)
                            .font(ILSTheme.bodyFont)
                            .foregroundColor(ILSTheme.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(ILSTheme.tertiaryText)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
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
            // Remove trailing slash
            if url.hasSuffix("/") {
                url = String(url.dropLast())
            }
            return url
        }
    }

    private func isValidTunnelURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Accept trycloudflare.com URLs
        if trimmed.contains("trycloudflare.com") { return true }

        // Accept any https:// URL as a custom domain
        if trimmed.hasPrefix("https://") { return true }

        // Accept bare domains (will prepend https://)
        if trimmed.contains(".") && !trimmed.contains(" ") { return true }

        return false
    }

    private func fillFromHistory(_ url: String) {
        // Detect the mode from the URL and fill appropriately
        if url.contains("trycloudflare.com") {
            selectedMode = .tunnel
            tunnelURL = url
        } else if url.starts(with: "http://localhost") || url.starts(with: "http://127.0.0.1") {
            selectedMode = .local
            localURL = url
        } else {
            // Try to parse as remote host:port
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
            ConnectionStep(id: 2, name: "Health Check", icon: "heart.fill", status: .pending),
        ]

        Task {
            let url = resolvedURL

            // Step 1: DNS Resolve (validate URL host)
            connectionSteps[0].status = .inProgress
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard let urlObj = URL(string: url), urlObj.host != nil else {
                connectionSteps[0].status = .failure("Invalid URL")
                isConnecting = false
                return
            }
            connectionSteps[0].status = .success

            // Step 2: TCP Connect (attempt connection)
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

            // Step 3: Health Check (verify backend responds correctly)
            connectionSteps[2].status = .inProgress
            try? await Task.sleep(nanoseconds: 200_000_000)

            do {
                let health = try await client.getHealth()
                connectionSteps[2].status = .success

                // Save to history
                saveToHistory(url)

                // Connect via AppState
                try await appState.connectToServer(url: url)

                HapticManager.notification(.success)

                backendInfo = BackendInfo(
                    claudeVersion: health.claudeVersion ?? "Unknown",
                    status: health.status
                )

                isConnecting = false
                showSteps = false
                showConnectedState = true

                // Auto-dismiss after 1.5s
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
        // Remove if already exists (move to top)
        history.removeAll { $0 == url }
        // Insert at front
        history.insert(url, at: 0)
        // Keep only last 5
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        UserDefaults.standard.set(history, forKey: "connectionHistory")
        connectionHistory = history
    }
}

