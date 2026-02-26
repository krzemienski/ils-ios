import SwiftUI

struct GlassCard: ViewModifier {
    @Environment(\.theme) private var theme
    var padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? theme.spacingMD)
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: theme.accent.opacity(0.08), radius: 8, x: 0, y: 0)
            .drawingGroup() // Offload shadow compositing to Metal
    }
}

extension View {
    func glassCard(padding: CGFloat? = nil) -> some View {
        modifier(GlassCard(padding: padding))
    }
}

struct FocusRingModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let isFocused: Bool
    var cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius ?? theme.cornerRadius)
                    .stroke(theme.accent, lineWidth: isFocused ? 2 : 0)
                    .opacity(isFocused ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

extension View {
    func focusRing(isFocused: Bool, cornerRadius: CGFloat? = nil) -> some View {
        modifier(FocusRingModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}
