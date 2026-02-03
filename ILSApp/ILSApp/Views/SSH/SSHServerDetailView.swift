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
    @State private var remoteSessions: [ChatSession] = []
    @State private var remoteConfig: ClaudeConfig?
    @State private var isLoadingRemoteData = false
    @State private var remoteDataError: String?

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
                    // Remote Sessions Section
                    Section {
                        if isLoadingRemoteData {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading remote sessions...")
                            }
                        } else if let error = remoteDataError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(ILSTheme.bodyFont)
                        } else if remoteSessions.isEmpty {
                            Label("No remote sessions found", systemImage: "bubble.left.and.bubble.right")
                                .foregroundColor(ILSTheme.secondaryText)
                                .font(ILSTheme.bodyFont)
                        } else {
                            ForEach(remoteSessions.prefix(5)) { session in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(session.name ?? "Unnamed Session")
                                            .font(ILSTheme.bodyFont)
                                            .lineLimit(1)

                                        Spacer()

                                        Text(session.model)
                                            .font(ILSTheme.captionFont)
                                            .foregroundColor(ILSTheme.secondaryText)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(ILSTheme.tertiaryBackground)
                                            .cornerRadius(ILSTheme.cornerRadiusS)
                                    }

                                    HStack {
                                        Label("\(session.messageCount) messages", systemImage: "bubble.left")
                                            .font(ILSTheme.captionFont)
                                            .foregroundColor(ILSTheme.tertiaryText)

                                        Spacer()

                                        Text(formattedRelativeDate(session.lastActiveAt))
                                            .font(ILSTheme.captionFont)
                                            .foregroundColor(ILSTheme.tertiaryText)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            if remoteSessions.count > 5 {
                                Text("+ \(remoteSessions.count - 5) more sessions")
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Remote Sessions")
                            Spacer()
                            Button {
                                loadRemoteData()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .disabled(isLoadingRemoteData)
                        }
                    }

                    // Remote Config Section
                    Section("Remote Configuration") {
                        if isLoadingRemoteData {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading remote config...")
                            }
                        } else if let config = remoteConfig {
                            if let model = config.model {
                                LabeledContent("Default Model", value: model)
                            }

                            if let apiKeyStatus = config.apiKeyStatus {
                                HStack {
                                    Text("API Key")
                                    Spacer()
                                    Label(
                                        apiKeyStatus.isConfigured ? "Configured" : "Not configured",
                                        systemImage: apiKeyStatus.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill"
                                    )
                                    .foregroundColor(apiKeyStatus.isConfigured ? .green : .red)
                                    .font(ILSTheme.captionFont)
                                }
                            }

                            if let theme = config.theme {
                                if let colorScheme = theme.colorScheme {
                                    LabeledContent("Theme", value: colorScheme.capitalized)
                                }
                            }

                            if let includeCoAuthor = config.includeCoAuthoredBy {
                                LabeledContent("Co-authored By", value: includeCoAuthor ? "Enabled" : "Disabled")
                            }

                            if let alwaysThinking = config.alwaysThinkingEnabled {
                                LabeledContent("Always Thinking", value: alwaysThinking ? "Enabled" : "Disabled")
                            }
                        } else if remoteDataError == nil {
                            Label("No remote config found", systemImage: "doc.text")
                                .foregroundColor(ILSTheme.secondaryText)
                                .font(ILSTheme.bodyFont)
                        }
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
            .task {
                // Load remote data when view appears
                if !isEditing {
                    loadRemoteData()
                }
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

    private func loadRemoteData() {
        isLoadingRemoteData = true
        remoteDataError = nil

        Task {
            // Retrieve credentials from keychain
            let keychainService = KeychainService()
            let credential: String?

            do {
                if server.authType == .password {
                    credential = try await keychainService.loadPassword(serverId: server.id.uuidString)
                } else {
                    credential = try await keychainService.loadKey(serverId: server.id.uuidString)
                }

                guard let credential = credential else {
                    remoteDataError = "No credentials found in keychain"
                    isLoadingRemoteData = false
                    return
                }

                // Load remote sessions and config in parallel
                async let sessionsTask = viewModel.loadRemoteSessions(
                    serverId: server.id,
                    credential: credential
                )
                async let configTask = viewModel.loadRemoteConfig(
                    serverId: server.id,
                    credential: credential
                )

                let (sessions, config) = await (sessionsTask, configTask)

                if let sessions = sessions {
                    remoteSessions = sessions
                }

                if let config = config {
                    remoteConfig = config
                }

                // If both failed, show error
                if sessions == nil && config == nil {
                    remoteDataError = "Failed to load remote data"
                }
            } catch {
                remoteDataError = "Credential error: \(error.localizedDescription)"
            }

            isLoadingRemoteData = false
        }
    }

    private func formattedRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
