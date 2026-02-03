import SwiftUI
import ILSShared

/// A view for editing environment variable key-value pairs
struct EnvironmentEditorView: View {
    @Binding var environment: [String: String]

    // Editing state
    @State private var isEditing = false
    @State private var editedEnvironment: [EnvVariable] = []

    // Add new variable state
    @State private var showAddVariable = false
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var showNewValueSecurely = false

    // Edit existing variable state
    @State private var editingVariable: EnvVariable?
    @State private var editKey = ""
    @State private var editValue = ""
    @State private var showEditValueSecurely = false

    var body: some View {
        Form {
            // MARK: - Environment Variables Section
            Section {
                if isEditing {
                    ForEach(editedEnvironment.indices, id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(editedEnvironment[index].key)
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.primaryText)
                                Text(maskValue(editedEnvironment[index].value))
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                            Spacer()

                            Button {
                                editingVariable = editedEnvironment[index]
                                editKey = editedEnvironment[index].key
                                editValue = editedEnvironment[index].value
                                showEditValueSecurely = isSensitiveKey(editedEnvironment[index].key)
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                            }

                            Button(role: .destructive) {
                                editedEnvironment.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Add new variable button
                    Button {
                        showAddVariable = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Variable")
                        }
                    }
                } else {
                    if !environment.isEmpty {
                        ForEach(Array(environment.keys.sorted()), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.primaryText)
                                Text(maskValue(environment[key] ?? ""))
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }
                    } else {
                        Text("No environment variables configured")
                            .foregroundColor(ILSTheme.tertiaryText)
                            .font(ILSTheme.captionFont)
                    }
                }
            } header: {
                HStack {
                    Label("Environment Variables", systemImage: "gearshape.2")
                    Spacer()
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            // Cancel editing - reset to original values
                            resetEditedValues()
                        }
                        isEditing.toggle()
                    }
                    .font(ILSTheme.captionFont)
                    .textCase(nil)
                }
            } footer: {
                Text("Custom environment variables for Claude Code sessions")
            }

            // MARK: - Save Button
            if isEditing {
                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save Changes")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Environment")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddVariable) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Variable Name", text: $newKey)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)

                        if isSensitiveKey(newKey) {
                            SecureField("Value", text: $newValue)
                        } else {
                            TextField("Value", text: $newValue)
                        }

                        if isSensitiveKey(newKey) {
                            Toggle("Show Value", isOn: $showNewValueSecurely)

                            if showNewValueSecurely {
                                Text(newValue)
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    } header: {
                        Text("New Environment Variable")
                    } footer: {
                        Text("Enter the variable name and value. Sensitive values like API keys will be masked.")
                    }
                }
                .navigationTitle("Add Variable")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            newKey = ""
                            newValue = ""
                            showNewValueSecurely = false
                            showAddVariable = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if !newKey.isEmpty && !newValue.isEmpty {
                                editedEnvironment.append(EnvVariable(key: newKey, value: newValue))
                                newKey = ""
                                newValue = ""
                                showNewValueSecurely = false
                                showAddVariable = false
                            }
                        }
                        .disabled(newKey.isEmpty || newValue.isEmpty)
                    }
                }
            }
        }
        .sheet(item: $editingVariable) { variable in
            NavigationStack {
                Form {
                    Section {
                        TextField("Variable Name", text: $editKey)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)

                        if isSensitiveKey(editKey) {
                            SecureField("Value", text: $editValue)
                        } else {
                            TextField("Value", text: $editValue)
                        }

                        if isSensitiveKey(editKey) {
                            Toggle("Show Value", isOn: $showEditValueSecurely)

                            if showEditValueSecurely {
                                Text(editValue)
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    } header: {
                        Text("Edit Environment Variable")
                    } footer: {
                        Text("Modify the variable name or value. Sensitive values like API keys will be masked.")
                    }
                }
                .navigationTitle("Edit Variable")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editKey = ""
                            editValue = ""
                            showEditValueSecurely = false
                            editingVariable = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if !editKey.isEmpty && !editValue.isEmpty,
                               let index = editedEnvironment.firstIndex(where: { $0.id == variable.id }) {
                                editedEnvironment[index] = EnvVariable(id: variable.id, key: editKey, value: editValue)
                                editKey = ""
                                editValue = ""
                                showEditValueSecurely = false
                                editingVariable = nil
                            }
                        }
                        .disabled(editKey.isEmpty || editValue.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            resetEditedValues()
        }
    }

    // MARK: - Helper Methods

    private func resetEditedValues() {
        editedEnvironment = environment.map { EnvVariable(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private func saveChanges() {
        // Convert array back to dictionary
        var newEnv: [String: String] = [:]
        for variable in editedEnvironment {
            newEnv[variable.key] = variable.value
        }
        environment = newEnv
        isEditing = false
    }

    private func maskValue(_ value: String) -> String {
        // Mask all but last 4 characters for sensitive-looking values
        if value.count > 8 {
            let suffix = String(value.suffix(4))
            return "***\(suffix)"
        }
        return value
    }

    private func isSensitiveKey(_ key: String) -> Bool {
        let sensitivePatterns = [
            "key", "secret", "token", "password", "pass", "pwd",
            "api", "auth", "credential", "private"
        ]
        let lowercaseKey = key.lowercased()
        return sensitivePatterns.contains { lowercaseKey.contains($0) }
    }
}

// MARK: - Supporting Types

/// Helper struct for managing environment variables in editing mode
private struct EnvVariable: Identifiable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EnvironmentEditorView(
            environment: .constant([
                "NODE_ENV": "production",
                "API_KEY": "sk_test_1234567890abcdef",
                "DEBUG": "true",
                "DATABASE_URL": "postgresql://localhost:5432/mydb"
            ])
        )
    }
}
