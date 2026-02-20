import SwiftUI

// MARK: - Theme Preview Card

/// Compact card showing a theme's color palette, name, and author.
///
/// Displays color swatches for the four primary tokens (background, accent, text,
/// secondary text) along with metadata. Shows an "Active" badge when the theme
/// is currently selected, or an "Install" button otherwise.
struct ThemePreviewCard: View {
    @Environment(\.theme) private var theme

    let themeName: String
    let author: String
    let bgColor: Color
    let accentColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Color swatches row
                swatchRow

                // Theme name
                Text(themeName)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                // Author
                Text("by \(author)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)

                // Active / Install badge
                statusBadge
            }
            .padding(theme.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        isActive ? theme.accent : theme.glassBorder,
                        lineWidth: isActive ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(themeName) theme by \(author), \(isActive ? "active" : "available")")
    }

    // MARK: - Swatches

    private var swatchRow: some View {
        HStack(spacing: theme.spacingSM) {
            swatchCircle(color: bgColor, label: "BG")
            swatchCircle(color: accentColor, label: "Accent")
            swatchCircle(color: textColor, label: "Text")
            swatchCircle(color: secondaryTextColor, label: "Sec")
            Spacer()
        }
    }

    private func swatchCircle(color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(theme.border, lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 8, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Group {
            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Active")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.success)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                    Text("Install")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.accent)
            }
        }
    }
}
