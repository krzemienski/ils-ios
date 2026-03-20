# Premium Feature Gating

**Type:** Feature Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/Services/FeatureGate.swift`
- `ILSApp/ILSApp/Services/SubscriptionManager.swift`
- `ILSApp/ILSApp/Views/Premium/FeatureGateView.swift`
- `ILSApp/ILSApp/Views/Premium/PremiumView.swift`

## Purpose

Controls access to premium features (chat export, custom themes, advanced monitoring, unlimited sessions) with a non-intrusive upgrade experience that lets free users see what they're missing.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Accesses Feature] --> GateUI{Feature Available?}
        GateUI -->|Yes| Content[Full Feature Access ✅]
        GateUI -->|No| Overlay[Premium Required Overlay]
        Overlay --> Upgrade[Tap Upgrade Button]
        Upgrade --> Paywall[Premium Sheet 🎯 Benefits + pricing]
        Paywall --> Purchase[StoreKit Purchase Flow 🛡️]
        Purchase -->|Success| Content
        Purchase -->|Cancel| Overlay
    end

    subgraph "Back-Stage (Implementation)"
        GateUI --> Check[FeatureGate.isAvailable 🛡️ Single check point]
        Check --> Sub[SubscriptionManager 💾 StoreKit source of truth]
        Sub --> StoreKit[StoreKit 2 🛡️ Apple-managed subscriptions]

        Content --> Imperative[Imperative: FeatureGate.shared ⚡]
        Content --> Declarative[Declarative: FeatureGateView ⚡]
    end

    StoreKit -->|Receipt validated| Sub
    Sub -->|Status change| Check

    Check -->|Error| FreeTier[Fallback to Free 🔄 Never blocks app]
```

## Key Insights

- **Non-Intrusive**: Free users see a tasteful overlay, never a hard block or nag screen
- **Two Usage Patterns**: `FeatureGateView` for SwiftUI views, `FeatureGate.shared.isAvailable()` for imperative logic
- **Single Source of Truth**: `SubscriptionManager` owns premium status via StoreKit 2
- **Graceful Fallback**: If StoreKit fails, app defaults to free tier — never crashes or locks out
- **4 Gated Features**: Chat export, custom themes (10/13), advanced monitoring, unlimited sessions (free: 5 max)

## Change History

- **2026-03-10:** Initial creation
