import SwiftUI

/// Temporary view to validate theme system — DELETE in Phase 2
struct ThemeTestView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                // Header
                Text("Theme: \(theme.name)")
                    .font(.system(size: theme.fontTitle1, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                // Background swatches
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Backgrounds")
                        .font(.system(size: theme.fontTitle3, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    HStack(spacing: theme.spacingSM) {
                        swatch("Primary", theme.bgPrimary)
                        swatch("Secondary", theme.bgSecondary)
                        swatch("Tertiary", theme.bgTertiary)
                        swatch("Sidebar", theme.bgSidebar)
                    }
                }

                // Glass Card demo
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Glass Card")
                        .font(.system(size: theme.fontTitle3, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        Text("This is a glass card")
                            .font(.system(size: theme.fontBody))
                            .foregroundColor(theme.textPrimary)
                        Text("With secondary text below")
                            .font(.system(size: theme.fontBody))
                            .foregroundColor(theme.textSecondary)
                    }
                    .glassCard()
                }

                // Accent button
                AccentButton("Create Session", icon: "plus") {
                    // no-op
                }

                // Entity badges
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Entity Badges")
                        .font(.system(size: theme.fontTitle3, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    HStack(spacing: theme.spacingMD) {
                        ForEach(EntityType.allCases, id: \.self) { entity in
                            EntityBadge(entity, showLabel: true)
                        }
                    }
                }

                // Semantic colors
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Semantic Colors")
                        .font(.system(size: theme.fontTitle3, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    HStack(spacing: theme.spacingSM) {
                        swatch("Success", theme.success)
                        swatch("Warning", theme.warning)
                        swatch("Error", theme.error)
                        swatch("Info", theme.info)
                    }
                }

                // Text hierarchy
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Text Primary")
                        .font(.system(size: theme.fontBody))
                        .foregroundColor(theme.textPrimary)
                    Text("Text Secondary")
                        .font(.system(size: theme.fontBody))
                        .foregroundColor(theme.textSecondary)
                    Text("Text Tertiary")
                        .font(.system(size: theme.fontBody))
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
    }

    private func swatch(_ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.border, lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.textTertiary)
        }
    }
}
