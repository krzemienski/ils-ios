import SwiftUI

/// Modal sheet presenting a guided 5-feature tour of ILS.
///
/// Displays each feature as a full-width page with an animated SF Symbol icon, title,
/// description, and a navigation hint. Users can swipe between pages or use the
/// **Previous** / **Next** navigation buttons. The final page shows a **Done** button
/// that calls ``onComplete``, and a **Skip Tour** button is always visible in the header.
///
/// ## Features Presented
/// 1. Sessions – start Claude Code sessions from iPhone
/// 2. Skills Browser – discover and manage skill packs
/// 3. MCP Management – configure Model Context Protocol servers
/// 4. System Monitor – real-time backend performance metrics
/// 5. Agent Teams – coordinate multiple Claude agents
///
/// ## Accessibility
/// - Respects `accessibilityReduceMotion` — all entrance animations are suppressed.
/// - VoiceOver: each feature page is combined into a single element describing the
///   title, description, and navigation hint.
/// - Page indicator announces current page index to assistive technology.
///
/// ## Callbacks
/// - ``onComplete``: Invoked when the user taps "Done" on the last page or "Skip Tour".
struct FeatureTourView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onComplete: () -> Void

    @State private var currentPage = 0

    private let features = FeatureTourItem.all

    var body: some View {
        ZStack {
            theme.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                tourHeader

                TabView(selection: $currentPage) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        TourFeatureCardView(feature: feature, isCurrentPage: currentPage == index)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentPage)

                tourBottomControls
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var tourHeader: some View {
        HStack {
            Text("What's Inside")
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button {
                HapticManager.selection()
                onComplete()
            } label: {
                Text("Skip Tour")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, theme.spacingXS)
                    .padding(.horizontal, theme.spacingSM)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip feature tour")
        }
        .padding(.horizontal, theme.spacingXL)
        .padding(.top, theme.spacingLG)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private var tourBottomControls: some View {
        VStack(spacing: theme.spacingMD) {
            TourPageDotsIndicator(count: features.count, currentIndex: currentPage)

            HStack(spacing: theme.spacingMD) {
                // Previous button
                Button {
                    HapticManager.impact(.light)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                        currentPage = max(0, currentPage - 1)
                    }
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        Text("Previous")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    }
                    .foregroundStyle(currentPage == 0 ? theme.textTertiary : theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 2)
                    .background(theme.glassBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .stroke(theme.glassBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(currentPage == 0)
                .accessibilityLabel("Go to previous feature")

                // Next / Done button
                Button {
                    HapticManager.impact(.medium)
                    if currentPage == features.count - 1 {
                        onComplete()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            currentPage = min(features.count - 1, currentPage + 1)
                        }
                    }
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Text(currentPage == features.count - 1 ? "Done" : "Next")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        Image(
                            systemName: currentPage == features.count - 1
                                ? "checkmark"
                                : "chevron.right"
                        )
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    }
                    .foregroundColor(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 2)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    currentPage == features.count - 1
                        ? "Done with feature tour"
                        : "Go to next feature"
                )
            }
            .padding(.horizontal, theme.spacingXL)
        }
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingXL)
    }
}

// MARK: - Feature Data Model

struct FeatureTourItem {
    let icon: String
    let title: String
    let description: String
    let navigationHint: String

    static let all: [FeatureTourItem] = [
        FeatureTourItem(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Sessions",
            description: "Start Claude Code sessions from your iPhone",
            navigationHint: "Tap Sessions in the sidebar to get started"
        ),
        FeatureTourItem(
            icon: "puzzlepiece.extension.fill",
            title: "Skills Browser",
            description: "Discover and manage Claude skill packs",
            navigationHint: "Browse and activate skills from the Skills tab"
        ),
        FeatureTourItem(
            icon: "network",
            title: "MCP Management",
            description: "Configure Model Context Protocol servers",
            navigationHint: "Add and configure MCP servers in Settings"
        ),
        FeatureTourItem(
            icon: "chart.bar.xaxis",
            title: "System Monitor",
            description: "Real-time backend performance metrics",
            navigationHint: "Check system health from the Monitor view"
        ),
        FeatureTourItem(
            icon: "person.3.sequence.fill",
            title: "Agent Teams",
            description: "Coordinate multiple Claude agents",
            navigationHint: "Manage agent teams from the Teams tab"
        )
    ]
}

// MARK: - Feature Card View

private struct TourFeatureCardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let feature: FeatureTourItem
    let isCurrentPage: Bool

    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                featureIconView

                VStack(spacing: theme.spacingSM) {
                    Text(feature.title)
                        .font(.system(size: theme.fontTitle1, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(feature.description)
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

                navigationHintCard
            }
            .padding(.top, theme.spacingXL)
            .padding(.horizontal, theme.spacingXL)
            .padding(.bottom, theme.spacingMD)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            animateIn()
        }
        .onChange(of: isCurrentPage) { _, isNowCurrent in
            if isNowCurrent {
                animateIn()
            } else {
                isVisible = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(feature.title): \(feature.description). \(feature.navigationHint)"
        )
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

    // MARK: - Icon View

    @ViewBuilder
    private var featureIconView: some View {
        ZStack {
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

            Image(systemName: feature.icon)
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
        }
        .frame(height: 160)
        .drawingGroup()
    }

    // MARK: - Navigation Hint Card

    @ViewBuilder
    private var navigationHintCard: some View {
        HStack(spacing: theme.spacingMD) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(theme.accent)

            Text(feature.navigationHint)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .modifier(GlassCard())
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 8)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.35),
            value: isVisible
        )
    }
}

// MARK: - Page Dots Indicator

private struct TourPageDotsIndicator: View {
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
        .accessibilityLabel("Feature \(currentIndex + 1) of \(count)")
    }
}

// MARK: - Preview

#Preview {
    FeatureTourView {
        // onComplete
    }
}
