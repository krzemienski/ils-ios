import SwiftUI
import ILSShared

// MARK: - Theme Color Tokens Section

struct ThemeColorTokensSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("colors") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("colors")
                        } else {
                            editorVM.expandedSections.remove("colors")
                        }
                    }
                )
            ) {
                // MARK: - Color Palette Picker
                Picker("Color Palette", selection: $editorVM.selectedPalette) {
                    ForEach(ColorPalette.allCases) { palette in
                        Text(palette.rawValue).tag(palette)
                    }
                }
                .onChange(of: editorVM.selectedPalette) { _, newValue in
                    editorVM.applyPalette(newValue)
                }

                Divider()
                    .padding(.vertical, 8)

                Group {
                    ColorPicker("Accent", selection: $editorVM.accent)
                    ColorPicker("Background", selection: $editorVM.background)
                    ColorPicker("Secondary Background", selection: $editorVM.secondaryBackground)
                    ColorPicker("Tertiary Background", selection: $editorVM.tertiaryBackground)
                }

                Group {
                    ColorPicker("Primary Text", selection: $editorVM.primaryText)
                    ColorPicker("Secondary Text", selection: $editorVM.secondaryText)
                    ColorPicker("Tertiary Text", selection: $editorVM.tertiaryText)
                }

                Group {
                    ColorPicker("Success", selection: $editorVM.success)
                    ColorPicker("Warning", selection: $editorVM.warning)
                    ColorPicker("Error", selection: $editorVM.error)
                    ColorPicker("Info", selection: $editorVM.info)
                }

                Group {
                    ColorPicker("User Bubble", selection: $editorVM.userBubble)
                    ColorPicker("Assistant Bubble", selection: $editorVM.assistantBubble)
                    ColorPicker("Border", selection: $editorVM.border)
                    ColorPicker("Separator", selection: $editorVM.separator)
                    ColorPicker("Overlay", selection: $editorVM.overlay)
                    ColorPicker("Highlight", selection: $editorVM.highlight)
                }
            } label: {
                Label("Color Tokens (17)", systemImage: "paintpalette")
            }
        } header: {
            Text("Colors")
        } footer: {
            Text("Choose a color palette preset or customize individual colors")
        }
    }
}
