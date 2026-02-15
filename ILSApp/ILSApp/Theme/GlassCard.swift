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
    }
}

extension View {
    func glassCard(padding: CGFloat? = nil) -> some View {
        modifier(GlassCard(padding: padding))
    }
}
