import SwiftUI
import ILSShared

/// A view for editing permissions configuration (allow/deny/defaultMode)
struct PermissionsEditorView: View {
    @Binding var permissions: PermissionsConfig

    // Editing state
    @State private var isEditing = false
    @State private var editedDefaultMode: String = "prompt"
    @State private var editedAllow: [String] = []
    @State private var editedDeny: [String] = []

    // Add new item state
    @State private var showAddAllow = false
    @State private var showAddDeny = false
    @State private var newAllowItem = ""
    @State private var newDenyItem = ""

    // Available default modes
    private let availableDefaultModes = ["allow", "deny", "prompt"]

    var body: some View {
        Form {
            // MARK: - Default Mode Section
            Section {
                if isEditing {
                    Picker("Default Mode", selection: $editedDefaultMode) {
                        ForEach(availableDefaultModes, id: \.self) { mode in
                            HStack {
                                Image(systemName: iconForMode(mode))
                                Text(mode.capitalized)
                            }
                            .tag(mode)
                        }
                    }
                } else {
                    LabeledContent("Default Mode") {
                        HStack(spacing: 6) {
                            Image(systemName: iconForMode(permissions.defaultMode ?? "prompt"))
                                .foregroundColor(colorForMode(permissions.defaultMode ?? "prompt"))
                            Text((permissions.defaultMode ?? "prompt").capitalized)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Default Permission Mode")
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
                Text("Default action when Claude requests permission for a command")
            }

            // MARK: - Allow List Section
            Section {
                if isEditing {
                    ForEach(editedAllow.indices, id: \.self) { index in
                        HStack {
                            Text(editedAllow[index])
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)
                            Spacer()
                            Button(role: .destructive) {
                                editedAllow.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Add new allow item
                    Button {
                        showAddAllow = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Rule")
                        }
                    }
                } else {
                    if let allowed = permissions.allow, !allowed.isEmpty {
                        ForEach(allowed, id: \.self) { item in
                            Text(item)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    } else {
                        Text("No allowed rules configured")
                            .foregroundColor(ILSTheme.tertiaryText)
                            .font(ILSTheme.captionFont)
                    }
                }
            } header: {
                Label("Allow Rules", systemImage: "checkmark.shield")
            } footer: {
                Text("Commands or patterns that are always allowed")
            }

            // MARK: - Deny List Section
            Section {
                if isEditing {
                    ForEach(editedDeny.indices, id: \.self) { index in
                        HStack {
                            Text(editedDeny[index])
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)
                            Spacer()
                            Button(role: .destructive) {
                                editedDeny.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Add new deny item
                    Button {
                        showAddDeny = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Rule")
                        }
                    }
                } else {
                    if let denied = permissions.deny, !denied.isEmpty {
                        ForEach(denied, id: \.self) { item in
                            Text(item)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    } else {
                        Text("No denied rules configured")
                            .foregroundColor(ILSTheme.tertiaryText)
                            .font(ILSTheme.captionFont)
                    }
                }
            } header: {
                Label("Deny Rules", systemImage: "xmark.shield")
            } footer: {
                Text("Commands or patterns that are always denied")
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
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add Allow Rule", isPresented: $showAddAllow) {
            TextField("Command or pattern", text: $newAllowItem)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
            Button("Add") {
                if !newAllowItem.isEmpty {
                    editedAllow.append(newAllowItem)
                    newAllowItem = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newAllowItem = ""
            }
        } message: {
            Text("Enter a command or pattern to always allow")
        }
        .alert("Add Deny Rule", isPresented: $showAddDeny) {
            TextField("Command or pattern", text: $newDenyItem)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
            Button("Add") {
                if !newDenyItem.isEmpty {
                    editedDeny.append(newDenyItem)
                    newDenyItem = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newDenyItem = ""
            }
        } message: {
            Text("Enter a command or pattern to always deny")
        }
        .onAppear {
            resetEditedValues()
        }
    }

    // MARK: - Helper Methods

    private func resetEditedValues() {
        editedDefaultMode = permissions.defaultMode ?? "prompt"
        editedAllow = permissions.allow ?? []
        editedDeny = permissions.deny ?? []
    }

    private func saveChanges() {
        permissions.defaultMode = editedDefaultMode
        permissions.allow = editedAllow.isEmpty ? nil : editedAllow
        permissions.deny = editedDeny.isEmpty ? nil : editedDeny
        isEditing = false
    }

    private func iconForMode(_ mode: String) -> String {
        switch mode {
        case "allow":
            return "checkmark.shield.fill"
        case "deny":
            return "xmark.shield.fill"
        case "prompt":
            return "questionmark.circle.fill"
        default:
            return "shield"
        }
    }

    private func colorForMode(_ mode: String) -> Color {
        switch mode {
        case "allow":
            return .green
        case "deny":
            return .red
        case "prompt":
            return .orange
        default:
            return ILSTheme.secondaryText
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PermissionsEditorView(
            permissions: .constant(
                PermissionsConfig(
                    allow: ["git*", "npm*"],
                    deny: ["rm -rf*"],
                    defaultMode: "prompt"
                )
            )
        )
    }
}
