import SwiftUI
import ILSShared

struct MCPServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var args: [String] = []
    @State private var newArg = ""
    @State private var envVars: [EnvVar] = []
    @State private var scope: MCPScope = .user
    @State private var isCreating = false
    @State private var errorMessage: String?

    let onCreated: (MCPServerItem) -> Void

    private let scopes: [MCPScope] = [.user, .project, .local]

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Server Name", text: $name)
                        .autocapitalization(.none)

                    TextField("Command (e.g., npx, node)", text: $command)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Arguments") {
                    ForEach(Array(args.enumerated()), id: \.offset) { index, arg in
                        HStack {
                            Text(arg)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)

                            Spacer()

                            Button(role: .destructive) {
                                removeArg(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(ILSTheme.error)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Add argument", text: $newArg)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addArg()
                            }

                        Button {
                            addArg()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(ILSTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(newArg.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Arguments")
                } footer: {
                    if !args.isEmpty {
                        Text("Full command: \(fullCommand)")
                            .font(ILSTheme.codeFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }

                Section("Environment Variables") {
                    ForEach(Array(envVars.enumerated()), id: \.offset) { index, envVar in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(envVar.key)
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.accent)

                                Spacer()

                                Button(role: .destructive) {
                                    removeEnvVar(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(ILSTheme.error)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(envVar.value)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }

                    NavigationLink {
                        AddEnvVarView { key, value in
                            addEnvVar(key: key, value: value)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(ILSTheme.accent)
                            Text("Add Environment Variable")
                        }
                    }
                } footer: {
                    Text("Environment variables are key-value pairs passed to the server process.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        ForEach(scopes, id: \.self) { scope in
                            Text(scope.rawValue.capitalized).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(scopeDescription)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.error)
                    }
                }
            }
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createServer()
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var fullCommand: String {
        if args.isEmpty {
            return command
        }
        return "\(command) \(args.joined(separator: " "))"
    }

    private var scopeDescription: String {
        switch scope {
        case .user:
            return "Available to all projects for this user"
        case .project:
            return "Available only to the current project"
        case .local:
            return "Local to this machine only"
        }
    }

    // MARK: - Actions

    private func addArg() {
        let trimmed = newArg.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        args.append(trimmed)
        newArg = ""
    }

    private func removeArg(at index: Int) {
        args.remove(at: index)
    }

    private func addEnvVar(key: String, value: String) {
        envVars.append(EnvVar(key: key, value: value))
    }

    private func removeEnvVar(at index: Int) {
        envVars.remove(at: index)
    }

    private func createServer() {
        errorMessage = nil
        isCreating = true

        Task {
            let client = APIClient()

            // Convert envVars array to dictionary
            let envDict: [String: String]? = envVars.isEmpty ? nil : Dictionary(
                uniqueKeysWithValues: envVars.map { ($0.key, $0.value) }
            )

            let request = CreateMCPServerRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                command: command.trimmingCharacters(in: .whitespaces),
                args: args,
                env: envDict,
                scope: scope.rawValue
            )

            do {
                let response: APIResponse<MCPServerItem> = try await client.post("/mcp", body: request)
                if let server = response.data {
                    await MainActor.run {
                        onCreated(server)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create MCP server: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct EnvVar: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

struct CreateMCPServerRequest: Encodable {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    let scope: String
}

// MARK: - Add Environment Variable View

struct AddEnvVarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var value = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        Form {
            Section("Environment Variable") {
                TextField("Key (e.g., API_KEY)", text: $key)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField("Value", text: $value)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            Section {
                Text("Environment variables are passed to the server process at startup.")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }
        }
        .navigationTitle("Add Variable")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onAdd(key.trimmingCharacters(in: .whitespaces), value)
                    dismiss()
                }
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

#Preview {
    MCPServerFormView { _ in }
}
