import SwiftUI
import ILSShared

struct ThemePreviewView: View {
    @Binding var theme: CustomTheme

    var body: some View {
        ScrollView {
            VStack(spacing: spacing(\.spacingL)) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: spacing(\.spacingS)) {
                    Text("Theme Preview")
                        .font(titleFont)
                        .foregroundColor(color(\.primaryText))

                    Text("See how your theme looks across different UI components")
                        .font(bodyFont)
                        .foregroundColor(color(\.secondaryText))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(spacing(\.spacingM))
                .background(color(\.background))

                Divider()

                // MARK: - Message Bubbles Section
                previewSection(title: "Message Bubbles") {
                    VStack(alignment: .leading, spacing: spacing(\.spacingM)) {
                        // User message
                        HStack {
                            Spacer()
                            Text("This is a user message bubble")
                                .font(bodyFont)
                                .padding(spacing(\.spacingM))
                                .background(color(\.userBubble))
                                .cornerRadius(cornerRadius(\.bubbleCornerRadius))
                        }

                        // Assistant message
                        HStack {
                            Text("This is an assistant message bubble with more text to show how longer messages appear in the theme")
                                .font(bodyFont)
                                .padding(spacing(\.spacingM))
                                .background(color(\.assistantBubble))
                                .cornerRadius(cornerRadius(\.bubbleCornerRadius))
                            Spacer()
                        }
                    }
                }

                // MARK: - Typography Section
                previewSection(title: "Typography") {
                    VStack(alignment: .leading, spacing: spacing(\.spacingS)) {
                        Text("Title Text")
                            .font(titleFont)
                            .foregroundColor(color(\.primaryText))

                        Text("Headline Text")
                            .font(headlineFont)
                            .foregroundColor(color(\.primaryText))

                        Text("Body text showing primary, secondary, and tertiary text colors")
                            .font(bodyFont)
                            .foregroundColor(color(\.primaryText))

                        Text("Secondary text for less important information")
                            .font(bodyFont)
                            .foregroundColor(color(\.secondaryText))

                        Text("Tertiary text for subtle hints and metadata")
                            .font(captionFont)
                            .foregroundColor(color(\.tertiaryText))

                        Text("Code font example: func helloWorld()")
                            .font(codeFont)
                            .foregroundColor(color(\.primaryText))
                    }
                }

                // MARK: - Buttons Section
                previewSection(title: "Buttons & Actions") {
                    VStack(spacing: spacing(\.spacingM)) {
                        // Primary button
                        Button(action: {}) {
                            Text("Primary Button")
                                .padding(.horizontal, spacing(\.buttonPaddingHorizontal))
                                .padding(.vertical, spacing(\.buttonPaddingVertical))
                                .background(color(\.accent))
                                .foregroundColor(.white)
                                .cornerRadius(cornerRadius(\.buttonCornerRadius))
                        }

                        // Secondary button
                        Button(action: {}) {
                            Text("Secondary Button")
                                .padding(.horizontal, spacing(\.buttonPaddingHorizontal))
                                .padding(.vertical, spacing(\.buttonPaddingVertical))
                                .background(color(\.secondaryBackground))
                                .foregroundColor(color(\.accent))
                                .cornerRadius(cornerRadius(\.buttonCornerRadius))
                        }
                    }
                }

                // MARK: - Status Colors Section
                previewSection(title: "Status Indicators") {
                    VStack(spacing: spacing(\.spacingS)) {
                        statusIndicator(label: "Success", color: color(\.success), icon: "checkmark.circle.fill")
                        statusIndicator(label: "Warning", color: color(\.warning), icon: "exclamationmark.triangle.fill")
                        statusIndicator(label: "Error", color: color(\.error), icon: "xmark.circle.fill")
                        statusIndicator(label: "Info", color: color(\.info), icon: "info.circle.fill")
                    }
                }

                // MARK: - Cards Section
                previewSection(title: "Cards & Containers") {
                    VStack(spacing: spacing(\.spacingM)) {
                        // Primary card
                        VStack(alignment: .leading, spacing: spacing(\.spacingS)) {
                            Text("Card Title")
                                .font(headlineFont)
                                .foregroundColor(color(\.primaryText))
                            Text("This is a card container showing how content is displayed with the theme's background colors and corner radius.")
                                .font(bodyFont)
                                .foregroundColor(color(\.secondaryText))
                        }
                        .padding(spacing(\.cardPadding))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(color(\.secondaryBackground))
                        .cornerRadius(cornerRadius(\.cardCornerRadius))

                        // Tertiary card
                        VStack(alignment: .leading, spacing: spacing(\.spacingS)) {
                            Text("Nested Container")
                                .font(captionFont)
                                .foregroundColor(color(\.secondaryText))
                            Text("Secondary level content")
                                .font(bodyFont)
                                .foregroundColor(color(\.primaryText))
                        }
                        .padding(spacing(\.spacingM))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(color(\.tertiaryBackground))
                        .cornerRadius(cornerRadius(\.cornerRadiusM))
                    }
                }

                // MARK: - Borders & Separators Section
                previewSection(title: "Borders & Separators") {
                    VStack(spacing: spacing(\.spacingM)) {
                        VStack(alignment: .leading, spacing: spacing(\.spacingS)) {
                            Text("Bordered Item")
                                .font(bodyFont)
                                .foregroundColor(color(\.primaryText))
                        }
                        .padding(spacing(\.spacingM))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(color(\.background))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius(\.cornerRadiusM))
                                .stroke(color(\.border), lineWidth: 1)
                        )

                        Rectangle()
                            .fill(color(\.separator))
                            .frame(height: 1)

                        Text("Separator line above")
                            .font(captionFont)
                            .foregroundColor(color(\.tertiaryText))
                    }
                }

                // MARK: - Overlay & Highlight Section
                previewSection(title: "Overlay & Highlight") {
                    VStack(spacing: spacing(\.spacingM)) {
                        ZStack {
                            Text("Background Content")
                                .font(bodyFont)
                                .foregroundColor(color(\.secondaryText))
                                .padding(spacing(\.spacingL))

                            color(\.overlay)
                                .opacity(0.5)
                        }
                        .frame(height: 80)
                        .cornerRadius(cornerRadius(\.cornerRadiusM))

                        Text("Highlighted text to draw attention")
                            .font(bodyFont)
                            .foregroundColor(color(\.primaryText))
                            .padding(spacing(\.spacingS))
                            .background(color(\.highlight))
                            .cornerRadius(cornerRadius(\.cornerRadiusS))
                    }
                }

                // MARK: - Spacing Examples Section
                previewSection(title: "Spacing Scale") {
                    VStack(alignment: .leading, spacing: spacing(\.spacingXS)) {
                        spacingExample(label: "XS", value: spacing(\.spacingXS))
                        spacingExample(label: "S", value: spacing(\.spacingS))
                        spacingExample(label: "M", value: spacing(\.spacingM))
                        spacingExample(label: "L", value: spacing(\.spacingL))
                        spacingExample(label: "XL", value: spacing(\.spacingXL))
                        spacingExample(label: "XXL", value: spacing(\.spacingXXL))
                    }
                }
            }
            .padding(spacing(\.spacingM))
        }
        .background(color(\.background))
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func previewSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing(\.spacingM)) {
            Text(title)
                .font(headlineFont)
                .foregroundColor(color(\.primaryText))

            content()
        }
        .padding(spacing(\.spacingM))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(\.secondaryBackground))
        .cornerRadius(cornerRadius(\.cardCornerRadius))
    }

    private func statusIndicator(label: String, color: Color, icon: String) -> some View {
        HStack(spacing: spacing(\.spacingS)) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .font(bodyFont)
                .foregroundColor(self.color(\.primaryText))
            Spacer()
        }
        .padding(spacing(\.spacingS))
        .background(color.opacity(0.1))
        .cornerRadius(cornerRadius(\.cornerRadiusS))
    }

    private func spacingExample(label: String, value: CGFloat) -> some View {
        HStack(spacing: spacing(\.spacingM)) {
            Text(label)
                .font(captionFont)
                .foregroundColor(color(\.secondaryText))
                .frame(width: 40, alignment: .leading)

            Rectangle()
                .fill(color(\.accent))
                .frame(width: value, height: 20)

            Text("\(Int(value))pt")
                .font(captionFont)
                .foregroundColor(color(\.tertiaryText))
        }
    }

    // MARK: - Theme Accessors

    private func color(_ keyPath: KeyPath<ColorTokens, String?>) -> Color {
        guard let colors = theme.colors,
              let hexString = colors[keyPath: keyPath] else {
            return fallbackColor(keyPath)
        }
        return Color(hex: hexString)
    }

    private func spacing(_ keyPath: KeyPath<SpacingTokens, Double?>) -> CGFloat {
        guard let spacing = theme.spacing,
              let value = spacing[keyPath: keyPath] else {
            return fallbackSpacing(keyPath)
        }
        return CGFloat(value)
    }

    private func cornerRadius(_ keyPath: KeyPath<CornerRadiusTokens, Double?>) -> CGFloat {
        guard let cornerRadius = theme.cornerRadius,
              let value = cornerRadius[keyPath: keyPath] else {
            return fallbackCornerRadius(keyPath)
        }
        return CGFloat(value)
    }

    private var titleFont: Font {
        if let typography = theme.typography,
           let size = typography.titleSize {
            return .system(size: size, weight: fontWeight(typography.titleWeight))
        }
        return ILSTheme.titleFont
    }

    private var headlineFont: Font {
        if let typography = theme.typography,
           let size = typography.headlineSize {
            return .system(size: size, weight: fontWeight(typography.headlineWeight))
        }
        return ILSTheme.headlineFont
    }

    private var bodyFont: Font {
        if let typography = theme.typography,
           let size = typography.bodySize {
            return .system(size: size, weight: fontWeight(typography.bodyWeight))
        }
        return ILSTheme.bodyFont
    }

    private var captionFont: Font {
        if let typography = theme.typography,
           let size = typography.captionSize {
            return .system(size: size)
        }
        return ILSTheme.captionFont
    }

    private var codeFont: Font {
        if let typography = theme.typography,
           let family = typography.monospacedFontFamily,
           let size = typography.bodySize {
            return fontWithFamily(family, size: size)
        }
        return ILSTheme.codeFont
    }

    // MARK: - Fallbacks

    private func fallbackColor(_ keyPath: KeyPath<ColorTokens, String?>) -> Color {
        switch keyPath {
        case \.accent: return ILSTheme.accent
        case \.background: return ILSTheme.background
        case \.secondaryBackground: return ILSTheme.secondaryBackground
        case \.tertiaryBackground: return ILSTheme.tertiaryBackground
        case \.primaryText: return ILSTheme.primaryText
        case \.secondaryText: return ILSTheme.secondaryText
        case \.tertiaryText: return ILSTheme.tertiaryText
        case \.success: return ILSTheme.success
        case \.warning: return ILSTheme.warning
        case \.error: return ILSTheme.error
        case \.info: return ILSTheme.info
        case \.userBubble: return ILSTheme.userBubble
        case \.assistantBubble: return ILSTheme.assistantBubble
        case \.border: return ILSTheme.secondaryText.opacity(0.2)
        case \.separator: return ILSTheme.secondaryText.opacity(0.1)
        case \.overlay: return Color.black.opacity(0.3)
        case \.highlight: return ILSTheme.accent.opacity(0.15)
        default: return .gray
        }
    }

    private func fallbackSpacing(_ keyPath: KeyPath<SpacingTokens, Double?>) -> CGFloat {
        switch keyPath {
        case \.spacingXS: return ILSTheme.spacingXS
        case \.spacingS: return ILSTheme.spacingS
        case \.spacingM: return ILSTheme.spacingM
        case \.spacingL: return ILSTheme.spacingL
        case \.spacingXL: return ILSTheme.spacingXL
        case \.spacingXXL: return 48
        case \.buttonPaddingHorizontal: return ILSTheme.spacingM
        case \.buttonPaddingVertical: return ILSTheme.spacingS
        case \.cardPadding: return ILSTheme.spacingM
        case \.listItemSpacing: return ILSTheme.spacingM
        default: return ILSTheme.spacingM
        }
    }

    private func fallbackCornerRadius(_ keyPath: KeyPath<CornerRadiusTokens, Double?>) -> CGFloat {
        switch keyPath {
        case \.cornerRadiusS: return ILSTheme.cornerRadiusS
        case \.cornerRadiusM: return ILSTheme.cornerRadiusM
        case \.cornerRadiusL: return ILSTheme.cornerRadiusL
        case \.cornerRadiusXL: return ILSTheme.cornerRadiusXL
        case \.buttonCornerRadius: return ILSTheme.cornerRadiusM
        case \.cardCornerRadius: return ILSTheme.cornerRadiusL
        case \.inputCornerRadius: return ILSTheme.cornerRadiusM
        case \.bubbleCornerRadius: return ILSTheme.cornerRadiusL
        default: return ILSTheme.cornerRadiusM
        }
    }

    private func fontWeight(_ weight: String?) -> Font.Weight {
        switch weight?.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    private func fontWithFamily(_ family: String, size: Double) -> Font {
        guard !family.isEmpty else {
            return .system(size: size, design: .default)
        }

        // Map family names to system fonts
        switch family.lowercased() {
        case "sf mono", "sfmono", "sf mono regular":
            return .system(size: size, design: .monospaced)
        case "menlo", "monaco", "courier", "courier new":
            return .custom(family, size: size)
        default:
            return .system(size: size, design: .default)
        }
    }
}

// MARK: - Preview

#Preview {
    ThemePreviewView(theme: .constant(CustomTheme(
        name: "Sample Theme",
        colors: ColorTokens(
            accent: "#FF6600",
            background: "#FFFFFF",
            secondaryBackground: "#F5F5F5",
            tertiaryBackground: "#EEEEEE",
            primaryText: "#000000",
            secondaryText: "#666666",
            tertiaryText: "#999999",
            success: "#00AA00",
            warning: "#FF9900",
            error: "#FF0000",
            info: "#0066FF",
            userBubble: "#FFEDE0",
            assistantBubble: "#F5F5F5"
        )
    )))
}
