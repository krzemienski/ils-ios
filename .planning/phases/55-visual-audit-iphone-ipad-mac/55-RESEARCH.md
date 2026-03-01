# Phase 55: Visual Audit -- iPhone, iPad & Mac - Research

**Researched:** 2026-02-28
**Domain:** Cross-platform screenshot evidence capture and visual validation
**Confidence:** HIGH

## Summary

Phase 55 is a pure evidence-capture phase -- no code changes are expected. The goal is to produce numbered screenshot artifacts proving that every major screen on every platform (iPhone, iPad, Mac) renders correctly with real data and proper theming. The app has 9 top-level screens (Home, System Monitor, Browser, Agent Teams, Host Profiles, Themes, Hooks, Settings) plus Chat, each navigable via the `ActiveScreen` enum and deep links. Browser further subdivides into 4 tabs (MCP, Skills, Plugins, Discover).

All three platforms share the same `ActiveScreen` routing enum and `AppState.handleURL()` deep link handler. iPhone uses a compact overlay sidebar; iPad uses `NavigationSplitView` with a persistent sidebar column; macOS uses a 3-column `NavigationSplitView` (sidebar + list + detail). The phase requires 15+ iPhone screenshots, 15+ iPad screenshots, and 10+ Mac screenshots -- all showing real data from the backend on port 9999.

**Primary recommendation:** Build a single shell script per platform that automates navigation via deep links and `xcrun simctl io` (iPhone/iPad) or `screencapture -l <windowid>` (Mac), producing sequentially numbered PNG artifacts in `evidence/phase-55-visual-audit/`. Run the backend first, then execute each script.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GATE-01 | Visual audit -- iPhone screens with numbered screenshot evidence (>=15 artifacts) | 9 top-level screens + Chat + Browser sub-tabs (MCP, Skills, Plugins, Discover) + detail views = 15+ screenshots. Captured via `xcrun simctl io 50523130-... screenshot`. Deep links navigate each screen. |
| GATE-02 | Visual audit -- iPad screens with numbered screenshot evidence (>=15 artifacts) | Same screen set on iPad Pro 13 (C074375B-...) which is already booted. iPad uses NavigationSplitView showing sidebar + detail simultaneously -- each screenshot proves split-view layout. Deep links work identically. |
| GATE-03 | Visual audit -- Mac screens with numbered screenshot evidence (>=10 artifacts) | macOS app built via `ILSMacApp` scheme. Launch app, navigate via keyboard shortcuts (Cmd+1..4, Cmd+,) and `ils://` URL scheme. Capture with `screencapture -l <windowid>` after getting window ID via `CGWindowListCopyWindowInfo`. |
</phase_requirements>

## Standard Stack

### Core Tools

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `xcrun simctl io` | Xcode 16+ | iPhone/iPad simulator screenshot capture | Apple's official simulator screenshot API; produces PNG at device resolution |
| `xcrun simctl openurl` | Xcode 16+ | Deep-link navigation on simulators | Triggers `ils://` URL handler without needing idb_tap automation |
| `screencapture -l` | macOS built-in | macOS window capture by window ID | Native macOS utility; `-l <windowid>` captures specific window without user interaction |
| `CGWindowListCopyWindowInfo` | macOS Quartz | Get macOS window IDs programmatically | Only reliable way to get window IDs for `screencapture -l` |
| `xcrun simctl install/launch` | Xcode 16+ | App installation and launch on simulators | Required to ensure latest build is running |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `open -a` / `open <url>` | Launch macOS app and open deep links | Navigate macOS app to specific screens |
| `lsof -i :9999` | Verify backend is running | Pre-flight check before capture |
| `curl` | Verify backend returns data | Ensure screenshots will show real data, not empty states |
| `python3 -c "import Quartz; ..."` | Get window IDs for screencapture | macOS-only: resolve ILSMacApp window ID |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Deep links for navigation | idb_tap on accessibility coordinates | Deep links are 100% reliable; idb_tap requires coordinate discovery and can miss SwiftUI toolbar buttons |
| `screencapture -l` for Mac | Xcode UI testing screenshots | screencapture is simpler, no test target needed |
| Manual Simulator.app screenshots | Automated script | Manual is error-prone, not reproducible |

## Architecture Patterns

### Evidence Directory Structure

```
evidence/phase-55-visual-audit/
├── iphone/
│   ├── 01-home.png
│   ├── 02-sessions-in-home.png
│   ├── 03-chat-view.png
│   ├── 04-browser-mcp.png
│   ├── 05-browser-skills.png
│   ├── 06-browser-plugins.png
│   ├── 07-browser-discover.png
│   ├── 08-settings.png
│   ├── 09-host-profiles.png
│   ├── 10-system-monitor.png
│   ├── 11-hooks.png
│   ├── 12-themes.png
│   ├── 13-sidebar.png
│   ├── 14-skill-detail.png
│   ├── 15-mcp-detail.png
│   └── (16+ optional: plugin-detail, chat-menu, session-info, etc.)
├── ipad/
│   ├── 01-home-splitview.png
│   ├── 02-chat-splitview.png
│   ├── 03-browser-mcp-splitview.png
│   ├── 04-browser-skills-splitview.png
│   ├── 05-browser-plugins-splitview.png
│   ├── 06-browser-discover-splitview.png
│   ├── 07-settings-splitview.png
│   ├── 08-host-profiles-splitview.png
│   ├── 09-system-monitor-splitview.png
│   ├── 10-hooks-splitview.png
│   ├── 11-themes-splitview.png
│   ├── 12-sidebar-expanded.png
│   ├── 13-skill-detail-splitview.png
│   ├── 14-mcp-detail-splitview.png
│   └── 15-chat-message-splitview.png
└── mac/
    ├── 01-home-3col.png
    ├── 02-chat-3col.png
    ├── 03-browser-mcp-3col.png
    ├── 04-browser-skills-3col.png
    ├── 05-settings-3col.png
    ├── 06-system-monitor-3col.png
    ├── 07-host-profiles-3col.png
    ├── 08-hooks-3col.png
    ├── 09-themes-3col.png
    └── 10-menu-bar.png
```

### Pattern 1: Deep-Link Navigation Loop

**What:** Navigate to each screen using `xcrun simctl openurl` with the `ils://` scheme, then capture.
**When to use:** iPhone and iPad simulators.
**Example:**

```bash
UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
OUT="evidence/phase-55-visual-audit/iphone"

# Navigate and capture
xcrun simctl openurl "$UDID" "ils://home"
sleep 1
xcrun simctl io "$UDID" screenshot "$OUT/01-home.png"

xcrun simctl openurl "$UDID" "ils://settings"
sleep 1
xcrun simctl io "$UDID" screenshot "$OUT/08-settings.png"

# Browser sub-tabs use deep links too
xcrun simctl openurl "$UDID" "ils://mcp"
sleep 1
xcrun simctl io "$UDID" screenshot "$OUT/04-browser-mcp.png"
```

### Pattern 2: macOS Window Capture

**What:** Get the ILSMacApp window ID via Quartz API, then capture with `screencapture -l`.
**When to use:** macOS app screenshots.
**Example:**

```bash
# Get window ID
WID=$(python3 -c "
import Quartz
wins = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in wins:
    if w.get('kCGWindowOwnerName','') == 'ILSMacApp' and w.get('kCGWindowLayer',0) == 0:
        print(w['kCGWindowNumber']); break
")

# Capture
screencapture -l "$WID" -x "evidence/phase-55-visual-audit/mac/01-home-3col.png"
```

### Pattern 3: macOS Navigation via URL Scheme

**What:** Use `open ils://screen` to navigate the macOS app via its registered URL scheme.
**When to use:** macOS deep link navigation (same handler as iOS).
**Example:**

```bash
open "ils://settings"
sleep 1
screencapture -l "$WID" -x "$OUT/05-settings-3col.png"
```

### Anti-Patterns to Avoid

- **Guessing idb_tap coordinates:** Deep links are deterministic; pixel guessing is fragile and breaks across devices.
- **Capturing empty states:** Always verify backend is running and returning data before starting capture. `curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'{len(d.get(\"data\",[]))} sessions')"` should show real session counts.
- **Using Simulator.app menu screenshots:** `xcrun simctl io` captures only the device screen without Simulator chrome -- this is what we want.
- **Hardcoding sleep durations too low:** Complex screens (Browser, System Monitor) with network fetches need 2-3s after navigation; simple screens (Settings, Themes) need only 1s.
- **Forgetting to install latest build:** Always `xcrun simctl install` before starting capture to ensure the latest code changes are reflected.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Simulator screenshot capture | Custom screenshotting code in Swift | `xcrun simctl io <UDID> screenshot` | Official Apple tool, perfect resolution, no app modification needed |
| Screen navigation | idb_tap with accessibility coordinates | `xcrun simctl openurl <UDID> "ils://..."` deep links | 100% reliable, no coordinate guessing, works across all device sizes |
| macOS window capture | Accessibility/AppKit screenshot code | `screencapture -l <windowid>` | Built-in macOS utility, no code changes, captures exactly the window |
| Window ID discovery | Manual `GetWindowInfo` calls | Python one-liner with `Quartz.CGWindowListCopyWindowInfo` | 3 lines of Python, deterministic |
| Evidence organization | Manual file renaming | Sequential numbering in capture script | Reproducible, matches requirement numbering |

**Key insight:** This phase requires zero code changes. Every tool needed is already available in the development environment. The challenge is orchestration (correct order, adequate sleep times, backend verification) not technology.

## Common Pitfalls

### Pitfall 1: Backend Not Running or Wrong Binary

**What goes wrong:** Screenshots show "Unable to connect" or empty state screens instead of real data.
**Why it happens:** Backend at port 9999 must be running from `/Users/nick/Desktop/ils-ios/` (not the old `/Users/nick/ils/ILSBackend/`).
**How to avoid:** Pre-flight check: `lsof -i :9999 -P -n` must show a binary path containing `ils-ios/`. Also: `curl -s http://localhost:9999/api/v1/sessions | head -50` must show real session data.
**Warning signs:** Empty lists, "No sessions" text, connection error banners.

### Pitfall 2: Stale App Binary on Simulator

**What goes wrong:** Screenshots show old UI that doesn't include Phase 49-54 changes.
**Why it happens:** `xcrun simctl launch` runs whatever was last installed, which may be an old build.
**How to avoid:** Always build fresh and install before capture:
```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-...' -quiet
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ILSApp.app" -path "*/Debug-iphonesimulator/*" | head -1)
xcrun simctl install 50523130-... "$APP"
```
**Warning signs:** Missing "Host Profiles" (still shows "Fleet"), missing config badges, missing GitHub browse.

### Pitfall 3: iPad Simulator Not Booted

**What goes wrong:** `xcrun simctl io` fails with "device not booted" error.
**Why it happens:** iPad Pro 13 (C074375B) may have been shut down between sessions.
**How to avoid:** Boot before capture: `xcrun simctl boot C074375B-2CB2-4F95-A55C-972F2FF35041 2>/dev/null || true`
**Warning signs:** simctl error output.

### Pitfall 4: macOS App Not Finding Backend

**What goes wrong:** macOS screenshots show disconnected state.
**Why it happens:** macOS app uses the same `ConnectionManager` but may have a different saved `serverURL` in UserDefaults.
**How to avoid:** Ensure the macOS app's stored server URL points to `http://localhost:9999`. Can verify by launching and checking the Settings > Connection screen.
**Warning signs:** "Offline" indicator, empty data, connection error banners.

### Pitfall 5: Insufficient Sleep After Navigation

**What goes wrong:** Screenshots capture loading spinners or partially-rendered screens.
**Why it happens:** Some screens (Home, Browser, System Monitor) fetch data asynchronously after appearing.
**How to avoid:** Use 2-3 second sleeps after navigating to data-heavy screens. For simple UI screens (Settings, Themes), 1 second suffices.
**Warning signs:** Skeleton loaders, "Loading..." text, empty lists with spinners.

### Pitfall 6: Chat Screen Requires a Real Session ID

**What goes wrong:** Chat view shows "No session selected" or empty state.
**Why it happens:** `ils://sessions/{uuid}` requires a valid session UUID from the backend database.
**How to avoid:** Fetch a real session ID first:
```bash
SESSION_ID=$(curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null)
xcrun simctl openurl "$UDID" "ils://sessions/$SESSION_ID"
```
**Warning signs:** Empty chat, "Session" placeholder name.

### Pitfall 7: macOS Window ID Changes on App Restart

**What goes wrong:** `screencapture -l` captures wrong window or fails.
**Why it happens:** Window IDs are assigned per-launch by the window server; they change on restart.
**How to avoid:** Query window ID immediately before capture, not once at script start. Or capture in a tight loop: navigate -> get WID -> capture.
**Warning signs:** Black or wrong screenshots, "window not found" errors.

### Pitfall 8: Deep Link Dialog on Simulator

**What goes wrong:** A system dialog "Open in ILSApp?" appears, blocking the actual screen.
**Why it happens:** iOS shows a confirmation dialog for URL scheme handling on first use.
**How to avoid:** Dismiss the dialog by tapping "Open" once manually before running the automated script, or handle it with a pre-warm step in the script.
**Warning signs:** Screenshots showing "Open in..." system alert instead of app content.

## Code Examples

### Complete iPhone Capture Script Template

```bash
#!/bin/bash
set -e

IPHONE_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
OUT="evidence/phase-55-visual-audit/iphone"
BUNDLE="com.ils.app"

# Pre-flight
echo "==> Checking backend..."
curl -sf http://localhost:9999/health > /dev/null || { echo "ERROR: Backend not running on :9999"; exit 1; }

# Get a real session ID for chat screenshot
SESSION_ID=$(curl -s http://localhost:9999/api/v1/sessions | python3 -c "
import json, sys
data = json.load(sys.stdin)
sessions = data.get('data', [])
if sessions: print(sessions[0]['id'])
else: print('')
")

mkdir -p "$OUT"

# Boot and install
xcrun simctl boot "$IPHONE_UDID" 2>/dev/null || true
sleep 2
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ILSApp.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
xcrun simctl install "$IPHONE_UDID" "$APP_PATH"
xcrun simctl launch "$IPHONE_UDID" "$BUNDLE"
sleep 3

capture() {
    local num=$1 name=$2 url=$3 wait=${4:-2}
    xcrun simctl openurl "$IPHONE_UDID" "$url"
    sleep "$wait"
    xcrun simctl io "$IPHONE_UDID" screenshot "$OUT/$(printf '%02d' $num)-$name.png"
    echo "  [$num] $name"
}

echo "==> Capturing iPhone screenshots..."
capture 1  "home"             "ils://home"        3
capture 2  "browser-mcp"      "ils://mcp"         2
capture 3  "browser-skills"   "ils://skills"      2
capture 4  "browser-plugins"  "ils://plugins"     2
capture 5  "settings"         "ils://settings"    2
capture 6  "host-profiles"    "ils://host-profiles" 2
capture 7  "system-monitor"   "ils://system"      3
capture 8  "hooks"            "ils://hooks"       2
capture 9  "themes"           "ils://themes"      2
capture 10 "teams"            "ils://teams"       2
if [ -n "$SESSION_ID" ]; then
    capture 11 "chat-view"    "ils://sessions/$SESSION_ID" 3
fi

# Sidebar requires swipe (not deep-linkable)
# Use idb or manual capture for sidebar screenshot

echo "==> Done. $(ls "$OUT"/*.png 2>/dev/null | wc -l) screenshots captured."
```

### iPad Capture (Same Pattern, Different UDID)

```bash
IPAD_UDID="C074375B-2CB2-4F95-A55C-972F2FF35041"
OUT="evidence/phase-55-visual-audit/ipad"
# Same capture() function, different UDID
# iPad screenshots will show NavigationSplitView with sidebar visible
```

### macOS Capture Script Template

```bash
#!/bin/bash
set -e

OUT="evidence/phase-55-visual-audit/mac"
MAC_APP="$HOME/Library/Developer/Xcode/DerivedData/ILSApp-dcfyrisermdykvdcbzcjkljzdben/Build/Products/Debug/ILSMacApp.app"

mkdir -p "$OUT"

# Launch macOS app
open "$MAC_APP"
sleep 3

get_wid() {
    python3 -c "
import Quartz
wins = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in wins:
    if w.get('kCGWindowOwnerName','') == 'ILSMacApp' and w.get('kCGWindowLayer',0) == 0:
        print(w['kCGWindowNumber']); break
"
}

mac_capture() {
    local num=$1 name=$2 url=$3 wait=${4:-2}
    open "$url"
    sleep "$wait"
    WID=$(get_wid)
    screencapture -l "$WID" -x "$OUT/$(printf '%02d' $num)-$name.png"
    echo "  [$num] $name"
}

echo "==> Capturing macOS screenshots..."
mac_capture 1  "home-3col"           "ils://home"           3
mac_capture 2  "browser-mcp-3col"    "ils://mcp"            2
mac_capture 3  "browser-skills-3col" "ils://skills"         2
mac_capture 4  "settings-3col"       "ils://settings"       2
mac_capture 5  "host-profiles-3col"  "ils://host-profiles"  2
mac_capture 6  "system-monitor-3col" "ils://system"         3
mac_capture 7  "hooks-3col"          "ils://hooks"          2
mac_capture 8  "themes-3col"         "ils://themes"         2
mac_capture 9  "teams-3col"          "ils://teams"          2

# Menu bar screenshot — activate app and use screencapture
osascript -e 'tell application "ILSMacApp" to activate'
sleep 1
# Capture full screen showing menu bar
screencapture -x "$OUT/10-menu-bar.png"

echo "==> Done. $(ls "$OUT"/*.png 2>/dev/null | wc -l) screenshots captured."
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual screenshots with Simulator.app | `xcrun simctl io` automated capture | Xcode 8+ (2016) | Reproducible, scriptable, no human error |
| idb_tap pixel guessing for navigation | Deep links (`ils://`) for navigation | Phase 34+ (2026-02) | 100% reliable across all device sizes |
| One-off capture scripts | Platform-specific capture scripts in evidence/ | This phase | Reusable for future milestones |
| Separate evidence directories per phase | Unified `evidence/phase-55-visual-audit/{platform}/` | This phase | All 3 platforms in one evidence set |

## Platform-Specific Details

### iPhone (GATE-01)

| Property | Value |
|----------|-------|
| Simulator UDID | `50523130-57AA-48B0-ABD0-4D59CE455F14` |
| Device | iPhone 16 Pro Max |
| iOS Version | 18.6 |
| Status | Booted |
| Build scheme | `ILSApp` |
| Build destination | `id=50523130-57AA-48B0-ABD0-4D59CE455F14` |
| DerivedData app path | `~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app` |
| Layout | Compact width: overlay sidebar (ZStack) |
| Navigation | Deep links via `xcrun simctl openurl` |
| Screenshot capture | `xcrun simctl io <UDID> screenshot <path>` |

### iPad (GATE-02)

| Property | Value |
|----------|-------|
| Simulator UDID | `C074375B-2CB2-4F95-A55C-972F2FF35041` |
| Device | iPad Pro 13-inch |
| iOS Version | 18.6 |
| Status | Booted |
| Build scheme | `ILSApp` (same binary, different size class) |
| Build destination | `id=C074375B-2CB2-4F95-A55C-972F2FF35041` |
| Layout | Regular width: `NavigationSplitView` with persistent sidebar |
| Navigation | Deep links via `xcrun simctl openurl` |
| Screenshot capture | `xcrun simctl io <UDID> screenshot <path>` |
| Key difference | Every screenshot shows sidebar + detail pane simultaneously |

### macOS (GATE-03)

| Property | Value |
|----------|-------|
| Build scheme | `ILSMacApp` |
| Build destination | `platform=macOS` |
| DerivedData app path | `~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app` |
| Default window size | 1200x800 |
| Layout | 3-column `NavigationSplitView` (sidebar 250 + list 320 + detail 800) |
| Navigation | `open "ils://..."` URL scheme + keyboard shortcuts (Cmd+1..4, Cmd+,) |
| Screenshot capture | `screencapture -l <windowid> -x <path>` |
| Window ID discovery | Python Quartz `CGWindowListCopyWindowInfo` (owner = "ILSMacApp") |
| Menu bar | Custom menus: Navigate (Cmd+1..4), Session (Cmd+Shift+R/F/E), New Session (Cmd+N) |

## Screen Inventory (All Platforms)

Screens available via `ActiveScreen` enum, shared by iOS and macOS:

| # | Screen | Deep Link | Browser Sub-Tab | Notes |
|---|--------|-----------|-----------------|-------|
| 1 | Home | `ils://home` | - | Quick actions + recent sessions |
| 2 | Chat | `ils://sessions/{uuid}` | - | Requires valid session UUID |
| 3 | System Monitor | `ils://system` | - | Real-time CPU/memory/disk/network |
| 4 | Settings | `ils://settings` | - | Config cascade badges |
| 5 | Browser (MCP) | `ils://mcp` | MCP tab | MCP server list |
| 6 | Browser (Skills) | `ils://skills` | Skills tab | Skills list |
| 7 | Browser (Plugins) | `ils://plugins` | Plugins tab | Plugin list |
| 8 | Browser (Discover) | - | Discover tab | GitHub browse (no direct deep link) |
| 9 | Host Profiles | `ils://host-profiles` | - | Profile list + active indicator |
| 10 | Themes | `ils://themes` | - | Theme list + editor |
| 11 | Hooks | `ils://hooks` | - | Hook management + CRUD |
| 12 | Agent Teams | `ils://teams` | - | Team management |
| 13 | Sidebar | (swipe/menu) | - | Navigation panel |

Detail views (reachable via list item taps, not deep links):
- Skill Detail, MCP Server Detail, Plugin Detail, Host Profile Detail
- Session Info, Chat Menu, Theme Editor, Hook Editor

## Minimum Screenshot Counts

| Platform | Required | Achievable From | Strategy |
|----------|----------|-----------------|----------|
| iPhone | 15+ | 13 deep-linkable + sidebar (swipe) + 1-2 detail views | Script + 1-2 manual captures |
| iPad | 15+ | 13 deep-linkable + sidebar + 1-2 detail views | Script + verify split-view layout |
| Mac | 10+ | 12 deep-linkable + menu bar | Script covers all |

## Open Questions

1. **Browser "Discover" tab navigation**
   - What we know: No direct deep link for the Discover tab; deep links go to `ils://skills` (Skills tab) or `ils://plugins` (Plugins tab)
   - What's unclear: Whether the Discover tab can be reached programmatically without idb_tap
   - Recommendation: Navigate to Browser via `ils://skills`, then use idb_tap on the "Discover" segment. Alternatively, capture Browser with Skills tab visible (already covers requirement) and add Discover as bonus.

2. **Detail view navigation**
   - What we know: Detail views (SkillDetailView, MCPServerDetailView) require tapping a list item; no deep link
   - What's unclear: Whether idb_tap coordinates are stable across devices
   - Recommendation: Use `idb_describe operation:all` to get accessibility tree, then `idb_tap` at the first list item's coordinates. This is needed only for 1-2 bonus detail screenshots per platform.

3. **Sidebar screenshot on iPhone**
   - What we know: iPhone sidebar is opened via left-edge swipe (`idb ui swipe 5 500 300 500 --duration 0.3`), not deep link
   - What's unclear: Whether the swipe gesture works reliably after deep link navigation
   - Recommendation: Capture sidebar after navigating to Home, then swipe. If unreliable, modify `@State isSidebarOpen = true` temporarily, build, capture, revert.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- direct reading of `SidebarRootView.swift`, `MacContentView.swift`, `AppState.swift`, `ILSMacApp.swift`, `ILSCommands.swift`
- **Simulator inventory** -- `xcrun simctl list devices available` (verified booted state of iPhone + iPad)
- **Evidence patterns** -- `evidence/phase-49-foundation/capture.sh` (existing capture script template)
- **Previous evidence** -- `.omc/evidence/ipad-validation/` (5 iPad screenshots), `.omc/evidence/cross-platform-audit/` (iphone/ipad/mac subdirectories)

### Secondary (MEDIUM confidence)
- **macOS screencapture** -- `man screencapture` (verified `-l <windowid>` flag exists and works)
- **Quartz window ID** -- Python one-liner tested successfully (found Simulator window ID = 7871)
- **DerivedData paths** -- `find` verified: iPhone at `.../Debug-iphonesimulator/ILSApp.app`, Mac at `.../Debug/ILSMacApp.app`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are Apple-provided CLI utilities already used in previous phases
- Architecture: HIGH - Evidence directory structure follows established patterns from phase-49-foundation
- Pitfalls: HIGH - Every pitfall documented from real issues encountered in previous validation phases (v3.5, v4.0)

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (30 days -- tools are stable Apple CLI utilities)
