import SwiftUI
import ILSShared

// MARK: - Appearance Section

/// Appearance settings section for the Settings screen.
///
/// Provides navigation links to ``ThemePickerView`` for selecting the app-wide
/// color theme and ``DensityPickerView`` for selecting the information density level.
/// Displays the currently active theme name and density level as subtitles,
/// sourced from ``ThemeManager`` and ``DensityManager``.
struct SettingsAppearanceSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(ThemeManager.self) var themeManager
    @Environment(DensityManager.self) var densityManager

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

            NavigationLink {
                DensityPickerView()
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .frame(width: 28, height: 28)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Information Density")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text(densityManager.currentDensity.displayName)
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
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }
}
