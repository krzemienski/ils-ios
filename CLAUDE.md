# ILS iOS/macOS App — Project Instructions

## Project Context

This is a **Swift iOS/macOS monorepo** for ILS (Intelligent Local Server), a native client for Claude Code.

**Key Paths:**
- `ILSApp/ILSApp/` — iOS app source (SwiftUI)
- `ILSApp/ILSMacApp/` — macOS app source (SwiftUI)
- `ILSApp/ILSApp.xcodeproj` — Xcode project (also `project.yml` for XcodeGen)
- `Sources/ILSBackend/` — Vapor backend (Swift)
- `Sources/ILSShared/` — Shared models between iOS and backend
- `scripts/` — setup.sh, install-backend-service.sh, run_regression_tests.sh
- `.claude/plan/` — Planning documents
- `.sop/` — Structured operating procedures and specs
- `AppStoreMetadata/` — Screenshots and metadata for App Store submission

**Bundle ID:** `com.ils.app` (iOS), `com.ils.mac` (macOS)
**URL Scheme:** `ils://` (registered in Info.plist)
**Backend Port:** 9999 (avoid 8080 — used by ralph-mobile)
**API Prefix:** `/api/v1` (added by APIClient.swift)

**Backend Controllers:** Sessions, Projects, Chat, Skills, MCP, Plugins, Config, Stats, Themes, System, Teams, Tunnel

**Build Commands:**
```bash
# iOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

# macOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet

# Backend
PORT=9999 swift run ILSBackend
```

**Dedicated Simulator (NEVER use any other):**
- UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`
- iPhone 16 Pro Max, iOS 18.6
- Other simulators belong to other AI sessions — DO NOT TOUCH

---

## Working Style

### Implement Immediately
When asked to fix or implement something, **start with implementation immediately**. Do NOT spend the entire session in planning/discovery mode reading files repeatedly. Limit exploration to what's strictly necessary, then make changes. If you need context, do a focused search — don't read every file in the project.

### No Redundant File Reads
Do not re-read files that have already been read in this session unless they have been modified since. Track what you've already analyzed. Re-reading wastes context window budget.

### Stay Focused — No Scope Creep
When fixing a specific bug or build error, **stay focused on that issue**. Do NOT escalate into full workspace reorganization, architecture changes, or broad refactoring unless explicitly asked. Fix the problem, verify the fix, move on.

### One Change, One Verify
Make a change. Verify it works. Then make the next change. Do not batch 5 changes and then discover 3 of them broke the build.

---

## Build & Verification

### Incremental Build Verification
After ANY code change to Swift files, run `xcodebuild` immediately to verify the build succeeds before moving on. Do not batch multiple changes without build verification.

```bash
# Quick iOS build check
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5

# Quick macOS build check
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5

# Backend build check
swift build 2>&1 | tail -5
```

### Build Failure Protocol
If a build fails:
1. Read the FULL error output (not just the first error)
2. Fix ALL errors in one pass (Swift errors often cascade)
3. Re-run the build
4. Do NOT introduce new files, reorganize the project, or switch to XcodeGen as a "fix"

### Backend Verification
Always verify backend is running from the correct binary:
```bash
lsof -i :9999 -P -n  # Binary path MUST be in ils-ios, NOT ils/ILSBackend
curl -s http://localhost:9999/health
curl -s http://localhost:9999/api/v1/sessions | head -100
```

---

## Common Pitfalls (from real sessions)

- **Wrong backend binary**: OLD backend at `/Users/nick/ils/ILSBackend/` returns raw data. ALWAYS use `/Users/nick/Desktop/ils-ios/`
- **Deep link UUIDs must be LOWERCASE** — uppercase causes failures
- **`import Crypto` vs `import CryptoKit`**: In Vapor, `Crypto` resolves to a different SHA256. Use `CryptoKit`
- **DerivedData path**: `~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/`, NOT `ILSApp/build/`
- **Simulator gestures**: Use `idb_describe operation:all` for accessibility tree coordinates, then `idb_tap` — never guess pixel coordinates
- **ClaudeCodeSDK in Vapor**: SDK uses RunLoop which NIO doesn't pump. Use direct `Process` + `DispatchQueue` instead
- **`process.terminationStatus`**: Always call `process.waitUntilExit()` first or get NSInvalidArgumentException
