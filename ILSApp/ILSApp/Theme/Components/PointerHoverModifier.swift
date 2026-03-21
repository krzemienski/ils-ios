import SwiftUI

/// Adds system pointer hover highlighting via `.hoverEffect(.highlight)`.
/// Use on interactive elements (buttons, cards, list rows) to provide
/// automatic pointer feedback on iPad and Mac Catalyst.
struct PointerHoverModifier: ViewModifier {
    var effect: HoverEffect

    func body(content: Content) -> some View {
        content
            .hoverEffect(effect)
    }
}

/// Tracks `.onHover` state and applies visual changes (background color shift,
/// opacity) when the pointer hovers over the view. Follows the GlassCard /
/// FocusRingModifier pattern.
struct HoverStateModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var hoveredOpacity: Double
    var cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius ?? theme.cornerRadius)
                    .fill(theme.accent.opacity(isHovered ? 0.08 : 0))
            )
            .opacity(isHovered ? hoveredOpacity : 1.0)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a system pointer hover effect (e.g. `.highlight`, `.lift`, `.automatic`).
    func pointerHover(_ effect: HoverEffect = .highlight) -> some View {
        modifier(PointerHoverModifier(effect: effect))
    }

    /// Applies a custom hover state with background color shift and optional opacity change.
    func hoverState(hoveredOpacity: Double = 1.0, cornerRadius: CGFloat? = nil) -> some View {
        modifier(HoverStateModifier(hoveredOpacity: hoveredOpacity, cornerRadius: cornerRadius))
    }
}
