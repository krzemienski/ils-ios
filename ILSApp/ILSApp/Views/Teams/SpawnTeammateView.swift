import SwiftUI
import ILSShared

struct SpawnTeammateView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) private var theme: any AppTheme
    @ObservedObject var viewModel: TeamsViewModel
    let teamName: String
    @State private var name = ""
    @State private var agentType = ""
    @State private var selectedModel = "sonnet"
    @State private var prompt = ""
    @State private var isSpawning = false

    let modelOptions = ["haiku", "sonnet", "opus"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                } header: {
                    Text("Teammate Name")
                        .foregroundStyle(theme.textSecondary)
                } footer: {
                    Text("Unique identifier for this teammate")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }

                Section {
                    TextField("Agent Type", text: $agentType)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                } header: {
                    Text("Agent Type")
                        .foregroundStyle(theme.textSecondary)
                } footer: {
                    Text("e.g., researcher, executor, designer")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }

                Section {
                    HStack(spacing: 0) {
                        ForEach(modelOptions, id: \.self) { model in
                            Button {
                                selectedModel = model
                            } label: {
                                Text(model.capitalized)
                                    .font(.system(size: theme.fontCaption, weight: selectedModel == model ? .semibold : .regular, design: theme.fontDesign))
                                    .foregroundStyle(selectedModel == model ? theme.textPrimary : theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, theme.spacingSM)
                                    .background(selectedModel == model ? theme.accent.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                } header: {
                    Text("AI Model")
                        .foregroundStyle(theme.textSecondary)
                }

                Section {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                } header: {
                    Text("Initial Prompt (Optional)")
                        .foregroundStyle(theme.textSecondary)
                } footer: {
                    Text("Instructions for the teammate's initial task")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Spawn Teammate")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Spawn") {
                        spawnTeammate()
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(name.isEmpty || agentType.isEmpty || isSpawning)
                }
            }
        }
    }

    private func spawnTeammate() {
        isSpawning = true
        Task {
            let request = SpawnTeammateRequest(
                name: name,
                agentType: agentType,
                model: selectedModel,
                prompt: prompt.isEmpty ? nil : prompt
            )
            await viewModel.spawnTeammate(teamName: teamName, request: request)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
