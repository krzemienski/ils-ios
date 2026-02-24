import SwiftUI
import ILSShared

// MARK: - Theme Spacing Section

struct ThemeSpacingSection: View {
    @Bindable var editorVM: ThemeEditorViewModel

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { editorVM.expandedSections.contains("spacing") },
                    set: { isExpanded in
                        if isExpanded {
                            editorVM.expandedSections.insert("spacing")
                        } else {
                            editorVM.expandedSections.remove("spacing")
                        }
                    }
                )
            ) {
                Group {
                    ThemeSliderRow(label: "Spacing XS", value: $editorVM.spacingXS, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Spacing S", value: $editorVM.spacingS, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Spacing M", value: $editorVM.spacingM, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Spacing L", value: $editorVM.spacingL, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Spacing XL", value: $editorVM.spacingXL, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Spacing XXL", value: $editorVM.spacingXXL, range: 0...100, step: 1)
                }

                Group {
                    ThemeSliderRow(label: "Button Padding Horizontal", value: $editorVM.buttonPaddingHorizontal, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Button Padding Vertical", value: $editorVM.buttonPaddingVertical, range: 0...100, step: 1)
                    ThemeSliderRow(label: "Card Padding", value: $editorVM.cardPadding, range: 0...100, step: 1)
                    ThemeSliderRow(label: "List Item Spacing", value: $editorVM.listItemSpacing, range: 0...100, step: 1)
                }
            } label: {
                Label("Spacing Tokens (10)", systemImage: "arrow.left.and.right")
            }
        } header: {
            Text("Spacing")
        } footer: {
            Text("Spacing values in points")
        }
    }
}
