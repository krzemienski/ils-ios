import SwiftUI
import ILSShared

struct AddMCPServerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    let mcpVM: MCPViewModel

    @State private var name = ""
    @State private var command = ""
    @State private var argsText = ""
    @State private var selectedScope: MCPScope = .user
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    // Name field
                    fieldSection(
                        label: "Name",
                        placeholder: "e.g. filesystem, postgres",
                        text: $name,
                        required: true
                    )

                    // Command field
                    fieldSection(
                        label: "Command",
                        placeholder: "e.g. npx, python3, node",
                        text: $command,
                        required: true
                    )

                    // Arguments field
                    fieldSection(
                        label: "Arguments",
                        placeholder: "e.g. -m mcp_server --port 3000",
                        text: $argsText,
                        required: false
                    )

                    // Scope picker
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        Text("Scope")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        HStack(spacing: 0) {
                            ForEach([MCPScope.user, .project, .local], id: \.self) { scope in
                                Button {
                                    selectedScope = scope
                                } label: {
                                    Text(scope.rawValue.capitalized)
                                        .font(.system(size: theme.fontCaption, weight: selectedScope == scope ? .semibold : .regular, design: theme.fontDesign))
                                        .foregroundStyle(selectedScope == scope ? theme.textPrimary : theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, theme.spacingSM)
                                        .background(selectedScope == scope ? theme.accent.opacity(0.15) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(scope.rawValue.capitalized) scope")
                                .accessibilityAddTraits(selectedScope == scope ? .isSelected : [])
                            }
                        }
                        .padding(4)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

                        Text(scopeDescription(selectedScope))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())

                    // Error message
                    if let errorMessage {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(theme.error)
                            Text(errorMessage)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.error)
                        }
                        .padding(theme.spacingMD)
                        .modifier(GlassCard())
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Add MCP Server")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                    }
                }
            }
        }
    }

    // MARK: - Field Section

    private func fieldSection(
        label: String,
        placeholder: String,
        text: Binding<String>,
        required: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                if required {
                    Text("*")
                        .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: theme.fontBody, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Scope Description

    private func scopeDescription(_ scope: MCPScope) -> String {
        switch scope {
        case .user:
            return "Available across all projects for this user."
        case .project:
            return "Scoped to the current project directory."
        case .local:
            return "Local to the current working directory only."
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        let args = argsText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        let result = await mcpVM.addServer(
            name: trimmedName,
            command: trimmedCommand,
            args: args,
            scope: selectedScope.rawValue
        )

        isSaving = false

        if result != nil {
            dismiss()
        } else {
            errorMessage = mcpVM.error?.localizedDescription ?? "Failed to add server. Please try again."
        }
    }
}
