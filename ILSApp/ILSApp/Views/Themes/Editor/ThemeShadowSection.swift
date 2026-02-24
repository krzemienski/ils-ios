import SwiftUI
import ILSShared

// MARK: - Theme Shadow Section

struct ThemeShadowSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("shadows") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("shadows")
                        } else {
                            editorVM.expandedSections.remove("shadows")
                        }
                    }
                )
            ) {
                Group {
                    Text("Light Shadow")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                    ColorPicker("Color", selection: $editorVM.shadowLightColor)
                    TextField("Opacity", text: $editorVM.shadowLightOpacity)
                        .keyboardType(.decimalPad)
                    TextField("Radius", text: $editorVM.shadowLightRadius)
                        .keyboardType(.decimalPad)
                    TextField("Offset X", text: $editorVM.shadowLightOffsetX)
                        .keyboardType(.decimalPad)
                    TextField("Offset Y", text: $editorVM.shadowLightOffsetY)
                        .keyboardType(.decimalPad)
                }

                Group {
                    Text("Medium Shadow")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                    ColorPicker("Color", selection: $editorVM.shadowMediumColor)
                    TextField("Opacity", text: $editorVM.shadowMediumOpacity)
                        .keyboardType(.decimalPad)
                    TextField("Radius", text: $editorVM.shadowMediumRadius)
                        .keyboardType(.decimalPad)
                    TextField("Offset X", text: $editorVM.shadowMediumOffsetX)
                        .keyboardType(.decimalPad)
                    TextField("Offset Y", text: $editorVM.shadowMediumOffsetY)
                        .keyboardType(.decimalPad)
                }

                Group {
                    Text("Heavy Shadow")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                    ColorPicker("Color", selection: $editorVM.shadowHeavyColor)
                    TextField("Opacity", text: $editorVM.shadowHeavyOpacity)
                        .keyboardType(.decimalPad)
                    TextField("Radius", text: $editorVM.shadowHeavyRadius)
                        .keyboardType(.decimalPad)
                    TextField("Offset X", text: $editorVM.shadowHeavyOffsetX)
                        .keyboardType(.decimalPad)
                    TextField("Offset Y", text: $editorVM.shadowHeavyOffsetY)
                        .keyboardType(.decimalPad)
                }
            } label: {
                Label("Shadow Tokens (15)", systemImage: "shadow")
            }
        } header: {
            Text("Shadows")
        } footer: {
            Text("Shadow properties: color (hex), opacity (0-1), radius and offsets (points)")
        }
    }
}
