# Phase 40: Environment Setup & Screen Inventory - Research

**Researched:** 2026-02-25
**Domain:** Simulator orchestration, binary installation, backend verification, and PASS criteria authoring for iOS/iPad functional validation
**Confidence:** HIGH

## Summary

Phase 40 is the foundation phase for v3.5 Comprehensive Functional Validation. It has zero code changes and zero feature work -- it is purely infrastructure: boot simulators, build and install the app, verify the backend, create evidence directories, author a PASS criteria document, and have two independent agents confirm everything is correct before validation begins.

The research confirms that every tool and resource needed already exists on this machine. Both simulators (iPhone 50523130 and iPad C074375B) are present but currently shutdown. There are 53 DerivedData directories for ILSApp, making the stale-binary pitfall the single highest risk. The newest binary dates to Feb 25 00:01:18 2026 -- but a fresh build should be performed rather than trusting this timestamp. The backend is not currently running on port 9999 and must be started from the correct path (`/Users/nick/Desktop/ils-ios/`). No new software, no new simulators, no new build targets are needed.

**Primary recommendation:** Build fresh, install from newest DerivedData by `ls -td` timestamp, verify backend binary path via `lsof`, override status bars to 9:41, create evidence directories, write the PASS criteria document, then have two agents independently verify the setup before proceeding.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ENV-01 | iPhone simulator (50523130) booted with app installed from newest DerivedData binary | Simulator exists (currently Shutdown). 53 DerivedData dirs present -- MUST use `ls -td` to find newest. Build fresh before install. Uninstall-then-install to avoid stale cached state (Pitfall P5). |
| ENV-02 | iPad simulator (C074375B) booted with same binary as iPhone | "iPad Pro 13 ILS" exists (currently Shutdown). Same `Debug-iphonesimulator` binary runs on both iPhone and iPad -- no separate iPad build needed. Install same `$APP_PATH` used for iPhone. |
| ENV-03 | Backend verified running from `ils-ios/` path on port 9999 with health check | Backend NOT currently running. Start with `PORT=9999 swift run ILSBackend` from `/Users/nick/Desktop/ils-ios/`. Verify with `lsof -i :9999 -P -n` (path must contain `ils-ios/`) AND `curl http://localhost:9999/health`. Also verify response format: `curl /api/v1/sessions` must return `{"data": [...]}` wrapper, not bare array. |
| ENV-04 | Evidence directories created (`/tmp/v3.5-evidence/{iphone,ipad}/`) | Simple `mkdir -p`. Also create subdirs: `logs/`, `deeplinks/`. Create sibling dirs: `gate/`, `fixes/`. |
| ENV-05 | Status bar overridden to 9:41 on both simulators for clean screenshots | `xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`. Run once per simulator after boot. |
| ENV-06 | PASS criteria document created listing all screens and their verification points | 9 ActiveScreen enum cases + sidebar + scrolled settings + deep links = 12+ screens. Each needs iPhone criteria and iPad-specific criteria. Architecture research (ARCHITECTURE.md) already has a detailed screen inventory table with PASS criteria per screen -- use as starting point. |
| GATE-05 | PASS requires 2/2 agent agreement -- applied as gate principle | Two independent agents each verify: (1) both simulators booted and responsive, (2) correct binary installed (timestamp check), (3) backend healthy from correct path, (4) evidence dirs exist and are empty, (5) PASS criteria document is complete. Both must agree before Phase 41 can begin. |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `xcrun simctl` | Xcode 16+ (iOS 18.6 runtime) | Boot, install, launch, screenshot, openurl, status_bar override | Apple's first-party simulator management; no dependency needed |
| `xcodebuild` | Xcode 16+ | Build `ILSApp` scheme for simulator | Standard Xcode build tool; auto-build hook also uses it |
| `curl` | System | Backend health check and response format verification | Standard HTTP client |
| `lsof` | System | Verify backend binary path on port 9999 | Standard process inspection |
| `mkdir` / `ls` / `stat` | System | Evidence directory creation and binary timestamp verification | Standard filesystem tools |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `idb` | Python 3.12 at `~/.local/bin/idb` | Accessibility tree inspection, tap/swipe | Only if deep link navigation is insufficient; not needed for Phase 40 setup |
| `swift run` | Swift 5.10+ | Start ILSBackend from correct directory | Backend startup only |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `xcrun simctl io screenshot` | `idb screenshot` | simctl needs no companion connection; idb adds overhead. Use simctl. |
| `ls -td` for newest binary | `find ... -maxdepth 0 -print0 \| xargs -0 ls -dt` | Both work; `ls -td` is simpler and proven in project. Use `ls -td`. |
| Fresh build before install | Trust existing DerivedData binary | 53 stale dirs exist; binary is from 12+ hours ago. ALWAYS build fresh. |

**Installation:** Nothing to install. All tools are pre-existing.

## Architecture Patterns

### Phase 40 Execution Structure

```
Phase 40: Environment Setup & Screen Inventory
├── Step 1: Backend startup + verification
│   ├── Kill anything on port 9999
│   ├── Start backend from ils-ios/
│   ├── Verify with lsof (path check) + curl (health + format)
│   └── Evidence: terminal output showing health response
├── Step 2: Build fresh binary
│   ├── xcodebuild -scheme ILSApp -destination iPhone UDID -quiet
│   ├── Capture APP_PATH via ls -td | head -1
│   ├── Verify binary timestamp with stat
│   └── Evidence: build success + timestamp
├── Step 3: iPhone simulator setup
│   ├── Boot simulator (50523130)
│   ├── Override status bar to 9:41
│   ├── Install from APP_PATH (uninstall first for clean state)
│   ├── Launch app, wait for auto-connect
│   ├── Navigate to home via ils://home
│   └── Evidence: screenshot of home screen
├── Step 4: iPad simulator setup
│   ├── Boot simulator (C074375B)
│   ├── Override status bar to 9:41
│   ├── Install from SAME APP_PATH
│   ├── Launch app, wait for auto-connect
│   ├── Navigate to home via ils://home
│   └── Evidence: screenshot of home screen (split-view)
├── Step 5: Evidence directory creation
│   ├── /tmp/v3.5-evidence/iphone/ (+ logs/, deeplinks/)
│   ├── /tmp/v3.5-evidence/ipad/ (+ logs/, deeplinks/)
│   ├── /tmp/v3.5-evidence/gate/
│   ├── /tmp/v3.5-evidence/fixes/
│   └── Verify all dirs exist and are empty
├── Step 6: PASS criteria document authoring
│   ├── List all 12+ screens with numbered verification points
│   ├── iPhone-specific criteria per screen
│   ├── iPad-specific criteria per screen
│   └── Write to .planning/phases/40-*/PASS-CRITERIA.md
└── Step 7: Dual-agent verification gate (GATE-05)
    ├── Agent A independently checks all 6 setup conditions
    ├── Agent B independently checks all 6 setup conditions
    ├── 2/2 agreement required
    └── Write gate verdicts to /tmp/v3.5-evidence/gate/
```

### Pattern 1: Newest-Binary-First Install

**What:** Always find the newest DerivedData binary by modification time after a fresh build.
**When to use:** Every `xcrun simctl install` in Phase 40 (and all subsequent phases).
**Example:**
```bash
# Build fresh
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

# Find newest binary (NOT find | head -1)
APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app 2>/dev/null | head -1)

# Verify timestamp is within last 2 minutes
stat -f "%Sm" "$APP_PATH/ILSApp"

# Install on both devices (same binary)
xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP_PATH"
xcrun simctl install C074375B-2CB2-4F95-A55C-972F2FF35041 "$APP_PATH"
```
Source: Quick Task 5 audit findings, PITFALLS.md P1

### Pattern 2: Backend Verification (Three-Point Check)

**What:** Verify backend identity, health, and response format -- not just connectivity.
**When to use:** Start of every validation session.
**Example:**
```bash
# 1. Binary path check (MUST contain "ils-ios")
lsof -i :9999 -P -n | grep LISTEN
# Expected: .../ils-ios/.build/... NOT .../ils/ILSBackend/...

# 2. Health check
curl -sf http://localhost:9999/health
# Expected: 200 OK

# 3. Response format check (APIResponse wrapper, not bare array)
curl -s http://localhost:9999/api/v1/sessions | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'data' in d:
    print(f'OK: APIResponse wrapper, {len(d[\"data\"])} sessions')
else:
    print('FAIL: bare array, wrong backend binary')
    sys.exit(1)
"
```
Source: PITFALLS.md P6, MEMORY.md "CRITICAL: Backend Binary Mismatch"

### Pattern 3: Status Bar Override for Clean Evidence

**What:** Override simulator status bar to Apple's canonical 9:41 time with full signal bars.
**When to use:** Once per simulator after boot, before any screenshots.
**Example:**
```bash
for UDID in 50523130-57AA-48B0-ABD0-4D59CE455F14 C074375B-2CB2-4F95-A55C-972F2FF35041; do
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3
done
```
Source: STACK.md, Apple developer practice

### Pattern 4: Dual-Agent Verification Gate

**What:** Two independent agents verify setup correctness without seeing each other's work.
**When to use:** End of Phase 40, before proceeding to Phase 41.
**Verification checklist for each agent:**
1. iPhone simulator booted? (`xcrun simctl list | grep 50523130`)
2. iPad simulator booted? (`xcrun simctl list | grep C074375B`)
3. App showing home screen on iPhone? (read screenshot)
4. App showing home screen on iPad? (read screenshot)
5. Backend healthy from correct path? (`lsof + curl`)
6. Evidence directories exist and are empty? (`ls /tmp/v3.5-evidence/`)
7. PASS criteria document exists and covers all screens? (read document)

Both agents must produce independent verdicts. 2/2 PASS required.

Source: ARCHITECTURE.md Pattern 4, GATE-05 requirement

### Anti-Patterns to Avoid

- **Skipping the fresh build:** 53 stale DerivedData dirs exist. Never trust an old binary. Always `xcodebuild` first.
- **Using `find | head -1` for binary path:** Returns arbitrary (often stale) binary. Use `ls -td | head -1`.
- **Starting backend from wrong directory:** `swift run ILSBackend` from `/Users/nick/ils/` returns raw data. MUST run from `/Users/nick/Desktop/ils-ios/`.
- **Installing without uninstalling first:** Cached UserDefaults from previous sessions may mask issues. Uninstall first for a clean state.
- **Capturing screenshots immediately after launch:** SwiftUI views need 2-3 seconds to load data from backend. Wait before screenshotting.
- **Skipping response format verification:** `curl health` returns 200 from BOTH old and new backends. Must also check `/api/v1/sessions` response shape.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Simulator management | Custom Swift tool for boot/install | `xcrun simctl` CLI directly | Shell commands are simpler, proven in 5 milestones, zero build overhead |
| Screenshot capture | Fastlane capture_screenshots | `xcrun simctl io screenshot` | Fastlane requires XCUITest scheme; simctl works on any booted simulator |
| Evidence organization | Database or JSON manifest tool | Filesystem directories + naming convention | Prior milestones proved `mkdir` + numbered filenames is sufficient |
| Binary freshness check | Build hash embedded in app | `stat` on binary + `ls -td` ordering | Adding build hash requires code change; stat is zero-overhead |
| Dual-agent gate | Custom orchestration framework | Two Task calls with independent prompts | Agents share filesystem; verdict files are the coordination mechanism |

**Key insight:** Phase 40 is infrastructure setup, not software engineering. Every temptation to build a "validation framework" or "evidence management system" adds complexity without capability gain. Shell commands + filesystem + markdown are the right tools.

## Common Pitfalls

### Pitfall 1: Stale DerivedData Binary Installed (CRITICAL)

**What goes wrong:** 53 `ILSApp-*` directories exist in DerivedData. `find | head -1` grabs a stale build. App launches and renders, but shows old behavior. Every screenshot validates the wrong binary.
**Why it happens:** DerivedData accumulates across sessions; `find` returns filesystem order, not time order.
**How to avoid:** Always build fresh first. Always use `ls -td | head -1` to find newest. Always `stat` the binary to verify timestamp matches build completion.
**Warning signs:** Deep link fixes from recent commits don't work; screen shows old layout that should have changed.

### Pitfall 2: Wrong Backend Binary on Port 9999 (CRITICAL)

**What goes wrong:** Old backend at `/Users/nick/ils/ILSBackend/` returns bare arrays with snake_case. App partially renders but with wrong data or missing fields.
**Why it happens:** Both backends use port 9999. Previous sessions may have left the old one running.
**How to avoid:** Three-point check: `lsof` (path), `curl /health` (connectivity), `curl /api/v1/sessions` (response format).
**Warning signs:** Home screen shows 41 sessions instead of 22,000+; JSON decoding silently produces nil for optional fields.

### Pitfall 3: Fresh Install Clears UserDefaults (MODERATE)

**What goes wrong:** `xcrun simctl uninstall` + `install` resets serverURL, hasConnectedBefore, colorSchemePreference. App may show onboarding/setup sheet instead of home screen.
**Why it happens:** Uninstall removes app sandbox including UserDefaults plist.
**How to avoid:** After fresh install, launch the app and wait 3-5 seconds for auto-connect to backend at localhost:9999. The app should auto-discover and connect. Then navigate to `ils://home` via deep link.
**Warning signs:** Screenshot shows ServerSetupSheet instead of home; no sessions visible despite backend having data.

### Pitfall 4: Screenshot Before View Loads (MODERATE)

**What goes wrong:** Screenshot captured before SwiftUI `.task {}` completes data fetch. Shows loading spinner or empty content instead of real data.
**Why it happens:** `xcrun simctl io screenshot` is instant; SwiftUI views need 1-3 seconds to fetch from localhost backend.
**How to avoid:** Wait 3 seconds after navigation before capturing any screenshot. For the Phase 40 home screen verification, wait 5 seconds (cold launch + data fetch).
**Warning signs:** Screenshot shows "Loading..." or empty cards where stats should be.

### Pitfall 5: iPad Shows iPhone Layout (MODERATE)

**What goes wrong:** iPad simulator is in multitasking or resized window, triggering compact size class. `isRegularWidth` returns false, rendering `iPhoneLayout` instead of `iPadLayout` (NavigationSplitView).
**Why it happens:** iPad full-screen is regular/regular size class; 1/3 Split View downgrades to compact horizontal.
**How to avoid:** Ensure iPad simulator runs full-screen. Verify the home screen screenshot shows persistent sidebar (NavigationSplitView), not an overlay sidebar with hamburger button.
**Warning signs:** iPad screenshot shows hamburger button (iPhone-only element); sidebar is overlay sheet instead of persistent column.

### Pitfall 6: Deep Link "Open in App?" Dialog on Fresh Install

**What goes wrong:** `xcrun simctl openurl` on a freshly installed app triggers a system confirmation dialog instead of navigating directly.
**Why it happens:** iOS requires the app to have been launched at least once before deep links route without user confirmation.
**How to avoid:** Always `xcrun simctl launch <UDID> com.ils.app` and wait for the app to fully launch before using any deep link.
**Warning signs:** `openurl` command succeeds but app shows a dialog instead of the expected screen.

## Code Examples

### Complete Phase 40 Setup Sequence

Verified patterns from prior milestones and project documentation:

### Backend Startup
```bash
# Kill any existing process on port 9999
lsof -ti :9999 | xargs kill -9 2>/dev/null || true

# Start backend from CORRECT directory (background)
cd /Users/nick/Desktop/ils-ios && PORT=9999 swift run ILSBackend &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 10

# Three-point verification
lsof -i :9999 -P -n | grep LISTEN
curl -sf http://localhost:9999/health
curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Format: APIResponse, Sessions: {len(d.get(\"data\",[]))}')"
```

### Build and Install
```bash
# Fresh build targeting iPhone simulator
cd /Users/nick/Desktop/ils-ios
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

# Find newest binary
APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app 2>/dev/null | head -1)
echo "Binary: $APP_PATH"
stat -f "%Sm" "$APP_PATH/ILSApp"
```

### Simulator Boot, Status Bar, and Install
```bash
IPHONE_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
IPAD_UDID="C074375B-2CB2-4F95-A55C-972F2FF35041"

# Boot both
xcrun simctl boot "$IPHONE_UDID" 2>/dev/null || true
xcrun simctl boot "$IPAD_UDID" 2>/dev/null || true

# Override status bars
for UDID in "$IPHONE_UDID" "$IPAD_UDID"; do
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3
done

# Uninstall old, install new (same binary for both)
for UDID in "$IPHONE_UDID" "$IPAD_UDID"; do
  xcrun simctl uninstall "$UDID" com.ils.app 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP_PATH"
  xcrun simctl launch "$UDID" com.ils.app
done

# Wait for app to connect to backend
sleep 5

# Navigate both to home
xcrun simctl openurl "$IPHONE_UDID" "ils://home"
xcrun simctl openurl "$IPAD_UDID" "ils://home"
sleep 3

# Capture verification screenshots
xcrun simctl io "$IPHONE_UDID" screenshot /tmp/v3.5-evidence/iphone/00-setup-verification.png
xcrun simctl io "$IPAD_UDID" screenshot /tmp/v3.5-evidence/ipad/00-setup-verification.png
```

### Evidence Directory Creation
```bash
# Create full evidence tree
mkdir -p /tmp/v3.5-evidence/{iphone,ipad}/{logs,deeplinks}
mkdir -p /tmp/v3.5-evidence/{gate,fixes}

# Verify
find /tmp/v3.5-evidence -type d | sort
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `find \| head -1` for binary | `ls -td \| head -1` for newest | Quick Task 5 (2026-02-25) | Prevents stale binary install -- the highest-risk pitfall |
| Phase 8: parallel 4-platform validation | v3.5: sequential iPhone-then-iPad | v3.5 research (2026-02-25) | Fix-as-you-go mandate requires sequential; iPad tests post-fix binary |
| Phase 8: evidence in git repo (22.5 MB) | v3.5: evidence in `/tmp/` | v3.5 research (2026-02-25) | Avoids git bloat; verdict text files copied to `.planning/` for record |
| Single-agent verification | Dual-agent gate (2/2 agreement) | v3.5 milestone definition | Prevents false PASS from confirmation bias (documented in MEMORY.md) |
| Phase 43 standalone gate phase | Embedded gates per phase | v3.5 roadmap revision (2026-02-25) | Issues caught where they belong; no rework pile-up |

## Screen Inventory for PASS Criteria Document

The PASS criteria document (ENV-06) must cover these screens. Derived from `ActiveScreen` enum (9 cases) in `SidebarRootView.swift` plus sidebar itself:

| # | Screen | Deep Link Route | ActiveScreen Case |
|---|--------|----------------|-------------------|
| 01 | Home / Dashboard | `ils://home` | `.home` |
| 02 | Sessions List | `ils://sessions` | `.home` (sessions section) |
| 03 | Chat View | `ils://sessions/{uuid}` | `.chat(session)` |
| 04 | Browser: MCP Servers | `ils://mcp` | `.browser` (segment: .mcp) |
| 05 | Browser: Skills | `ils://skills` | `.browser` (segment: .skills) |
| 06 | Browser: Plugins | `ils://plugins` | `.browser` (segment: .plugins) |
| 07 | System Monitor | `ils://system` | `.system` |
| 08 | Settings | `ils://settings` | `.settings` |
| 09 | Host Profiles | `ils://fleet` | `.hostProfiles` |
| 10 | Agent Teams | `ils://teams` | `.teams` |
| 11 | Themes | `ils://themes` | `.themes` |
| 12 | Hooks | `ils://hooks` | `.hooks` |
| 13 | Sidebar | swipe/persistent | (navigation chrome) |

Additional deep link routes that alias to screens above: `ils://browser` and `ils://projects` (both -> .browser default), `ils://profiles` (-> .hostProfiles).

**iPad-specific criteria** for every screen: NavigationSplitView persistent sidebar visible alongside detail content. Sidebar highlight matches active screen. Detail content fills remaining width without white bands or compression.

### Per-Screen PASS Criteria Summary

| # | Screen | iPhone PASS Criteria | iPad Additional Criteria |
|---|--------|---------------------|-------------------------|
| 01 | Home | Stats cards > 0 (sessions, skills, MCP, plugins). Quick Actions visible. Recent Sessions non-empty. | Split-view: sidebar + home in detail column |
| 02 | Sessions | Session rows with names, model tags, timestamps. Count > 0. Search bar. | Sessions in content area; detail shows placeholder or selected session |
| 03 | Chat | Real messages displayed. Back button. Session title in nav bar. No stuck spinner. | Chat fills detail column. Session highlighted in sidebar. |
| 04 | MCP | Server list with health badges. Count > 0. | Tab bar in detail column. Sidebar visible. |
| 05 | Skills | Skills with Active/Inactive badges. Search placeholder. Count > 0. | Same in detail column. |
| 06 | Plugins | Plugins with category filters. Enable/Disable badges. Count > 0. | Same in detail column. |
| 07 | System | Live CPU/Memory/Disk/Network stats. Process count > 0. | Metrics in detail column. |
| 08 | Settings | Config values displayed. InheritanceBadges. Info tooltips. Connection status. | Full-width detail. |
| 09 | Host Profiles | At least one host (localhost). Health badge. Active indicator. | In detail column. |
| 10 | Agent Teams | Renders without crash. Team list or empty state. | In detail column. |
| 11 | Themes | 12+ built-in themes listed. Current theme indicated. | In detail column. |
| 12 | Hooks | Renders without crash. Hook list or empty state with config path. | In detail column. |
| 13 | Sidebar | All nav items visible. Active screen highlighted. Session list. Host name. | Persistent (not overlay). 260-380pt width. All items without scrolling. |

## Open Questions

1. **Backend startup time in this session**
   - What we know: `swift run ILSBackend` typically takes 5-15 seconds for first build + launch. If backend is already compiled, startup is ~3 seconds.
   - What's unclear: Whether the backend Swift package cache is warm or cold in the current session.
   - Recommendation: Budget 15 seconds for backend startup; verify with health check before proceeding.

2. **iPad simulator data directory state**
   - What we know: iPad Pro 13 ILS was last booted 2026-02-20 and has a 2.2GB data directory. It may have a stale version of the app installed from a previous milestone.
   - What's unclear: Whether the stale app state will interfere with the fresh install.
   - Recommendation: Uninstall before install (`xcrun simctl uninstall C074375B com.ils.app`) to ensure clean state. Accept that UserDefaults will be reset (Pitfall 3).

3. **Evidence directory path: `/tmp/v3.5-evidence/` vs `/tmp/v3.5-validation/`**
   - What we know: The roadmap success criteria say `/tmp/v3.5-evidence/`. The ARCHITECTURE.md research used `/tmp/v3.5-validation/`.
   - What's unclear: Which name is canonical.
   - Recommendation: Use `/tmp/v3.5-evidence/` as specified in the roadmap success criteria (ENV-04). The roadmap is the authoritative source.

4. **Chat session UUID for `ils://sessions/{uuid}` verification**
   - What we know: Deep link requires a real session UUID from the backend. UUID must be lowercase.
   - What's unclear: Which session UUID to use -- this depends on backend data at runtime.
   - Recommendation: During Phase 40 setup verification, query `curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'][0]['id'])"` to get a real session ID. Save it for use in Phase 41 deep link testing.

## Sources

### Primary (HIGH confidence)
- Local machine: `xcrun simctl list devices` -- both simulators confirmed present (iPhone 50523130 Shutdown, iPad C074375B Shutdown)
- Local machine: `ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*` -- 53 directories, newest binary dated Feb 25 00:01:18 2026
- Local machine: `lsof -i :9999` -- port currently unused (backend not running)
- Codebase: `SidebarRootView.swift` -- ActiveScreen enum (9 cases: home, chat, system, settings, browser, teams, hostProfiles, themes, hooks)
- Codebase: `AppState.swift` -- handleURL() with 13 deep link routes
- Project: `.planning/research/ARCHITECTURE.md` -- evidence directory structure, build order, dual-agent gate pattern
- Project: `.planning/research/PITFALLS.md` -- 16 catalogued pitfalls (P1 stale binary, P6 wrong backend are critical for Phase 40)
- Project: `.planning/research/STACK.md` -- tool inventory, simulator configuration, status bar override commands
- Project: `.planning/REQUIREMENTS.md` -- ENV-01 through ENV-06, GATE-05 definitions
- Project: `.planning/ROADMAP.md` -- Phase 40 success criteria (6 items)

### Secondary (MEDIUM confidence)
- MEMORY.md: DerivedData path pattern, backend binary mismatch history, fresh install UserDefaults clearing
- Quick Task 5 summary: Stale binary discovery (40+ dirs), `find | head -1` pitfall

### Tertiary (LOW confidence)
- None. All findings verified against local machine state and project source code.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools verified present on this machine via direct commands
- Architecture: HIGH - execution structure follows proven patterns from 5 prior milestones
- Pitfalls: HIGH - top 6 pitfalls all sourced from documented project incidents, not speculation

**Research date:** 2026-02-25
**Valid until:** 2026-03-10 (stable -- no moving targets in the tool stack)
