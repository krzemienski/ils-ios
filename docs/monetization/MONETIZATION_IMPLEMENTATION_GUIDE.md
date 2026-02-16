# ILS Monetization - Quick Implementation Guide

**Purpose:** Rapid reference for implementing free + premium tier subscription model
**Target:** Development team building StoreKit 2 integration
**Status:** Ready to implement

---

## Quick Summary

```
┌─────────────────────────────────────────────────────────────┐
│ PREMIUM TIER MONETIZATION MODEL                             │
├─────────────────────────────────────────────────────────────┤
│ Pricing: $4.99/month OR $49.99/year                         │
│ Free tier: Chat, sessions, projects, 12 themes              │
│ Premium tier: Export, custom themes, sync, monitoring       │
│ Target conversion: 5-8% of free users                       │
│ Revenue target: $2.5-50K annually                           │
│ Implementation time: 6-8 weeks                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Setup (Week 1-2)

### 1.1 App Store Connect Configuration

1. Go to **App Store Connect** → Your App → In-App Purchases
2. Create subscription product:
   - **Product ID:** `com.ils.app.premium.monthly` (or `.annual`)
   - **Type:** Subscription
   - **Subscription Group:** `premium_subscriptions`
   - **Frequency:** Monthly (or Annual)
   - **Price Tier:** Tier 3 ($4.99) or Tier 90 ($49.99)
   - **Renewal:** Auto-renewable, immediately
3. Set up pricing:
   - **Regions:** US, EU, UK (at minimum)
   - **Localization:** Add descriptions per region
4. Free trial (optional):
   - Enable 7-day free trial
   - No billing until trial ends

### 1.2 Local Development Setup

Create `.storekit` configuration file for testing:

```json
{
  "version": 2,
  "products": [
    {
      "id": "com.ils.app.premium.monthly",
      "type": "subscription",
      "displayName": "ILS Premium - Monthly",
      "price": "4.99",
      "currency": "USD",
      "subscriptionDuration": "P1M",
      "subscriptionGroupId": "group1"
    },
    {
      "id": "com.ils.app.premium.annual",
      "type": "subscription",
      "displayName": "ILS Premium - Annual",
      "price": "49.99",
      "currency": "USD",
      "subscriptionDuration": "P1Y",
      "subscriptionGroupId": "group1"
    }
  ]
}
```

Place in `ILSApp/` directory and select in Xcode scheme.

### 1.3 Entitlements Configuration

Add to `ILSApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-purchase</key>
    <true/>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.ils.app</string>
    </array>
</dict>
</plist>
```

---

## Phase 2: Core Implementation (Week 3-4)

### 2.1 SubscriptionManager Class

Create `Services/SubscriptionManager.swift`:

```swift
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isPremium = false
    @Published var subscription: StoreKit.Product?
    @Published var subscriptions: [StoreKit.Product] = []
    @Published var isLoading = false
    @Published var error: String?

    private var updateTask: Task<Void, Never>?

    init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()

            // Listen for transaction updates
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await updateSubscriptionStatus()
                } else if case .unverified = result {
                    // Handle unverified transaction
                }
            }
        }
    }

    func loadProducts() async {
        do {
            subscriptions = try await Product.products(
                for: [
                    "com.ils.app.premium.monthly",
                    "com.ils.app.premium.annual"
                ]
            )
        } catch {
            self.error = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: StoreKit.Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Handle verification
                if case .verified = verification {
                    await updateSubscriptionStatus()
                    return true
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            self.error = "Purchase failed: \(error.localizedDescription)"
            return false
        }
        return false
    }

    func updateSubscriptionStatus() async {
        var activeSubscription: StoreKit.Product?

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let product = subscriptions.first(where: { $0.id == transaction.productID }) {
                    activeSubscription = product
                    break
                }
            }
        }

        self.subscription = activeSubscription
        self.isPremium = activeSubscription != nil
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            self.error = "Restore failed: \(error.localizedDescription)"
        }
    }
}
```

### 2.2 Feature Gating Setup

Create `Services/FeatureGate.swift`:

```swift
import SwiftUI

struct FeatureGate {
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    // Check if premium feature is available
    static func isPremiumAvailable(in environment: EnvironmentValues) -> Bool {
        // Get subscription manager from environment
        // Return subscription status
        return false // Default to false
    }
}

// View modifier for gating premium features
struct PremiumGated<Content: View>: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let content: () -> Content
    let fallback: (() -> AnyView)?

    var body: some View {
        if subscriptionManager.isPremium {
            content()
        } else if let fallback = fallback {
            fallback()
        } else {
            UpgradePromptView()
        }
    }
}

extension View {
    func premiumGated(
        @ViewBuilder fallback: @escaping () -> AnyView = {
            AnyView(UpgradePromptView())
        }
    ) -> some View {
        PremiumGated(content: { self }, fallback: fallback)
    }
}
```

### 2.3 Update App Entry Point

Modify `ILSAppApp.swift`:

```swift
@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)  // Add this
                .preferredColorScheme(.dark)
        }
    }
}
```

---

## Phase 3: UI Implementation (Week 5-6)

### 3.1 Upgrade Prompt View

Create `Views/Settings/PremiumView.swift`:

```swift
import SwiftUI
import StoreKit

struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("ILS Premium")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Unlock advanced features")
                        .foregroundColor(.gray)
                }
                .padding(.top, 24)

                Spacer()

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "arrow.up.doc",
                        title: "Export Chats",
                        description: "Save sessions as JSON, Markdown, or PDF"
                    )
                    FeatureRow(
                        icon: "paintpalette.fill",
                        title: "Custom Themes",
                        description: "Create unlimited custom themes"
                    )
                    FeatureRow(
                        icon: "icloud.fill",
                        title: "Cloud Sync",
                        description: "Sync across iPhone, iPad, and Mac"
                    )
                    FeatureRow(
                        icon: "chart.bar.fill",
                        title: "Advanced Monitoring",
                        description: "Deep system metrics and analytics"
                    )
                }

                Spacer()

                // Pricing
                VStack(spacing: 12) {
                    if let monthly = subscriptionManager.subscriptions.first(where: { $0.id.contains("monthly") }) {
                        PurchaseButton(monthly, action: { _ in
                            Task {
                                await subscriptionManager.purchase(monthly)
                                dismiss()
                            }
                        })
                        .buttonStyle(.bordered)
                    }

                    if let annual = subscriptionManager.subscriptions.first(where: { $0.id.contains("annual") }) {
                        PurchaseButton(annual, action: { _ in
                            Task {
                                await subscriptionManager.purchase(annual)
                                dismiss()
                            }
                        })
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PremiumView()
            .environmentObject(SubscriptionManager())
    }
}
```

### 3.2 Upgrade Prompt (Small)

Create `Views/Shared/UpgradePromptView.swift`:

```swift
import SwiftUI

struct UpgradePromptView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text("Premium Feature")
                .fontWeight(.semibold)

            Text("Upgrade to ILS Premium to unlock this feature")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: {
                // Navigate to Premium screen
            }) {
                Label("Upgrade to Premium", systemImage: "star.fill")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(16)
    }
}

#Preview {
    UpgradePromptView()
        .environmentObject(SubscriptionManager())
}
```

### 3.3 Settings → Subscriptions

Add to `SettingsView.swift`:

```swift
Section("Subscription") {
    if subscriptionManager.isPremium {
        Label("Premium Active", systemImage: "star.fill")
            .foregroundColor(.green)

        Button(role: .destructive) {
            // Open manage subscriptions
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("Manage Subscription")
        }
    } else {
        NavigationLink("Upgrade to Premium") {
            PremiumView()
        }
    }

    Button(action: {
        Task {
            await subscriptionManager.restorePurchases()
        }
    }) {
        Text("Restore Purchases")
    }
}
```

---

## Phase 4: Feature Gating Examples (Week 7)

### 4.1 Gate: Chat Export

```swift
// In ChatView or wherever export is triggered
if subscriptionManager.isPremium {
    Button(action: exportChat) {
        Label("Export", systemImage: "arrow.up.doc")
    }
} else {
    NavigationLink(destination: PremiumView()) {
        Label("Export (Premium)", systemImage: "lock.fill")
    }
}
```

### 4.2 Gate: Custom Themes

```swift
// In ThemesListView
Section {
    NavigationLink("Create Custom Theme") {
        if subscriptionManager.isPremium {
            ThemeEditorView()
        } else {
            PremiumView()
        }
    }
}
```

### 4.3 Gate: Advanced Monitoring

```swift
// In SystemMetricsView
if subscriptionManager.isPremium {
    AdvancedMetricsChart()
} else {
    VStack {
        Text("Advanced metrics are a premium feature")
        NavigationLink("Upgrade") { PremiumView() }
    }
}
```

---

## Phase 5: Testing (Week 7-8)

### 5.1 Local Testing

```swift
// In Xcode scheme, select StoreKit Configuration File:
// ILSApp → Edit Scheme → Run → Pre-actions
// Xcode will use .storekit file for testing
```

### 5.2 TestFlight Testing

1. Create TestFlight group
2. Add sandbox tester account:
   - **Email:** `sandbox.tester@example.com`
   - **Password:** Any password
3. Build and upload to TestFlight
4. Test full purchase flow:
   - Tap upgrade
   - Purchase with sandbox account
   - Verify `isPremium` becomes true
   - Restart app, verify subscription persists

### 5.3 Checklist

- [ ] Free features work without subscription
- [ ] Premium features show upgrade prompt when locked
- [ ] Purchase completes successfully
- [ ] Subscription persists after restart
- [ ] Free trial works (if enabled)
- [ ] Restore purchases button works
- [ ] Price displays correctly
- [ ] Cancel/refund doesn't break app

---

## Phase 6: App Store Submission

### 6.1 Metadata Updates

1. **Description:**
   ```
   ILS Premium: $4.99/month or $49.99/year

   Features:
   • Export chats (JSON, Markdown, PDF)
   • Custom theme creator
   • iCloud sync across devices
   • Advanced system monitoring
   • Team collaboration tools

   7-day free trial included.
   Subscription renews automatically unless cancelled.
   ```

2. **Keywords:** Add "subscription", "premium", "pro"

3. **Support URL:** Add subscription support page

### 6.2 Privacy Policy Update

Add section:
```
Subscriptions and In-App Purchases

ILS Premium is offered as an auto-renewing subscription.

Pricing:
- $4.99/month (monthly plan)
- $49.99/year (annual plan)
- 7-day free trial available

Your subscription will renew automatically unless cancelled
at least 24 hours before the renewal date through your
iTunes account settings.

We do not sell or share subscription data with third parties.
```

### 6.3 App Store Review Notes

```
ILS Premium is a companion app to Claude Code that adds
advanced features like chat export, custom themes, and
cloud sync.

Free features include full chat access, session management,
and project browsing. Premium adds convenience and
customization features.

Testing with sandbox account:
Email: sandbox.tester@example.com
All features work in free and premium modes.
```

---

## Implementation Checklist

### Code
- [ ] SubscriptionManager class created
- [ ] StoreKit 2 integration complete
- [ ] Feature gates implemented
- [ ] PremiumView created
- [ ] UpgradePromptView created
- [ ] Settings → Subscriptions added
- [ ] Environment injection complete
- [ ] Restore purchases button added

### Configuration
- [ ] App Store Connect products created
- [ ] .storekit file created locally
- [ ] Entitlements configured
- [ ] Sandbox testers added
- [ ] Bundle ID matches App Store Connect

### Testing
- [ ] Local StoreKit testing complete
- [ ] TestFlight testing complete
- [ ] Purchase flow verified
- [ ] Restore purchases verified
- [ ] Free trial tested
- [ ] Free features still work
- [ ] Premium gates working
- [ ] No console errors

### Launch
- [ ] Metadata updated
- [ ] Privacy policy updated
- [ ] Screenshots updated (if needed)
- [ ] Review guidelines approved
- [ ] Submitted to App Store
- [ ] Wait for review (24-48 hours typically)

---

## Common Issues & Fixes

### Issue: "Product not found"
**Solution:** Ensure Product ID matches App Store Connect exactly, wait 24 hours for propagation

### Issue: Purchase succeeds but `isPremium` stays false
**Solution:** Call `updateSubscriptionStatus()` after purchase, check Transaction.currentEntitlements

### Issue: StoreKit configuration not loading
**Solution:** In Xcode scheme, select .storekit file in Run → Pre-actions

### Issue: "Invalid signature" error
**Solution:** Ensure app is signed with correct provisioning profile that has StoreKit entitlements

### Issue: Free trial appears but shouldn't
**Solution:** Check App Store Connect → Subscription → Billing Cycle settings

---

## Revenue Monitoring

### AppStore Connect Dashboard
- **Subscriptions → Reports:**
  - Active subscriptions (count)
  - Subscription events (new, renewal, cancel)
  - Revenue per day/month
  - Churn analysis

### Analytics to Track
```swift
// Log in Analytics
Analytics.log(event: "subscription_purchased", parameters: [
    "product_id": product.id,
    "price": product.displayPrice
])
```

---

## Post-Launch Operations

### Week 1 (Launch)
- Monitor conversion rate (target: 3-5%)
- Fix critical bugs
- Respond to reviews

### Week 2-4
- A/B test pricing if conversion < 2%
- Monitor churn
- Analyze which features users unlock
- Gather user feedback

### Month 2-3
- Optimize feature gates based on data
- Consider team tier if demand exists
- Plan Phase 2 features (iCloud sync, etc.)

---

## Q&A

**Q: Should free tier have limits?**
A: No, keep free tier unlimited/generous. Premium should feel like an enhancement, not essential.

**Q: What if conversion is low?**
A: Test different pricing ($2.99 vs $4.99), messaging, or premium features. Move core value to premium only if needed.

**Q: How to handle free trial?**
A: 7 days free is standard. User must provide payment method, but charged only after trial ends.

**Q: Can I change pricing later?**
A: Yes, but existing subscribers keep old price. New trials/subscribers get new price.

**Q: What about the existing free user base?**
A: Existing free users can upgrade at any time. No forced upgrade.

**Q: Should I email free users about premium?**
A: Use in-app messaging only (no email without consent). Passive prompts are less annoying.

