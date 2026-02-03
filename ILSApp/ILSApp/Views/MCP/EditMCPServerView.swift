import SwiftUI
import ILSShared

struct EditMCPServerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MCPViewModel()

    let server: MCPServerItem
    let onUpdated: ((MCPServerItem) -> Void)?

    @State private var name: String
    @State private var command: String
    @State private var args: String
    @State private var scope: String
    @State private var envVars: [EnvVar]
    @State private var isUpdating = false
    @State private var showingAddEnvVar = false
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""

    private let scopes = ["user", "project", "local"]

    init(server: MCPServerItem, onUpdated: ((MCPServerItem) -> Void)? = nil) {
        self.server = server
        self.onUpdated = onUpdated

        // Initialize state with server data
        _name = State(initialValue: server.name)
        _command = State(initialValue: server.command)
        _args = State(initialValue: server.args.joined(separator: " "))
        _scope = State(initialValue: server.scope)

        // Convert env dictionary to array of EnvVar for easier editing
        let envArray = (server.env ?? [:]).map { EnvVar(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
        _envVars = State(initialValue: envArray)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command (e.g., npx)", text: $command)
                    TextField("Arguments (space-separated)", text: $args)
                }

                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        ForEach(scopes, id: \.self) { scope in
                            Text(scope.capitalized).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Environment Variables Section
                Section {
                    ForEach(envVars.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(envVars[index].key)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)

                            TextField("Value", text: $envVars[index].value)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                    .onDelete(perform: deleteEnvVar)

                    Button {
                        showingAddEnvVar = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Environment Variable")
                        }
                        .foregroundColor(ILSTheme.accent)
                    }
                } header: {
                    Text("Environment Variables")
                } footer: {
                    Text("Environment variables will be passed to the MCP server process.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Section {
                    Text("Changes will be saved to your Claude Code configuration file.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("Edit MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateServer()
                    }
                    .disabled(name.isEmpty || command.isEmpty || isUpdating)
                }
            }
            .sheet(isPresented: $showingAddEnvVar) {
                addEnvVarSheet
            }
        }
    }

    private var addEnvVarSheet: some View {
        NavigationStack {
            Form {
                Section("Environment Variable") {
                    TextField("Key (e.g., API_KEY)", text: $newEnvKey)
                        .font(ILSTheme.codeFont)
                        .autocapitalization(.allCharacters)

                    TextField("Value", text: $newEnvValue)
                        .font(ILSTheme.codeFont)
                }

                Section {
                    Text("Add an environment variable that will be available to the MCP server.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("Add Environment Variable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetEnvVarForm()
                        showingAddEnvVar = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEnvVar()
                    }
                    .disabled(newEnvKey.isEmpty)
                }
            }
        }
    }

    private func deleteEnvVar(at offsets: IndexSet) {
        envVars.remove(atOffsets: offsets)
    }

    private func addEnvVar() {
        let key = newEnvKey.trimmingCharacters(in: .whitespaces)
        let value = newEnvValue.trimmingCharacters(in: .whitespaces)

        // Check if key already exists and update it, otherwise add new
        if let index = envVars.firstIndex(where: { $0.key == key }) {
            envVars[index].value = value
        } else {
            envVars.append(EnvVar(key: key, value: value))
            envVars.sort { $0.key < $1.key }
        }

        resetEnvVarForm()
        showingAddEnvVar = false
    }

    private func resetEnvVarForm() {
        newEnvKey = ""
        newEnvValue = ""
    }

    private func updateServer() {
        isUpdating = true

        Task {
            let argsArray = args.split(separator: " ").map(String.init)
            let envDict = Dictionary(uniqueKeysWithValues: envVars.map { ($0.key, $0.value) })

            if let updatedServer = await viewModel.updateServer(
                server,
                name: name != server.name ? name : nil,
                command: command != server.command ? command : nil,
                args: argsArray != server.args ? argsArray : nil,
                env: envDict != (server.env ?? [:]) ? envDict : nil
            ) {
                await MainActor.run {
                    onUpdated?(updatedServer)
                    dismiss()
                }
            }

            isUpdating = false
        }
    }
}

// MARK: - Supporting Types

private struct EnvVar: Identifiable {
    let id = UUID()
    let key: String
    var value: String
}

#Preview {
    let sampleServer = MCPServerItem(
        id: UUID(),
        name: "Test Server",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem"],
        env: ["API_KEY": "test123", "DEBUG": "true"],
        scope: "user",
        status: "healthy",
        configPath: nil,
        disabled: false
    )

    return EditMCPServerView(server: sampleServer) { _ in }
}
