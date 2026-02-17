---
name: appstore-pipeline
description: >
  Parallel App Store submission readiness pipeline for ILS iOS/macOS app. Spawns
  5 simultaneous agents for iPhone screenshots, macOS screenshots, metadata
  validation, security audit, and build verification. Use before App Store
  submission, after major releases, or when asked "is the app ready to ship?"
  Covers screenshots, metadata character limits, privacy policy, encryption
  declarations, and signing. Generates go/no-go report.
---

# App Store Readiness Pipeline

## Before You Start

Ask yourself:
- **Which platform(s)?** iOS-only, macOS-only, or both? Skip irrelevant agents.
- **Is this a first submission or update?** First submission needs ALL checks. Updates can skip metadata if unchanged.
- **Is the backend running on 9999?** Screenshots require live data. Verify: `curl -sf http://localhost:9999/health`

## The 5 Critical Rejection Reasons (from real ILS submissions)

These are the issues Apple WILL reject you for. Check these FIRST:

| # | Rejection Reason | How to Check | Fix |
|---|-----------------|--------------|-----|
| 1 | Missing `ITSAppUsesNonExemptEncryption` | `grep -c ITSAppUsesNonExemptEncryption ILSApp/ILSApp/Info.plist` | Add `<false/>` — app uses HTTPS only (exempt) |
| 2 | Privacy policy URL returns 404 | `curl -sf https://krzemienski.github.io/ils-ios/privacy` | Enable GitHub Pages, check CNAME |
| 3 | Screenshots wrong dimensions | `sips -g pixelWidth -g pixelHeight <file>` | iPhone 6.7": 1320x2868, macOS: 2880x1800 |
| 4 | Missing NSLocalNetworkUsageDescription | `grep -c NSLocalNetworkUsageDescription ILSApp/ILSApp/Info.plist` | Add usage string — app connects to local backend |
| 5 | App crashes on launch without backend | Test with backend OFF | Must show onboarding/setup, not crash |

## Agent Architecture

Launch 5 agents via Task tool with `run_in_background: true`. Each writes to `.claude/audit/appstore-status-{date}.json`.

### Agent 1: iPhone Screenshots (Simulator)

**Target**: `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max) — NO OTHER SIMULATOR.

```bash
# Build, install, launch
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 | head -1)
xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP_PATH"
xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
sleep 3

# Navigate via deep links (MUST be lowercase UUIDs)
for screen in home sessions settings system browser; do
  xcrun simctl openurl booted "ils://$screen"
  sleep 2
  xcrun simctl io booted screenshot "AppStoreMetadata/screenshots/iphone_67/$screen.png"
done
```

**When deep links fail** (shows "Open in ILSApp?" dialog):
1. App is not foregrounded — launch it first with `xcrun simctl launch`
2. URL scheme not registered — check `ils://` in Info.plist
3. Retry 3x with 5s delays before marking BLOCKED

**When screenshots look wrong**:
- Black screen → app hasn't loaded yet, increase sleep to 5s
- Shows onboarding instead of content → backend not running on 9999
- White flash → dark mode not enforced, check `preferredColorScheme(.dark)`

### Agent 2: macOS Screenshots

```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet
# Launch and capture after 5s settle time
open ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app
sleep 5
screencapture -x AppStoreMetadata/screenshots/macos/main.png
```

### Agent 3: Metadata Validation

**Character limits (App Store Connect enforced):**

| Field | Max | File | Check Command |
|-------|-----|------|--------------|
| App Name | 30 | `name.txt` | `wc -c < AppStoreMetadata/en-US/name.txt` |
| Subtitle | 30 | `subtitle.txt` | `wc -c < AppStoreMetadata/en-US/subtitle.txt` |
| Keywords | 100 | `keywords.txt` | `wc -c < AppStoreMetadata/en-US/keywords.txt` |
| Promotional | 170 | `promotional_text.txt` | `wc -c < AppStoreMetadata/en-US/promotional_text.txt` |
| Description | 4000 | `description.txt` | `wc -c < AppStoreMetadata/en-US/description.txt` |

**URL checks:**
```bash
curl -sf https://krzemienski.github.io/ils-ios/privacy && echo "PASS" || echo "FAIL: Privacy policy 404"
curl -sf https://krzemienski.github.io/ils-ios/support && echo "PASS" || echo "FAIL: Support URL 404"
```

### Agent 4: Security Audit

```bash
bash scripts/headless-audit.sh
```

Plus Info.plist checks:
```bash
plutil -extract ITSAppUsesNonExemptEncryption xml1 -o - ILSApp/ILSApp/Info.plist 2>/dev/null || echo "MISSING"
plutil -extract NSLocalNetworkUsageDescription xml1 -o - ILSApp/ILSApp/Info.plist 2>/dev/null || echo "MISSING"
```

### Agent 5: Build Verification

```bash
bash scripts/headless-build.sh all
```

Also verify code signing entitlements exist:
```bash
ls ILSApp/ILSApp/ILSApp.entitlements 2>/dev/null && echo "PASS" || echo "WARN: No entitlements file"
```

## Completion: Go/No-Go Decision

After all agents finish, classify results:

| Category | BLOCK (cannot submit) | WARN (submit with risk) | OK |
|----------|----------------------|------------------------|-----|
| Builds | Any target fails | Warnings present | 0 errors, 0 warnings |
| Screenshots | Missing or wrong dimensions | Minor UI issues | All correct dimensions |
| Metadata | Missing required files | Over character limit | All present and valid |
| Security | Exposed secrets or tracked DBs | Hardcoded paths in non-shipping code | Clean |
| Info.plist | Missing encryption or privacy keys | Missing optional keys | All required keys present |

Generate report at `.claude/audit/appstore-readiness-{date}.md`.

## NEVER

- **NEVER submit without checking `ITSAppUsesNonExemptEncryption`** — Apple rejects 100% of the time if missing
- **NEVER use uppercase UUIDs in deep links** — they silently fail to navigate
- **NEVER capture screenshots with the backend down** — you'll screenshot the onboarding flow, not the real app
- **NEVER use a simulator other than `50523130-57AA-48B0-ABD0-4D59CE455F14`** — other simulators belong to other AI sessions
- **NEVER trust that iPad simulator will connect** — persistent connection errors have blocked iPad screenshots across 4+ sessions; have a fallback plan
- **NEVER skip the "launch without backend" crash test** — this is the #1 real-world crash scenario
