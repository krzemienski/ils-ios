import SwiftUI

/// Programmatic app icon generator for ILS following cyberpunk design
/// Render at 1024x1024 and export as PNG for the app icon asset
struct AppIconGenerator: View {
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    private let bgColor = Color(hex: "030306")
    private let accentCyan = Color(hex: "00fff2")
    private let accentMagenta = Color(hex: "ff00ff")
    private let bgElevated = Color(hex: "0e0e16")

    var body: some View {
        ZStack {
            // Layer 1: Background gradient
            RadialGradient(
                colors: [
                    Color(hex: "07070c"),
                    bgColor
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.6
            )

            // Layer 2: Glass ring with gradient
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            accentCyan.opacity(0.7),
                            accentMagenta.opacity(0.7),
                            accentCyan.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.08
                )
                .frame(width: size * 0.75, height: size * 0.75)
                .shadow(color: accentCyan.opacity(0.4), radius: size * 0.01)
                .shadow(color: accentMagenta.opacity(0.3), radius: size * 0.015)

            // Layer 3: Inner glass surface
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            bgElevated.opacity(0.95),
                            bgElevated.opacity(0.85)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
                .frame(width: size * 0.6, height: size * 0.6)
                .overlay(
                    Circle()
                        .stroke(accentCyan.opacity(0.2), lineWidth: size * 0.005)
                )
                .shadow(color: .black.opacity(0.3), radius: size * 0.005, y: size * 0.003)

            // Layer 4: Terminal prompt symbol with gradient and glow
            VStack(spacing: size * 0.02) {
                Text(">_")
                    .font(.system(size: size * 0.32, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                accentCyan,
                                accentMagenta
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: accentCyan.opacity(0.6), radius: size * 0.012)
                    .shadow(color: accentCyan.opacity(0.4), radius: size * 0.024)
                    .shadow(color: accentMagenta.opacity(0.4), radius: size * 0.02)
                    .shadow(color: .black.opacity(0.8), radius: size * 0.002, y: size * 0.002)

                // Layer 5: Accent indicators
                HStack(spacing: size * 0.015) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(accentCyan)
                            .frame(width: size * 0.08, height: size * 0.015)
                            .shadow(color: accentCyan.opacity(0.5), radius: size * 0.005)
                    }
                }
                .opacity(0.8)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Utility to render the icon as PNG data
@MainActor
struct AppIconExporter {
    @available(iOS 16.0, macOS 13.0, *)
    static func renderIcon(size: CGFloat = 1024) -> Data? {
        let renderer = ImageRenderer(content: AppIconGenerator(size: size))
        renderer.scale = 1.0
        #if canImport(UIKit)
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.pngData()
        #elseif canImport(AppKit)
        guard let nsImage = renderer.nsImage else { return nil }
        guard let tiffData = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}

#Preview("App Icon 512") {
    AppIconGenerator(size: 512)
        .background(Color(hex: "030306"))
}

#Preview("App Icon 256") {
    AppIconGenerator(size: 256)
        .background(Color(hex: "030306"))
}
