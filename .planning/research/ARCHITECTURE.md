# Architecture Patterns

**Domain:** Functional validation workflow for iOS/iPad SwiftUI app
**Researched:** 2026-02-25
**Confidence:** HIGH (based on 5 prior milestones of validation evidence and proven tooling)

## Recommended Architecture

The v3.5 validation milestone does not introduce new app code proactively. It is an orchestration architecture: how agents set up simulators, capture evidence, fix issues discovered during validation, and confirm results across two device form factors. The system under test is the existing ILS SwiftUI app; the architecture described here is the validation workflow that wraps it.

```
                          +---------------------------+
                          |   Phase 40: Environment   |
                          |   Setup & Screen Inventory|
                          +---------------------------+
                                      |
                          +-----------+-----------+
                          |                       |
                 +--------v--------+              |
                 | Phase 41:       |              |
                 | iPhone Full     |              |
                 | Validation      |              |
                 | (fix-as-you-go) |              |
                 +--------+--------+              |
                          |                       |
                 +--------v--------+     +--------+
                 | Phase 42:       |<----+
                 | iPad Full       |
                 | Validation      |
                 | (fix-as-you-go) |
                 +--------+--------+
                          |
                 +--------v--------+
                 |   Phase 43:     |
                 |   Evidence Gate |
                 |   (2 parallel   |
                 |    agents)      |
                 +-----------------+
```

### Why Sequential (Not Parallel) for iPhone Then iPad

Phase 8 (v1.0) ran 4 platform validators in parallel. That worked for a pure audit pass where no fixes were expected. v3.5 is explicitly fix-as-you-go: any issue found on iPhone gets fixed immediately, the app is rebuilt, and re-validated. If iPad validation ran in parallel, it would be testing a stale binary while iPhone fixes are being applied. Sequential ordering means:

1. iPhone validation finds and fixes issues against a single build.
2. iPad validation runs against the already-fixed binary, so iPad-specific issues are the only things left to address.
3. Evidence gate compares screenshots from the same final codebase.

**Exception:** If Phase 41 finds zero fixes needed, Phase 42 could theoretically run in parallel. But planning for that exception adds complexity without saving meaningful wall-clock time (each phase is ~30 minutes).

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Environment Setup (Phase 40)** | Create/boot iPad simulator, boot iPhone, build & install on both, verify backend, create evidence dirs, produce screen inventory with PASS criteria | All subsequent phases (provides UDIDs, paths, criteria doc) |
| **ios-validation-runner Protocol** | 5-phase pipeline (SETUP-RECORD-ACT-COLLECT-VERIFY) per screen | Each validation task executes this independently |
| **Screen Navigator** | Deep link + sidebar navigation to reach each screen deterministically | AppState.handleURL(), SidebarRootView |
| **Evidence Capture** | Screenshots, log streams, crash report checks per screen | `/tmp/v3.5-validation/{device}/{nn-screen}.png` |
| **Fix Loop** | Detect failure, edit Swift, auto-build hook fires, reinstall, re-validate | Xcode auto-build hook, `xcrun simctl install` |
| **Evidence Gate (Phase 43)** | Two independent agents read every screenshot, produce separate verdicts | Evidence directory, VERDICT files |

### Data Flow

```
1. SETUP
   xcrun simctl boot {UDID}
   xcrun simctl status_bar {UDID} override --time "9:41" --batteryState charged ...
   lsof -i :9999 -P -n | grep ils-ios      (backend binary check)
   curl -sf http://localhost:9999/health     (backend health check)

2. BUILD & INSTALL
   xcodebuild -scheme ILSApp -destination 'id={UDID}' -quiet
   APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app | head -1)
   xcrun simctl install {UDID} "$APP_PATH"
   xcrun simctl launch {UDID} com.ils.app

3. PER-SCREEN VALIDATION (repeat for each of 12+ screens)
   a. Navigate: xcrun simctl openurl {UDID} "ils://{route}"
   b. Wait 2-3s for data load
   c. Screenshot: xcrun simctl io {UDID} screenshot /tmp/v3.5-validation/{device}/{nn}-{screen}.png
   d. Read screenshot via multimodal Read tool (agent visually inspects)
   e. Check logs: grep -iE "error|crash|fatal" from log stream output
   f. PASS? --> next screen
      FAIL? --> enter Fix Loop

4. FIX LOOP (when FAIL detected)
   a. Diagnose from screenshot + logs
   b. Edit Swift file(s) -- auto-build hook fires xcodebuild automatically
   c. Wait for build to succeed
   d. xcrun simctl install {UDID} "$APP_PATH"  (reinstall with new binary)
   e. xcrun simctl launch {UDID} com.ils.app
   f. Re-navigate to failed screen via deep link
   g. Re-screenshot --> re-verify
   h. If still FAIL, loop back to (a)
   i. If PASS, log fix in FIX-NNN.md, continue to screen N+1

5. EVIDENCE GATE (Phase 43)
   Agent A reads all screenshots independently --> writes VERDICT-AGENT-A.md
   Agent B reads all screenshots independently --> writes VERDICT-AGENT-B.md
   Compare: 2/2 agree PASS on all screens --> FINAL-VERDICT.md = PASS
            Any disagreement --> re-validate that specific screen
```

---

## Evidence Directory Structure

Use `/tmp/v3.5-validation/` as the root. This follows the established pattern from Phases 8-10 and Quick Task 5, which all used `/tmp/` for evidence.

```
/tmp/v3.5-validation/
  iphone/
    00-environment-check.png        # Backend health confirmation, simulator booted
    01-home.png                     # Home/Dashboard screen
    02-sessions.png                 # Sessions list
    03-chat.png                     # Chat view with real messages
    04-browser-mcp.png              # Browser: MCP Servers tab
    05-browser-skills.png           # Browser: Skills tab
    06-browser-plugins.png          # Browser: Plugins tab
    07-settings.png                 # Settings (top section)
    07b-settings-scrolled.png       # Settings (bottom section)
    08-system-monitor.png           # System Monitor with live metrics
    09-host-profiles.png            # Host Profiles / Fleet
    10-agent-teams.png              # Agent Teams
    11-themes.png                   # Theme picker
    12-sidebar.png                  # Sidebar open state
    13-deep-link-skills.png         # Deep link verification: ils://skills
    14-deep-link-plugins.png        # Deep link verification: ils://plugins
    15-deep-link-settings.png       # Deep link verification: ils://settings
    logs/
      app.log                       # Full log stream during validation run
      errors.txt                    # Filtered errors (grep output)
      crash-check.txt               # Crash report check output
    VERDICT-iphone.md               # Per-screen PASS/FAIL with evidence refs
  ipad/
    00-environment-check.png
    01-home.png
    ... (same numbering scheme as iPhone)
    01b-split-view-layout.png       # iPad-specific: NavigationSplitView visible
    12-sidebar-persistent.png       # iPad-specific: sidebar always visible
    logs/
      app.log
      errors.txt
      crash-check.txt
    VERDICT-ipad.md
  gate/
    VERDICT-AGENT-A.md              # Independent agent A full verdict
    VERDICT-AGENT-B.md              # Independent agent B full verdict
    FINAL-VERDICT.md                # Consolidated pass/fail determination
    comparison-matrix.md            # iPhone vs iPad per-screen comparison
  fixes/
    FIX-001-{description}.md        # Fix log: what broke, what changed, before/after
    FIX-002-{description}.md
    ...
```

### Numbering Convention

Two-digit prefix (01-15) maps directly to the screen inventory in Phase 40. Suffixes like `b` (scrolled state) or `-detail` (drill-down) extend the base. Deep link screenshots use 13+ numbering. This is consistent with Phase 9 (21 screenshots) and Phase 10 (per-REQ evidence).

### Why /tmp/ and Not evidence/ in the Git Repo

Previous milestones used both patterns:
- Phase 8/9/10: `evidence/phase-{N}/` in repo (86 files, ~22.5 MB)
- Phase 12, Quick Task 5: `/tmp/` directories

For v3.5, `/tmp/` is correct because:
1. Screenshots are validation artifacts, not shipped product assets.
2. The `AppStoreMetadata/` directory already has curated marketing screenshots via Fastlane.
3. Binary PNG files bloat git history. Previous `evidence/` directories added 22.5 MB.
4. VERDICT.md files (text) and FIX-NNN.md files can be copied to `.planning/phases/` for permanent record.

---

## Device Configuration

### iPhone (Existing -- DO NOT create new)

| Property | Value |
|----------|-------|
| Name | iPhone 16 Pro Max |
| UDID | `50523130-57AA-48B0-ABD0-4D59CE455F14` |
| OS | iOS 18.6 |
| Width | 430pt (compact size class) |
| Navigation | Sheet-based sidebar overlay, NavigationStack for drill-downs |
| Screenshot cmd | `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot {path}` |

### iPad (Already Exists -- verify and boot)

| Property | Value |
|----------|-------|
| Name | iPad Pro 13 ILS |
| UDID | `C074375B-2CB2-4F95-A55C-972F2FF35041` |
| OS | iPadOS 18.6 (verify with `xcrun simctl list`) |
| Width | ~1032pt landscape / ~768pt portrait (regular size class) |
| Navigation | NavigationSplitView with persistent sidebar column |
| Screenshot cmd | `xcrun simctl io C074375B-2CB2-4F95-A55C-972F2FF35041 screenshot {path}` |

**Critical discovery:** The "iPad Pro 13 ILS" simulator already exists (UDID `C074375B-2CB2-4F95-A55C-972F2FF35041`), confirmed by `xcrun simctl list devices`. It was created during Phase 8 platform validation. No `xcrun simctl create` needed -- just boot it. An alternative is the generic "iPad Pro 13-inch (M4)" at `265C1F9B-5495-4ADC-957C-123FA879C5DE`, but the "ILS" named one was purpose-built for this project and avoids conflicts with other sessions.

### iPad-Specific Validation Points

The app uses `@Environment(\.horizontalSizeClass)` in `SidebarRootView` to branch layout:
- **iPhone (compact):** `iPhoneLayout` -- ZStack overlay sidebar, hamburger button, edge-swipe gesture
- **iPad (regular):** `iPadLayout` -- `NavigationSplitView(columnVisibility:)` with persistent sidebar (~300pt), detail area (~732pt)

iPad validation must specifically verify:
1. Sidebar is persistently visible (not overlay sheet)
2. Screen content renders in the detail column, not full-screen push
3. Sheets present as centered form sheets (standard iPad behavior)
4. Column proportions are reasonable (sidebar min:260, ideal:300, max:380)
5. Chat sessions open in detail column from sidebar session tap
6. `columnVisibility` state works (sidebar can be toggled if needed)

---

## Patterns to Follow

### Pattern 1: ios-validation-runner (Proven in Phases 8, 9, 10)

**What:** Five-phase protocol (SETUP-RECORD-ACT-COLLECT-VERIFY) for every screen interaction.
**When:** Every screen validation on every device.
**Why proven:** Phase 8 validated 49/49 screens across 4 platforms with 86 evidence files and 0 crashes. Phase 9 found and fixed 30 bugs. Phase 10 produced a full traceability matrix.

```bash
# SETUP
xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl status_bar $UDID override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4
lsof -i :9999 -P -n | grep -q "ils-ios" || { echo "WRONG BACKEND"; exit 1; }
curl -sf http://localhost:9999/health || { echo "BACKEND UNHEALTHY"; exit 1; }

# RECORD
xcrun simctl spawn $UDID log stream \
  --predicate 'subsystem == "com.ils.app"' \
  > /tmp/v3.5-validation/$DEVICE/logs/app.log 2>&1 &
LOG_PID=$!

# ACT
xcrun simctl openurl $UDID "ils://home"
sleep 3
xcrun simctl io $UDID screenshot /tmp/v3.5-validation/$DEVICE/01-home.png

# COLLECT
kill $LOG_PID 2>/dev/null || true
grep -iE "(error|crash|fatal|exception)" /tmp/v3.5-validation/$DEVICE/logs/app.log \
  > /tmp/v3.5-validation/$DEVICE/logs/errors.txt || echo "NO ERRORS"
find ~/Library/Logs/DiagnosticReports -name "ILSApp*" -newer /tmp/v3.5-start-marker 2>/dev/null \
  > /tmp/v3.5-validation/$DEVICE/logs/crash-check.txt

# VERIFY
# Agent reads screenshot via multimodal Read tool
# Agent writes PASS/FAIL verdict with specific evidence reference
```

### Pattern 2: Fix-as-you-go Loop (New for v3.5, extends Phase 9 fix pattern)

**What:** When a screen fails validation, fix it immediately rather than logging for a later fix pass.
**When:** Any FAIL verdict during Phase 41 or 42.
**Why:** Previous milestones (Phase 8) deferred cosmetic fixes. Phase 9 fixed bugs but in a separate pass. v3.5 explicitly requires every screen to PASS before moving to the next. This prevents fix accumulation and ensures the evidence gate sees only passing screenshots.

```
Screen N fails validation
  |
  v
Diagnose from screenshot + logs
  |
  v
Edit Swift file(s)
  |  (auto-build hook fires xcodebuild automatically)
  v
Build succeeds?
  |--- NO --> Fix build error, re-edit
  |--- YES -+
             v
         xcrun simctl install $UDID "$APP_PATH"   (reinstall)
         xcrun simctl launch $UDID com.ils.app
             |
             v
         Re-navigate to screen N via deep link
         Re-screenshot
             |
             v
         PASS? --> Log fix in fixes/FIX-{NNN}.md, continue to screen N+1
         FAIL? --> Loop back to diagnose
```

**Fix documentation template** (`/tmp/v3.5-validation/fixes/FIX-001-{slug}.md`):
```markdown
# FIX-001: {Brief description}
**Screen:** {nn}-{screen-name}
**Device:** iPhone / iPad / Both
**Symptom:** {What the screenshot showed}
**Root cause:** {Why it happened}
**Files changed:** {list}
**Before screenshot:** {path or description}
**After screenshot:** {path}
**Build verified:** YES (auto-build hook)
```

### Pattern 3: Deep Link Navigation (Proven in Phase 9, Quick Task 5)

**What:** Use `xcrun simctl openurl` with `ils://` deep links to navigate to each screen deterministically.
**When:** Navigating to any screen that has a registered deep link route.
**Why:** More reliable than `idb_tap` coordinate guessing. Deep links route through `AppState.handleURL()` which sets `navigationIntent`, and `SidebarRootView.onChange(of:)` switches `activeScreen`. Quick Task 5 validated and fixed browser segment routing for this exact use case.

All registered deep link routes (from `AppState.handleURL()`):
```bash
xcrun simctl openurl $UDID "ils://home"
xcrun simctl openurl $UDID "ils://sessions"
xcrun simctl openurl $UDID "ils://sessions/{lowercase-uuid}"
xcrun simctl openurl $UDID "ils://browser"
xcrun simctl openurl $UDID "ils://mcp"
xcrun simctl openurl $UDID "ils://skills"
xcrun simctl openurl $UDID "ils://plugins"
xcrun simctl openurl $UDID "ils://settings"
xcrun simctl openurl $UDID "ils://system"
xcrun simctl openurl $UDID "ils://fleet"       # routes to .hostProfiles
xcrun simctl openurl $UDID "ils://themes"
xcrun simctl openurl $UDID "ils://hooks"
xcrun simctl openurl $UDID "ils://teams"
```

**Screens that require alternative navigation (no deep link or needs interaction):**
- **Sidebar:** Swipe from left edge (`idb ui swipe 5 500 300 500 --duration 0.3`) or tap hamburger. On iPad, sidebar is persistent -- just screenshot the current view.
- **Chat View:** Needs a real session UUID. Query `/api/v1/sessions` first, take the first session ID, use `ils://sessions/{uuid}` with lowercase UUID.
- **Settings scrolled:** Navigate via `ils://settings`, wait, then scroll with Quartz scroll events or `idb ui swipe` downward.

### Pattern 4: Dual-Agent Evidence Gate (New for v3.5)

**What:** Two independent agent teammates each read every screenshot and produce independent PASS/FAIL verdicts without seeing each other's work. Final verdict requires 2/2 agreement.
**When:** Phase 43, after all screens pass on both devices.
**Why:** Prevents single-agent confirmation bias. MEMORY.md explicitly warns: "Sub-agent validation reports can contain inaccurate claims -- cross-check with actual screenshots." Having two agents independently verify eliminates this risk.

```
Phase 43 Inputs:
  /tmp/v3.5-validation/iphone/*.png   (12-15 screenshots)
  /tmp/v3.5-validation/ipad/*.png     (12-15 screenshots)
  PASS criteria document (from Phase 40 screen inventory)

Agent A (independently):
  for each screenshot in both device dirs:
    Read(screenshot.png)
    Compare visible content to PASS criteria
    Write PASS or FAIL with specific reasoning
  Write VERDICT-AGENT-A.md

Agent B (independently, same task, zero access to A's output):
  for each screenshot in both device dirs:
    Read(screenshot.png)
    Compare visible content to PASS criteria
    Write PASS or FAIL with specific reasoning
  Write VERDICT-AGENT-B.md

Orchestrator:
  diff VERDICT-A and VERDICT-B
  All screens both PASS? --> FINAL-VERDICT.md = PASS
  Any disagreement? --> Re-validate that specific screen with both agents watching
```

### Pattern 5: Newest-Binary-First Install (Lesson from Quick Task 5)

**What:** When installing from DerivedData, always select the newest binary by modification time.
**When:** Every `xcrun simctl install` call in every phase.
**Why:** Quick Task 5 discovered 40+ stale `ILSApp-*` directories in DerivedData. Using `find | head -1` grabbed a stale build. Using `ls -td | head -1` gets the newest.

```bash
# WRONG (grabs arbitrary/stale build)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 2>/dev/null | head -1)

# RIGHT (grabs newest build by modification time)
APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app 2>/dev/null | head -1)
```

Both iPhone and iPad use the same `Debug-iphonesimulator` binary. There is no separate iPad build artifact -- the universal iOS binary runs on both device types.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Parallel Fix-and-Validate on Multiple Devices

**What:** Running iPhone and iPad validation simultaneously while also fixing issues.
**Why bad:** A fix applied during iPhone validation changes the codebase. If iPad validation is running against the pre-fix binary, its results are invalid. The fix may also introduce iPad-specific regressions that only surface if iPad re-tests with the new code.
**Instead:** Complete iPhone validation first (all screens PASS). Then run iPad validation against the post-fix binary. Only the evidence gate (Phase 43) runs agents in parallel because it is read-only.

### Anti-Pattern 2: Guessing Tap Coordinates from Screenshots

**What:** Looking at a screenshot and estimating pixel coordinates for `idb_tap`.
**Why bad:** Coordinates vary by device size class, Dynamic Type setting, and content layout. Guesses frequently miss. This was a major lesson in MEMORY.md.
**Instead:** Use `idb_describe operation:all` to get the accessibility tree with exact `centerX`/`centerY`, then use those coordinates. Or, strongly prefer deep links for top-level navigation -- no tapping needed.

### Anti-Pattern 3: Video Recording for Every Screen

**What:** Starting a video recording for each individual screen validation step.
**Why bad:** Video recording consumes resources, produces large files (~50MB per recording), and the start/stop overhead slows validation. Phase 8 used video but Phase 9/10 found screenshots were the primary evidence cited in verdicts -- video was never referenced for passing screens.
**Instead:** Use screenshots as primary evidence. Use video recording only as a fallback for intermittent or animation-related issues that cannot be captured in a single frame.

### Anti-Pattern 4: Evidence Screenshots in Git Repo

**What:** Storing screenshots in `evidence/` within the git working tree.
**Why bad:** Phase 8 added 22.5 MB of binary files to the repo history. Screenshots from v3.5 would add another 10-20 MB. This bloats clone times permanently and provides no value since the VERDICT.md text files contain the actual pass/fail determinations.
**Instead:** Use `/tmp/v3.5-validation/` for screenshots. Copy only VERDICT.md and FIX-NNN.md text files to `.planning/phases/` for permanent record.

### Anti-Pattern 5: Re-reading Already-Read Files in a Session

**What:** Agents re-reading source files or screenshots they already analyzed in the same session.
**Why bad:** Wastes context window budget. CLAUDE.md explicitly warns against this pattern.
**Instead:** Track what has been read in the session. If a file has not been modified since last read, use the cached understanding.

---

## Integration Points with Existing Architecture

### Existing Components (No Modification Needed)

| Component | Location | How v3.5 Uses It |
|-----------|----------|-------------------|
| Auto-build hook | `.claude/settings.local.json` | Fires xcodebuild on every .swift edit -- fix loop gets automatic build verification for free |
| Deep link handler | `AppState.handleURL()` | All 13 routes already registered and tested (Quick Task 5 fixed browser segment routing) |
| SidebarRootView routing | `Views/Root/SidebarRootView.swift` | `ActiveScreen` enum has all 9 cases needed for screen navigation |
| iPad NavigationSplitView | `SidebarRootView.iPadLayout` | Already implemented with `columnVisibility` control for persistent sidebar |
| Status bar override | `xcrun simctl status_bar` | Proven in Phases 8-10 for clean, consistent screenshots |
| Backend health check | `curl http://localhost:9999/health` | Standard prerequisite check from all previous phases |
| iPhone simulator | UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` | Dedicated device, never use another |
| iPad simulator | UDID `C074375B-2CB2-4F95-A55C-972F2FF35041` | "iPad Pro 13 ILS" created during Phase 8, ready to boot |
| Fastlane screenshots lane | `fastlane/Fastfile` | Not used for v3.5 (it requires XCUITest snapshots); manual `simctl io screenshot` is the method |
| `idb_describe` | Facebook IDB tool | Accessibility tree with exact coordinates for any needed taps |

### New Components Created by Phase 40

| Component | Type | Purpose |
|-----------|------|---------|
| `/tmp/v3.5-validation/` tree | Filesystem dirs | Evidence storage: `{iphone,ipad}/{screenshots,logs}`, `gate/`, `fixes/` |
| Screen inventory document | Markdown | Numbered list of all 12+ screens with per-device PASS criteria |
| PASS criteria definitions | Markdown table | Specific observable states per screen: "Screen X shows Y from backend, Z layout, no errors" |
| Fix log template | Markdown | Standardized FIX-NNN documentation for every fix applied during validation |
| VERDICT templates | Markdown | Per-device verdict format and per-agent gate verdict format |
| Start marker | Empty file | `touch /tmp/v3.5-start-marker` for crash report time-gating |

### Modified Components

None planned proactively. All source code modifications happen reactively through the fix-as-you-go loop when validation discovers issues. The architecture is designed to discover what needs fixing, not to pre-plan fixes.

---

## Screen Inventory with PASS Criteria

Each screen requires specific observable evidence. These criteria define what "PASS" means concretely.

| # | Screen | Deep Link | iPhone PASS Criteria | iPad Additional Criteria |
|---|--------|-----------|---------------------|-------------------------|
| 01 | Home/Dashboard | `ils://home` | Stats cards show numbers > 0 (sessions, skills, MCP, plugins). Quick Actions row visible. Recent Sessions list non-empty. Hamburger button in nav bar. | Split view: persistent sidebar visible alongside home content in detail column. |
| 02 | Sessions List | `ils://sessions` | Session rows with names, model tags, timestamps. Count label > 0. Search bar visible at top. | Sessions visible in sidebar column or content area. Detail area shows placeholder or selected session. |
| 03 | Chat View | `ils://sessions/{uuid}` | Real messages displayed (not empty). Back button present. Session title in nav bar. No stuck loading spinner. | Chat renders in detail column. Sidebar shows session highlighted with accent color. |
| 04 | Browser: MCP | `ils://mcp` | Server list with health status badges (green "Healthy"). Server count > 0. Detail tappable. | Tab bar within detail column. Persistent sidebar still visible. |
| 05 | Browser: Skills | `ils://skills` | Skills listed with Active/Inactive badges. Search placeholder visible. Count > 0. | Same content in detail column. |
| 06 | Browser: Plugins | `ils://plugins` | Plugins listed with category filters. Enable/Disable badges visible. Version tags. Count > 0. | Same content in detail column. |
| 07 | Settings | `ils://settings` | Config values displayed. InheritanceBadge (Host Default/Custom) on fields. Info tooltip (i) buttons present. Connection status section at top with green indicator. | Full-width detail content. |
| 08 | System Monitor | `ils://system` | Live CPU %, Memory %, Disk %, Network stats visible. Process count > 0. "Live" indicator or real-time updates. | Metrics render in detail column. |
| 09 | Host Profiles | `ils://fleet` | At least one host listed (localhost). Health badge visible. Active indicator on connected host. | Host list in detail column. |
| 10 | Agent Teams | `ils://teams` | Screen renders without crash. Shows team list or empty state. | Detail column render. |
| 11 | Themes | `ils://themes` | Theme picker with 12+ built-in themes listed. Current theme visually highlighted or indicated. | Theme picker in detail column. |
| 12 | Sidebar | swipe/hamburger | All nav items visible: Home, System Monitor, Browse, Agent Teams, Host Profiles, Settings. Themes somewhere accessible. Active screen highlighted. Session list with counts. Host name shown if connected. | Sidebar is persistent (not overlay). Approximately 260-380pt width. All items visible without scrolling. |

---

## Build Order and Phase Dependencies

```
Phase 40: Environment Setup & Screen Inventory
  Prerequisites: None (milestone start)
  Outputs: Both simulators booted and verified
           App built and installed on both devices
           Backend running and health-checked
           Evidence directory tree created
           Screen inventory document with numbered PASS criteria
           Start marker file for crash report gating
  Duration: ~15 minutes

Phase 41: iPhone Full Validation
  Prerequisites: Phase 40 complete
  Inputs: iPhone UDID, evidence dir, screen inventory, PASS criteria
  Outputs: 12-15 iPhone screenshots in /tmp/v3.5-validation/iphone/
           app.log, errors.txt, crash-check.txt in logs/
           VERDICT-iphone.md with per-screen PASS/FAIL
           FIX-NNN.md files for any fixes applied
           Rebuilt binary if any fixes were made
  Duration: ~30-45 minutes (depends on number of fixes)
  Constraint: Single agent, sequential screen-by-screen, fix before advancing

Phase 42: iPad Full Validation
  Prerequisites: Phase 41 COMPLETE (all iPhone screens PASS, final binary ready)
  Inputs: iPad UDID, SAME binary from end of Phase 41, evidence dir, PASS criteria
  Outputs: 12-15 iPad screenshots in /tmp/v3.5-validation/ipad/
           app.log, errors.txt, crash-check.txt in logs/
           VERDICT-ipad.md with per-screen PASS/FAIL
           Additional FIX-NNN.md files if iPad-specific issues found
  Duration: ~20-30 minutes (fewer fixes expected -- shared code already fixed)
  Constraint: Must install the SAME binary that passed iPhone validation
  Note: If fixes are needed, must also re-verify affected iPhone screens

Phase 43: Evidence Gate
  Prerequisites: Phase 41 AND Phase 42 both COMPLETE with all PASS
  Inputs: All screenshots from both devices, PASS criteria document
  Outputs: VERDICT-AGENT-A.md, VERDICT-AGENT-B.md
           FINAL-VERDICT.md (consolidated determination)
           comparison-matrix.md (iPhone vs iPad per-screen)
  Duration: ~15-20 minutes
  Constraint: Two agents run IN PARALLEL (read-only, no code changes)
  Note: Any disagreement triggers targeted re-validation of disputed screen
```

**Total estimated duration:** 80-110 minutes

**Critical path:** Phase 40 --> Phase 41 --> Phase 42 --> Phase 43 (fully sequential except Phase 43 has internal parallelism between the two gate agents)

### Phase 42 Re-verification Rule

If Phase 42 (iPad) discovers an issue that requires a code fix, the fix may affect iPhone behavior. In that case:
1. Apply the fix.
2. Auto-build hook fires.
3. Reinstall on iPad, re-verify the fixed screen.
4. Also reinstall on iPhone, re-verify the affected screen(s) only (not full re-run).
5. Update both VERDICT files.

This prevents a scenario where an iPad fix silently breaks an iPhone screen that already passed.

---

## Sources

All findings based on direct inspection of project files and prior milestone artifacts:

- Phase 8 PLAN and SUMMARY (`.planning/phases/08-platform-validation/`) -- 49/49 screens across 4 platforms, ios-validation-runner protocol definition, team composition for parallel validation
- Phase 9 SUMMARY (`.planning/phases/09-functional-bughunt/`) -- 30 bugs found/fixed, 65+ screenshots, evidence directory structure
- Phase 10 PLAN (`.planning/phases/10-final-gate/`) -- Detailed ios-validation-runner protocol with exact bash commands, video recording approach, crash report detection
- Quick Task 5 SUMMARY (`.planning/quick/5-cross-milestone-reflection-audit-with-fu/`) -- DerivedData stale binary discovery (40+ dirs), deep link browser segment fix, 7/12 screens validated
- v3.5 Milestone Context (`.planning/v3.5-MILESTONE-CONTEXT.md`) -- Phase structure (40-43), device list, screen inventory, skill requirements
- `AppState.swift` -- Deep link routing implementation (13 routes via `handleURL()`)
- `SidebarRootView.swift` -- `ActiveScreen` enum (9 cases), `horizontalSizeClass` branching for iPhone/iPad layout, `columnVisibility` for NavigationSplitView
- `xcrun simctl list devices` output -- Confirmed "iPad Pro 13 ILS" exists at UDID `C074375B-2CB2-4F95-A55C-972F2FF35041`
- MEMORY.md -- Lessons about sub-agent validation inaccuracy, stale DerivedData binaries, idb_describe for coordinates, Quartz scroll for SwiftUI Forms

Confidence: HIGH -- all integration points verified against actual source code and proven in prior milestones.

---
*Architecture research for: ILS iOS/macOS v3.5 Comprehensive Functional Validation*
*Researched: 2026-02-25*
