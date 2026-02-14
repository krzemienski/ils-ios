import SwiftUI
import ILSShared

struct SSHSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = SetupViewModel()
    @StateObject private var sshViewModel = SSHViewModel()

    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: ServerConnection.AuthMethod = .password
    @State private var credential = ""
    @State private var backendPort = "9999"

    @State private var isSettingUp = false
    @State private var platformRejected = false
    @State private var rejectionMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                credentialForm
                if isSettingUp || !viewModel.steps.isEmpty {
                    setupProgressView
                }
                if platformRejected {
                    rejectionBanner
                }
                if let setupError = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.error)
                        Text(setupError)
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(theme.spacingMD)
                    .background(theme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                if !isSettingUp {
                    connectAndSetupButton
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("SSH Setup")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }

    // MARK: - Credential Form

    @ViewBuilder
    private var credentialForm: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Connection")

            VStack(spacing: theme.spacingSM) {
                HStack {
                    iconTextField("Host", text: $host, icon: "server.rack")
                    iconTextField("Port", text: $port, icon: "number")
                        .frame(width: 80)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                iconTextField("Username", text: $username, icon: "person")

                HStack(spacing: 0) {
                    ForEach([ServerConnection.AuthMethod.password, .sshKey], id: \.self) { method in
                        Button {
                            authMethod = method
                        } label: {
                            Text(method == .password ? "Password" : "SSH Key")
                                .font(.system(size: theme.fontCaption, weight: authMethod == method ? .semibold : .regular))
                                .foregroundStyle(authMethod == method ? theme.textPrimary : theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, theme.spacingSM)
                                .background(authMethod == method ? theme.accent.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(theme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

                if authMethod == .password {
                    SecureField("Password", text: $credential)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } else {
                    iconTextField("Private Key Path", text: $credential, icon: "key")
                }

                iconTextField("Backend Port", text: $backendPort, icon: "network")
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Setup Progress

    @ViewBuilder
    private var setupProgressView: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Setup Progress")

            VStack(spacing: theme.spacingSM) {
                ForEach(viewModel.steps, id: \.step) { step in
                    HStack {
                        stepStatusIcon(step.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.step.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: theme.fontBody))
                                .foregroundStyle(theme.textPrimary)
                            Text(step.message)
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Rejection Banner

    @ViewBuilder
    private var rejectionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.error)
            Text(rejectionMessage)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(theme.spacingMD)
        .background(theme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Connect Button

    @ViewBuilder
    private var connectAndSetupButton: some View {
        Button {
            Task { await startSetup() }
        } label: {
            HStack {
                if sshViewModel.isConnecting || viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text("Connect & Set Up")
            }
            .font(.system(size: theme.fontBody, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMD)
            .background(isFormValid ? theme.accent : theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .disabled(!isFormValid || sshViewModel.isConnecting || viewModel.isRunning)
        .padding(.horizontal, theme.spacingMD)
        .accessibilityLabel("Connect and set up server")
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !host.isEmpty && !username.isEmpty && !credential.isEmpty
    }

    private func startSetup() async {
        isSettingUp = true
        platformRejected = false

        // Go straight to SetupViewModel which handles SSH connection (Step 1),
        // platform detection (Step 2), and all remaining steps with progress UI.
        // No need to connect via sshViewModel separately — that creates a duplicate
        // SSH connection with no visual feedback.
        let request = StartSetupRequest(
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod.rawValue,
            credential: credential,
            backendPort: Int(backendPort) ?? 9999
        )
        await viewModel.startSetup(request: request)
        isSettingUp = false

        if viewModel.isComplete {
            // Connect appState to the newly-set-up remote backend
            // Use tunnel URL if available, otherwise direct HTTP connection
            let serverURL = viewModel.tunnelURL ?? "http://\(host):\(backendPort)"
            appState.updateServerURL(serverURL)

            do {
                try await appState.connectToServer(url: serverURL)
                // Connection successful - dismiss and navigate to dashboard
                dismiss()
            } catch {
                // Connection failed - show error and keep setup view open
                viewModel.error = "Failed to connect to server: \(error.localizedDescription)"
                // User can retry connection by tapping the connect button again
            }
        }
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: SetupProgress.StepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(theme.textTertiary)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
                .tint(theme.accent)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(theme.error)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(theme.textTertiary)
        }
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func iconTextField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        }
    }
}
