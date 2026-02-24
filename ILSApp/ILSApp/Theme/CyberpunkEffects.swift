import SwiftUI
import Foundation

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            // ENRG-05: Single shadow pass instead of double — halves GPU blur render cost.
            .shadow(color: color.opacity(opacity), radius: radius * 1.5)
            .drawingGroup()
    }
}

extension View {
    func subtleGlow(_ color: Color, radius: CGFloat = 5, opacity: Double = 0.3) -> some View {
        modifier(GlowEffect(color: color, radius: radius, opacity: opacity))
    }

    func mediumGlow(_ color: Color, radius: CGFloat = 10, opacity: Double = 0.5) -> some View {
        modifier(GlowEffect(color: color, radius: radius, opacity: opacity))
    }

    func intenseGlow(_ color: Color, radius: CGFloat = 15, opacity: Double = 0.7) -> some View {
        modifier(GlowEffect(color: color, radius: radius, opacity: opacity))
    }
}

// MARK: - Pulsing Glow

struct PulsingGlow: ViewModifier {
    let color: Color
    @State private var isAnimating = false
    @State private var isVisible = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity((reduceMotion || isLowPowerMode) ? 0.4 : (isAnimating ? 0.6 : 0.2)),
                radius: (reduceMotion || isLowPowerMode) ? 10 : (isAnimating ? 15 : 5)
            )
            .onAppear {
                isVisible = true
                guard !reduceMotion, !isLowPowerMode, !isAnimating else { return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isVisible = false
                withAnimation(.linear(duration: 0.1)) {
                    isAnimating = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !reduceMotion, !isLowPowerMode else { return }
                if newPhase == .active, isVisible {
                    guard !isAnimating else { return }
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    withAnimation(.linear(duration: 0.1)) {
                        isAnimating = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name.NSProcessInfoPowerStateDidChange
            )) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                if isLowPowerMode {
                    withAnimation(.linear(duration: 0.1)) {
                        isAnimating = false
                    }
                }
            }
    }
}

extension View {
    func pulsingGlow(_ color: Color) -> some View {
        modifier(PulsingGlow(color: color))
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    let active: Bool
    @State private var isAnimating = false
    @State private var isVisible = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity((reduceMotion || isLowPowerMode) ? 1.0 : (active && isAnimating ? 0.5 : 1.0))
            .onAppear {
                isVisible = true
                guard active, !isAnimating, !reduceMotion, !isLowPowerMode else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isVisible = false
                isAnimating = false
            }
            .onChange(of: active) { oldValue, newValue in
                guard !reduceMotion, !isLowPowerMode else { return }
                if newValue {
                    guard !isAnimating else { return }
                    isAnimating = false // reset before re-arming
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    isAnimating = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard active, !reduceMotion, !isLowPowerMode else { return }
                if newPhase == .active, isVisible {
                    guard !isAnimating else { return }
                    isAnimating = false // reset before re-arming
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    withAnimation(.linear(duration: 0.1)) {
                        isAnimating = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name.NSProcessInfoPowerStateDidChange
            )) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                if isLowPowerMode {
                    isAnimating = false
                }
            }
    }
}

extension View {
    func pulsing(active: Bool = true) -> some View {
        modifier(PulsingModifier(active: active))
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    var lineSpacing: CGFloat = 4
    var opacity: Double = 0.03

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(opacity)))
                y += lineSpacing
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Cyberpunk Card Style

struct CyberpunkCardStyle: ViewModifier {
    @Environment(\.theme) private var theme
    var highlighted: Bool = false
    var accentColor: Color?

    func body(content: Content) -> some View {
        let accent = accentColor ?? theme.accent
        content
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        highlighted ? accent.opacity(0.6) : theme.glassBorder,
                        lineWidth: highlighted ? 1 : 0.5
                    )
            )
            .shadow(
                color: highlighted ? accent.opacity(0.2) : .clear,
                radius: highlighted ? 8 : 0
            )
    }
}

extension View {
    func cyberpunkCard(highlighted: Bool = false, accent: Color? = nil) -> some View {
        modifier(CyberpunkCardStyle(highlighted: highlighted, accentColor: accent))
    }
}
