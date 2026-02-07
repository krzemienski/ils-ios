import SwiftUI
import ILSShared

struct EditMCPServerView: View {
    let server: MCPServerItem
    let apiClient: APIClient
    @ObservedObject var viewModel: MCPViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var command: String
    @State private var args: String
    @State private var scope: String
    @State private var isSaving = false

    init(server: MCPServerItem, apiClient: APIClient, viewModel: MCPViewModel) {
        self.server = server
        self.apiClient = apiClient
        self.viewModel = viewModel
        _name = State(initialValue: server.name)
        _command = State(initialValue: server.command)
        _args = State(initialValue: server.args.joined(separator: " "))
        _scope = State(initialValue: server.scope)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    LabeledContent("Name", value: name)
                    TextField("Command", text: $command)
                        .accessibilityLabel("Server command")
                    TextField("Arguments (space-separated)", text: $args)
                        .accessibilityLabel("Command arguments")
                }

                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        Text("User").tag("user")
                        Text("Project").tag("project")
                        Text("Local").tag("local")
                    }
                    .pickerStyle(.segmented)
                }

                if let env = server.env, !env.isEmpty {
                    Section("Environment Variables") {
                        ForEach(env.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(ILSTheme.codeFont)
                                Spacer()
                                Text("••••••")
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.tertiaryText)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle("Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(command.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            let argsArray = args.split(separator: " ").map(String.init)
            _ = await viewModel.updateServer(name: name, command: command, args: argsArray, scope: scope)
            await MainActor.run {
                dismiss()
            }
            isSaving = false
        }
    }
}
