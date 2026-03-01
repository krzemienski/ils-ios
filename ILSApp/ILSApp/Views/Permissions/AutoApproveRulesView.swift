import SwiftUI

/// Auto-approve rules management view.
///
/// Full implementation provided in subtask-3-4.
/// This stub allows PermissionHistoryView to compile and navigate to the rules editor.
struct AutoApproveRulesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("Auto-Approve Rules")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Coming soon — configure rules for automatic permission approval.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("Auto-Approve Rules")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }
}

#Preview {
    NavigationStack {
        AutoApproveRulesView()
    }
}
