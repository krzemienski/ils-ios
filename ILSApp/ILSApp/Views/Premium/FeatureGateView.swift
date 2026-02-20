import SwiftUI

// MARK: - FeatureGateView

/// A reusable container that shows content when the user has access,
/// or displays a "Premium Required" overlay prompting upgrade.
///
/// ## Usage
/// ```swift
/// FeatureGateView(feature: .chatExport) {
///     ChatExportButton()
/// }
/// ```
struct FeatureGateView<Content: View>: View {
    let feature: FeatureGate.Feature
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme
    @State private var showPremiumSheet = false

    var body: some View {
        if FeatureGate.shared.isAvailable(feature) {
            content()
        } else {
            premiumRequiredOverlay
                .sheet(isPresented: $showPremiumSheet) {
                    PremiumView()
                }
        }
    }

    // MARK: - Premium Required Overlay

    private var premiumRequiredOverlay: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.textTertiary)

            Text("Premium Required")
                .font(.system(size: theme.fontTitle3, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            Text(featureDescription)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)

            Button {
                showPremiumSheet = true
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Upgrade to Premium")
                        .font(.system(size: theme.fontBody, weight: .semibold))
                }
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, theme.spacingLG)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.accentGradient)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
    }

    // MARK: - Feature Descriptions

    private var featureDescription: String {
        switch feature {
        case .chatExport:
            return "Export chat transcripts as Markdown or PDF with a Premium subscription."
        case .customThemes:
            return "Unlock all 13 visual themes to personalize your experience."
        case .advancedMonitoring:
            return "Access real-time system monitoring and performance metrics."
        case .unlimitedSessions:
            return "Remove the \(FeatureGate.freeSessionLimit)-session limit and create unlimited sessions."
        }
    }
}

// MARK: - Preview

#Preview {
    FeatureGateView(feature: .chatExport) {
        Text("This is premium content")
    }
    .environment(\.theme, ThemeSnapshot(CyberpunkTheme()))
}
