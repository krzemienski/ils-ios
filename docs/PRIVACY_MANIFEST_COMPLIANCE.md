# Privacy Manifest Compliance — ILS (Intelligent Local Server)

**Bundle ID:** `com.ils.app` (iOS), `com.ils.mac` (macOS)
**Version:** 1.0 (Build 1)
**Prepared:** 2026-03-21
**Last Audited:** 2026-03-21
**Purpose:** Consolidated privacy manifest compliance documentation for App Store submission. Covers all required-reason API declarations, third-party dependency audit, tracking exemptions, nutrition label guidance, and zero-telemetry verification.

Each item is marked:
- ✅ **COMPLIANT** — Declaration in place with verified justification
- ⚠️ **ACTION REQUIRED** — Must be resolved before submission
- ℹ️ **INFORMATIONAL** — No action needed; context only

---

## Table of Contents

1. [Privacy Manifest Files Overview](#1-privacy-manifest-files-overview)
2. [Required-Reason API Declarations](#2-required-reason-api-declarations)
3. [Third-Party Dependency Privacy Manifest Audit](#3-third-party-dependency-privacy-manifest-audit)
4. [App Tracking Transparency Exemption](#4-app-tracking-transparency-exemption)
5. [Privacy Nutrition Label Recommendations](#5-privacy-nutrition-label-recommendations)
6. [Zero Telemetry Verification Checklist](#6-zero-telemetry-verification-checklist)

---

## 1. Privacy Manifest Files Overview

ILS ships three privacy manifests — one per target:

| Target | Manifest Path | Purpose |
|--------|--------------|---------|
| **ILSApp** (iOS) | `ILSApp/ILSApp/PrivacyInfo.xcprivacy` | Main iOS app — declares all first-party API usage |
| **ILSMacApp** (macOS) | `ILSApp/ILSMacApp/PrivacyInfo.xcprivacy` | macOS Catalyst/native — mirrors iOS declarations minus widget-specific reasons |
| **ILSWidgets** | `ILSApp/ILSWidgets/PrivacyInfo.xcprivacy` | Widget extension — declares UserDefaults via app group only |

All three manifests declare:
- `NSPrivacyTracking = false`
- `NSPrivacyTrackingDomains = []` (empty)
- `NSPrivacyCollectedDataTypes = []` (empty)

---

## 2. Required-Reason API Declarations

### 2.1 NSPrivacyAccessedAPICategoryUserDefaults

**Declared in:** ILSApp, ILSMacApp, ILSWidgets

| Reason Code | Description | Justification | Key Files |
|-------------|-------------|---------------|-----------|
| `CA92.1` | Access UserDefaults to read/write data accessible only to the app itself | Server URL, connection settings, theme preferences, onboarding state, keyboard shortcuts, UI density, offline cache configuration | `SettingsView.swift`, `ConnectionManager.swift`, `DensityManager.swift`, `KeyboardShortcutStore.swift`, `OfflineCacheSettings.swift`, `AppLogger.swift` |
| `1C8F.1` | Access UserDefaults to read/write data accessible to the app and app groups (widgets) | Widget data sharing via `group.com.ils.app` app group — session counts, connection status, recent project names displayed in widgets | `WidgetDataProvider.swift`, `ILSWidgets/` |

**Targets using each reason:**
- `CA92.1` — ILSApp (iOS), ILSMacApp (macOS)
- `1C8F.1` — ILSApp (iOS), ILSWidgets

**Usage scope:** 73+ Swift files reference `UserDefaults` across the app. All access is for local preferences and app-group widget communication. No UserDefaults data is transmitted off-device.

### 2.2 NSPrivacyAccessedAPICategoryFileTimestamp

**Declared in:** ILSApp, ILSMacApp

| Reason Code | Description | Justification | Key Files |
|-------------|-------------|---------------|-----------|
| `DDA9.1` | Access file timestamps or metadata to display to the user | `AppLogger.swift` reads `.size` attribute for log rotation decisions; `FileBrowserView.swift` displays file metadata; `LocalDatabase.swift` manages local cache file attributes | `AppLogger.swift`, `FileBrowserView.swift`, `LocalDatabase.swift` |
| `C617.1` | Access file timestamps for internal app file management | Internal cache and database file housekeeping — checking modification dates for cache invalidation, log rotation thresholds | `LocalDatabase.swift`, `AppLogger.swift` |

**Not declared in:** ILSWidgets (widgets do not access file timestamps)

### 2.3 NSPrivacyAccessedAPICategorySystemBootTime

**Declared in:** ILSApp, ILSMacApp

| Reason Code | Description | Justification | Key Files |
|-------------|-------------|---------------|-----------|
| `35F9.1` | Access system boot time / uptime to measure elapsed time within the app | `PerformanceMonitor.swift` uses `ProcessInfo` for performance timing; `ConnectionQualityService.swift` measures connection latency using system uptime; `CyberpunkEffects.swift` and `LowPowerModeMonitor.swift` use `ProcessInfo` for animation timing and power state checks | `PerformanceMonitor.swift`, `ConnectionQualityService.swift`, `CyberpunkEffects.swift`, `LowPowerModeMonitor.swift` |

**Not declared in:** ILSWidgets (widgets do not access boot time)

### 2.4 NSPrivacyAccessedAPICategoryDiskSpace

**Status:** ℹ️ NOT DECLARED — Not required

**Rationale:** System metrics views (disk stats) display data fetched from the ILS backend API (`/api/v1/system/metrics`), not from local iOS disk space APIs. The app does not call `FileManager.attributesOfFileSystem(forPath:)` or equivalent local disk space APIs. No declaration needed.

---

## 3. Third-Party Dependency Privacy Manifest Audit

### 3.1 iOS/macOS App Dependencies (via SPM)

Audited all SPM dependencies resolved in `Package.resolved` as of 2026-03-21.

#### Dependencies WITH Privacy Manifests (Apple ecosystem packages)

These packages are maintained by Apple or the Swift Server ecosystem and include `PrivacyInfo.xcprivacy`:

| # | Package | Version | Privacy Manifest | Required-Reason APIs | Status |
|---|---------|---------|-----------------|---------------------|--------|
| 3.1.1 | **swift-nio** | 2.94.0 | ✅ Included | FileTimestamp, SystemBootTime | ✅ COMPLIANT |
| 3.1.2 | **swift-crypto** | 3.15.1 | ✅ Included | None (pure crypto) | ✅ COMPLIANT |
| 3.1.3 | **swift-nio-ssl** | 2.36.0 | ✅ Included | None (TLS layer) | ✅ COMPLIANT |
| 3.1.4 | **swift-nio-http2** | 1.39.0 | ✅ Included | None | ✅ COMPLIANT |
| 3.1.5 | **swift-nio-transport-services** | 1.26.0 | ✅ Included | None | ✅ COMPLIANT |
| 3.1.6 | **swift-collections** | 1.3.0 | ✅ Included | None (data structures) | ✅ COMPLIANT |
| 3.1.7 | **swift-system** | 1.6.4 | ✅ Included | None | ✅ COMPLIANT |
| 3.1.8 | **swift-log** | 1.9.1 | ✅ Included | None | ✅ COMPLIANT |

#### Dependencies WITHOUT Privacy Manifests

These packages do not bundle their own `PrivacyInfo.xcprivacy`. Their required-reason API usage (if any) must be declared in the host app's manifest:

| # | Package | Version | Required-Reason APIs Used | Risk | Status |
|---|---------|---------|--------------------------|------|--------|
| 3.1.9 | **GRDB.swift** | 7.10.0 | FileTimestamp (SQLite file management), UserDefaults (unlikely) | Medium | ⚠️ NO MANIFEST — covered by app's `DDA9.1` / `C617.1` declarations |
| 3.1.10 | **Citadel** | 0.12.0 | None expected (SSH networking via NIO) | Low | ✅ LOW RISK — pure networking, no required-reason APIs |
| 3.1.11 | **MarkdownUI** | 2.4.1 | None (SwiftUI rendering only) | Low | ✅ LOW RISK — no system API access |
| 3.1.12 | **HighlightSwift** | 1.1.0 | None (syntax highlighting only) | Low | ✅ LOW RISK — no system API access |
| 3.1.13 | **BigInt** | 5.7.0 | None (math library) | None | ✅ NO RISK |
| 3.1.14 | **NetworkImage** | 6.0.1 | None expected (async image loading via URLSession) | Low | ✅ LOW RISK — standard URLSession usage |
| 3.1.15 | **Splash** | 0.16.0 | None (code syntax parsing) | None | ✅ NO RISK |
| 3.1.16 | **Yams** | 5.4.0 | None (YAML parsing) | None | ✅ NO RISK |
| 3.1.17 | **swift-nio-ssh** (Joannis fork) | 0.3.5 | None expected (SSH protocol, NIO-based) | Low | ✅ LOW RISK |

#### Backend-Only Dependencies (Not in iOS bundle)

The following are used only by `ILSBackend` (Vapor server) and are NOT included in the iOS/macOS app bundle. They do not require privacy manifest declarations:

| Package | Purpose | In iOS Bundle? |
|---------|---------|---------------|
| Vapor 4.121.1 | HTTP server framework | ❌ No |
| Fluent 4.13.0 | ORM | ❌ No |
| fluent-sqlite-driver 4.8.1 | SQLite driver | ❌ No |
| async-http-client 1.30.3 | HTTP client | ❌ No |
| console-kit 4.15.2 | CLI framework | ❌ No |
| routing-kit 4.9.3 | URL routing | ❌ No |
| multipart-kit 4.7.1 | Multipart parsing | ❌ No |
| websocket-kit 2.16.1 | WebSocket | ❌ No |
| sql-kit 3.34.0 | SQL query building | ❌ No |
| sqlite-kit 4.5.2 | SQLite client | ❌ No |
| sqlite-nio 1.12.2 | SQLite via NIO | ❌ No |

### 3.2 GRDB Privacy Manifest Note

GRDB.swift v7.10.0 does not include a bundled `PrivacyInfo.xcprivacy`. GRDB accesses SQLite database files which involves file timestamp/attribute reads. This usage is covered by the host app's declarations:
- `DDA9.1` — file timestamps displayed to user (database file info)
- `C617.1` — file timestamps for internal file management (WAL, journal files)

**Recommendation:** Monitor GRDB releases for future manifest inclusion. As of v7.10.0, the app-level manifest is sufficient.

---

## 4. App Tracking Transparency Exemption

### 4.1 ATT Framework Not Required

ILS is **exempt** from implementing the App Tracking Transparency (ATT) framework prompt (`ATTrackingManager.requestTrackingAuthorization`).

**Exemption rationale:**

| ATT Requirement | ILS Status | Evidence |
|----------------|-----------|----------|
| App tracks users across other companies' apps/websites | ❌ No | No cross-app identifiers collected |
| App uses IDFA (Advertising Identifier) | ❌ No | No `ASIdentifierManager` or `AdSupport` framework linked |
| App shares data with data brokers | ❌ No | No data transmitted to third parties |
| App uses third-party analytics SDKs that track | ❌ No | No Firebase, Amplitude, Mixpanel, or equivalent SDK |
| App contains advertising | ❌ No | No ad frameworks linked |

### 4.2 Tracking Declaration in Privacy Manifest

All three privacy manifests explicitly declare:
```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>
```

This tells Apple's automated review system that the app does not engage in tracking as defined by Apple's App Tracking Transparency policy.

### 4.3 No Fingerprinting

ILS does not use device characteristics (screen size, installed fonts, hardware model, etc.) to create a device fingerprint. System metrics displayed in the app are fetched from the user's own backend server, not from the local device for identification purposes.

---

## 5. Privacy Nutrition Label Recommendations

The following recommendations are for configuring App Store Connect's Privacy Nutrition Labels (App Privacy section).

### 5.1 Recommended Declarations

| Data Category | Collected? | Recommendation | Rationale |
|---------------|-----------|----------------|-----------|
| **Contact Info** | ❌ No | Do not declare | App does not collect name, email, phone, or address |
| **Health & Fitness** | ❌ No | Do not declare | N/A for developer tools |
| **Financial Info** | ❌ No | Do not declare | StoreKit handles payments; app never sees card data |
| **Location** | ❌ No | Do not declare | No location permissions requested |
| **Sensitive Info** | ❌ No | Do not declare | No biometric data collected (Face ID used for auth only, not stored) |
| **Contacts** | ❌ No | Do not declare | No contacts access |
| **User Content** | ❌ No | Do not declare | Chat messages sent to user's own backend, not to developer |
| **Browsing History** | ❌ No | Do not declare | No web browsing tracked |
| **Search History** | ❌ No | Do not declare | No search data transmitted off-device |
| **Identifiers** | ❌ No | Do not declare | No user ID, device ID, or IDFA collected by developer |
| **Purchases** | ❌ No | Do not declare | StoreKit transactions managed by Apple, not by app |
| **Usage Data** | ❌ No | Do not declare | No analytics transmitted to developer servers |
| **Diagnostics** | ❌ No | Do not declare | MetricKit data stays on-device; no crash reports sent to developer |

### 5.2 Summary for App Store Connect

**Select:** "Data Not Collected"

ILS collects no data from users as defined by Apple's privacy nutrition label categories. All data (sessions, projects, chat messages) flows between the user's device and the user's own self-hosted backend server. The developer (ILS) never receives, stores, or processes any user data.

### 5.3 Key Distinctions

- **StoreKit purchases:** Managed entirely by Apple. The app verifies entitlements locally but does not collect or transmit purchase data.
- **Server connection data:** Server URL is stored locally in UserDefaults. It points to the user's own machine (localhost:9999 by default). No server addresses are transmitted to the developer.
- **Chat/session data:** Sent to the user's own ILS backend, which runs on the user's own Mac. The developer has no access to this data.
- **MetricKit (PerformanceMonitor.swift):** Collects performance metrics locally for display in the app's analytics dashboard. Data is NOT transmitted to any external server or the developer.

---

## 6. Zero Telemetry Verification Checklist

ILS claims zero telemetry / zero tracking. The following checklist verifies this claim.

### 6.1 No Analytics SDKs

| Check | Status | Evidence |
|-------|--------|----------|
| No Firebase SDK | ✅ VERIFIED | Not in `Package.resolved` or any `Package.swift` |
| No Amplitude SDK | ✅ VERIFIED | Not in any dependency manifest |
| No Mixpanel SDK | ✅ VERIFIED | Not in any dependency manifest |
| No Segment SDK | ✅ VERIFIED | Not in any dependency manifest |
| No Sentry SDK | ✅ VERIFIED | Not in any dependency manifest |
| No Crashlytics | ✅ VERIFIED | Not in any dependency manifest |
| No custom analytics endpoint | ✅ VERIFIED | `AnalyticsView.swift` and `AnalyticsViewModel.swift` display data from the user's own backend (`/api/v1/sessions`, `/api/v1/stats`), not from a developer-controlled server |

### 6.2 No Outbound Data to Developer

| Check | Status | Evidence |
|-------|--------|----------|
| No hardcoded analytics URLs | ✅ VERIFIED | Grep for `analytics.`, `telemetry.`, `tracking.` — no matches to external services |
| No developer-controlled API endpoints | ✅ VERIFIED | All API calls go to user-configured server URL (default `localhost:9999`) |
| No phone-home on launch | ✅ VERIFIED | `ConnectionManager.swift` connects only to user-specified server |
| No background URL sessions to external hosts | ✅ VERIFIED | No `BGTaskScheduler` or background URL sessions calling external endpoints |
| No diagnostic uploads | ✅ VERIFIED | `PerformanceMonitor.swift` uses MetricKit locally; no upload mechanism implemented |

### 6.3 No Tracking Infrastructure

| Check | Status | Evidence |
|-------|--------|----------|
| `NSPrivacyTracking = false` in all manifests | ✅ VERIFIED | All 3 manifests (`ILSApp`, `ILSMacApp`, `ILSWidgets`) |
| `NSPrivacyTrackingDomains` is empty | ✅ VERIFIED | All 3 manifests |
| `NSPrivacyCollectedDataTypes` is empty | ✅ VERIFIED | All 3 manifests |
| No IDFA / `AdSupport` framework | ✅ VERIFIED | Not linked in Xcode project |
| No `ATTrackingManager` usage | ✅ VERIFIED | No import of `AppTrackingTransparency` |
| No third-party tracking pixels/SDKs | ✅ VERIFIED | No web views loading tracking scripts |

### 6.4 Data Flow Summary

```
User's iPhone/Mac ←→ User's own ILS Backend (localhost:9999)
                          ↓
                    User's own Claude Code CLI
                          ↓
                    Anthropic API (user's own API key)

Developer (ILS) receives: NOTHING
Apple receives: StoreKit purchase data (standard for all App Store apps)
```

### 6.5 Verification Commands

To independently verify zero telemetry, run these on the built `.app` bundle:

```bash
# Check for tracking frameworks
otool -L ILSApp.app/ILSApp | grep -i -E "analytics|tracking|firebase|amplitude|sentry"
# Expected: no output

# Check for hardcoded external URLs (excluding Apple/GitHub)
strings ILSApp.app/ILSApp | grep -E "https?://" | grep -v -E "apple|github|localhost|127.0.0.1"
# Expected: no analytics/telemetry URLs

# Verify privacy manifest is bundled
find ILSApp.app -name "PrivacyInfo.xcprivacy" -exec echo "Found: {}" \;
# Expected: at least one manifest in app bundle

# Check no AdSupport framework
otool -L ILSApp.app/ILSApp | grep -i adsupport
# Expected: no output
```

---

## Appendix A: Privacy Manifest XML Reference

### ILSApp (iOS) — `ILSApp/ILSApp/PrivacyInfo.xcprivacy`

Declares 3 API categories with 5 reason codes:
- `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`, `1C8F.1`
- `NSPrivacyAccessedAPICategoryFileTimestamp` → `DDA9.1`, `C617.1`
- `NSPrivacyAccessedAPICategorySystemBootTime` → `35F9.1`

### ILSMacApp (macOS) — `ILSApp/ILSMacApp/PrivacyInfo.xcprivacy`

Declares 3 API categories with 4 reason codes:
- `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`
- `NSPrivacyAccessedAPICategoryFileTimestamp` → `DDA9.1`, `C617.1`
- `NSPrivacyAccessedAPICategorySystemBootTime` → `35F9.1`

### ILSWidgets — `ILSApp/ILSWidgets/PrivacyInfo.xcprivacy`

Declares 1 API category with 1 reason code:
- `NSPrivacyAccessedAPICategoryUserDefaults` → `1C8F.1`

---

## Appendix B: Apple Required-Reason API Reference

| API Category | Apple Documentation |
|-------------|-------------------|
| UserDefaults | [TN3186: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api) |
| File Timestamp | Same as above |
| System Boot Time | Same as above |
| Disk Space | Same as above (not used by ILS) |

| Reason Code | Meaning |
|-------------|---------|
| `CA92.1` | Access UserDefaults to read/write data accessible only within the app |
| `1C8F.1` | Access UserDefaults to read/write data via app groups (shared with extensions) |
| `DDA9.1` | Access file timestamps to display to the user |
| `C617.1` | Access file timestamps for internal app file management |
| `35F9.1` | Access system boot time to measure elapsed time within the app |

---

*Document maintained as part of App Store submission compliance. Update when dependencies change or new required-reason APIs are adopted.*
