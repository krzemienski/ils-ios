import SwiftUI
import ILSShared

struct NewSSHServerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authType: SSHAuthType = .password
    @State private var password = ""
    @State private var privateKey = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    let viewModel: SSHViewModel
    let onCreated: (SSHServer) -> Void

    private let keychainService = KeychainService()

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Server Name", text: $name)
                    TextField("Host", text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    TextField("Description (optional)", text: $description)
                }

                Section("Authentication") {
                    Picker("Auth Type", selection: $authType) {
                        Text("Password").tag(SSHAuthType.password)
                        Text("Private Key").tag(SSHAuthType.key)
                    }
                    .pickerStyle(.segmented)

                    if authType == .password {
                        SecureField("Password", text: $password)
                    } else {
                        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                            Text("Private Key")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.secondaryText)
                            TextEditor(text: $privateKey)
                                .font(ILSTheme.codeFont)
                                .frame(minHeight: 120)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bolt.circle")
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTesting || !isFormValid)

                    if let testResult = testResult {
                        switch testResult {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle")
                                .foregroundColor(ILSTheme.success)
                        case .failure(let error):
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundColor(ILSTheme.error)
                                .font(ILSTheme.captionFont)
                        }
                    }
                }

                Section {
                    Text("The SSH server will be used to connect to remote machines running Claude Code.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("New SSH Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createServer()
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !host.isEmpty &&
        !port.isEmpty &&
        Int(port) != nil &&
        !username.isEmpty &&
        (authType == .password ? !password.isEmpty : !privateKey.isEmpty)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let client = APIClient()

            // Create request with credential field
            struct TestConnectionRequestWithCredential: Codable {
                let host: String
                let port: Int
                let username: String
                let authType: SSHAuthType
                let credential: String
            }

            let credential = authType == .password ? password : privateKey
            let request = TestConnectionRequestWithCredential(
                host: host,
                port: Int(port) ?? 22,
                username: username,
                authType: authType,
                credential: credential
            )

            do {
                // Test connection endpoint
                let response: APIResponse<TestConnectionResponse> = try await client.post("/ssh/test", body: request)
                if response.success {
                    await MainActor.run {
                        testResult = .success
                    }
                } else {
                    await MainActor.run {
                        testResult = .failure(response.error?.message ?? "Connection failed")
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                }
            }

            isTesting = false
        }
    }

    private func createServer() {
        isCreating = true

        Task {
            // Create server
            let portInt = Int(port) ?? 22
            if let server = await viewModel.createServer(
                name: name,
                host: host,
                port: portInt,
                username: username,
                authType: authType,
                description: description.isEmpty ? nil : description
            ) {
                // Save credentials to keychain
                do {
                    if authType == .password {
                        try await keychainService.savePassword(serverId: server.id.uuidString, password: password)
                    } else {
                        try await keychainService.saveKey(serverId: server.id.uuidString, privateKey: privateKey)
                    }

                    await MainActor.run {
                        onCreated(server)
                        dismiss()
                    }
                } catch {
                    // Server created but keychain save failed - should we delete the server?
                    // For now, just log and dismiss
                    await MainActor.run {
                        onCreated(server)
                        dismiss()
                    }
                }
            }

            isCreating = false
        }
    }
}

// MARK: - Support Types

private struct TestConnectionResponse: Codable {
    let success: Bool
}

#Preview {
    NewSSHServerView(viewModel: SSHViewModel()) { _ in }
}
