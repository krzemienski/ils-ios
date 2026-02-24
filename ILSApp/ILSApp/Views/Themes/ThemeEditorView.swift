import SwiftUI
import ILSShared

// SPERF-MED-1: 50+ @State properties are accepted as inherent complexity.
// Each maps 1:1 to a theme token: colors (17), typography (13), spacing (10),
// radius (8), shadow (9). Consolidating into structs would require custom Bindings
// for every ColorPicker/Slider, adding complexity without reducing re-renders.
struct ThemeEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemesViewModel.self) var viewModel

    @State private var editorVM: ThemeEditorViewModel

    init(theme: CustomTheme? = nil) {
        _editorVM = State(initialValue: ThemeEditorViewModel(theme: theme))
    }

    var body: some View {
        NavigationStack {
            TabView {
                // MARK: - Editor Tab
                editorForm
                    .tabItem {
                        Label("Editor", systemImage: "slider.horizontal.3")
                    }

                // MARK: - Preview Tab
                ThemePreviewView(theme: .constant(editorVM.previewTheme))
                    .tabItem {
                        Label("Preview", systemImage: "eye")
                    }
            }
            .navigationTitle(editorVM.isNewTheme ? "New Theme" : "Edit Theme")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorVM.exportTheme()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(editorVM.name.isEmpty)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await editorVM.saveTheme(viewModel: viewModel)
                        }
                    } label: {
                        if editorVM.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(editorVM.isSaving || editorVM.name.isEmpty)
                }
            }
            .alert("Save Error", isPresented: $editorVM.showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(editorVM.saveErrorMessage)
            }
            .sheet(isPresented: $editorVM.showShareSheet, onDismiss: {
                if let url = editorVM.exportURL {
                    try? FileManager.default.removeItem(at: url)
                    editorVM.exportURL = nil
                }
            }) {
                if let url = editorVM.exportURL {
                    ShareSheet(items: [url])
                }
            }
            .onChange(of: editorVM.didSave) { _, didSave in
                if didSave {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Editor Form

    private var editorForm: some View {
        Form {
            ThemeMetadataSection(editorVM: editorVM)
            ThemeColorTokensSection(editorVM: editorVM)
            ThemeTypographySection(editorVM: editorVM)
            ThemeSpacingSection(editorVM: editorVM)
            ThemeCornerRadiusSection(editorVM: editorVM)
            ThemeShadowSection(editorVM: editorVM)
        }
    }
}

#Preview {
    ThemeEditorView()
        .environment(ThemesViewModel())
}
