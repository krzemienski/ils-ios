import SwiftUI
import ILSShared

/// A picker view for selecting configuration scope (user/project/local)
struct ScopePickerView: View {
    @Binding var selectedScope: String

    private let availableScopes = ["user", "project", "local"]

    var body: some View {
        Picker("Configuration Scope", selection: $selectedScope) {
            ForEach(availableScopes, id: \.self) { scope in
                HStack {
                    Image(systemName: iconForScope(scope))
                    Text(scope.capitalized)
                }
                .tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Helper Methods

    private func iconForScope(_ scope: String) -> String {
        switch scope {
        case "user":
            return "person.circle"
        case "project":
            return "folder"
        case "local":
            return "doc"
        default:
            return "circle"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ScopePickerView(selectedScope: .constant("user"))
            .padding()

        ScopePickerView(selectedScope: .constant("project"))
            .padding()

        ScopePickerView(selectedScope: .constant("local"))
            .padding()
    }
}
