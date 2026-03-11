# Theme System

**Type:** Feature Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/Theme/ThemeSnapshot.swift`
- `ILSApp/ILSApp/Theme/ThemeManager.swift`
- `ILSApp/ILSApp/Theme/AppTheme.swift`
- `ILSApp/ILSApp/Views/Themes/ThemeEditorView.swift`
- `ILSApp/ILSApp/Services/FeatureGate.swift`

## Purpose

Enables users to personalize their ILS experience with 13 built-in themes (3 free, 10 premium) while maintaining Dynamic Type accessibility and consistent design tokens across all screens.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Opens Themes] --> Browse[Browse 13 Themes ⚡ Live preview]
        Browse --> Select[Select Theme]
        Select --> Preview[Instant Preview ⚡ All screens update]
        Browse --> Edit[Theme Editor 🎯 17 color + 13 typography tokens]
    end

    subgraph "Back-Stage (Implementation)"
        Select --> Gate{Premium Check 🛡️}
        Gate -->|Free: 3 themes| Apply[Apply Theme]
        Gate -->|Premium: all 13| Apply
        Gate -->|Free + premium theme| Paywall[Show Premium Sheet]

        Apply --> Snapshot[ThemeSnapshot 💾 Concrete value struct]
        Snapshot --> Environment[@Environment 🎯 Injected into all views]
        Environment --> DynamicType[@ScaledMetric ✅ Accessibility scaling]

        Edit --> CustomTheme[Custom Theme 💾 User-created]
        CustomTheme --> Gate
    end

    Paywall --> Subscribe[User Subscribes]
    Subscribe --> Apply

    DynamicType --> AllViews[All Views Themed ✅]
    AllViews --> User

    Gate -->|Error| Fallback[Default Theme 🔄 Always works]
```

## Key Insights

- **Live Preview**: Theme changes apply instantly across all screens — no restart needed
- **Accessibility First**: All font sizes use `@ScaledMetric` for Dynamic Type compliance
- **Premium Monetization**: 10/13 themes gated behind subscription — clear upgrade path
- **Concrete Types**: `ThemeSnapshot` struct replaces existential `any AppTheme` — better performance
- **Design Tokens**: 17 color + 13 typography + 10 spacing + 8 radius tokens = full design system

## Change History

- **2026-03-10:** Initial creation
