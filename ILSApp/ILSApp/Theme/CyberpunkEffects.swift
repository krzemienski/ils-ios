import SwiftUI

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
            .shadow(color: color.opacity(opacity * 0.5), radius: radius * 2)
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(reduceMotion ? 0.4 : (isAnimating ? 0.6 : 0.2)),
                radius: reduceMotion ? 10 : (isAnimating ? 15 : 5)
            )
            .onAppear {
                guard !reduceMotion, !isAnimating else { return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !reduceMotion else { return }
                if newPhase == .active {
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1.0 : (active && isAnimating ? 0.5 : 1.0))
            .onAppear {
                guard active, !isAnimating, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onChange(of: active) { oldValue, newValue in
                guard !reduceMotion else { return }
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
                guard active, !reduceMotion else { return }
                if newPhase == .active {
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
    }
}

extension View {
    func pulsing(active: Bool = true) -> some View {
        modifier(PulsingModifier(active: active))
    }
}

// MARK: - Scanline Overlay

/// Module-level cache keyed by "lineSpacing_opacity" — avoids re-creating the tile on every layout pass.
nonisolated(unsafe) private var scanlineTileCache: [String: Image] = [:]

private func makeScanlineTile(lineSpacing: CGFloat, opacity: Double) -> Image {
    let key = "\(lineSpacing)_\(opacity)"
    if let cached = scanlineTileCache[key] {
        return cached
    }

    let height = max(1, Int(lineSpacing))
    guard let context = CGContext(
        data: nil,
        width: 1,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return Image(systemName: "square")
    }

    context.clear(CGRect(x: 0, y: 0, width: 1, height: height))
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: opacity))
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

    guard let cgImage = context.makeImage() else {
        return Image(systemName: "square")
    }

    #if canImport(UIKit)
    let image = Image(uiImage: UIImage(cgImage: cgImage))
    #elseif canImport(AppKit)
    let image = Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: 1, height: height)))
    #endif

    scanlineTileCache[key] = image
    return image
}

struct ScanlineOverlay: View {
    var lineSpacing: CGFloat = 4
    var opacity: Double = 0.03

    var body: some View {
        makeScanlineTile(lineSpacing: lineSpacing, opacity: opacity)
            .resizable(resizingMode: .tile)
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
