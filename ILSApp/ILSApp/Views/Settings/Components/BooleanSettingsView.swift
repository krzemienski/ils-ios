import SwiftUI
import ILSShared

/// A reusable view for editing boolean configuration settings with a toggle control
struct BooleanSettingsView: View {
    let label: String
    @Binding var value: Bool
    let description: String?

    init(label: String, value: Binding<Bool>, description: String? = nil) {
        self.label = label
        self._value = value
        self.description = description
    }

    var body: some View {
        Toggle(isOn: $value) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.primaryText)

                if let description = description {
                    Text(description)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.green)
    }
}

// MARK: - Preview

#Preview {
    Form {
        Section {
            BooleanSettingsView(
                label: "Include Co-Author",
                value: .constant(true),
                description: "Add Claude as co-author in git commits"
            )

            BooleanSettingsView(
                label: "Extended Thinking",
                value: .constant(false),
                description: "Enable extended thinking mode for complex tasks"
            )

            BooleanSettingsView(
                label: "Simple Toggle",
                value: .constant(true)
            )
        } header: {
            Text("Boolean Settings")
        }
    }
}
