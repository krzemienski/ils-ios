import SwiftUI
import ILSShared

// MARK: - Theme Metadata Section

struct ThemeMetadataSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            TextField("Theme Name", text: $editorVM.name)
                .autocapitalization(.words)

            TextField("Description (optional)", text: $editorVM.description, axis: .vertical)
                .lineLimit(2...4)

            TextField("Author (optional)", text: $editorVM.author)
                .autocapitalization(.words)

            TextField("Version", text: $editorVM.version)
                .keyboardType(.decimalPad)
        } header: {
            Text("Theme Information")
        } footer: {
            Text("Basic information about your custom theme")
        }
    }
}
