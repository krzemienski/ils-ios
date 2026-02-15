import SwiftUI

/// Launch screen following Liquid Glass design principles with cyberpunk theming
struct LaunchScreenView: View {
    @Environment(\.theme) private var theme
    @State private var isAnimating = false
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        ZStack {
            // Deep background
            theme.bgPrimary
                .ignoresSafeArea()

            // Scanline overlay for cyberpunk effect
            ScanlineOverlay()
                .opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Main icon representation
                ZStack {
                    // Outer glow ring - Liquid Glass inspired
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.6),
                                    theme.accentSecondary.opacity(0.4),
                                    theme.accent.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 2)
                        .opacity(isAnimating ? 1.0 : 0.3)

                    // Middle glass layer
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.bgSecondary.opacity(0.9),
                                    theme.bgPrimary.opacity(0.95)
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    theme.accent.opacity(0.3),
                                    lineWidth: 1
                                )
                        )

                    // Terminal prompt symbol with neon effect
                    VStack(spacing: 4) {
                        Text(">_")
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        theme.accent,
                                        theme.accentSecondary
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: theme.accent.opacity(glowIntensity), radius: 20)
                            .shadow(color: theme.accentSecondary.opacity(glowIntensity), radius: 30)

                        // Subtitle indicator capsules
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                Capsule()
                                    .fill(theme.accent)
                                    .frame(width: 6, height: 2)
                                    .opacity(isAnimating ? 1.0 : 0.3)
                                    .animation(
                                        .easeInOut(duration: 0.8)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: isAnimating
                                    )
                            }
                        }
                    }
                }
                .scaleEffect(isAnimating ? 1.0 : 0.9)

                // App name with cyberpunk styling
                VStack(spacing: 8) {
                    Text("ILS")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .kerning(12)
                        .shadow(color: theme.accent.opacity(0.5), radius: 10)

                    Text("INTELLIGENT LOCAL SERVER")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                        .kerning(3)
                }
                .opacity(isAnimating ? 1.0 : 0.0)
            }

            // Bottom accent line
            VStack {
                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.accent.opacity(0.6),
                                        theme.accentSecondary.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 3)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .delay(Double(index) * 0.1),
                                value: isAnimating
                            )
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                isAnimating = true
            }

            // Pulsing glow effect
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                glowIntensity = 0.8
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
