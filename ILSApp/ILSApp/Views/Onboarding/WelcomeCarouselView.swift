import SwiftUI

/// Animated 3-slide welcome carousel shown to first-time users.
///
/// Presents ILS's top three differentiators — Mobile Access, MCP Management,
/// and Multi-Agent Coordination — as full-screen swipeable slides with animated
/// SF Symbol icons, feature bullets, and a page indicator.
///
/// ## Callbacks
/// - ``onGetStarted``: Invoked when the user taps "Get Started".
/// - ``onSkip``: Invoked when the user taps the "Skip" text button.
struct WelcomeCarouselView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onGetStarted: () -> Void
    var onSkip: () -> Void

    @State private var currentPage = 0

    private let slides = WelcomeSlide.all

    var body: some View {
        ZStack {
            theme.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Swipeable page content
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        CarouselSlideView(slide: slide, isCurrentSlide: currentPage == index)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif

                // Bottom controls
                bottomControls
            }
        }
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: theme.spacingMD) {
            // Page dots indicator
            PageDotsIndicator(count: slides.count, currentIndex: currentPage)

            // Get Started CTA
            Button {
                HapticManager.impact(.medium)
                onGetStarted()
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Text("Get Started")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    Image(systemName: "arrow.right")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
                .foregroundColor(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.spacingXL)
            .accessibilityLabel("Get Started with ILS")

            // Skip text button
            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, theme.spacingSM)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip onboarding")
        }
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingXL)
    }
}

// MARK: - Slide Data Model

struct WelcomeSlide {
    let icons: [String]
    let title: String
    let subtitle: String
    let bullets: [String]

    static let all: [WelcomeSlide] = [
        WelcomeSlide(
            icons: ["iphone", "antenna.radiowaves.left.and.right"],
            title: "Mobile Access",
            subtitle: "Control Claude Code from anywhere",
            bullets: [
                "Full iOS & macOS native client",
                "Real-time session streaming",
                "Push notifications for long tasks"
            ]
        ),
        WelcomeSlide(
            icons: ["server.rack"],
            title: "MCP Management",
            subtitle: "Manage your Model Context Protocol tools",
            bullets: [
                "Browse and enable MCP servers",
                "Tool call inspection & logging",
                "Hot-reload without restarting"
            ]
        ),
        WelcomeSlide(
            icons: ["person.3.fill"],
            title: "Multi-Agent Coordination",
            subtitle: "Orchestrate multiple AI agents in parallel",
            bullets: [
                "Run concurrent Claude sessions",
                "Team collaboration & shared context",
                "Cross-agent task delegation"
            ]
        )
    ]
}

// MARK: - Individual Slide View

private struct CarouselSlideView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let slide: WelcomeSlide
    let isCurrentSlide: Bool

    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                // Icon cluster with pulsing glow animation
                iconCluster

                // Title & subtitle
                VStack(spacing: theme.spacingSM) {
                    Text(slide.title)
                        .font(.system(size: theme.fontTitle1, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(slide.subtitle)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(isVisible ? 1.0 : 0.0)
                .offset(y: isVisible ? 0 : 10)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.2),
                    value: isVisible
                )

                // Feature bullets wrapped in glass card
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    ForEach(Array(slide.bullets.enumerated()), id: \.offset) { index, bullet in
                        BulletRow(
                            text: bullet,
                            delay: Double(index) * 0.1 + 0.35,
                            isVisible: isVisible
                        )
                    }
                }
                .modifier(GlassCard())
                .padding(.horizontal, theme.spacingXL)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.3),
                    value: isVisible
                )
            }
            .padding(.top, theme.spacingXL)
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingMD)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            // Animate in on first appear
            animateIn()
        }
        .onChange(of: isCurrentSlide) { _, isNowCurrent in
            if isNowCurrent {
                animateIn()
            } else {
                // Reset so re-entry triggers animation again
                isVisible = false
            }
        }
    }

    private func animateIn() {
        guard !isVisible else { return }
        if reduceMotion {
            isVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
        }
    }

    // MARK: - Icon Cluster

    @ViewBuilder
    private var iconCluster: some View {
        ZStack {
            // Radial glow backdrop
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.accent.opacity(0.15),
                            theme.bgPrimary.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 85
                    )
                )
                .frame(width: 170, height: 170)

            if slide.icons.count == 1 {
                // Single centered icon
                Image(systemName: slide.icons[0])
                    .font(.system(size: 72, design: theme.fontDesign))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .pulsingGlow(theme.accent)
                    .scaleEffect(isVisible ? 1.0 : 0.8)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                        value: isVisible
                    )
            } else {
                // Two-icon layout with staggered animation
                HStack(spacing: theme.spacingMD) {
                    ForEach(Array(slide.icons.enumerated()), id: \.offset) { index, icon in
                        Image(systemName: icon)
                            .font(.system(size: 52, design: theme.fontDesign))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [theme.accent, theme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .pulsingGlow(index == 0 ? theme.accent : theme.accentSecondary)
                            .scaleEffect(isVisible ? 1.0 : 0.8)
                            .opacity(isVisible ? 1.0 : 0.0)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.12),
                                value: isVisible
                            )
                    }
                }
            }
        }
        .frame(height: 160)
        .drawingGroup()
    }
}

// MARK: - Bullet Row

private struct BulletRow: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let delay: Double
    let isVisible: Bool

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)

            Text(text)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: isVisible ? 0 : -12)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.4).delay(delay),
            value: isVisible
        )
    }
}

// MARK: - Page Dots Indicator

private struct PageDotsIndicator: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? theme.accent : theme.textTertiary.opacity(0.4))
                    .frame(width: index == currentIndex ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentIndex + 1) of \(count)")
    }
}

// MARK: - Preview

#Preview {
    WelcomeCarouselView {
        // onGetStarted
    } onSkip: {
        // onSkip
    }
}
