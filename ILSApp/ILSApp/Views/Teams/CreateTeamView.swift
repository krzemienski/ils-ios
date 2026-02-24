import SwiftUI
import ILSShared

/// Modal form for creating a new team.
///
/// Presents name and description fields, validates the team name against an
/// alphanumeric-plus-hyphen pattern, and delegates creation to ``TeamsViewModel``.
/// Dismisses automatically on success.
///
/// ## Key State
/// - ``name`` - Required team name (alphanumeric and hyphens only)
/// - ``description`` - Optional human-readable description
/// - ``isCreating`` - Disables the Create button while the async request is in flight
struct CreateTeamView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: TeamsViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false

    private var isValidName: Bool {
        let pattern = "^[a-zA-Z0-9-]+$"
        return !name.isEmpty && name.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
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
    }

    private func createTeam() {
        isCreating = true
        Task {
            await viewModel.createTeam(name: name, description: description.isEmpty ? nil : description)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
