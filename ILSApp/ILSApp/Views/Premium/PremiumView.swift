import SwiftUI
import StoreKit

// MARK: - PremiumView

/// Paywall screen presenting subscription options with feature comparison.
///
/// Matches the app's dark theme aesthetic with gradient accents. Displays
/// free vs. premium feature comparison, subscription tiers, and purchase controls.
struct PremiumView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let subscriptionManager = SubscriptionManager.shared
    private let featureGate = FeatureGate.shared

    @State private var selectedProductID: String = SubscriptionManager.annualProductID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingLG) {
                    heroSection
                    featureComparisonSection
                    subscriptionOptionsSection
                    trialCallout
                    purchaseButton
                    restoreLink
                    legalLinks
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingXL)
            }
            .background(theme.bgPrimary.ignoresSafeArea())
            .navigationTitle("ILS Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accentGradient)
                .padding(.top, theme.spacingLG)

            Text("Unlock ILS Premium")
                .font(.system(size: theme.fontTitle1, weight: .bold, design: .default))
                .foregroundStyle(theme.textPrimary)

            Text("Supercharge your Claude Code experience")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(spacing: 0) {
            featureComparisonHeader
            Divider().background(theme.divider)
            featureRow("Core chat interface", free: true, premium: true)
            featureRow("Session management", free: true, premium: true)
            featureRow("Up to \(FeatureGate.freeSessionLimit) sessions", free: true, premium: true)
            featureRow("Unlimited sessions", free: false, premium: true)
            featureRow("Chat export", free: false, premium: true)
            featureRow("All 13 themes", free: false, premium: true)
            featureRow("System monitoring", free: false, premium: true)
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var featureComparisonHeader: some View {
        HStack {
            Text("Feature")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Free")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 60)

            Text("Premium")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 60)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
    }

    private func featureRow(_ name: String, free: Bool, premium: Bool) -> some View {
        VStack(spacing: 0) {
            Divider().background(theme.borderSubtle)
            HStack {
                Text(name)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                checkmark(active: free)
                    .frame(width: 60)

                checkmark(active: premium)
                    .frame(width: 60)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
    }

    private func checkmark(active: Bool) -> some View {
        Image(systemName: active ? "checkmark.circle.fill" : "xmark.circle")
            .font(.system(size: 16))
            .foregroundStyle(active ? theme.success : theme.textTertiary.opacity(0.5))
    }

    // MARK: - Subscription Options

    private var subscriptionOptionsSection: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(subscriptionManager.products, id: \.id) { product in
                subscriptionOptionCard(product: product)
            }
        }
    }

    private func subscriptionOptionCard(product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isAnnual = product.id == SubscriptionManager.annualProductID

        return Button {
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: theme.spacingXS) {
                        Text(isAnnual ? "Annual" : "Monthly")
                            .font(.system(size: theme.fontBody, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        if isAnnual {
                            Text("Save 17%")
                                .font(.system(size: theme.fontCaption, weight: .bold))
                                .foregroundStyle(theme.textOnAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.displayPrice + (isAnnual ? "/yr" : "/mo"))
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .background(isSelected ? theme.accent.opacity(0.1) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trial Callout

    private var trialCallout: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("7-day free trial")
                    .font(.system(size: theme.fontBody, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("Try all premium features risk-free. Cancel anytime.")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .background(theme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                guard let product = subscriptionManager.products.first(
                    where: { $0.id == selectedProductID }
                ) else { return }
                await subscriptionManager.purchase(product)
            }
        } label: {
            Group {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(theme.textOnAccent)
                } else {
                    Text(featureGate.isPremium ? "Already Subscribed" : "Start Free Trial")
                        .font(.system(size: theme.fontBody, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.accentGradient)
            .foregroundStyle(theme.textOnAccent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .disabled(subscriptionManager.isLoading || featureGate.isPremium)
        .opacity(featureGate.isPremium ? 0.6 : 1.0)
    }

    // MARK: - Restore Link

    private var restoreLink: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
                .underline()
        }
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Legal Links

    private var legalLinks: some View {
        HStack(spacing: theme.spacingMD) {
            if let termsURL = URL(string: "https://ils.app/terms") {
                Link("Terms of Service", destination: termsURL)
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }

            Text("|")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)

            if let privacyURL = URL(string: "https://ils.app/privacy") {
                Link("Privacy Policy", destination: privacyURL)
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.top, theme.spacingXS)
    }
}

// MARK: - Preview

#Preview {
    PremiumView()
        .environment(\.theme, ThemeSnapshot(CyberpunkTheme()))
}
