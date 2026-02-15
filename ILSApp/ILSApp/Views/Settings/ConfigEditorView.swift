import SwiftUI
import ILSShared

struct ConfigEditorView: View {
    @Environment(\.theme) private var theme: any AppTheme
    @EnvironmentObject private var appState: AppState
    let scope: String
    @StateObject private var viewModel = ConfigEditorViewModel()
    @State private var configText = ""
    @State private var originalConfigText = ""
    @State private var isSaving = false
    @State private var validationErrors: [String] = []
    @State private var hasUnsavedChanges = false
    @State private var showUnsavedChangesAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView().tint(theme.accent)
            } else {
                TextEditor(text: $configText)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding()

                HStack {
                    if isValidJSON(configText) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.success)
                        Text("Valid JSON")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.error)
                        Text("Invalid JSON")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                if !validationErrors.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.error)
                        }
                    }
                    .padding()
                    .background(theme.error.opacity(0.1))
                }
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("\(scope.capitalized) Settings")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        showUnsavedChangesAlert = true
                    } else {
                        dismiss()
                    }
                }
                .foregroundStyle(theme.textSecondary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { saveConfig() }
                    .foregroundStyle(theme.accent)
                    .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadConfig(scope: scope)
            configText = viewModel.configJson
            originalConfigText = viewModel.configJson
        }
        .onChange(of: configText) { _, newValue in
            hasUnsavedChanges = (newValue != originalConfigText)
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private func saveConfig() {
        isSaving = true
        validationErrors = []
        Task {
            let errors = await viewModel.saveConfig(scope: scope, json: configText)
            validationErrors = errors
            isSaving = false
            if errors.isEmpty {
                originalConfigText = configText
                hasUnsavedChanges = false
                dismiss()
            }
        }
    }

    private func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
