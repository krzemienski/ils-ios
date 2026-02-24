import SwiftUI
import ILSShared

// MARK: - Theme Typography Section

struct ThemeTypographySection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("typography") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("typography")
                        } else {
                            editorVM.expandedSections.remove("typography")
                        }
                    }
                )
            ) {
                Group {
                    Picker("Primary Font Family", selection: $editorVM.primaryFontFamily) {
                        Text("System (Default)").tag("")
                        Text("San Francisco").tag("SF Pro")
                        Text("San Francisco Rounded").tag("SF Pro Rounded")
                        Text("New York").tag("New York")
                        Text("Helvetica").tag("Helvetica")
                        Text("Arial").tag("Arial")
                        Text("Georgia").tag("Georgia")
                        Text("Times New Roman").tag("Times New Roman")
                        Text("Palatino").tag("Palatino")
                        Text("Gill Sans").tag("Gill Sans")
                        Text("Courier").tag("Courier")
                    }

                    Picker("Monospaced Font Family", selection: $editorVM.monospacedFontFamily) {
                        Text("System Monospaced (Default)").tag("")
                        Text("SF Mono").tag("SF Mono")
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("Courier").tag("Courier")
                        Text("Courier New").tag("Courier New")
                    }
                }

                Group {
                    TextField("Title Size", text: $editorVM.titleSize)
                        .keyboardType(.decimalPad)
                    TextField("Headline Size", text: $editorVM.headlineSize)
                        .keyboardType(.decimalPad)
                    TextField("Body Size", text: $editorVM.bodySize)
                        .keyboardType(.decimalPad)
                    TextField("Caption Size", text: $editorVM.captionSize)
                        .keyboardType(.decimalPad)
                    TextField("Footnote Size", text: $editorVM.footnoteSize)
                        .keyboardType(.decimalPad)
                }

                Group {
                    TextField("Title Weight", text: $editorVM.titleWeight)
                    TextField("Headline Weight", text: $editorVM.headlineWeight)
                    TextField("Body Weight", text: $editorVM.bodyWeight)
                }

                Group {
                    TextField("Title Line Height", text: $editorVM.titleLineHeight)
                        .keyboardType(.decimalPad)
                    TextField("Body Line Height", text: $editorVM.bodyLineHeight)
                        .keyboardType(.decimalPad)
                    TextField("Caption Line Height", text: $editorVM.captionLineHeight)
                        .keyboardType(.decimalPad)
                }
            } label: {
                Label("Typography Tokens (13)", systemImage: "textformat")
            }
        } header: {
            Text("Typography")
        } footer: {
            Text("Font families, sizes (in points), weights, and line heights")
        }
    }
}
