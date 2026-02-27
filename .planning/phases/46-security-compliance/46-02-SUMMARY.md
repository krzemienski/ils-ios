---
phase: 46-security-compliance
plan: 02
status: complete
---

# Plan 46-02: StoreKit Config, Trial Eligibility, GDPR Deletion UI

## What Was Built

1. **Products.storekit** -- StoreKit sandbox configuration with two subscription products: monthly ($4.99) and annual ($49.99). Both include 7-day free trial introductory offers (P1W period, free payment mode).

2. **Trial Eligibility Detection** -- `SubscriptionManager` gains `trialEligible` and `trialDurationDays` observable properties. `checkTrialEligibility()` uses StoreKit 2's `isEligibleForIntroOffer` and `introductoryOffer.period` to determine eligibility dynamically. Called at startup and whenever products are refreshed.

3. **Dynamic Trial Display** -- `PremiumView.trialCallout` wrapped in `@ViewBuilder` with eligibility guard. Shows dynamic day count from `trialDurationDays`. Hidden entirely when not eligible. Purchase button text changes: "Start Free Trial" when eligible, "Subscribe Now" when not.

4. **GDPR Deletion UI** -- `SettingsView` gains a "Data & Privacy" section with "Delete All My Data" button. Destructive confirmation alert before executing `DELETE /data/all` via APIClient. Result displayed inline with per-table counts.

## Key Files

### Created
- `ILSApp/Products.storekit`

### Modified
- `ILSApp/ILSApp/Services/SubscriptionManager.swift`
- `ILSApp/ILSApp/Views/Premium/PremiumView.swift`
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift`

## Self-Check: PASSED

- [x] Products.storekit with monthly/annual products and 7-day trials
- [x] SubscriptionManager detects trial eligibility dynamically
- [x] PremiumView shows/hides trial callout based on eligibility
- [x] Purchase button text reflects trial state
- [x] Settings Data & Privacy section with deletion UI
- [x] Destructive confirmation alert
- [x] iOS builds with zero errors
- [x] macOS builds with zero errors
