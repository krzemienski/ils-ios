import SwiftUI
import ILSShared

// MARK: - Theme Corner Radius Section

struct ThemeCornerRadiusSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("cornerRadius") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("cornerRadius")
                        } else {
                            editorVM.expandedSections.remove("cornerRadius")
                        }
                    }
                )
            ) {
                Group {
                    ThemeSliderRow(label: "Corner Radius S", value: $editorVM.cornerRadiusS, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Corner Radius M", value: $editorVM.cornerRadiusM, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Corner Radius L", value: $editorVM.cornerRadiusL, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Corner Radius XL", value: $editorVM.cornerRadiusXL, range: 0...50, step: 1)
                }

                Group {
                    ThemeSliderRow(label: "Button Corner Radius", value: $editorVM.buttonCornerRadius, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Card Corner Radius", value: $editorVM.cardCornerRadius, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Input Corner Radius", value: $editorVM.inputCornerRadius, range: 0...50, step: 1)
                    ThemeSliderRow(label: "Bubble Corner Radius", value: $editorVM.bubbleCornerRadius, range: 0...50, step: 1)
                }
            } label: {
                Label("Corner Radius Tokens (8)", systemImage: "square.dashed")
            }
        } header: {
            Text("Corner Radius")
        } footer: {
            Text("Corner radius values in points")
        }
    }
}
