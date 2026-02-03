import SwiftUI
import ILSShared

struct SSHServerDetailView: View {
    let server: SSHServer
    @ObservedObject var viewModel: SSHViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var authType: SSHAuthType
    @State private var description: String
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    init(server: SSHServer, viewModel: SSHViewModel) {
        self.server = server
        self.viewModel = viewModel
        _name = State(initialValue: server.name)
        _host = State(initialValue: server.host)
        _port = State(initialValue: String(server.port))
        _username = State(initialValue: server.username)
        _authType = State(initialValue: server.authType)
        _description = State(initialValue: server.description ?? "")
    }

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Info") {
                    if isEditing {
                        TextField("Name", text: $name)
                        TextField("Host", text: $host)
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                        TextField("Username", text: $username)
                    } else {
                        LabeledContent("Name", value: server.name)
                        LabeledContent("Host", value: server.host)
                        LabeledContent("Port", value: "\(server.port)")
                        LabeledContent("Username", value: server.username)
                    }

                    if isEditing {
                        Picker("Authentication", selection: $authType) {
                            Text("Password").tag(SSHAuthType.password)
                            Text("SSH Key").tag(SSHAuthType.key)
                        }
                    } else {
                        LabeledContent("Authentication", value: server.authType == .password ? "Password" : "SSH Key")
                    }

                    if isEditing {
                        TextField("Description", text: $description)
                    } else if let desc = server.description {
                        LabeledContent("Description", value: desc)
                    }
                }

                Section("Connection Status") {
                    if let lastConnected = server.lastConnectedAt {
                        LabeledContent("Status", value: "Connected")
                        LabeledContent("Last Connected", value: formattedDate(lastConnected))
                    } else {
                        LabeledContent("Status", value: "Not Connected")
                    }

                    if let testResult = testResult {
                        switch testResult {
                        case .success:
                            Label("Connection test succeeded", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failure(let error):
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("Statistics") {
                    LabeledContent("Created", value: formattedDate(server.createdAt))
                    if let lastConnected = server.lastConnectedAt {
                        LabeledContent("Last Connected", value: formattedDate(lastConnected))
                    }
                }

                if !isEditing {
                    Section {
                        Button {
                            testConnection()
                        } label: {
                            if isTesting {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                    Text("Testing Connection...")
                                }
                            } else {
                                Label("Test Connection", systemImage: "network")
                            }
                        }
                        .disabled(isTesting)
                    }

                    Section {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteServer(server)
                                dismiss()
                            }
                        } label: {
                            Label("Delete Server", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Server Details")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                // Refresh server details from backend
                await viewModel.loadServers()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            // Reset values
                            name = server.name
                            host = server.host
                            port = String(server.port)
                            username = server.username
                            authType = server.authType
                            description = server.description ?? ""
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isSaving)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saveChanges() {
        isSaving = true

        Task {
            // Convert port string to Int
            let portInt = Int(port) ?? server.port

            _ = await viewModel.updateServer(
                server,
                name: name != server.name ? name : nil,
                host: host != server.host ? host : nil,
                port: portInt != server.port ? portInt : nil,
                username: username != server.username ? username : nil,
                authType: authType != server.authType ? authType : nil,
                description: description != (server.description ?? "") ? description : nil
            )

            isSaving = false
            isEditing = false
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            // TODO: Implement actual connection test using SSHService
            // For now, simulate a test
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // Simulate success/failure
            if server.host.isEmpty {
                testResult = .failure("Invalid host")
            } else {
                testResult = .success
            }

            isTesting = false
        }
    }
}

#Preview {
    SSHServerDetailView(
        server: SSHServer(
            id: UUID(),
            name: "Production Server",
            host: "prod.example.com",
            port: 22,
            username: "deploy",
            authType: .key,
            description: "Main production server",
            createdAt: Date(),
            lastConnectedAt: Date()
        ),
        viewModel: SSHViewModel()
    )
}
