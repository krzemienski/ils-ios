# Phase 41: iPhone Full Validation + Deep Links - Research

**Researched:** 2026-02-25
**Domain:** iPhone simulator functional validation, deep link navigation testing, fix-as-you-go workflow, dual-agent evidence gate
**Confidence:** HIGH

## Summary

Phase 41 is the first active validation phase of v3.5. It takes the environment established by Phase 40 (simulator booted, app installed, backend verified, PASS criteria authored) and systematically walks through every iPhone screen, captures numbered screenshot evidence, tests every deep link route, and fixes any issue discovered on the spot. The phase concludes with a dual-agent evidence gate where two independent agents review all iPhone screenshots against the PASS-CRITERIA.md document and must agree 2/2 on every screen before Phase 42 (iPad) can begin.

The critical technical finding is that `xcrun simctl io screenshot` does NOT work on this machine -- it fails with "Timeout waiting for screen surfaces" (error code 60). Phase 40 confirmed the workaround: `screencapture -l <windowID>` via Quartz `CGWindowListCopyWindowInfo`. All screenshot capture in Phase 41 MUST use this workaround, not the standard `simctl io` path. Additionally, the roadmap success criteria #2 lists 11 deep link routes but the actual codebase (`AppState.handleURL`) supports 15 routes including `hooks`, `teams`, `projects`, and `profiles`. The PASS-CRITERIA.md correctly covers all 15 routes. Phase 41 must test all 15.

The app is already in a mature state (5 prior milestones, 39 phases complete). Quick Task 5 validated 7 of 12+ screens. The primary gaps are: Chat View (including back button), Host Profiles, Themes, Hooks, and Agent Teams. These 5 screens are the highest-risk items in Phase 41 because they have never been systematically validated on the iPhone.

**Primary recommendation:** Execute screen-by-screen validation in PASS-CRITERIA.md order using deep links for navigation, `screencapture -l` for screenshots, 3-second delays after each navigation, and the fix-as-you-go loop for any failures. Capture console logs throughout. Conclude with a dual-agent gate where both agents READ every screenshot file against the PASS criteria.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IPH-01 | Home screen -- stats cards, quick actions, recent sessions, sparklines render correctly | Deep link `ils://home`. PASS criteria: stats > 0, Quick Actions visible, recent sessions non-empty, sparklines present, no stuck spinners. Quick-5 PASS -- low risk. Wait 3s for data load. |
| IPH-02 | Sessions list -- sessions load, row tap opens chat, session count matches | Deep link `ils://sessions`. PASS criteria: rows with cleaned names (no UUIDs, no `##`), model tags, timestamps, count > 0, search bar. Quick-5 PASS -- low risk. |
| IPH-03 | Chat view -- messages display, back button returns to sessions, toolbar actions visible | Deep link `ils://sessions/{uuid}` with lowercase UUID from `/tmp/v3.5-evidence/gate/session-uuid.txt` (saved in Phase 40: `eeba4856-c40c-47cc-9029-95599704c82f`). PASS criteria: real messages, session title in nav, back button, no stuck spinner, markdown rendered. NOT validated in Quick-5 -- HIGH risk. |
| IPH-04 | Browser MCP tab -- MCP servers list with health status indicators | Deep link `ils://mcp`. PASS criteria: server list with health badges, count > 0 (expect 15+), Browser tab bar visible with MCP selected. Quick-5 partial -- verify full capture. |
| IPH-05 | Browser Skills tab -- skills list with install/enable states, GitHub browse | Deep link `ils://skills`. PASS criteria: skills with Active/Inactive badges, search bar, count > 0 (expect 1000+). Quick-5 PASS -- low risk. |
| IPH-06 | Browser Plugins tab -- plugins list with enable/disable, GitHub browse | Deep link `ils://plugins`. PASS criteria: plugins with enable/disable badges, category filters, count > 0 (expect 50+). Quick-5 PASS -- low risk. |
| IPH-07 | System Monitor -- live metrics (CPU, memory, disk, network), process list, WebSocket connected | Deep link `ils://system`. PASS criteria: CPU %, Memory %, Disk %, Network stats, process count > 0 (expect 1000+), "Live" indicator. Quick-5 PASS -- low risk. |
| IPH-08 | Settings -- all sections render, inheritance badges visible, tooltips functional | Deep link `ils://settings`. PASS criteria: config values (not empty), InheritanceBadge visible, info tooltips, connection status section, PERMISSIONS section (may need scroll). Quick-5 PASS -- low risk. Scrolling needed for full coverage. |
| IPH-09 | Host Profiles -- profile list, active indicator, health badges | Deep link `ils://fleet`. PASS criteria: at least one host (localhost/"Local Backend"), health badge, active indicator, address/port info. NOT validated in Quick-5 -- MEDIUM risk. |
| IPH-10 | Themes -- theme list with preview, theme editor form | Deep link `ils://themes`. PASS criteria: 12+ built-in themes listed, current theme indicated, theme previews visible. NOT validated in Quick-5 -- MEDIUM risk. |
| IPH-11 | Sidebar navigation -- accessible from all screens, active item highlighted | iPhone sidebar requires swipe from left edge: `idb ui swipe 5 500 300 500 --duration 0.3`. PASS criteria: all nav items visible (Home, System Monitor, Browse, Agent Teams, Host Profiles, Settings, Themes, Hooks), active screen highlighted, session list visible, host name shown. |
| IPH-12 | Connection states -- connected banner, disconnected banner, reconnection behavior | Backend is running (verified in Phase 40). Only "connected" state needs screenshot. Disconnected/reconnect testing is a differentiator, not a requirement. PASS criteria: connection status visible in Settings or sidebar. |
| IPH-13 | Any issue found during validation is fixed immediately, rebuilt, and re-validated | Fix-as-you-go loop: diagnose from screenshot + logs, edit Swift (auto-build fires), reinstall via `xcrun simctl install`, re-navigate via deep link, re-screenshot. Log each fix in `/tmp/v3.5-evidence/fixes/FIX-NNN.md`. |
| DL-01 | `ils://home` navigates to Home screen | `xcrun simctl openurl 50523130-57AA-48B0-ABD0-4D59CE455F14 "ils://home"` -- sets `navigationIntent = .home` in AppState. Screenshot after 3s. |
| DL-02 | `ils://sessions` navigates to Sessions list | Sets `navigationIntent = .home` (sessions are part of home). No parameterized UUID. |
| DL-03 | `ils://sessions/{uuid}` opens specific chat session | UUID MUST be lowercase. Uses `navigateToSession(id:)` which fetches session from `/api/v1/sessions/{id}` then sets `navigationIntent = .chat(session)`. Use saved UUID: `eeba4856-c40c-47cc-9029-95599704c82f`. |
| DL-04 | `ils://browser`, `ils://mcp`, `ils://skills`, `ils://plugins` navigate to correct Browser tabs | `browser`/`projects` -> `.browser` default segment. `mcp`/`skills`/`plugins` set `browserSegmentIntent` then navigate to `.browser`. SidebarRootView consumes segment intent in `onChange`. |
| DL-05 | `ils://settings`, `ils://system`, `ils://fleet`, `ils://themes` navigate correctly | Direct `navigationIntent` mapping. `fleet`/`profiles` both map to `.hostProfiles`. Also test `ils://hooks` and `ils://teams` (present in code, missing from roadmap SC#2 but in PASS-CRITERIA.md). |
| DL-06 | Console logs captured during deep link testing -- zero crashes, zero unhandled errors | Start `xcrun simctl spawn log stream` before validation. Filter for `ILSApp` process. Capture to `/tmp/v3.5-evidence/iphone/logs/`. Grep for `error|crash|fatal|exception` at end. |
| GATE-01 | All iPhone screenshots organized with numbered naming in evidence directory | Naming convention: `01-home.png`, `02-sessions.png`, ..., `13-sidebar.png`, plus `deeplinks/dl-{route}.png`. All in `/tmp/v3.5-evidence/iphone/`. |
| GATE-03 | Agent A independently reviews screenshots and produces verdicts | Agent A reads every screenshot via multimodal Read tool, compares to PASS-CRITERIA.md, writes `VERDICT-AGENT-A.md` in `/tmp/v3.5-evidence/gate/`. Must cite specific evidence per screen. |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `screencapture -l <windowID>` | macOS system | Screenshot capture (PRIMARY) | `xcrun simctl io screenshot` fails with error 60 on this machine; `screencapture -l` captures Simulator window via Quartz -- confirmed working in Phase 40 |
| `xcrun simctl openurl` | Xcode 16+ | Deep link navigation to all `ils://` routes | Deterministic, device-independent, avoids coordinate guessing |
| `xcrun simctl spawn log stream` | Xcode 16+ | Console log capture filtered to ILSApp process | No companion connection needed; works on booted simulator |
| `xcrun simctl install` | Xcode 16+ | App installation after fix-as-you-go rebuilds | Standard reinstall path |
| `xcrun simctl launch / terminate` | Xcode 16+ | App lifecycle control | Required for clean app state after reinstall |
| `idb ui swipe` | Python 3.12 at `~/.local/bin/idb` | Open iPhone sidebar (swipe from left edge) | Only way to reach sidebar on iPhone without toolbar tap |
| `idb describe` | Python 3.12 | Accessibility tree inspection with exact coordinates | Needed for taps that have no deep link equivalent |
| `python3 -c "import Quartz; ..."` | Python 3.12 + Quartz | Discover Simulator window IDs for `screencapture -l` | Required to find correct window ID for the iPhone simulator |
| `curl` | System | Backend health check and data verification | Verify backend state before and during validation |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `idb ui tap` | Python 3.12 | Tap specific elements by coordinate | Only when deep links cannot reach a UI state (e.g., scroll, dismiss, tooltip tap) |
| `idb screenshot` | Python 3.12 | Backup screenshot method | If `screencapture -l` fails for any reason |
| `lsof -i :9999 -P -n` | System | Verify backend binary path | At session start -- must show `ils-ios/` in path |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `screencapture -l` | `xcrun simctl io screenshot` | simctl io FAILS on this machine with error 60. Not an option. |
| Deep links for navigation | `idb_tap` on sidebar items | Deep links are deterministic and device-independent; taps require `idb_describe` per device and can miss toolbar buttons |
| Manual edge swipe for sidebar | Toolbar hamburger tap | `idb_tap` cannot reliably hit SwiftUI toolbar buttons (documented in MEMORY.md) |
| `xcrun simctl spawn log stream` | `idb log` | simctl spawn is simpler; idb log needs companion but has richer predicates |

**Installation:** Nothing to install. All tools are pre-existing on this machine.

## Architecture Patterns

### Phase 41 Execution Structure

```
Phase 41: iPhone Full Validation + Deep Links
├── Pre-flight (5 min)
│   ├── Verify backend still running (lsof + curl health + response format)
│   ├── Verify iPhone simulator booted (xcrun simctl list)
│   ├── Verify app installed (xcrun simctl get_app_container)
│   ├── Find Simulator window ID via Quartz CGWindowListCopyWindowInfo
│   ├── Start log stream in background
│   └── Navigate to ils://home as clean starting point
│
├── Screen Walk: 13 screens sequential (25-35 min)
│   ├── For each screen:
│   │   ├── Navigate via deep link (or sidebar swipe for screen 13)
│   │   ├── Wait 3 seconds for data load + render
│   │   ├── screencapture -l <windowID> /tmp/v3.5-evidence/iphone/{nn}-{name}.png
│   │   ├── READ screenshot (multimodal) -- compare to PASS criteria
│   │   ├── PASS? → continue to next screen
│   │   └── FAIL? → enter Fix Loop
│   │       ├── Diagnose from screenshot + logs
│   │       ├── Edit Swift file(s) -- auto-build hook fires
│   │       ├── Wait for build success
│   │       ├── xcrun simctl install (reinstall)
│   │       ├── xcrun simctl launch (relaunch)
│   │       ├── Re-navigate + re-screenshot
│   │       ├── Log fix in /tmp/v3.5-evidence/fixes/FIX-NNN.md
│   │       └── PASS? → continue. FAIL? → loop
│   │
│   ├── 01: Home (ils://home)
│   ├── 02: Sessions (ils://sessions)
│   ├── 03: Chat (ils://sessions/eeba4856-c40c-47cc-9029-95599704c82f)
│   ├── 04: Browser MCP (ils://mcp)
│   ├── 05: Browser Skills (ils://skills)
│   ├── 06: Browser Plugins (ils://plugins)
│   ├── 07: System Monitor (ils://system)
│   ├── 08: Settings (ils://settings) + scrolled variant
│   ├── 09: Host Profiles (ils://fleet)
│   ├── 10: Agent Teams (ils://teams)
│   ├── 11: Themes (ils://themes)
│   ├── 12: Hooks (ils://hooks)
│   └── 13: Sidebar (idb ui swipe from left edge)
│
├── Deep Link Sweep: 15 routes (10 min)
│   ├── For each route:
│   │   ├── xcrun simctl openurl $UDID "ils://{route}"
│   │   ├── Wait 2 seconds
│   │   ├── screencapture -l /tmp/v3.5-evidence/iphone/deeplinks/dl-{route}.png
│   │   ├── READ screenshot -- verify correct screen displayed
│   │   └── Check logs for crashes
│   ├── Test: home, sessions, sessions/{uuid}, browser, projects, mcp,
│   │         skills, plugins, settings, system, fleet, profiles, themes, hooks, teams
│   └── Verify: no "Open in ILSApp?" dialog (app already launched)
│
├── Evidence Collection (5 min)
│   ├── Stop log stream
│   ├── Capture historical logs (log show --last 120s)
│   ├── Grep for errors/crashes
│   ├── Check crash reports (find ~/Library/Logs/DiagnosticReports)
│   ├── Write VERDICT-iphone.md with per-screen PASS/FAIL
│   └── Verify all numbered screenshots present
│
└── Dual-Agent Evidence Gate (10-15 min)
    ├── Agent A: independently reads ALL screenshots + PASS criteria → VERDICT-AGENT-A.md
    ├── Agent B: independently reads ALL screenshots + PASS criteria → VERDICT-AGENT-B.md
    ├── Compare: 2/2 agree on all screens → GATE PASSED
    └── Disagreement? → re-investigate + re-capture specific screen → re-review
```

### Pattern 1: Screenshot Capture via Quartz Window ID

**What:** `xcrun simctl io screenshot` fails on this machine. Use `screencapture -l <windowID>` instead.
**When:** Every screenshot capture in Phase 41.
**Example:**
```bash
# Find iPhone Simulator window ID (run once per session)
WINDOW_ID=$(python3 -c "
import Quartz
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly,
    Quartz.kCGNullWindowID
)
for w in windows:
    name = w.get('kCGWindowName', '')
    owner = w.get('kCGWindowOwnerName', '')
    if owner == 'Simulator' and 'iPhone' in str(name):
        print(w['kCGWindowNumber'])
        break
")

# Capture screenshot
screencapture -l "$WINDOW_ID" /tmp/v3.5-evidence/iphone/01-home.png
```
Source: Phase 40 40-01-SUMMARY.md confirmed this workaround works.

**Important:** The window ID may change if the Simulator app is restarted. Re-discover the window ID after any Simulator restart.

### Pattern 2: Deep Link Navigation + Wait + Capture

**What:** Navigate to a screen via deep link, wait for data to load, then capture.
**When:** Every screen validation.
**Example:**
```bash
UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"

# Navigate
xcrun simctl openurl "$UDID" "ils://mcp"

# Wait for navigation transition + data fetch + render
sleep 3

# Capture
screencapture -l "$WINDOW_ID" /tmp/v3.5-evidence/iphone/04-browser-mcp.png
```
Source: PITFALLS.md Pitfall 2 -- screenshot before view loads. 3 seconds accounts for navigation transition (~300ms) + API call (~100-500ms) + SwiftUI render (~200ms) + safety margin.

### Pattern 3: Fix-as-you-go Loop

**What:** When a screen fails PASS criteria, fix the code immediately, rebuild, reinstall, re-validate.
**When:** Any FAIL verdict during screen walk.
**Example:**
```bash
# 1. Diagnose from screenshot + logs
# 2. Edit Swift file(s) -- auto-build hook fires automatically
# 3. Wait for build success (hook output)
# 4. Find newest binary
APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app 2>/dev/null | head -1)
# 5. Reinstall
xcrun simctl install "$UDID" "$APP_PATH"
# 6. Relaunch
xcrun simctl launch "$UDID" com.ils.app
sleep 3
# 7. Re-navigate to failed screen
xcrun simctl openurl "$UDID" "ils://mcp"
sleep 3
# 8. Re-screenshot
screencapture -l "$WINDOW_ID" /tmp/v3.5-evidence/iphone/04-browser-mcp.png
```
Source: ARCHITECTURE.md Pattern 2, Phase 41 roadmap success criteria #4.

### Pattern 4: Sidebar Screenshot on iPhone

**What:** Open the overlay sidebar via edge swipe, then capture.
**When:** Screen 13 (Sidebar) validation.
**Example:**
```bash
# Navigate to a known screen first (so sidebar highlight is predictable)
xcrun simctl openurl "$UDID" "ils://home"
sleep 2

# Swipe from left edge to open sidebar
idb ui swipe --udid "$UDID" 5 500 300 500 --duration 0.3
sleep 1

# Capture with sidebar visible
screencapture -l "$WINDOW_ID" /tmp/v3.5-evidence/iphone/13-sidebar.png
```
Source: MEMORY.md sidebar interaction, STACK.md UI interaction tools.

### Pattern 5: Dual-Agent Evidence Gate

**What:** Two independent agents each review every screenshot against PASS criteria.
**When:** After all screens pass and evidence is collected.
**Protocol:**
1. Agent A receives: screenshot directory path + PASS-CRITERIA.md path
2. Agent A reads every screenshot (multimodal Read), compares to criteria, writes `VERDICT-AGENT-A.md`
3. Agent B receives: same inputs, zero access to Agent A's output
4. Agent B reads every screenshot independently, writes `VERDICT-AGENT-B.md`
5. Orchestrator compares: 2/2 PASS on all screens = gate passed
6. Any disagreement triggers re-investigation of that specific screen

Source: ARCHITECTURE.md Pattern 4, GATE-01/GATE-03 requirements.

### Anti-Patterns to Avoid

- **Using `xcrun simctl io screenshot`:** FAILS on this machine. Always use `screencapture -l`.
- **Screenshotting immediately after navigation:** SwiftUI views need 2-3 seconds to fetch data from backend and render. Always `sleep 3` after navigation.
- **Using `find | head -1` for DerivedData binary:** Returns arbitrary stale binary. Use `ls -td | head -1`.
- **Guessing tap coordinates from screenshots:** Use `idb describe` for accessibility tree or deep links for navigation.
- **Tapping SwiftUI toolbar buttons via `idb_tap`:** Known limitation -- fails silently. Use edge swipe for sidebar, deep links for screens.
- **Uppercase UUIDs in deep links:** `UUID().uuidString` returns uppercase. Deep link handler uses `UUID(uuidString:)` which is case-insensitive, but the path extraction trims and passes to the API. Always use lowercase.
- **Capturing screenshots between a fix and a rebuild:** The simulator still has the OLD binary. Always wait for auto-build hook + reinstall before re-screenshot.
- **Running video recording for every screen:** Wastes resources and produces 50MB files. Use screenshots as primary evidence. Video only for intermittent issues.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screenshot capture | Custom Swift tool, Fastlane snapshot | `screencapture -l <windowID>` via Quartz | Zero overhead, proven in Phase 40, no build required |
| Screen navigation | Tap coordinate scripts | `xcrun simctl openurl` deep links | Deterministic, device-independent, no coordinate calculation |
| Evidence naming | Metadata database or JSON manifest | Filesystem naming convention (`{nn}-{name}.png`) | Proven in 5 milestones; agent reads filenames directly |
| Build verification | Manual xcodebuild after fixes | Auto-build hook (fires on every .swift edit) | Already configured; no action needed |
| Dual-agent coordination | IPC, WebSocket, or custom framework | File system + separate Task calls | Agents share filesystem; verdict files are the coordination mechanism |
| Log analysis | Custom log parsing tool | `grep -iE "error|crash|fatal|exception"` on captured log | One-liner, zero build, proven approach |

**Key insight:** Phase 41 is a validation workflow, not a software engineering task. Every tool needed already exists. The temptation to build "validation infrastructure" adds complexity without capability.

## Common Pitfalls

### Pitfall 1: `xcrun simctl io screenshot` Fails With Error 60 (CRITICAL -- CONFIRMED)

**What goes wrong:** `xcrun simctl io screenshot` returns "Timeout waiting for screen surfaces" (error code 60) and produces no output file. This is not intermittent -- it fails consistently on this machine.
**Why it happens:** macOS/Simulator GPU rendering issue where the screen surface is not available to `simctl io`.
**How to avoid:** Use `screencapture -l <windowID>` exclusively. Discover window ID via Quartz `CGWindowListCopyWindowInfo`.
**Warning signs:** Empty evidence directory, zero-byte screenshot files, or command returning non-zero exit code.
**Confidence:** HIGH -- confirmed in Phase 40 (40-01-SUMMARY.md).

### Pitfall 2: Screenshot Before View Finishes Loading (CRITICAL)

**What goes wrong:** Screenshot captured before SwiftUI `.task {}` completes data fetch. Shows loading spinner, empty content, or partial list.
**Why it happens:** `screencapture` is instant; SwiftUI views need 1-3 seconds to fetch from localhost backend and render.
**How to avoid:** `sleep 3` after every deep link navigation before capturing. For cold launch (first screen after install), wait 5 seconds.
**Warning signs:** Screenshot shows "Loading..." or empty cards where stats should be.
**Confidence:** HIGH -- documented in PITFALLS.md P2.

### Pitfall 3: Stale Binary After Fix-as-you-go (CRITICAL)

**What goes wrong:** Code is fixed, auto-build hook fires, but the screenshot is captured before `xcrun simctl install` reinstalls the new binary. The screenshot shows the OLD behavior, producing a false FAIL or false PASS.
**Why it happens:** Auto-build hook builds the binary but does NOT reinstall it. The agent must explicitly run `xcrun simctl install` after the build completes.
**How to avoid:** Full cycle after every fix: build (auto) -> find newest binary (`ls -td | head -1`) -> install -> launch -> navigate -> wait 3s -> screenshot.
**Warning signs:** Fix applied but screenshot looks unchanged; deep link that was "fixed" still does not work.
**Confidence:** HIGH -- documented in PITFALLS.md P1, occurred in Quick Task 5.

### Pitfall 4: Deep Link UUID Must Be Lowercase (MODERATE)

**What goes wrong:** `ils://sessions/EEBA4856-...` with uppercase UUID navigates to Home instead of the specific session. `UUID(uuidString:)` is case-insensitive, but path extraction or API lookup may fail with uppercase.
**Why it happens:** Documented in CLAUDE.md: "Deep link UUIDs must be LOWERCASE -- uppercase causes failures."
**How to avoid:** Always lowercase UUIDs: `echo "$UUID" | tr '[:upper:]' '[:lower:]'`. The session UUID saved in Phase 40 (`eeba4856-c40c-47cc-9029-95599704c82f`) is already lowercase.
**Warning signs:** Deep link navigates to Home instead of chat session.
**Confidence:** HIGH -- documented project pitfall.

### Pitfall 5: Sidebar Swipe Fails or Misses (MODERATE)

**What goes wrong:** `idb ui swipe` from left edge does not open the sidebar, or opens it partially.
**Why it happens:** Swipe coordinates or duration may not trigger the `DragGesture` in SidebarRootView. The swipe must start from x=5 (very left edge) and travel at least 100 points horizontally.
**How to avoid:** Use the proven command: `idb ui swipe --udid $UDID 5 500 300 500 --duration 0.3`. If it fails, try with slightly different y-coordinate or longer duration (0.5).
**Warning signs:** Screenshot 13 shows no sidebar overlay.
**Confidence:** HIGH -- proven in multiple prior sessions (MEMORY.md).

### Pitfall 6: Fresh Install Triggers Onboarding Sheet (MODERATE)

**What goes wrong:** If the app was uninstalled/reinstalled during a fix cycle, UserDefaults are cleared. `showOnboarding` may become true, showing ServerSetupSheet instead of the expected screen.
**Why it happens:** `xcrun simctl uninstall` + `install` removes app sandbox. `ConnectionManager` reads `hasConnectedBefore` from UserDefaults.
**How to avoid:** After reinstall, launch and wait 3-5 seconds for auto-connect to backend at localhost:9999. The app should auto-discover and connect. If onboarding appears, dismiss it by connecting to `http://localhost:9999`.
**Warning signs:** Screenshot shows ServerSetupSheet instead of expected screen.
**Confidence:** HIGH -- documented in PITFALLS.md P5.

### Pitfall 7: Simulator Window ID Changes After Restart (MINOR)

**What goes wrong:** The Quartz window ID discovered at the start of the session becomes stale if the Simulator app crashes or is restarted.
**Why it happens:** `CGWindowListCopyWindowInfo` returns runtime window IDs that are not persistent.
**How to avoid:** Re-discover window ID if any Simulator restart occurs. Add a verification step: `screencapture -l $WINDOW_ID /tmp/test.png && stat /tmp/test.png` to confirm the ID is still valid.
**Warning signs:** `screencapture -l` produces an error or captures the wrong window.
**Confidence:** MEDIUM -- inferred from Quartz API behavior; not yet observed in practice.

### Pitfall 8: Agent Reads Wrong Screenshot for Wrong Screen (MINOR)

**What goes wrong:** During evidence gate, agent reads `05-browser-skills.png` but it actually shows the MCP tab (wrong segment was selected). The naming implies Skills but content is MCP.
**Why it happens:** Browser segment routing was fragile (fixed in commit d351068 for Quick Task 5). If `browserSegmentIntent` is not consumed correctly, wrong tab may display.
**How to avoid:** After capturing each Browser tab screenshot, visually verify the tab bar shows the correct segment selected. During evidence gate, agents must verify BOTH filename AND content match expectations.
**Warning signs:** Browser screenshots all look identical; tab bar highlight does not match expected segment.
**Confidence:** MEDIUM -- browser segment routing was recently fixed but remains a known fragile area.

## Code Examples

### Complete Screenshot Capture Setup

```bash
# Discover iPhone Simulator window ID
IPHONE_WINDOW_ID=$(python3 -c "
import Quartz
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly,
    Quartz.kCGNullWindowID
)
for w in windows:
    name = w.get('kCGWindowName', '')
    owner = w.get('kCGWindowOwnerName', '')
    if owner == 'Simulator' and 'iPhone' in str(name):
        print(w['kCGWindowNumber'])
        break
")
echo "iPhone Window ID: $IPHONE_WINDOW_ID"

# Verify it works
screencapture -l "$IPHONE_WINDOW_ID" /tmp/test-capture.png
stat /tmp/test-capture.png  # Should show non-zero size
rm /tmp/test-capture.png
```

### Complete Deep Link Test Sequence

```bash
UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
EVIDENCE="/tmp/v3.5-evidence/iphone/deeplinks"

# All 15 deep link routes
ROUTES=(
  "home" "sessions" "browser" "projects"
  "mcp" "skills" "plugins"
  "settings" "system" "fleet" "profiles"
  "themes" "hooks" "teams"
)

for route in "${ROUTES[@]}"; do
  xcrun simctl openurl "$UDID" "ils://$route"
  sleep 2
  screencapture -l "$IPHONE_WINDOW_ID" "$EVIDENCE/dl-$route.png"
done

# Parameterized session deep link (lowercase UUID)
SESSION_UUID="eeba4856-c40c-47cc-9029-95599704c82f"
xcrun simctl openurl "$UDID" "ils://sessions/$SESSION_UUID"
sleep 3
screencapture -l "$IPHONE_WINDOW_ID" "$EVIDENCE/dl-session-detail.png"
```

### Log Capture Pattern

```bash
UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
LOGDIR="/tmp/v3.5-evidence/iphone/logs"

# Start background log stream (info + debug levels MANDATORY per skill protocol)
xcrun simctl spawn "$UDID" log stream \
  --process ILSApp --level info --style compact \
  > "$LOGDIR/validation-run.log" 2>&1 &
LOG_PID=$!

# ... run all validation steps ...

# Stop log stream
kill "$LOG_PID" 2>/dev/null || true

# Also capture historical logs
xcrun simctl spawn "$UDID" log show --last 120s \
  --process ILSApp --style compact \
  > "$LOGDIR/historical.log" 2>&1

# Extract errors
grep -iE "(error|crash|fatal|exception|abort)" "$LOGDIR/validation-run.log" \
  > "$LOGDIR/errors.txt" 2>/dev/null || echo "NO ERRORS FOUND" > "$LOGDIR/errors.txt"

# Check crash reports
find ~/Library/Logs/DiagnosticReports -name "ILSApp*" -newer /tmp/v3.5-evidence/iphone/01-home.png 2>/dev/null \
  > "$LOGDIR/crash-check.txt" || echo "NO CRASH REPORTS" > "$LOGDIR/crash-check.txt"
```

### Fix-as-you-go Documentation Template

```markdown
# FIX-001: {Brief description}

**Screen:** {nn}-{screen-name}
**Symptom:** {What the screenshot showed -- specific, not vague}
**Root cause:** {Why it happened -- file and line if possible}
**Files changed:** {list of modified files}
**Build verified:** YES (auto-build hook)
**Reinstalled:** YES (xcrun simctl install)
**Before screenshot:** {path to failed screenshot or "not captured"}
**After screenshot:** {path to passing screenshot}
**Other screens affected:** {list or "none"}
```

### Backend Verification (Pre-flight)

```bash
# 1. Binary path check
lsof -i :9999 -P -n | grep LISTEN
# Must contain "ils-ios" in path

# 2. Health check
curl -sf http://localhost:9999/health
# Must return {"status":"healthy"}

# 3. Response format check
curl -s http://localhost:9999/api/v1/sessions | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'data' in d or 'items' in d.get('data', {}):
    print('OK: APIResponse wrapper')
else:
    print('FAIL: wrong backend binary')
    sys.exit(1)
"
```

## Specific Screen Navigation Details

### Screen-by-Screen Deep Link + Expected ActiveScreen

| # | Screen | Navigation Command | ActiveScreen | Special Notes |
|---|--------|--------------------|--------------|---------------|
| 01 | Home | `openurl ils://home` | `.home` | Wait 5s on cold launch for stats |
| 02 | Sessions | `openurl ils://sessions` | `.home` (sessions section) | Sessions are part of Home view |
| 03 | Chat | `openurl ils://sessions/eeba4856-c40c-47cc-9029-95599704c82f` | `.chat(session)` | Async fetch; wait 3s; lowercase UUID |
| 04 | MCP | `openurl ils://mcp` | `.browser` (segment: .mcp) | Uses browserSegmentIntent mechanism |
| 05 | Skills | `openurl ils://skills` | `.browser` (segment: .skills) | Uses browserSegmentIntent mechanism |
| 06 | Plugins | `openurl ils://plugins` | `.browser` (segment: .plugins) | Uses browserSegmentIntent mechanism |
| 07 | System | `openurl ils://system` | `.system` | WebSocket connection; may need 3-5s |
| 08 | Settings | `openurl ils://settings` | `.settings` | Scroll down for PERMISSIONS section |
| 09 | Fleet | `openurl ils://fleet` | `.hostProfiles` | Also: `ils://profiles` alias |
| 10 | Teams | `openurl ils://teams` | `.teams` | May show empty state |
| 11 | Themes | `openurl ils://themes` | `.themes` | 12+ built-in themes expected |
| 12 | Hooks | `openurl ils://hooks` | `.hooks` | May show empty state with config path |
| 13 | Sidebar | `idb ui swipe 5 500 300 500 --duration 0.3` | (overlay chrome) | Must be on a screen first; active item highlighted |

### Settings Scrolling (for IPH-08 full coverage)

Settings requires scrolling to see PERMISSIONS section. Options:
1. **Quartz scroll events:** `CGEventCreateScrollWheelEvent` via Python (proven in MEMORY.md)
2. **idb ui swipe:** Downward swipe `idb ui swipe --udid $UDID 200 800 200 300 --duration 0.3`
3. **Capture two screenshots:** `08-settings-top.png` and `08b-settings-scrolled.png`

The idb swipe approach is simplest. Capture Settings top first, swipe down, capture scrolled state.

## Deep Link Route Discrepancy

**Finding:** The roadmap success criteria #2 for Phase 41 lists 11 routes:
> `home`, `sessions`, `sessions/{uuid}`, `browser`, `mcp`, `skills`, `plugins`, `settings`, `system`, `fleet`, `themes`

But `AppState.handleURL()` actually handles 15 routes:
- All 11 listed above, PLUS:
- `projects` (alias for `browser`)
- `profiles` (alias for `fleet`)
- `hooks`
- `teams`

The PASS-CRITERIA.md deep link table correctly lists all 15 routes. **Phase 41 must test all 15 routes**, not just the 11 in the roadmap success criteria. The roadmap omission is not intentional -- it was authored before the PASS criteria refinement.

**Confidence:** HIGH -- verified by reading `AppState.handleURL()` source code directly.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `xcrun simctl io screenshot` | `screencapture -l <windowID>` | Phase 40 (2026-02-25) | simctl io fails on this machine; screencapture is the only working method |
| `find \| head -1` for binary | `ls -td \| head -1` for newest | Quick Task 5 (2026-02-25) | Prevents stale binary install -- highest-risk pitfall |
| Single-agent verification | Dual-agent gate (2/2 agreement) | v3.5 milestone definition | Prevents false PASS from confirmation bias |
| Separate fix phase after validation | Fix-as-you-go during validation | v3.5 Phase 41 design | Issues fixed before advancing; iPad gets post-fix binary |
| Phase 43 standalone gate | Gate embedded in Phase 41 and 42 | v3.5 roadmap revision | Issues caught where they belong; no rework pile-up |

## Evidence Organization

### iPhone Evidence Directory Structure

```
/tmp/v3.5-evidence/iphone/
  01-home.png
  02-sessions.png
  03-chat.png
  04-browser-mcp.png
  05-browser-skills.png
  06-browser-plugins.png
  07-system-monitor.png
  08-settings-top.png
  08b-settings-scrolled.png
  09-host-profiles.png
  10-agent-teams.png
  11-themes.png
  12-hooks.png
  13-sidebar.png
  deeplinks/
    dl-home.png
    dl-sessions.png
    dl-session-detail.png
    dl-browser.png
    dl-projects.png
    dl-mcp.png
    dl-skills.png
    dl-plugins.png
    dl-settings.png
    dl-system.png
    dl-fleet.png
    dl-profiles.png
    dl-themes.png
    dl-hooks.png
    dl-teams.png
  logs/
    validation-run.log
    historical.log
    errors.txt
    crash-check.txt
```

### Verdict File Format

```markdown
# VERDICT: iPhone Validation - Agent {A/B}

**Date:** 2026-02-25
**Agent:** A (or B)
**Evidence Directory:** /tmp/v3.5-evidence/iphone/

## Screen Verdicts

| # | Screen | File | Verdict | Evidence |
|---|--------|------|---------|----------|
| 01 | Home | 01-home.png | PASS/FAIL | {specific observation: "Stats cards show 22,439 sessions, 1,152 skills..."} |
| 02 | Sessions | 02-sessions.png | PASS/FAIL | {specific observation} |
...

## Deep Link Verdicts

| Route | File | Correct Screen? | Verdict |
|-------|------|-----------------|---------|
| ils://home | dl-home.png | YES/NO | PASS/FAIL |
...

## Log Verdict

- Crashes found: {count}
- Unhandled errors: {count}
- Overall: PASS/FAIL

## Summary

**Screens:** {count} PASS / {count} FAIL
**Deep Links:** {count} PASS / {count} FAIL
**Overall:** PASS / FAIL
```

## Open Questions

1. **Settings scrolled screenshot method**
   - What we know: PERMISSIONS section requires scrolling. Both Quartz scroll events and `idb ui swipe` are documented as working.
   - What's unclear: Whether `idb ui swipe` scroll on a SwiftUI Form (which is a List under the hood) will work reliably on this specific screen.
   - Recommendation: Try `idb ui swipe` first. Fall back to Quartz scroll if needed. Two screenshots (top + scrolled) is the safe approach.

2. **Connection state validation scope (IPH-12)**
   - What we know: Requirement says "connected banner, disconnected banner, reconnection behavior." Backend IS running (connected state). Disconnected testing would require stopping the backend mid-validation.
   - What's unclear: Whether the requirement demands actual disconnected-state screenshots or just connected-state validation.
   - Recommendation: Capture connected state (visible in Settings connection indicator and sidebar host name). Document disconnected/reconnect as out of scope for Phase 41 unless explicitly required. The connected state is the prerequisite for all other screenshots.

3. **Chat view session UUID validity**
   - What we know: Phase 40 saved UUID `eeba4856-c40c-47cc-9029-95599704c82f` in `/tmp/v3.5-evidence/gate/session-uuid.txt`. The `navigateToSession` code fetches from `/api/v1/sessions/{id}` and falls back to a minimal session if not found.
   - What's unclear: Whether this session has actual message content for a compelling chat screenshot.
   - Recommendation: Use the saved UUID first. If the chat view shows no messages, query the backend for a session with messages: `curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; sessions=json.load(sys.stdin)['data']['items']; [print(s['id']) for s in sessions if s.get('messageCount',0) > 2][:1]"`.

4. **Browser segment persistence across deep link switches**
   - What we know: `browserSegmentIntent` is set by `handleURL` and consumed by `SidebarRootView.onChange`. When switching from `ils://skills` to `ils://mcp`, the segment should update.
   - What's unclear: Whether rapid successive deep link calls (e.g., testing all 3 browser tabs in quick succession) cause the `browserSegmentIntent` to be consumed correctly each time, or if the `.id()` regeneration on BrowserView causes state loss.
   - Recommendation: Wait 3 seconds between browser tab deep link tests. If a wrong tab appears, navigate away (`ils://home`) and back to the desired browser tab.

## Skill Protocol Integration

The five pre-invoked skills define the following mandatory behaviors for Phase 41:

### ios-validation-runner (Five-Phase Protocol)
Every screen validation follows: SETUP (verify simulator + backend) -> RECORD (start log stream) -> ACT (navigate + interact) -> COLLECT (stop logs, check crashes) -> VERIFY (read screenshot, write verdict). The RECORD phase starts log stream with `--info --debug` MANDATORY. VERIFY phase must READ every screenshot, not just confirm file existence.

### ils-ios-project (Project Knowledge)
- Simulator UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Backend port: 9999 (NOT 9090 -- some old docs reference wrong port)
- Bundle ID: `com.ils.app`
- Sidebar swipe: `idb ui swipe 5 500 300 500 --duration 0.3`
- Deep link routes: 15 total in `AppState.handleURL()`

### functional-validation (No-Mock Mandate)
- ZERO test frameworks, mocks, or stubs
- Validate through real user interfaces only
- Define PASS criteria BEFORE capturing evidence (done: PASS-CRITERIA.md)
- After fixing, RE-VALIDATE from step 1 (full re-validation of that screen)

### ios-validation-gate (Three-Gate Protocol)
Each screen must pass three gates:
1. SIMULATOR -- screenshot captured AND read, expected UI visible
2. BACKEND -- relevant endpoint returns valid data (verify with curl)
3. ANALYSIS -- frontend screenshot + backend response + logs tell consistent story

### gate-validation-discipline (Evidence Examination)
- NEVER mark complete based on sub-agent reports without personal examination
- Must READ actual screenshots (multimodal Read tool)
- Must CITE specific evidence for each criterion ("Stats show 22,439 sessions" not "stats visible")
- Anti-pattern: "Agent reported PASS" without reading the screenshot yourself

## Sources

### Primary (HIGH confidence)
- Local machine: Phase 40 execution confirmed `screencapture -l` workaround, backend running, simulators booted
- Codebase: `AppState.swift` handleURL() -- 15 deep link routes verified line by line
- Codebase: `SidebarRootView.swift` -- ActiveScreen enum (9 cases), navigationIntent consumption, browserSegmentIntent handling
- Project: PASS-CRITERIA.md -- 13 screens with numbered verification points per device
- Project: PITFALLS.md -- 16 catalogued pitfalls with prevention strategies
- Project: ARCHITECTURE.md -- fix-as-you-go loop, dual-agent gate, evidence directory structure
- Project: STACK.md -- tool inventory, screenshot commands, deep link patterns
- Project: FEATURES.md -- 14 screens, 15 deep link routes, validation dimensions

### Secondary (MEDIUM confidence)
- MEMORY.md -- sidebar swipe coordinates, idb_describe for taps, Quartz scroll for Forms, fresh install UserDefaults clearing
- Quick Task 5 SUMMARY -- 7/12 screens validated, stale binary discovery, deep link browser segment fix

### Tertiary (LOW confidence)
- None. All findings verified against local machine state, source code, and Phase 40 execution evidence.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools verified present and working (screencapture workaround confirmed in Phase 40)
- Architecture: HIGH -- execution structure follows proven patterns from 5 prior milestones, adapted for fix-as-you-go and embedded gate
- Pitfalls: HIGH -- top 8 pitfalls sourced from documented project incidents and Phase 40 execution
- Deep links: HIGH -- all 15 routes verified in source code (AppState.handleURL)

**Research date:** 2026-02-25
**Valid until:** 2026-03-10 (stable -- no moving targets in the tool stack or app architecture)
