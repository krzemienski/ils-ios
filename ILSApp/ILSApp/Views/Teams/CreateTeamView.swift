import SwiftUI
import ILSShared

struct CreateTeamView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: TeamsViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTemplate: TeamTemplate?
    @State private var isCreating = false

    private var isValidName: Bool {
        let pattern = "^[a-zA-Z0-9-]+$"
        return !name.isEmpty && name.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Team Name", text: $name)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                } header: {
                    Text("Name")
                        .foregroundStyle(theme.textSecondary)
                } footer: {
                    Text("Only alphanumeric characters and hyphens allowed")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }

                Section {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("None (Blank Team)")
                            .tag(nil as TeamTemplate?)

                        ForEach(viewModel.templates) { template in
                            Text(template.name)
                                .tag(template as TeamTemplate?)
                        }
                    }

                    if let template = selectedTemplate {
                        VStack(alignment: .leading, spacing: theme.spacingSM) {
                            if let description = template.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }

                            HStack(spacing: theme.spacingMD) {
                                HStack(spacing: theme.spacingSM) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    Text("\(template.members.count) members")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                }

                                HStack(spacing: theme.spacingSM) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    Text("\(template.tasks.count) tasks")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                }
                            }
                            .foregroundStyle(theme.textTertiary)
                        }
                    }
                } header: {
                    Text("Template (Optional)")
                        .foregroundStyle(theme.textSecondary)
                } footer: {
                    if selectedTemplate == nil {
                        Text("Start with a template or create a blank team")
                            .foregroundStyle(theme.textTertiary)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                }

                Section {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Create Team")
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
                    Button("Create") {
                        createTeam()
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(!isValidName || isCreating)
                }
            }
            .task {
                await viewModel.loadTemplates()
            }
        }
    }

    private func createTeam() {
        isCreating = true
        Task {
            if let template = selectedTemplate {
                await viewModel.applyTemplate(
                    id: template.id,
                    teamName: name,
                    teamDescription: description.isEmpty ? nil : description
                )
            } else {
                await viewModel.createTeam(name: name, description: description.isEmpty ? nil : description)
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
}
