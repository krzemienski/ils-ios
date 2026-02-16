import SwiftUI

/// Overlays a blur when the app is not in the active scene phase,
/// preventing sensitive content from appearing in screenshots or the app switcher.
struct ScreenshotProtectionModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot

    func body(content: Content) -> some View {
        content
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        theme.bgPrimary
                        VStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(theme.accent)
                            Text("Content Hidden")
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: scenePhase)
    }
}

extension View {
    /// Hides view content when the app enters the background or app switcher.
    /// Use on screens that display sensitive information (API keys, tokens, credentials).
    func screenshotProtected() -> some View {
        modifier(ScreenshotProtectionModifier())
    }
}
