import SwiftUI

struct GlassCard: ViewModifier {
    @Environment(\.theme) private var theme
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? theme.spacingMD)
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.glassBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(padding: CGFloat? = nil) -> some View {
        modifier(GlassCard(padding: padding))
    }
}
