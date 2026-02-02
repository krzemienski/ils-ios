import SwiftUI

/// ILS Design System
enum ILSTheme {
    // MARK: - Colors

    /// Primary accent color - hot orange
    static let accent = Color(red: 1.0, green: 0.4, blue: 0.0)

    /// Background colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

    /// Text colors
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)

    /// Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    /// Message bubble colors
    static let userBubble = accent.opacity(0.15)
    static let assistantBubble = Color(uiColor: .secondarySystemBackground)

    // MARK: - Typography

    static let titleFont = Font.system(.title, design: .default, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default)
    static let codeFont = Font.system(.body, design: .monospaced)

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    static let cornerRadiusS: CGFloat = 4
    static let cornerRadiusM: CGFloat = 8
    static let cornerRadiusL: CGFloat = 12
    static let cornerRadiusXL: CGFloat = 16

    // MARK: - Shadows

    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.2)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ILSTheme.secondaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(ILSTheme.cornerRadiusM)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.secondaryBackground)
            .foregroundColor(ILSTheme.accent)
            .cornerRadius(ILSTheme.cornerRadiusM)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
