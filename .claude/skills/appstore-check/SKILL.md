---
name: appstore-check
description: Use when preparing ILS app for App Store submission - runs checklist covering security, builds, metadata, icons, screenshots, privacy policy, setup scripts, and Info.plist validation
---

# App Store Readiness Check

## Overview
Systematic pre-submission validation for the ILS iOS/macOS app. Runs all checks without re-discovering project structure.

## When to Use
- Before App Store submission
- After major changes to verify nothing broke submission readiness
- When asked "is the app ready to ship?"

## Quick Reference

| Check | Command | Pass Criteria |
|-------|---------|---------------|
| iOS Build | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet` | Exit 0 |
| macOS Build | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet` | Exit 0 |
| Backend Build | `swift build` | Exit 0 |
| Security Scan | `grep -rn 'apiKey\|api_key\|secret\|password\|token' Sources/ ILSApp/ --include='*.swift' \| grep -v '//\|Mock\|test\|example'` | Zero real secrets |
| Hardcoded Paths | `grep -rn '/Users/' Sources/ ILSApp/ docs/ --include='*.swift' --include='*.md'` | Zero results |
| Git-tracked DBs | `git ls-files '*.sqlite' '*.db'` | Zero results |
| Info.plist Keys | Check CFBundleDisplayName, ITSAppUsesNonExemptEncryption, NSLocalNetworkUsageDescription | All present |
| App Icons | `ls ILSApp/ILSApp/Assets.xcassets/AppIcon.appiconset/*.png` and macOS equivalent | Files exist, 1024x1024 |
| Screenshots | `ls AppStoreMetadata/screenshots/iphone_67/*.png` | 5+ files, 1320x2868 |
| Metadata Files | `ls AppStoreMetadata/en-US/` | description.txt, keywords.txt, name.txt, subtitle.txt, etc. |
| Privacy Policy | `curl -sf https://krzemienski.github.io/ils-ios/privacy` | HTTP 200 |
| Support URL | `curl -sf https://krzemienski.github.io/ils-ios/support` | HTTP 200 |
| Setup Script | `bash scripts/setup.sh` (on fresh clone) | Exit 0 |
| .gitignore | Check .omc/, .env*, *.log, .build/ are excluded | All present |

## Execution

Run each check sequentially. Report results as:
- **PASS** — check succeeded
- **FAIL** — check failed, with details
- **SKIP** — not applicable or blocked

Generate report at `.claude/audit/appstore-readiness-{date}.md`.

## Character Limits (App Store Connect)

| Field | Max |
|-------|-----|
| App Name | 30 chars |
| Subtitle | 30 chars |
| Keywords | 100 chars |
| Promotional Text | 170 chars |
| Description | 4000 chars |
| Release Notes | 4000 chars |
| Review Notes | 4000 chars |

## Common Failures

| Issue | Fix |
|-------|-----|
| Missing CFBundleDisplayName | Add `CFBundleDisplayName = "ILS"` to Info.plist |
| Exposed API key in git | Revoke key, use BFG to clean history |
| Wrong screenshot dimensions | Resize with `sips --resampleWidth 1320 --resampleHeight 2868` |
| Privacy policy 404 | Enable GitHub Pages on Settings > Pages > Source: /docs |
| Import Crypto vs CryptoKit | Use `import CryptoKit` in Vapor context |
