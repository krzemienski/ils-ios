import SwiftUI

// MARK: - Reduced Transparency Background

private struct ReducedTransparencyBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let solidColor: Color
    let transparentBackground: AnyView

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(solidColor)
        } else {
            content.background(transparentBackground)
        }
    }
}

// MARK: - Contrast Adaptive Border

private struct ContrastAdaptiveBorderModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let color: Color
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    var shouldShowBorder: Bool {
        differentiateWithoutColor || colorSchemeContrast == .increased
    }

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(color, lineWidth: shouldShowBorder ? lineWidth : 0)
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a solid color background when the user has enabled Reduce Transparency,
    /// otherwise uses the provided transparent background view.
    func reducedTransparencyBackground<Background: View>(
        solidColor: Color,
        @ViewBuilder transparentBackground: () -> Background
    ) -> some View {
        modifier(ReducedTransparencyBackgroundModifier(
            solidColor: solidColor,
            transparentBackground: AnyView(transparentBackground())
        ))
    }

    /// Adds a visible border when the user has enabled Increase Contrast or
    /// Differentiate Without Color, providing clearer element boundaries.
    func contrastAdaptiveBorder(
        color: Color = .primary,
        lineWidth: CGFloat = 1.0,
        cornerRadius: CGFloat = 8.0
    ) -> some View {
        modifier(ContrastAdaptiveBorderModifier(
            color: color,
            lineWidth: lineWidth,
            cornerRadius: cornerRadius
        ))
    }

    /// Shorthand for setting an accessibility identifier.
    func accessibilityID(_ identifier: String) -> some View {
        accessibilityIdentifier(identifier)
    }
}
