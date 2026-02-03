import SwiftUI
import ILSShared

struct ConnectionSetupView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var serverHost: String = "localhost"
    @State private var serverPort: String = "8080"

    // Alert state
    @State private var showSaveSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Header Section
                Section {
                    VStack(spacing: ILSTheme.spacingM) {
                        Image(systemName: "network")
                            .font(.system(size: 60))
                            .foregroundColor(ILSTheme.accent)

                        Text("Connect to ILS Backend")
                            .font(ILSTheme.titleFont)

                        Text("Configure your local ILS backend server to get started")
                            .font(ILSTheme.bodyFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ILSTheme.spacingL)
                    .listRowBackground(Color.clear)
                }

                // MARK: - Connection Configuration Section
                Section {
                    HStack {
                        Text("Host")
                            .frame(width: 50, alignment: .leading)
                        TextField("localhost", text: $serverHost)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }

                    HStack {
                        Text("Port")
                            .frame(width: 50, alignment: .leading)
                        TextField("8080", text: $serverPort)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Server Configuration")
                } footer: {
                    Text("Enter the address where your ILS backend server is running")
                }

                // MARK: - Connection Status Section
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(appState.isConnected ? "Connected" : "Disconnected")
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isTestingConnection ? "Testing..." : "Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isTestingConnection)

                    // Error message display
                    if let errorMessage = viewModel.lastConnectionError {
                        HStack(alignment: .top, spacing: ILSTheme.spacingS) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ILSTheme.error)
                                .font(ILSTheme.captionFont)
                            Text(errorMessage)
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.error)
                        }
                        .padding(.vertical, ILSTheme.spacingS)
                    }
                } header: {
                    Text("Connection Test")
                } footer: {
                    Text("Test the connection to verify your server is running and accessible")
                }

                // MARK: - Save Section
                Section {
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save and Continue")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!appState.isConnected || viewModel.isTestingConnection)
                } footer: {
                    if !appState.isConnected {
                        Text("Please test the connection successfully before saving")
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
            .navigationTitle("Backend Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .alert("Connection Saved", isPresented: $showSaveSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your backend connection has been configured successfully")
            }
            .onAppear {
                loadSavedSettings()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSavedSettings() {
        // Load from UserDefaults
        if let savedHost = UserDefaults.standard.string(forKey: "ils_server_host") {
            serverHost = savedHost
        }
        if let savedPort = UserDefaults.standard.string(forKey: "ils_server_port") {
            serverPort = savedPort
        }
    }

    private func testConnection() {
        Task {
            let serverURL = "http://\(serverHost):\(serverPort)"
            let success = await viewModel.testConnection(serverURL: serverURL)
            if success {
                // Update app state to reflect connection
                appState.serverURL = serverURL
                appState.isConnected = true
            } else {
                appState.isConnected = false
            }
        }
    }

    private func saveSettings() {
        // Save to UserDefaults
        UserDefaults.standard.set(serverHost, forKey: "ils_server_host")
        UserDefaults.standard.set(serverPort, forKey: "ils_server_port")

        // Update AppState
        let serverURL = "http://\(serverHost):\(serverPort)"
        appState.serverURL = serverURL

        // Show success and dismiss
        showSaveSuccess = true
    }
}

#Preview {
    ConnectionSetupView()
        .environmentObject(AppState())
}
