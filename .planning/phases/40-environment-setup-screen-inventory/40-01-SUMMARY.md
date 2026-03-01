# Plan 40-01 Summary: Environment Infrastructure Setup

**Status:** COMPLETE
**Date:** 2026-02-25

## What Was Done

### Task 1: Build, Install, and Start Backend

1. **Backend**: Killed existing process on port 9999, started fresh with `PORT=9999 swift run ILSBackend`
2. **Three-point verification PASSED**:
   - `lsof -i :9999` confirms binary path is in `ils-ios/` (not the stale `ils/` binary)
   - `curl /health` returns `{"status":"healthy"}` with database=ok, filesystem=ok
   - `curl /api/v1/sessions` returns `{"success":true,"data":{"items":[...]}}` (APIResponse wrapper, 50 sessions)
3. **iOS build**: `xcodebuild -scheme ILSApp` completed successfully (binary timestamp Feb 25 15:25:46)
4. **Evidence directories created**: `/tmp/v3.5-evidence/{iphone,ipad,gate,fixes}` with `logs/` and `deeplinks/` subdirs

### Task 2: Boot Simulators, Install App, Capture Screenshots

1. **Simulators booted**:
   - iPhone 16 Pro Max (50523130-57AA-48B0-ABD0-4D59CE455F14) - Booted
   - iPad Pro 13 ILS (C074375B-2CB2-4F95-A55C-972F2FF35041) - Booted
2. **Status bars overridden** to 9:41, full battery, full signal on both
3. **App installed fresh** on both (uninstall + install from DerivedData)
4. **App launched** and deep linked to `ils://home` on both
5. **Screenshots captured**:
   - `/tmp/v3.5-evidence/iphone/00-setup-verification.png` (552KB) - Home screen with stats cards, Quick Actions, Recent Sessions (22,439)
   - `/tmp/v3.5-evidence/ipad/00-setup-verification.png` (617KB) - Home screen with persistent sidebar, detail column with stats
6. **Session UUID saved** for Phase 41: `eeba4856-c40c-47cc-9029-95599704c82f` at `/tmp/v3.5-evidence/gate/session-uuid.txt`

## Blockers Encountered

- **`xcrun simctl io screenshot` fails with "Timeout waiting for screen surfaces" (error code 60)** on both simulators. This is a known macOS/Simulator GPU rendering issue where the screen surface isn't available to `simctl io`.
- **Workaround**: Used `screencapture -l <windowID>` to capture Simulator windows directly via Quartz. Window IDs obtained via `CGWindowListCopyWindowInfo`. This produces equivalent screenshots including the Simulator chrome (device bezel).

## Artifacts

| Artifact | Path | Size |
|----------|------|------|
| iPhone screenshot | `/tmp/v3.5-evidence/iphone/00-setup-verification.png` | 552KB |
| iPad screenshot | `/tmp/v3.5-evidence/ipad/00-setup-verification.png` | 617KB |
| Session UUID | `/tmp/v3.5-evidence/gate/session-uuid.txt` | 36B |
| Evidence dirs | `/tmp/v3.5-evidence/{iphone,ipad,gate,fixes}/` | - |

## Screenshot Verification

### iPhone (00-setup-verification.png)
- Status bar: 9:41 visible
- Home screen: "Welcome back" title, http://localhost:9999
- Stats: Skills 1152, MCP Servers 16, Plugins 97
- Recent Sessions: 22,439 count, session names visible (not UUIDs)
- Quick Actions section visible

### iPad (00-setup-verification.png)
- Persistent sidebar visible on left with navigation items (Home highlighted)
- Sessions list in sidebar
- Detail column shows dashboard with stats cards (22,438, 374, 1,152)
- Sparkline charts visible
- "New Session" button at bottom of sidebar
- NavigationSplitView layout confirmed (not compact/iPhone layout)

## Requirements Covered

- **ENV-01**: Both simulators booted and running
- **ENV-02**: Backend running on port 9999 from correct binary
- **ENV-03**: App built, installed, and launched on both simulators
- **ENV-04**: Evidence directory structure created
- **ENV-05**: Setup verification screenshots captured and verified
