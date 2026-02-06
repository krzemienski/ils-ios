import SwiftUI
import ILSShared

struct ServerConnectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ServerConnectionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectionForm
                connectButton
                if !viewModel.recentConnections.isEmpty {
                    recentConnectionsList
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(ILSTheme.background)
        .navigationTitle("Server Connection")
        .alert("Connection Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .onAppear {
            viewModel.configure(client: appState.apiClient)
            viewModel.loadRecentConnections()
        }
    }

    private var connectionForm: some View {
        VStack(spacing: 16) {
            // Host
            VStack(alignment: .leading, spacing: 6) {
                Text("Host")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                TextField("hostname or IP", text: $viewModel.host)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Port
            VStack(alignment: .leading, spacing: 6) {
                Text("Port")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                TextField("22", text: $viewModel.port)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                    .keyboardType(.numberPad)
            }

            // Username
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                TextField("username", text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Auth Method
            VStack(alignment: .leading, spacing: 6) {
                Text("Authentication")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                Picker("Auth Method", selection: $viewModel.authMethod) {
                    ForEach(ServerConnectionViewModel.AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Credential
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.authMethod == .password ? "Password" : "SSH Key Path")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                if viewModel.authMethod == .password {
                    SecureField("password", text: $viewModel.credential)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(ILSTheme.secondaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusSmall)
                } else {
                    TextField("~/.ssh/id_rsa", text: $viewModel.credential)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(ILSTheme.secondaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusSmall)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
        .padding()
        .background(ILSTheme.tertiaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusMedium)
    }

    private var connectButton: some View {
        Button(action: {
            Task {
                if let response = await viewModel.connect() {
                    appState.isServerConnected = true
                    appState.serverConnectionInfo = response
                    dismiss()
                }
            }
        }) {
            HStack {
                if viewModel.isConnecting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(viewModel.isConnecting ? "Connecting..." : "Connect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ILSTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(ILSTheme.cornerRadiusSmall)
            .font(.headline)
        }
        .disabled(viewModel.isConnecting)
    }

    private var recentConnectionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Connections")
                .font(.headline)
                .foregroundColor(ILSTheme.primaryText)

            ForEach(viewModel.recentConnections) { connection in
                Button(action: { viewModel.selectRecentConnection(connection) }) {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(connection.username)@\(connection.host)")
                                .font(.subheadline)
                                .foregroundColor(ILSTheme.primaryText)
                            Text("Port \(connection.port) - \(connection.authMethod)")
                                .font(.caption)
                                .foregroundColor(ILSTheme.tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(ILSTheme.tertiaryText)
                    }
                    .padding(12)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                }
            }
        }
    }
}
