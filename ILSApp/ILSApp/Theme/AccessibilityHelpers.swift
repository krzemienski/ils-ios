import SwiftUI

// MARK: - WCAG Contrast Ratio Utilities

/// WCAG 2.1 AA contrast ratio requirements:
/// - **Body text** (< 18pt or < 14pt bold): minimum **4.5:1** contrast ratio
/// - **Large text** (≥ 18pt or ≥ 14pt bold): minimum **3:1** contrast ratio
/// - **UI components & graphical objects**: minimum **3:1** contrast ratio
///
/// These helpers allow runtime validation of theme color pairs against WCAG AA
/// standards. Use `contrastRatio(_:on:)` to compute the ratio and
/// `meetsWCAGAA(foreground:background:isLargeText:)` for a quick pass/fail check.
///
/// ## Usage
/// ```swift
/// let ratio = ContrastChecker.contrastRatio(theme.textPrimary, on: theme.bgPrimary)
/// let passes = ContrastChecker.meetsWCAGAA(
///     foreground: theme.textPrimary,
///     background: theme.bgPrimary,
///     isLargeText: false
/// )
/// ```
enum ContrastChecker {

    // MARK: - Constants

    /// Minimum contrast ratio for WCAG AA body text (< 18pt / < 14pt bold).
    static let wcagAABodyMinimum: CGFloat = 4.5

    /// Minimum contrast ratio for WCAG AA large text (≥ 18pt / ≥ 14pt bold)
    /// and UI components / graphical objects.
    static let wcagAALargeTextMinimum: CGFloat = 3.0

    // MARK: - Public API

    /// Computes the WCAG 2.1 contrast ratio between two colors.
    ///
    /// The ratio is always ≥ 1 (identical colors) up to 21 (black on white).
    ///
    /// - Parameters:
    ///   - foreground: The foreground (text) color.
    ///   - background: The background color.
    /// - Returns: The contrast ratio as a `CGFloat`, e.g. 4.5.
    static func contrastRatio(_ foreground: Color, on background: Color) -> CGFloat {
        let fgLuminance = relativeLuminance(of: foreground)
        let bgLuminance = relativeLuminance(of: background)

        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Checks whether a foreground/background color pair meets WCAG AA requirements.
    ///
    /// - Parameters:
    ///   - foreground: The foreground (text) color.
    ///   - background: The background color.
    ///   - isLargeText: `true` for text ≥ 18pt (or ≥ 14pt bold). Defaults to `false`.
    /// - Returns: `true` if the pair meets the minimum contrast ratio.
    static func meetsWCAGAA(
        foreground: Color,
        background: Color,
        isLargeText: Bool = false
    ) -> Bool {
        let ratio = contrastRatio(foreground, on: background)
        let minimum = isLargeText ? wcagAALargeTextMinimum : wcagAABodyMinimum
        return ratio >= minimum
    }

    // MARK: - Private Helpers

    /// Computes the relative luminance of a color per WCAG 2.1 definition.
    ///
    /// Formula: L = 0.2126 * R + 0.7152 * G + 0.0722 * B
    /// where R, G, B are linearized sRGB values.
    private static func relativeLuminance(of color: Color) -> CGFloat {
        let components = color.rgbaComponents
        let r = linearize(components.red)
        let g = linearize(components.green)
        let b = linearize(components.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Linearizes an sRGB channel value (gamma-decodes).
    private static func linearize(_ value: CGFloat) -> CGFloat {
        if value <= 0.04045 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, 2.4)
        }
    }
}

// MARK: - Color RGBA Extraction

private extension Color {
    /// Extracts RGBA components from a SwiftUI `Color`.
    ///
    /// Falls back to opaque black if the color cannot be resolved.
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return (0, 0, 0, 1)
        #endif
    }
}

// MARK: - Accessibility Grouping ViewModifier

/// A `ViewModifier` that groups child elements into a single accessibility
/// element with a combined label, improving VoiceOver navigation.
///
/// ## Usage
/// ```swift
/// HStack {
///     Image(systemName: "folder")
///     Text("Projects")
///     Text("12 items")
/// }
/// .accessibilityGrouped(label: "Projects, 12 items")
/// ```
struct AccessibilityGroupedModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Groups child accessibility elements into a single element with a combined label.
    ///
    /// - Parameters:
    ///   - label: The combined accessibility label for the group.
    ///   - hint: Optional accessibility hint describing the result of interaction.
    ///   - traits: Additional accessibility traits (defaults to none).
    func accessibilityGrouped(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(AccessibilityGroupedModifier(label: label, hint: hint, traits: traits))
    }
}

// MARK: - Scaled Spacing ViewModifier

/// A `ViewModifier` that applies Dynamic Type–scaled padding using `@ScaledMetric`.
///
/// Use this instead of fixed padding values in views that should respect the user's
/// preferred text size. The base value scales proportionally with Dynamic Type.
///
/// ## Usage
/// ```swift
/// Text("Hello")
///     .scaledPadding(12)
/// ```
struct ScaledPaddingModifier: ViewModifier {
    @ScaledMetric private var scaledValue: CGFloat

    init(base: CGFloat) {
        _scaledValue = ScaledMetric(wrappedValue: base)
    }

    func body(content: Content) -> some View {
        content.padding(scaledValue)
    }
}

/// A `ViewModifier` that applies Dynamic Type–scaled padding on specific edges.
struct ScaledEdgePaddingModifier: ViewModifier {
    let edges: Edge.Set
    @ScaledMetric private var scaledValue: CGFloat

    init(edges: Edge.Set, base: CGFloat) {
        self.edges = edges
        _scaledValue = ScaledMetric(wrappedValue: base)
    }

    func body(content: Content) -> some View {
        content.padding(edges, scaledValue)
    }
}

extension View {
    /// Applies padding that scales with Dynamic Type.
    ///
    /// - Parameter base: The base padding value at the default text size.
    func scaledPadding(_ base: CGFloat) -> some View {
        modifier(ScaledPaddingModifier(base: base))
    }

    /// Applies edge-specific padding that scales with Dynamic Type.
    ///
    /// - Parameters:
    ///   - edges: The edges to apply padding to.
    ///   - base: The base padding value at the default text size.
    func scaledPadding(_ edges: Edge.Set, _ base: CGFloat) -> some View {
        modifier(ScaledEdgePaddingModifier(edges: edges, base: base))
    }
}

// MARK: - Scaled Spacing

/// A `ViewModifier` that applies a Dynamic Type–scaled frame height,
/// useful for consistent spacing between sections.
struct ScaledSpacerModifier: ViewModifier {
    @ScaledMetric private var scaledValue: CGFloat

    init(base: CGFloat) {
        _scaledValue = ScaledMetric(wrappedValue: base)
    }

    func body(content: Content) -> some View {
        content.frame(height: scaledValue)
    }
}

extension View {
    /// Applies a frame height that scales with Dynamic Type, useful for spacers.
    ///
    /// - Parameter base: The base height at the default text size.
    func scaledHeight(_ base: CGFloat) -> some View {
        modifier(ScaledSpacerModifier(base: base))
    }
}
