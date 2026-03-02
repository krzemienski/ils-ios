# App Store Rejection Checklist — ILS (Intelligent Local Server)

**Bundle ID:** `com.ils.app`
**Version:** 1.0 (Build 1)
**Prepared:** 2026-02-28
**Purpose:** Comprehensive pre-submission checklist to catch known rejection vectors before App Store review.

Each item is marked:
- ✅ **ADDRESSED** — Mitigation in place; evidence cited
- ⚠️ **NEEDS ATTENTION** — Action required before submission
- ℹ️ **INFORMATIONAL** — No action needed; context only

---

## 1. Backend Dependency Disclosure

Apple Guideline **2.1 (App Completeness)** and **4.2 (Minimum Functionality)** require that apps with external dependencies clearly disclose them and work gracefully in their absence.

| # | Check | Status | Evidence / Notes |
|---|-------|--------|-----------------|
| 1.1 | Backend requirement disclosed in App Review notes | ✅ ADDRESSED | `AppStoreMetadata/en-US/review_notes.txt` Section 1 — step-by-step setup (clone repo, `swift run ILSBackend`). Includes demo server option. |
| 1.2 | App launches without backend connected | ✅ ADDRESSED | `ConnectionManager.swift` defaults to `localhost:9999`. If unreachable, `isConnected = false`. UI shows Disconnected state. |
| 1.3 | Disconnected state shown gracefully (no crash) | ✅ ADDRESSED | App shows "Disconnected" status with prompt to configure server. No crash, no error modal. |
| 1.4 | Non-chat features work without backend | ✅ ADDRESSED | Settings, theme selection (free tier), and onboarding flow are fully local. |
| 1.5 | Backend is free and open-source | ✅ ADDRESSED | MIT License. GitHub URL in review notes: `https://github.com/krzemienski/ils-ios`. |
| 1.6 | Review notes include demo / test server option | ✅ ADDRESSED | Section 3, Option B provides demo server URL and developer contact. |
| 1.7 | Backend is self-hosted (not a paid third-party SaaS) | ✅ ADDRESSED | No revenue dependency on backend. Not a subscription-wall for the backend. |

---

## 2. In-App Purchase Compliance (Guideline 3.1.1)

Apple requires that digital content sold within apps use IAP. Physical goods and third-party services sold outside the app are exempt.

| # | Check | Status | Evidence / Notes |
|---|-------|--------|-----------------|
| 2.1 | Premium subscription uses StoreKit 2 (not external payment) | ✅ ADDRESSED | `SubscriptionManager.swift` uses `StoreKit` framework with `Product.purchase()`. No web-based payment flow. |
| 2.2 | IAP product IDs registered in App Store Connect | ⚠️ NEEDS ATTENTION | Product IDs `com.ils.app.premium.monthly` and `com.ils.app.premium.annual` must be created in App Store Connect → In-App Purchases before TestFlight upload. |
| 2.3 | No external payment links or "go to website to subscribe" UI | ✅ ADDRESSED | No external payment URLs in any SwiftUI view. |
| 2.4 | Free tier provides meaningful functionality | ✅ ADDRESSED | `FeatureGate.swift`: Dashboard, Sessions (up to 5), Projects, Skills browse, MCP status, System monitoring all free. |
| 2.5 | Premium features genuinely improve the experience | ✅ ADDRESSED | Premium unlocks: chat export, all 13 themes, advanced monitoring, unlimited sessions. Disclosed in `description.txt`. |
| 2.6 | "Restore Purchases" button implemented | ✅ ADDRESSED | `SubscriptionManager.swift` implements restore flow. Review notes Section 4f describes how to test. |
| 2.7 | Subscription terms and pricing clearly displayed | ✅ ADDRESSED | StoreKit paywall shows subscription price, duration, and renewal terms from App Store Connect product metadata. |
| 2.8 | No misleading "free" claim that hides required IAP | ✅ ADDRESSED | App Store description explicitly lists premium subscription with pricing. Free tier clearly marked. |
| 2.9 | Subscription cancellation managed by iOS Settings | ✅ ADDRESSED | StoreKit 2 subscriptions are managed by iOS. App does not claim to manage cancellation. |
| 2.10 | Claude Code CLI is optional (not an IAP bypass) | ✅ ADDRESSED | CLI is free, installed by user on their own Mac. Not an in-app purchase. Disclosed in review notes Section 5. |

---

## 3. Privacy Manifest Completeness

Apple requires a `PrivacyInfo.xcprivacy` manifest for all apps (mandatory since Spring 2024) and for any third-party SDKs that access required-reason APIs.

### 3.1 First-Party App Manifest (`ILSApp/ILSApp/PrivacyInfo.xcprivacy`)

| # | Required Reason API | Declared? | Reason Code | Usage | Status |
|---|---------------------|-----------|-------------|-------|--------|
| 3.1.1 | `NSPrivacyAccessedAPICategoryUserDefaults` | ✅ Yes | `CA92.1` | Store server URL, connection settings, theme preferences | ✅ ADDRESSED |
| 3.1.2 | `NSPrivacyAccessedAPICategoryFileTimestamp` | ✅ Yes | `DDA9.1` | `AppLogger.swift` reads file `.size` attribute for log rotation | ✅ ADDRESSED |
| 3.1.3 | `NSPrivacyAccessedAPICategorySystemBootTime` | ✅ Yes | `35F9.1` | `LowPowerModeMonitor.swift` / `CyberpunkEffects.swift` uses `ProcessInfo` | ✅ ADDRESSED |
| 3.1.4 | `NSPrivacyAccessedAPICategoryDiskSpace` | ⚠️ Check | — | `SystemMetrics` views display disk stats — verify these are from backend API (no local API call) | ⚠️ NEEDS VERIFICATION |
| 3.1.5 | `NSPrivacyTracking = false` | ✅ Yes | — | App does not perform cross-app tracking | ✅ ADDRESSED |
| 3.1.6 | `NSPrivacyTrackingDomains = []` | ✅ Yes | — | No tracking domains | ✅ ADDRESSED |
| 3.1.7 | `NSPrivacyCollectedDataTypes = []` | ✅ Yes | — | No data collected per Apple's definition | ✅ ADDRESSED |

### 3.2 Third-Party SDK Privacy Manifests

The following SDKs are linked and may need their own `PrivacyInfo.xcprivacy` files (Apple validates these starting with SDK manifests bundled into the framework):

| # | SDK | Required Reason APIs Used | SDK Manifest Present? | Status |
|---|-----|--------------------------|----------------------|--------|
| 3.2.1 | **GRDB** (`LocalDatabase.swift`) | FileTimestamp, UserDefaults | Check GRDB >= 6.27 (includes manifest) | ⚠️ VERIFY GRDB VERSION |
| 3.2.2 | **MarkdownUI** (`MarkdownTextView.swift`, etc.) | None expected (rendering only) | Likely none needed | ✅ LOW RISK |
| 3.2.3 | **Citadel** (`CitadelSSHService.swift`) | Likely none (network only) | Check Citadel package for manifest | ⚠️ VERIFY CITADEL |

**Action:** Run `xcodebuild -showBuildSettings` and inspect the built `.app` bundle for `PrivacyInfo.xcprivacy` files in framework subdirectories to confirm SDK manifests are present.

---

## 4. Placeholder / Incomplete Content

Guideline **2.1** rejects apps with Lorem Ipsum, "TBD", or clearly placeholder content.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 4.1 | App Store name not placeholder | ✅ ADDRESSED | `name.txt` = "ILS" — final |
| 4.2 | Subtitle not placeholder | ✅ ADDRESSED | `subtitle.txt` = "Claude Code Session Manager" |
| 4.3 | Description fully written | ✅ ADDRESSED | `description.txt` — 500+ word production description |
| 4.4 | Keywords finalized | ✅ ADDRESSED | `keywords.txt` — 100-char limit compliant, relevant terms |
| 4.5 | Promotional text finalized | ✅ ADDRESSED | `promotional_text.txt` — concise marketing copy |
| 4.6 | Release notes written | ✅ ADDRESSED | `release_notes.txt` — feature list for v1.0 |
| 4.7 | Review notes complete | ✅ ADDRESSED | `review_notes.txt` — comprehensive, 5 sections |
| 4.8 | Privacy URL resolves | ⚠️ VERIFY | `https://krzemienski.github.io/ils-ios/privacy` — must be live before submission |
| 4.9 | Support URL resolves | ⚠️ VERIFY | `https://krzemienski.github.io/ils-ios/support` — must be live before submission |
| 4.10 | No Lorem Ipsum in metadata files | ✅ ADDRESSED | Grep confirms no placeholder text in `AppStoreMetadata/` |
| 4.11 | No "TODO" / "FIXME" in user-visible strings | ✅ ADDRESSED | Confirmed via grep |
| 4.12 | Demo server URL in review notes is real or notes it's on-request | ✅ ADDRESSED | Review notes say "Contact developer to verify demo server is active prior to review session" |

---

## 5. App Works Gracefully Without Backend

Guideline **2.1** and the general principle of a complete, functional app apply.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 5.1 | App launches to a usable state without backend | ✅ ADDRESSED | `ConnectionManager` initializes; UI shows Disconnected state with onboarding prompt |
| 5.2 | No crash on launch without backend | ✅ ADDRESSED | All API calls are async with error handling; `isConnected = false` path is fully implemented |
| 5.3 | Disconnected state is informative (not a blank screen) | ✅ ADDRESSED | Dashboard shows "Disconnected" with instructions. Onboarding shown on first launch. |
| 5.4 | Chat gracefully handles missing Claude Code CLI | ✅ ADDRESSED | Review notes Section 5: "Chat tab shows a clear informational message." App does not crash. |
| 5.5 | Settings screen accessible without backend | ✅ ADDRESSED | Settings/theme are local-only; accessible regardless of connection state |
| 5.6 | No network timeout dialog shown to user on launch | ✅ ADDRESSED | `ConnectionManager.connectToServer()` uses `try/catch`; errors go to UI state not system alerts |
| 5.7 | Onboarding shown when no server configured | ✅ ADDRESSED | `showOnboardingIfNeeded()` triggers when `hasConnectedBefore` UserDefault is false |

---

## 6. Screenshots & Visual Assets

Guideline **2.3 (Accurate Metadata)** requires screenshots that match the actual app.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 6.1 | iPhone 6.7" screenshots | ✅ ADDRESSED | 7 screenshots in `AppStoreMetadata/screenshots/iphone_67/` |
| 6.2 | iPhone 6.1" screenshots | ✅ ADDRESSED | 6 screenshots in `AppStoreMetadata/screenshots/iphone_61/` |
| 6.3 | iPhone 5.5" screenshots | ✅ ADDRESSED | Not required — Apple auto-scales from 6.7"; see `AppStoreMetadata/screenshots/iphone_55/README.md` |
| 6.4 | iPad 12.9" (M4/6th gen) screenshots | ✅ ADDRESSED | 6 screenshots in `AppStoreMetadata/screenshots/ipad_13/` |
| 6.5 | iPad 11" screenshots | ✅ ADDRESSED | 6 screenshots in `AppStoreMetadata/screenshots/ipad_11/` |
| 6.6 | Mac screenshots | ✅ ADDRESSED | 5 screenshots in `AppStoreMetadata/screenshots/mac/` |
| 6.7 | Screenshots show real app content (not mockups) | ✅ ADDRESSED | Screenshots generated from live simulator sessions |
| 6.8 | No overlaid device frames violating Apple guidelines | ⚠️ VERIFY | Confirm screenshots are clean (no third-party frame overlays that show competitor devices) |
| 6.9 | Screenshots match declared supported iOS version (17.0+) | ✅ ADDRESSED | Generated on iOS 18 simulator (backward compatible UI) |

---

## 7. App Icon

Guideline **2.3** requires a non-placeholder, professional app icon.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 7.1 | iOS app icon present (1024×1024 PNG) | ✅ ADDRESSED | `ILSApp/ILSApp/Assets.xcassets/AppIcon.appiconset/` — universal 1024×1024 PNG |
| 7.2 | macOS app icon set complete | ✅ ADDRESSED | Full set: 16, 32, 64, 128, 256, 512, 1024 px variants |
| 7.3 | Icon is not a system SF Symbol or Apple-owned icon | ✅ ADDRESSED | Custom ILS brand icon |
| 7.4 | Icon does not contain the Apple logo | ✅ ADDRESSED | No Apple trademarks |
| 7.5 | Icon does not reference competitor trademarks | ✅ ADDRESSED | No third-party marks |
| 7.6 | Icon does not appear to be a placeholder (gradient/letter only) | ⚠️ VERIFY | Confirm final icon design is production-quality before submission |

---

## 8. Prohibited Content

Guidelines **1.1–1.6** cover prohibited content categories.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 8.1 | No adult/sexual content | ✅ ADDRESSED | App is a developer tool; no such content exists |
| 8.2 | No gambling mechanics | ✅ ADDRESSED | Developer tool, no gambling |
| 8.3 | No hate speech or discriminatory content | ✅ ADDRESSED | N/A |
| 8.4 | No content encouraging illegal activity | ✅ ADDRESSED | N/A |
| 8.5 | No malware or harmful code | ✅ ADDRESSED | Open source, MIT license, public GitHub |
| 8.6 | App does not facilitate unauthorized access to systems | ✅ ADDRESSED | SSH feature (`CitadelSSHService.swift`) connects to user's own Mac — no unauthorized access |
| 8.7 | App does not collect user data without consent | ✅ ADDRESSED | No analytics SDK. No data transmitted to developer servers. All data stays on-device or to user's own backend. |
| 8.8 | No private API usage | ⚠️ VERIFY | Run `nm -u` or `otool -L` on the final binary to confirm no private framework usage |

---

## 9. Permissions & Info.plist

Guideline **5.1.1** requires accurate permission usage descriptions.

| # | Permission Key | Declared? | Usage Description | Status |
|---|---------------|-----------|-------------------|--------|
| 9.1 | `NSFaceIDUsageDescription` | ✅ Yes | "Face ID is used to protect your server credentials stored in the Keychain." | ✅ ADDRESSED |
| 9.2 | `NSLocalNetworkUsageDescription` | ⚠️ MISSING | App uses `NSAllowsLocalNetworking` for HTTP to localhost. If any `NWBrowser`/Bonjour discovery is used at runtime, this key is required. | ⚠️ NEEDS VERIFICATION |
| 9.3 | `NSBonjourServices` | ⚠️ CHECK | Review notes mention "Bonjour/mDNS auto-discovery" — if implemented, `_ils._tcp` must be listed. If not implemented, remove the claim from review notes. | ⚠️ NEEDS VERIFICATION |
| 9.4 | Camera, Microphone, Location, Contacts | ✅ Not declared | App does not use these sensors — correct | ✅ ADDRESSED |
| 9.5 | `NSAppTransportSecurity` → `NSAllowsLocalNetworking` | ✅ Yes | Allows HTTP to localhost (port 9999). Does not allow arbitrary HTTP to the internet. | ✅ ADDRESSED |

**Action Required (9.2/9.3):**
1. Confirm whether Bonjour/mDNS auto-discovery is implemented in code.
2. If YES: Add `NSLocalNetworkUsageDescription` to `Info.plist` with a clear reason string, and add `NSBonjourServices` with the service type.
3. If NO: Remove "Bonjour/mDNS" claim from `review_notes.txt` to avoid reviewer confusion.

---

## 10. Metadata Accuracy

Guideline **2.3** prohibits misleading metadata.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 10.1 | App name matches binary name | ✅ ADDRESSED | App name "ILS", bundle name "ILS" |
| 10.2 | Keywords do not include competitor app names | ✅ ADDRESSED | Keywords: `claude code,ai assistant,developer tools,session manager,mcp,skills,plugins,anthropic,terminal,llm,coding,ios dev,ai chat,swift` — no competitor names |
| 10.3 | Description does not claim features not in app | ⚠️ VERIFY | "3,000+ Claude Code skills" in description — verify current count from GitHub. "1,500+ skills" in promotional text — align numbers. |
| 10.4 | "Anthropic" used correctly (not implying Apple endorsement) | ✅ ADDRESSED | Used as descriptive context ("AI by Anthropic"), not as an endorsement claim |
| 10.5 | Rating: app is appropriate for all ages | ✅ ADDRESSED | Developer tool, no age-inappropriate content. Select "4+" rating. |
| 10.6 | Copyright year correct | ⚠️ VERIFY | Set copyright to "2026 Nick Krzemienski" in App Store Connect |
| 10.7 | App category selected (Developer Tools or Productivity) | ⚠️ ACTION | Set Primary Category: **Developer Tools**; Secondary: **Productivity** in App Store Connect |

---

## 11. Build & Technical Requirements

Guideline **2.1** and App Store technical requirements.

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 11.1 | App built with latest Xcode release | ⚠️ VERIFY | Build with Xcode 16+ for iOS 18 SDK compliance |
| 11.2 | Deployment target iOS 17.0+ | ✅ ADDRESSED | `IPHONEOS_DEPLOYMENT_TARGET = 17.0` in project settings |
| 11.3 | App runs on latest iOS release (18.x) | ✅ ADDRESSED | Tested on iOS 18.6 simulator (UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`) |
| 11.4 | App runs on iPad (not iPhone-only stretch) | ✅ ADDRESSED | iPadOS screenshots confirm native iPad support |
| 11.5 | No deprecated API warnings that could become errors | ⚠️ VERIFY | Run `xcodebuild` and check for deprecation warnings in Swift output |
| 11.6 | Bitcode / Privacy report generated | ✅ ADDRESSED | Xcode generates privacy report automatically from `PrivacyInfo.xcprivacy` at archive time |
| 11.7 | Distribution certificate + provisioning profile configured | ⚠️ ACTION | `HC36V7B67Z` team must have a Distribution certificate and App Store provisioning profile for `com.ils.app` |
| 11.8 | App Store Connect app record created | ⚠️ ACTION | Create app record in App Store Connect before first TestFlight upload |

---

## 12. Summary — Items Requiring Action Before Submission

The following items require action before the app can be safely submitted:

| Priority | Item | Action |
|----------|------|--------|
| 🔴 HIGH | **2.2** IAP product IDs in App Store Connect | Create `com.ils.app.premium.monthly` and `com.ils.app.premium.annual` in App Store Connect |
| 🔴 HIGH | **9.2/9.3** Local Network / Bonjour permissions | Audit code for NWBrowser usage; add `NSLocalNetworkUsageDescription` if needed; reconcile review notes |
| 🔴 HIGH | **11.7** Code signing | Obtain Distribution certificate + App Store provisioning profile for `HC36V7B67Z` / `com.ils.app` |
| 🔴 HIGH | **11.8** App Store Connect app record | Create app record before TestFlight upload |
| 🟡 MEDIUM | **3.1.4** DiskSpace API | Verify SystemMetrics views call backend API (not local `FileManager` or `statfs`) — add to manifest if local |
| 🟡 MEDIUM | **3.2.1** GRDB privacy manifest | Verify GRDB version includes `PrivacyInfo.xcprivacy`; update if < 6.27 |
| 🟡 MEDIUM | **3.2.3** Citadel privacy manifest | Verify Citadel includes `PrivacyInfo.xcprivacy` or determine it doesn't access required-reason APIs |
| 🟡 MEDIUM | **4.8/4.9** Privacy & Support URLs | Confirm both GitHub Pages URLs resolve before submission |
| 🟡 MEDIUM | **6.8** Screenshot device frames | Confirm no third-party device frames violate App Store guidelines |
| 🟡 MEDIUM | **7.6** App icon quality | Final review of icon design quality |
| 🟡 MEDIUM | **10.3** Skills count claim | Align "3,000+" (description) vs "1,500+" (promotional text) — pick one accurate number |
| 🟡 MEDIUM | **10.7** App category | Set Developer Tools / Productivity in App Store Connect |
| 🟡 MEDIUM | **10.6** Copyright year | Set "2026" copyright in App Store Connect |
| 🟢 LOW | **8.8** Private API audit | Run binary analysis on final archive to confirm no private APIs |
| 🟢 LOW | **11.1** Xcode version | Confirm built with Xcode 16+ |
| 🟢 LOW | **11.5** Deprecation warnings | Review build logs for deprecation warnings |

---

## 13. Pre-Submission Final Checklist

Run through this gate list immediately before submitting to App Store review:

- [ ] IAP product IDs active in App Store Connect (not in "Ready to Submit" state — needs to be in "Approved" state first if possible, or submit simultaneously)
- [ ] Privacy manifest items verified for DiskSpace API
- [ ] GRDB and Citadel privacy manifests confirmed
- [ ] `NSLocalNetworkUsageDescription` added if Bonjour code exists, OR review notes corrected
- [ ] Privacy URL live: `https://krzemienski.github.io/ils-ios/privacy`
- [ ] Support URL live: `https://krzemienski.github.io/ils-ios/support`
- [ ] Distribution certificate and App Store provisioning profile valid and not expired
- [ ] TestFlight build uploaded and at least one external tester has run the app
- [ ] App Store Connect: category, rating, copyright, pricing all set
- [ ] Skills count claim aligned across description and promotional text
- [ ] Review notes updated if Bonjour section changes
- [ ] Archive built with production scheme (Release, not Debug)
- [ ] Binary validated with `altool` or Xcode Organizer (no errors)

---

*Last updated: 2026-02-28. Update this document after each significant code or metadata change.*
