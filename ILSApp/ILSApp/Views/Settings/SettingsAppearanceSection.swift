import SwiftUI
import ILSShared

// MARK: - Appearance Section

struct SettingsAppearanceSection: View {
    @Environment(\.theme) private var theme: any AppTheme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Appearance")

            NavigationLink {
                ThemePickerView()
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .frame(width: 28, height: 28)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text(themeManager.currentTheme.name)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }
}
