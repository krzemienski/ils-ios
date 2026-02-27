import SwiftUI
import ILSShared

// MARK: - Theme MeshGradient Section

struct ThemeMeshGradientSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("meshGradient") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("meshGradient")
                        } else {
                            editorVM.expandedSections.remove("meshGradient")
                        }
                    }
                )
            ) {
                Toggle("Enable MeshGradient", isOn: $editorVM.meshGradientEnabled)

                if editorVM.meshGradientEnabled {
                    Toggle("Animated", isOn: $editorVM.meshGradientAnimated)

                    Text("3x3 Color Grid")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)

                    // Row 0
                    Group {
                        Text("Row 1")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                        ColorPicker("Top Left", selection: $editorVM.meshGradientColor0)
                        ColorPicker("Top Center", selection: $editorVM.meshGradientColor1)
                        ColorPicker("Top Right", selection: $editorVM.meshGradientColor2)
                    }

                    // Row 1
                    Group {
                        Text("Row 2")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                        ColorPicker("Middle Left", selection: $editorVM.meshGradientColor3)
                        ColorPicker("Middle Center", selection: $editorVM.meshGradientColor4)
                        ColorPicker("Middle Right", selection: $editorVM.meshGradientColor5)
                    }

                    // Row 2
                    Group {
                        Text("Row 3")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                        ColorPicker("Bottom Left", selection: $editorVM.meshGradientColor6)
                        ColorPicker("Bottom Center", selection: $editorVM.meshGradientColor7)
                        ColorPicker("Bottom Right", selection: $editorVM.meshGradientColor8)
                    }

                    // Preview
                    meshGradientPreview
                }
            } label: {
                Label("MeshGradient Background", systemImage: "square.stack.3d.up")
            }
        } header: {
            Text("MeshGradient")
        } footer: {
            Text("A 3x3 grid of colors interpolated across the background. Requires iOS 18+.")
        }
    }

    // MARK: - MeshGradient Preview

    @ViewBuilder
    private var meshGradientPreview: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            let colors: [Color] = [
                editorVM.meshGradientColor0,
                editorVM.meshGradientColor1,
                editorVM.meshGradientColor2,
                editorVM.meshGradientColor3,
                editorVM.meshGradientColor4,
                editorVM.meshGradientColor5,
                editorVM.meshGradientColor6,
                editorVM.meshGradientColor7,
                editorVM.meshGradientColor8
            ]

            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: colors
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        } else {
            Text("MeshGradient preview requires iOS 18+ / macOS 15+")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
        }
    }
}
