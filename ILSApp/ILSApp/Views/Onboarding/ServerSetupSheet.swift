import SwiftUI
import ILSShared

struct ServerSetupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = "http://localhost:9090"
    @State private var isTesting = false
    @State private var connectionResult: ConnectionResult?

    enum ConnectionResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundColor(ILSTheme.accent)

                Text("Connect to Backend")
                    .font(ILSTheme.titleFont)

                Text("Enter the URL of your ILS backend server.")
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("server-url-field")

                    if let result = connectionResult {
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
                                .padding(.horizontal, 32)
                        }
                    }
                }

                Button {
                    testConnection()
                } label: {
                    if isTesting {
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
                .disabled(serverURL.isEmpty || isTesting)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("connect-button")

                Spacer()
                Spacer()
            }
            .background(ILSTheme.background)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            // Pre-fill with current URL if set
            if !appState.serverURL.isEmpty {
                serverURL = appState.serverURL
            }
        }
    }

    private func testConnection() {
        isTesting = true
        connectionResult = nil

        Task {
            do {
                let cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                let client = APIClient(baseURL: cleanURL)
                _ = try await client.healthCheck()

                HapticManager.notification(.success)
                connectionResult = .success

                // Update app state
                appState.serverURL = cleanURL
                appState.isConnected = true
                UserDefaults.standard.set(true, forKey: "hasConnectedBefore")

                // Dismiss after brief success indication
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                HapticManager.notification(.error)
                connectionResult = .failure("Cannot reach server at \(serverURL)")
            }

            isTesting = false
        }
    }
}
