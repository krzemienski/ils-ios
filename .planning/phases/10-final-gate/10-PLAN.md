# Phase 10: Final Gate — PLAN

## Objective

Verify every requirement (REQ-01 through REQ-15) with concrete, real-device evidence captured through the ios-validation-runner protocol. Produce a comprehensive pass/fail report with a full traceability matrix and declare the cross-platform audit complete or identify remaining gaps.

**Governing Mandates:**
- **Functional Validation Only**: NO mocks, stubs, test doubles, unit tests, or test files. NO test frameworks. NO mock fallbacks. All validation is through the real running system on real user interfaces.
- **ios-validation-runner Protocol**: Every task that touches the real app follows the SETUP-RECORD-ACT-COLLECT-VERIFY pipeline (defined below).
- **Evidence-First**: Define specific PASS criteria BEFORE capturing evidence. Every claim must reference a concrete evidence file.

---

## ios-validation-runner Protocol

Every task that interacts with the iOS app MUST follow this five-phase protocol. No shortcuts.

### SETUP
1. Boot simulator `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max, iOS 18.6):
   ```bash
   xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null || true
   ```
2. Override status bar for clean screenshots:
   ```bash
   xcrun simctl status_bar 50523130-57AA-48B0-ABD0-4D59CE455F14 override \
     --time "9:41" --batteryState charged --batteryLevel 100 \
     --wifiBars 3 --cellularBars 4
   ```
3. Verify backend health at port 9999:
   ```bash
   # Confirm correct binary (MUST be from ils-ios, NOT ils/ILSBackend)
   lsof -i :9999 -P -n | grep -q "ils-ios" || { echo "WRONG BACKEND"; exit 1; }
   curl -sf http://localhost:9999/health || { echo "BACKEND UNHEALTHY"; exit 1; }
   ```
4. If backend is not running or wrong binary:
   ```bash
   lsof -ti :9999 | xargs kill -9 2>/dev/null || true
   cd /Users/nick/Desktop/ils-ios && PORT=9999 swift run ILSBackend &
   sleep 8
   curl -sf http://localhost:9999/health
   ```

### RECORD
1. Start video recording BEFORE app launch:
   ```bash
   xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 recordVideo \
     --codec h264 --force evidence/phase-10-final/<task-id>-recording.mp4 &
   VIDEO_PID=$!
   ```
2. Start log streaming BEFORE app launch:
   ```bash
   xcrun simctl spawn 50523130-57AA-48B0-ABD0-4D59CE455F14 log stream \
     --predicate 'subsystem == "com.ils.app"' \
     > evidence/phase-10-final/<task-id>-logs.txt 2>&1 &
   LOG_PID=$!
   ```

### ACT
1. Fresh install from DerivedData (NOT local build/):
   ```bash
   xcrun simctl uninstall 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app 2>/dev/null || true
   APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 2>/dev/null | head -1)
   xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP_PATH"
   xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
   sleep 3
   ```
2. Interact with the app: navigate, tap, scroll, trigger the feature under test.
3. Screenshot each meaningful state:
   ```bash
   xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot \
     evidence/phase-10-final/<task-id>-<state-name>.png
   ```

### COLLECT
1. Stop log streaming:
   ```bash
   kill $LOG_PID 2>/dev/null || true
   ```
2. Stop video recording (SIGINT, NOT kill -9 — kill -9 corrupts the mp4):
   ```bash
   kill -INT $VIDEO_PID 2>/dev/null || true
   wait $VIDEO_PID 2>/dev/null || true
   ```
3. Check for crash reports:
   ```bash
   find ~/Library/Logs/DiagnosticReports -name "ILSApp*" -newer /tmp/phase10-start-marker 2>/dev/null
   ```

### VERIFY
1. Read every screenshot captured (visually confirm content matches PASS criteria).
2. Grep logs for errors:
   ```bash
   grep -iE "(error|crash|fatal|exception|assert)" evidence/phase-10-final/<task-id>-logs.txt || echo "NO ERRORS"
   ```
3. Write PASS/FAIL verdict with specific evidence file references.
4. If FAIL: document the gap, apply the fix, re-run the protocol from SETUP.

---

## Prerequisites

- Phase 9 complete (VG-28 functional PASS, VG-29 bug hunt PASS, all P0/P1 bugs fixed)
- Clean builds on all targets:
  - iOS: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet`
  - macOS: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet`
  - Backend: `swift build` (zero errors)
- Backend running: `PORT=9999 swift run ILSBackend` from `/Users/nick/Desktop/ils-ios/`
- Backend health confirmed: `curl -s http://localhost:9999/health` returns OK
- Simulator booted: iPhone 16 Pro Max UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Evidence directory created: `mkdir -p evidence/phase-10-final/visual`
- Start marker for crash report detection: `touch /tmp/phase10-start-marker`

---

## Team Composition

| Teammate | Agent Type | Model | Responsibilities |
|----------|-----------|-------|------------------|
| requirements-verifier | verifier | opus | Verify each REQ (01-15) individually using the ios-validation-runner protocol. Produce per-REQ evidence with PASS/FAIL verdicts. Make the final determination. |
| evidence-collector | verifier | opus | Capture all screenshots, curl outputs, video recordings, and build logs. Organize into `evidence/phase-10-final/`. Run visual regression capture in parallel with requirements verification. |
| report-generator | writer | opus | Compile the final report with traceability matrix, per-REQ evidence links, overall PASS/FAIL verdict, confidence level, and known issues. |

---

## Task Breakdown

### Task 10.1: Build Verification Baseline

- **Owner**: evidence-collector
- **Description**: Produce clean build evidence for all three targets. This establishes that the final binary is clean and the app can be installed fresh.

- **PASS Criteria** (define BEFORE capturing):
  - iOS build: zero errors, zero warnings
  - macOS build: zero errors, zero warnings
  - Backend build: zero errors
  - Backend health endpoint: HTTP 200
  - Fresh install succeeds on simulator

- **Steps**:
  1. Create evidence directory:
     ```bash
     mkdir -p evidence/phase-10-final/visual
     touch /tmp/phase10-start-marker
     ```
  2. Run iOS build and capture full output:
     ```bash
     xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
       -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' \
       -quiet 2>&1 | tee evidence/phase-10-final/00-ios-build.log | tail -20
     ```
  3. Run macOS build and capture full output:
     ```bash
     xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
       -destination 'platform=macOS' -quiet 2>&1 | tee evidence/phase-10-final/00-macos-build.log | tail -20
     ```
  4. Run backend build and capture output:
     ```bash
     swift build 2>&1 | tee evidence/phase-10-final/00-backend-build.log | tail -20
     ```
  5. Verify backend is running from correct binary:
     ```bash
     lsof -i :9999 -P -n | tee -a evidence/phase-10-final/00-backend-check.log
     curl -sv http://localhost:9999/health 2>&1 | tee -a evidence/phase-10-final/00-backend-check.log
     ```
  6. Fresh install on simulator (ios-validation-runner SETUP + ACT):
     ```bash
     xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null || true
     xcrun simctl status_bar 50523130-57AA-48B0-ABD0-4D59CE455F14 override \
       --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
     xcrun simctl uninstall 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app 2>/dev/null || true
     APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 2>/dev/null | head -1)
     xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP_PATH"
     xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
     sleep 3
     xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot \
       evidence/phase-10-final/00-fresh-launch.png
     ```
  7. Compile results into `evidence/phase-10-final/00-build-baseline.md`

- **Files to create**: `evidence/phase-10-final/00-build-baseline.md`, build logs, screenshot
- **Acceptance Criteria**: All three targets build with zero errors, backend healthy, fresh install screenshot captured

---

### Task 10.2: REQ-01 — Sidebar Navigation on All Platforms

- **Owner**: requirements-verifier
- **Description**: Verify sidebar is present and functional on iPhone, iPad, and Mac. Every sidebar item must navigate to the correct destination. Deep links must work.

- **PASS Criteria** (define BEFORE capturing):
  - iPhone: hamburger menu visible in toolbar, sidebar slides in from left (280pt width), all 6 items present (Home, System Monitor, Browse, Agent Teams, Fleet/Profiles, Settings), each item navigates correctly, sidebar dismisses after selection
  - iPad: persistent `NavigationSplitView` with sidebar column (min 260, ideal 300, max 380)
  - macOS: three-column `NavigationSplitView` with all 7 sections (Home, System Monitor, Browse, Agent Teams, Fleet, Themes, Settings)
  - Deep links: `ils://home`, `ils://settings`, `ils://system`, `ils://browser`, `ils://fleet`, `ils://themes` all navigate to correct screen
  - Zero crashes during navigation

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.2-sidebar-recording.mp4`, start log stream `10.2-sidebar-logs.txt`
  - **ACT**:
    1. Launch app, screenshot home screen (`req-01-home-initial.png`)
    2. Swipe from left edge to open sidebar: `idb ui swipe 5 500 300 500 --duration 0.3`
    3. Screenshot sidebar open (`req-01-sidebar-open.png`)
    4. Verify all items visible via `idb_describe operation:all`
    5. Tap each sidebar item, screenshot the resulting screen:
       - Home -> `req-01-nav-home.png`
       - System Monitor -> `req-01-nav-sysmon.png`
       - Browse -> `req-01-nav-browse.png`
       - Agent Teams -> `req-01-nav-teams.png`
       - Fleet/Profiles -> `req-01-nav-fleet.png`
       - Settings -> `req-01-nav-settings.png`
    6. Test deep links:
       ```bash
       xcrun simctl openurl 50523130-57AA-48B0-ABD0-4D59CE455F14 "ils://settings"
       sleep 2
       xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot evidence/phase-10-final/req-01-deeplink-settings.png
       xcrun simctl openurl 50523130-57AA-48B0-ABD0-4D59CE455F14 "ils://system"
       sleep 2
       xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot evidence/phase-10-final/req-01-deeplink-system.png
       ```
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Read every screenshot. Grep logs for errors. Write verdict.

- **Evidence**: `evidence/phase-10-final/req-01-*.png` (8+ screenshots), video, logs
- **Acceptance Criteria**: All sidebar items navigate correctly, deep links work, zero crashes

---

### Task 10.3: REQ-02 — Settings Inherit from Host CLI

- **Owner**: requirements-verifier
- **Description**: Verify >= 3 settings show "Inherited from host" badge via the `InheritanceBadge` component.

- **PASS Criteria** (define BEFORE capturing):
  - At least 3 settings display "Host Default" badge with link icon (indicating inherited from CLI)
  - Badge text is "Host Default" (inherited) or "Custom" (overridden) -- see `InheritanceBadge.body`
  - Specific settings to check: Default Model, Color Scheme, Extended Thinking, Co-Author, Default Permission Mode
  - Toggling a setting from inherited to custom changes badge from "Host Default" to "Custom"
  - Toggling back restores "Host Default"

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.3-inheritance-recording.mp4`, start log stream `10.3-inheritance-logs.txt`
  - **ACT**:
    1. Navigate to Settings
    2. Screenshot full settings showing inheritance badges (`req-02-settings-full.png`)
    3. Scroll to show all config sections, screenshot each visible section:
       - General section with model/colorScheme (`req-02-general-section.png`)
       - Thinking section (`req-02-thinking-section.png`)
       - Permissions section (`req-02-permissions-section.png`)
    4. Count visible "Host Default" badges (must be >= 3)
    5. Toggle one inherited setting to custom, screenshot (`req-02-toggled-custom.png`)
    6. Toggle it back, screenshot (`req-02-toggled-back.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Read screenshots, confirm >= 3 "Host Default" badges visible, toggle round-trip works

- **Evidence**: `evidence/phase-10-final/req-02-*.png` (5+ screenshots), video, logs
- **Acceptance Criteria**: 3+ settings display "Host Default" badge, toggle round-trip works

---

### Task 10.4: REQ-03 — Model Defaults to Host CLI Value

- **Owner**: requirements-verifier
- **Description**: Verify the default model shown is from the host CLI, not hardcoded.

- **PASS Criteria** (define BEFORE capturing):
  - Backend config endpoint returns a model value or null (null = inherited from CLI)
  - Settings UI model picker shows the correct model name (not "Sonic" or garbage)
  - If config.model is null, the displayed model reflects the CLI default (typically Opus or Sonnet)
  - Model picker opens and shows available models

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.4-model-recording.mp4`, start log stream `10.4-model-logs.txt`
  - **ACT**:
    1. Query backend config:
       ```bash
       curl -s http://localhost:9999/api/v1/config | python3 -m json.tool | tee evidence/phase-10-final/req-03-config-response.json
       ```
    2. Navigate to Settings in app
    3. Screenshot model picker area (`req-03-model-picker.png`)
    4. Tap model picker to open it, screenshot expanded picker (`req-03-model-picker-open.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Compare API response model value with what the UI displays. Confirm NOT "Sonic".

- **Evidence**: `evidence/phase-10-final/req-03-*.png`, `req-03-config-response.json`, video, logs
- **Acceptance Criteria**: Model picker shows correct host CLI default, not "Sonic" or incorrect value

---

### Task 10.5: REQ-04 — Skills Screen Shows Real Skills

- **Owner**: requirements-verifier
- **Description**: Verify skills data is from the real Claude Code skills API. No node_modules entries.

- **PASS Criteria** (define BEFORE capturing):
  - API total count matches UI displayed count
  - Zero entries contain "node_modules" in their path or name
  - Skills show real names (e.g., "commit", "review-pr", etc.)
  - Skill rows display name and relevant metadata
  - Tapping a skill shows detail view

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.5-skills-recording.mp4`, start log stream `10.5-skills-logs.txt`
  - **ACT**:
    1. Query backend skills API:
       ```bash
       curl -s "http://localhost:9999/api/v1/skills?page=1&per=10" | python3 -m json.tool | tee evidence/phase-10-final/req-04-skills-api.json
       curl -s "http://localhost:9999/api/v1/skills?page=1&per=100" | python3 -c "import sys,json; d=json.load(sys.stdin); print('total:', d.get('metadata',{}).get('total','N/A')); [print('HAS NODE_MODULES:', s) for s in json.dumps(d).split(',') if 'node_modules' in s.lower()]" | tee evidence/phase-10-final/req-04-node-modules-check.txt
       ```
    2. Navigate to Browser -> Skills tab
    3. Screenshot skills list (`req-04-skills-list.png`)
    4. Scroll through first page of skills, screenshot (`req-04-skills-scrolled.png`)
    5. Tap a skill for detail view, screenshot (`req-04-skill-detail.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Compare API count with UI count. Confirm zero node_modules. Read screenshots.

- **Evidence**: `evidence/phase-10-final/req-04-*.png`, API JSON, node_modules check output, video, logs
- **Acceptance Criteria**: API count matches UI count, zero node_modules entries, detail view works

---

### Task 10.6: REQ-05 — Plugins Screen with GitHub Browse/Install

- **Owner**: requirements-verifier
- **Description**: Verify plugins display correctly with GitHub browse/install functionality.

- **PASS Criteria** (define BEFORE capturing):
  - Plugins tab shows installed plugins with name, enabled/disabled status
  - GitHub browse action is available (button/link visible)
  - Clear distinction between Skills (capabilities) and Plugins (extensions) in UI
  - Plugin detail view shows configuration options
  - API plugin count matches UI count

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.6-plugins-recording.mp4`, start log stream `10.6-plugins-logs.txt`
  - **ACT**:
    1. Query backend plugins API:
       ```bash
       curl -s "http://localhost:9999/api/v1/plugins?page=1&per=10" | python3 -m json.tool | tee evidence/phase-10-final/req-05-plugins-api.json
       ```
    2. Navigate to Browser -> Plugins tab
    3. Screenshot plugins list (`req-05-plugins-list.png`)
    4. Verify enabled/disabled indicators visible
    5. Tap a plugin for detail/config view (`req-05-plugin-detail.png`)
    6. Look for GitHub browse button, screenshot if present (`req-05-github-action.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Read screenshots. Confirm GitHub action visible. Confirm skills vs plugins distinction.

- **Evidence**: `evidence/phase-10-final/req-05-*.png`, API JSON, video, logs
- **Acceptance Criteria**: Plugins display with status, GitHub actions available, distinct from Skills

---

### Task 10.7: REQ-06 — Hooks Management Screen

- **Owner**: requirements-verifier
- **Description**: Verify hooks management is present and functional.

- **PASS Criteria** (define BEFORE capturing):
  - Hooks are listed with: event type (sessionStart, subagentStart, userPromptSubmit, preToolUse, postToolUse), command/script path, enabled/disabled status
  - Toggle to enable/disable a hook works (or is available)
  - Distinction between inherited (global) and local (project) hooks shown
  - If hooks screen is incomplete, document exact gap with severity

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.7-hooks-recording.mp4`, start log stream `10.7-hooks-logs.txt`
  - **ACT**:
    1. Query backend config for hooks:
       ```bash
       curl -s http://localhost:9999/api/v1/config | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('data',{}).get('hooks',d.get('hooks','NO HOOKS KEY')), indent=2))" | tee evidence/phase-10-final/req-06-hooks-api.json
       ```
    2. Navigate to hooks display in Settings -> Advanced section
    3. Screenshot hooks area (`req-06-hooks-display.png`)
    4. If dedicated HooksView exists, navigate there and screenshot (`req-06-hooks-full.png`)
    5. Check for event type labels, command paths, status indicators
    6. If a toggle exists, tap it and screenshot (`req-06-hooks-toggled.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Read screenshots. Confirm hooks listed with name, type, status. Document any gaps.

- **Evidence**: `evidence/phase-10-final/req-06-*.png`, API JSON, video, logs
- **Files**: May need modifications if hooks management is incomplete
- **Acceptance Criteria**: Hooks visible with name, type, and status. Gaps documented if present.

---

### Task 10.8: REQ-07 — System Monitor Real-Time Metrics

- **Owner**: requirements-verifier
- **Description**: Verify system monitor shows live data that updates, not stale or stuck.

- **PASS Criteria** (define BEFORE capturing):
  - CPU, Memory, Disk, Network metrics display with real numeric values (not "Loading...", not "N/A")
  - At least one metric value changes within 10 seconds (proves live data)
  - WebSocket connection indicator shows connected
  - Process list loads with real processes (count > 0)
  - File browser loads directory listing

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.8-sysmon-recording.mp4`, start log stream `10.8-sysmon-logs.txt`
  - **ACT**:
    1. Navigate to System Monitor
    2. Screenshot immediately at T=0 (`req-07-sysmon-t0.png`)
    3. Wait 12 seconds
    4. Screenshot at T=12s (`req-07-sysmon-t12.png`)
    5. Navigate to Process List, screenshot (`req-07-process-list.png`)
    6. Navigate to File Browser, screenshot (`req-07-file-browser.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Compare T=0 and T=12 screenshots — at least one metric value must differ. Confirm no "Loading..." text. Read process list screenshot for real data.

- **Evidence**: `evidence/phase-10-final/req-07-*.png` (4 screenshots), video, logs
- **Acceptance Criteria**: Metrics update within 10 seconds, processes visible, no "Loading..."

---

### Task 10.9: REQ-08 — Fleet -> Profiles Terminology

- **Owner**: requirements-verifier
- **Description**: Verify "Fleet" has been replaced with appropriate terminology or document remaining occurrences.

- **PASS Criteria** (define BEFORE capturing):
  - `grep -ri "fleet"` in user-visible Swift strings returns zero hits (ideal)
  - OR all remaining "Fleet" occurrences are documented with severity assessment
  - Profile switching UI works (if renamed) or fleet management UI works (if kept)
  - Navigation to the screen works from sidebar

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.9-fleet-recording.mp4`, start log stream `10.9-fleet-logs.txt`
  - **ACT**:
    1. Run grep for "fleet" in user-visible strings:
       ```bash
       grep -ri "fleet" ILSApp/ILSApp/Views/ --include="*.swift" -n | tee evidence/phase-10-final/req-08-fleet-grep-ios.txt
       grep -ri "fleet" ILSApp/ILSMacApp/ --include="*.swift" -n | tee evidence/phase-10-final/req-08-fleet-grep-macos.txt
       ```
    2. Navigate to Fleet/Profiles screen from sidebar
    3. Screenshot the screen (`req-08-fleet-screen.png`)
    4. Screenshot the navigation title (`req-08-fleet-title.png`)
    5. Check sidebar label, screenshot sidebar with this item visible (`req-08-sidebar-label.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Analyze grep results. Read screenshots for visible "Fleet" vs "Profiles" text. Document every user-visible occurrence.

- **Evidence**: `evidence/phase-10-final/req-08-*.png`, grep output files, video, logs
- **Acceptance Criteria**: All user-visible "Fleet" replaced with "Profiles"/"Hosts" (or documented as known gap with severity)

---

### Task 10.10: REQ-09 — Quick Actions Above Recent Sessions

- **Owner**: requirements-verifier
- **Description**: Verify visual ordering on home screen: quick actions grid is ABOVE recent sessions.

- **PASS Criteria** (define BEFORE capturing):
  - Home screen layout order (top to bottom): welcome section, quick actions grid, recent sessions
  - Quick actions include: New Session, Skills, MCP Servers, Plugins (4 items)
  - Quick actions are visually above (higher Y coordinate) than the "Recent Sessions" section
  - Each quick action is tappable and navigates to the correct destination

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.10-home-recording.mp4`, start log stream `10.10-home-logs.txt`
  - **ACT**:
    1. Navigate to Home screen (should be default)
    2. Screenshot full home screen (`req-09-home-full.png`)
    3. Use `idb_describe operation:all` to get accessibility tree and confirm element order
    4. Tap "New Session" quick action, screenshot destination (`req-09-new-session-tap.png`)
    5. Navigate back, tap "Skills" quick action, screenshot (`req-09-skills-tap.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Read home screenshot. Confirm quick actions grid is visually above "Recent Sessions" header. Confirm all 4 actions present.

- **Evidence**: `evidence/phase-10-final/req-09-*.png` (3+ screenshots), video, logs
- **Acceptance Criteria**: Quick actions visually above recent sessions, all 4 actions present and tappable

---

### Task 10.11: REQ-10 — All Settings Have Tooltips

- **Owner**: requirements-verifier
- **Description**: Verify all settings items have info tooltip explanations.

- **PASS Criteria** (define BEFORE capturing):
  - At least 8 settings items have an info tooltip button (SettingsInfoButton / InfoTooltipButton)
  - Tapping the info button shows a popover with explanatory text
  - Tooltips cover at minimum: Default Model, Color Scheme, Extended Thinking, Co-Author, Permission Mode
  - Each tooltip text is meaningful (not empty, not placeholder)

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.11-tooltips-recording.mp4`, start log stream `10.11-tooltips-logs.txt`
  - **ACT**:
    1. Navigate to Settings
    2. Use `idb_describe operation:all` to locate all info tooltip buttons (14x14 buttons)
    3. Count tooltip buttons visible
    4. Tap first tooltip button, screenshot popover (`req-10-tooltip-1.png`)
    5. Dismiss, scroll to next section, tap another tooltip, screenshot (`req-10-tooltip-2.png`)
    6. Repeat for at least 3 distinct tooltips (`req-10-tooltip-3.png`)
    7. Code-verify total count:
       ```bash
       grep -c "settingAnnotation\|InfoTooltipButton\|SettingsInfoButton" ILSApp/ILSApp/Views/Settings/*.swift | tee evidence/phase-10-final/req-10-tooltip-count.txt
       ```
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Confirm >= 8 tooltip instances from code grep. Confirm screenshots show real popover text. Write count table.

- **Evidence**: `evidence/phase-10-final/req-10-*.png` (3+ screenshots), `req-10-tooltip-count.txt`, video, logs
- **Files**: May need to add tooltips if count < 8
- **Acceptance Criteria**: >= 8 settings have info tooltips that display meaningful text on tap

---

### Task 10.12: REQ-11 — Default Themes with Previews

- **Owner**: requirements-verifier
- **Description**: Verify >= 3 themes are available with previews, and selection changes appearance.

- **PASS Criteria** (define BEFORE capturing):
  - Themes list shows all 13 built-in themes (Carbon, Crimson, Cyberpunk, ElectricGrid, Ember, GhostProtocol, Graphite, Midnight, NeonNoir, Obsidian, Paper, Slate, Snow)
  - Each theme row has a preview card with color swatches
  - Selecting a different theme changes the entire app appearance (background, text, accent colors)
  - Theme editor shows editable tokens (color, typography, spacing, radius)

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.12-themes-recording.mp4`, start log stream `10.12-themes-logs.txt`
  - **ACT**:
    1. Navigate to Themes screen
    2. Screenshot themes list (`req-11-themes-list.png`)
    3. Scroll to show all themes (`req-11-themes-scrolled.png`)
    4. Select a visually distinct theme (e.g., Cyberpunk or NeonNoir), wait 1s for transition
    5. Screenshot with new theme applied (`req-11-theme-applied-1.png`)
    6. Navigate to Home to see theme applied globally (`req-11-theme-on-home.png`)
    7. Select a second theme (e.g., Paper or Snow)
    8. Screenshot with second theme (`req-11-theme-applied-2.png`)
    9. Open Theme Editor, screenshot (`req-11-theme-editor.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Confirm 13 themes visible. Compare theme-applied screenshots — colors must be different. Theme editor must show token categories.

- **Evidence**: `evidence/phase-10-final/req-11-*.png` (6 screenshots), video, logs
- **Acceptance Criteria**: 13 themes available, previews visible, selection visibly changes app appearance, editor works

---

### Task 10.13: REQ-12 — MCP Servers Properly Registered

- **Owner**: requirements-verifier
- **Description**: Verify MCP servers are registered in backend and display correctly in the app.

- **PASS Criteria** (define BEFORE capturing):
  - API returns array of MCP servers with fields: name, status (healthy/unhealthy), config
  - Browser -> MCP tab shows server count matching API
  - Health status indicator (green = healthy, red = unhealthy) visible per server
  - Tapping a server opens detail view with name, status, tools list, config

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.13-mcp-recording.mp4`, start log stream `10.13-mcp-logs.txt`
  - **ACT**:
    1. Query MCP API:
       ```bash
       curl -s "http://localhost:9999/api/v1/mcp" | python3 -m json.tool | tee evidence/phase-10-final/req-12-mcp-api.json
       ```
    2. Navigate to Browser -> MCP tab
    3. Screenshot MCP server list (`req-12-mcp-list.png`)
    4. Verify server count matches API
    5. Tap a server for detail view (`req-12-mcp-detail.png`)
    6. Scroll detail to show tools list if present (`req-12-mcp-tools.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Compare API count with UI count. Confirm health indicators. Detail view shows real data.

- **Evidence**: `evidence/phase-10-final/req-12-*.png`, `req-12-mcp-api.json`, video, logs
- **Acceptance Criteria**: MCP servers listed with name, status, health indicator, detail view functional

---

### Task 10.14: REQ-13 — Backend API Correct Structures

- **Owner**: requirements-verifier
- **Description**: Verify all major API endpoints return proper `APIResponse` wrappers with camelCase keys.

- **PASS Criteria** (define BEFORE capturing):
  - All endpoints return JSON with `APIResponse` wrapper structure (typically `data`, `metadata` or `success` keys)
  - All field names are camelCase (NOT snake_case) — e.g., `messageCount`, `createdAt`, `updatedAt`
  - Paginated responses include metadata: `total`, `page`, `per`
  - Error responses return appropriate HTTP codes (404 for missing resource, not 500)
  - Tested endpoints: health, sessions, projects, skills, mcp, plugins, config, stats

- **Steps** (no ios-validation-runner needed — API-only verification):
  1. Test each endpoint:
     ```bash
     echo "=== Health ===" | tee evidence/phase-10-final/req-13-api-verification.md
     curl -s http://localhost:9999/health | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Sessions ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/sessions?page=1&per=3" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Projects ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/projects?page=1&per=3" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Skills ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/skills?page=1&per=3" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== MCP ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/mcp" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Plugins ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/plugins?page=1&per=3" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Config ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/config" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== Stats ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s "http://localhost:9999/api/v1/stats" | python3 -m json.tool | tee -a evidence/phase-10-final/req-13-api-verification.md
     echo -e "\n\n=== 404 Error Handling ===" | tee -a evidence/phase-10-final/req-13-api-verification.md
     curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:9999/api/v1/sessions/00000000-0000-0000-0000-000000000000 | tee -a evidence/phase-10-final/req-13-api-verification.md
     ```
  2. Verify camelCase in responses:
     ```bash
     curl -s "http://localhost:9999/api/v1/sessions?page=1&per=1" | python3 -c "
     import sys,json
     d = json.dumps(json.load(sys.stdin))
     snake = [w for w in ['message_count','created_at','updated_at','session_id'] if w in d]
     camel = [w for w in ['messageCount','createdAt','updatedAt','sessionId'] if w in d]
     print(f'snake_case found: {snake}')
     print(f'camelCase found: {camel}')
     print('PASS' if not snake and camel else 'FAIL')
     " | tee evidence/phase-10-final/req-13-case-check.txt
     ```

- **Evidence**: `evidence/phase-10-final/req-13-api-verification.md`, `req-13-case-check.txt`
- **Acceptance Criteria**: All endpoints return proper APIResponse, camelCase, correct HTTP codes

---

### Task 10.15: REQ-14 — Zero Visual Regressions

- **Owner**: evidence-collector
- **Description**: Capture final screenshots of all screens on iOS. Compare against Phase 8 baselines if they exist. Run macOS build and verify visually.

- **PASS Criteria** (define BEFORE capturing):
  - All major screens render without layout breaks, clipped text, or missing elements
  - Colors are consistent with active theme (no raw white/black leaking through themed views)
  - Font sizes use Dynamic Type / theme tokens (no hardcoded size: 10)
  - Spacing is consistent (theme spacing tokens applied)
  - If Phase 8 baselines exist: no regressions (same layout, same elements, colors may differ if theme changed)
  - macOS app builds and launches without crash

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.15-visual-recording.mp4`, start log stream `10.15-visual-logs.txt`
  - **ACT**: Capture fresh screenshots of every major screen:
    1. Home (`visual/ios-01-home.png`)
    2. Sidebar open (`visual/ios-02-sidebar.png`)
    3. System Monitor (`visual/ios-03-sysmon.png`)
    4. Browse - MCP tab (`visual/ios-04-browse-mcp.png`)
    5. Browse - Skills tab (`visual/ios-05-browse-skills.png`)
    6. Browse - Plugins tab (`visual/ios-06-browse-plugins.png`)
    7. Agent Teams (`visual/ios-07-teams.png`)
    8. Fleet/Profiles (`visual/ios-08-fleet.png`)
    9. Settings top (`visual/ios-09-settings-top.png`)
    10. Settings scrolled (`visual/ios-10-settings-scroll.png`)
    11. Themes list (`visual/ios-11-themes.png`)
    12. Chat view (open a session) (`visual/ios-12-chat.png`)
    13. New Session sheet (`visual/ios-13-new-session.png`)
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**:
    1. Read every screenshot — check for layout breaks, clipped text, missing elements
    2. If Phase 8 baselines exist at `evidence/phase-04-platforms/`, compare
    3. Build and verify macOS:
       ```bash
       xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
         -destination 'platform=macOS' -quiet 2>&1 | tail -5
       ```
    4. Write comparison notes to `evidence/phase-10-final/req-14-visual-regression.md`

- **Evidence**: `evidence/phase-10-final/visual/ios-*.png` (13 screenshots), regression notes, video, logs
- **Files**: Fix any visual regressions found
- **Acceptance Criteria**: Zero layout breaks, zero visual regressions, macOS builds clean

---

### Task 10.16: REQ-15 — Sessions Data Consistency

- **Owner**: requirements-verifier
- **Description**: Verify home recent sessions matches dedicated sessions view and API data.

- **PASS Criteria** (define BEFORE capturing):
  - Home screen shows top 5 recent sessions (sorted by updatedAt descending)
  - The same 5 sessions appear in the sidebar/sessions list
  - Session names, models, and message counts match between Home, Sidebar, and API
  - Total session count on Home matches API total
  - No phantom or duplicate sessions

- **ios-validation-runner Protocol**:
  - **SETUP**: Boot simulator, override status bar, verify backend at :9999
  - **RECORD**: Start video `10.16-sessions-recording.mp4`, start log stream `10.16-sessions-logs.txt`
  - **ACT**:
    1. Query API for recent sessions:
       ```bash
       curl -s "http://localhost:9999/api/v1/sessions?page=1&per=5&sort=updatedAt&order=desc" | python3 -m json.tool | tee evidence/phase-10-final/req-15-sessions-api.json
       ```
    2. Navigate to Home screen, screenshot recent sessions area (`req-15-home-sessions.png`)
    3. Open sidebar, expand sessions list (`req-15-sidebar-sessions.png`)
    4. Compare: same 5 sessions with same names visible in both
    5. Note total session count on Home screen
  - **COLLECT**: Stop logs, stop video (SIGINT), check crash reports
  - **VERIFY**: Cross-reference API response with Home screenshot and Sidebar screenshot. All 5 sessions must match by name. Total counts must match.

- **Evidence**: `evidence/phase-10-final/req-15-*.png`, `req-15-sessions-api.json`, video, logs
- **Acceptance Criteria**: Same 5 sessions in Home, Sidebar, and API with matching data

---

### Task 10.17: Final Report Generation

- **Owner**: report-generator
- **Description**: Compile the final audit report with complete traceability matrix, per-REQ evidence links, overall verdict, confidence level, and known issues.

- **PASS Criteria** (define BEFORE writing):
  - Report contains: build verification section, traceability matrix (all 15 REQs), per-REQ PASS/FAIL with evidence file references, overall verdict with confidence level, known issues table, recommendations
  - Every REQ references specific evidence files (not "see evidence/" generically)
  - Verdict follows the threshold rules (PASS/CONDITIONAL PASS/FAIL)
  - Report is at `evidence/phase-10-final/FINAL-REPORT.md`

- **Report structure** (`evidence/phase-10-final/FINAL-REPORT.md`):
  ```markdown
  # ILS iOS/macOS Cross-Platform Audit — Final Report

  **Date**: [date]
  **Commit**: [git rev-parse HEAD]
  **Auditors**: requirements-verifier (opus), evidence-collector (opus), report-generator (opus)

  ## Build Verification
  - iOS: [PASS/FAIL] — zero errors, zero warnings — `evidence/phase-10-final/00-ios-build.log`
  - macOS: [PASS/FAIL] — zero errors, zero warnings — `evidence/phase-10-final/00-macos-build.log`
  - Backend: [PASS/FAIL] — zero errors — `evidence/phase-10-final/00-backend-build.log`
  - Fresh install: [PASS/FAIL] — `evidence/phase-10-final/00-fresh-launch.png`

  ## Requirements Traceability Matrix

  | REQ-ID | Requirement | Status | Evidence Files | Notes |
  |--------|-------------|--------|----------------|-------|
  | REQ-01 | Sidebar navigation | PASS/FAIL | `req-01-sidebar-open.png`, `req-01-nav-*.png`, `req-01-deeplink-*.png` | [details] |
  | REQ-02 | Settings inheritance | PASS/FAIL | `req-02-settings-full.png`, `req-02-toggled-*.png` | [details] |
  | REQ-03 | Model defaults | PASS/FAIL | `req-03-model-picker.png`, `req-03-config-response.json` | [details] |
  | REQ-04 | Skills accuracy | PASS/FAIL | `req-04-skills-list.png`, `req-04-skills-api.json` | [details] |
  | REQ-05 | Plugins + GitHub | PASS/FAIL | `req-05-plugins-list.png`, `req-05-plugin-detail.png` | [details] |
  | REQ-06 | Hooks management | PASS/FAIL | `req-06-hooks-display.png`, `req-06-hooks-api.json` | [details] |
  | REQ-07 | System monitor | PASS/FAIL | `req-07-sysmon-t0.png`, `req-07-sysmon-t12.png` | [details] |
  | REQ-08 | Fleet -> Profiles | PASS/FAIL | `req-08-fleet-grep-*.txt`, `req-08-fleet-screen.png` | [details] |
  | REQ-09 | Quick actions | PASS/FAIL | `req-09-home-full.png` | [details] |
  | REQ-10 | Settings tooltips | PASS/FAIL | `req-10-tooltip-*.png`, `req-10-tooltip-count.txt` | [details] |
  | REQ-11 | Themes + previews | PASS/FAIL | `req-11-themes-list.png`, `req-11-theme-applied-*.png` | [details] |
  | REQ-12 | MCP servers | PASS/FAIL | `req-12-mcp-list.png`, `req-12-mcp-api.json` | [details] |
  | REQ-13 | API structures | PASS/FAIL | `req-13-api-verification.md`, `req-13-case-check.txt` | [details] |
  | REQ-14 | Visual regression | PASS/FAIL | `visual/ios-*.png`, `req-14-visual-regression.md` | [details] |
  | REQ-15 | Sessions consistency | PASS/FAIL | `req-15-home-sessions.png`, `req-15-sessions-api.json` | [details] |

  ## Summary
  - Total requirements: 15
  - PASS: X/15
  - FAIL: Y/15
  - Overall verdict: [PASS / CONDITIONAL PASS / FAIL]
  - Confidence level: [HIGH / MEDIUM / LOW] — [justification]

  ## Known Issues & Deferred Items
  | ID | Severity | REQ | Description | Status | Workaround |
  |----|----------|-----|-------------|--------|------------|
  | ... | P2/P3 | REQ-XX | ... | Deferred | ... |

  ## Crash Report Summary
  - Crash reports found: [0 / N]
  - Details: [none / list]

  ## Recommendations
  - [Post-audit recommendations for future work]
  ```

- **Files to create**: `evidence/phase-10-final/FINAL-REPORT.md`
- **Acceptance Criteria**: Complete report with all 15 REQs addressed, every REQ has specific evidence file references, verdict stated with confidence level, known issues documented

---

## Parallel Execution Plan

```
Phase Start
  |
  +--[SEQUENTIAL: Build Baseline]--+
  |  evidence-collector: Task 10.1  |
  |  (ios-validation-runner: SETUP) |
  +---------------------------------+
  |
  +--[PARALLEL BLOCK 1: Requirements Verification]--------------------+
  |                                                                     |
  |  requirements-verifier (sequential per-REQ, each with full         |
  |  ios-validation-runner cycle):                                      |
  |    Task 10.2 (REQ-01: Sidebar Navigation)                          |
  |      -> 10.3 (REQ-02: Settings Inheritance)                        |
  |      -> 10.4 (REQ-03: Model Defaults)                              |
  |      -> 10.5 (REQ-04: Skills)                                      |
  |      -> 10.6 (REQ-05: Plugins)                                     |
  |      -> 10.7 (REQ-06: Hooks)                                       |
  |      -> 10.8 (REQ-07: System Monitor)                              |
  |      -> 10.9 (REQ-08: Fleet/Profiles)                              |
  |      -> 10.10 (REQ-09: Quick Actions)                              |
  |      -> 10.11 (REQ-10: Tooltips)                                   |
  |      -> 10.12 (REQ-11: Themes)                                     |
  |      -> 10.13 (REQ-12: MCP Servers)                                |
  |      -> 10.14 (REQ-13: API Structures)                             |
  |      -> 10.16 (REQ-15: Sessions Consistency)                       |
  |                                                                     |
  |  evidence-collector (parallel with verifier):                       |
  |    Task 10.15 (REQ-14: Visual Regression) — full screenshot set    |
  |    ios-validation-runner for all 13 screen captures                 |
  |                                                                     |
  +---------------------------------------------------------------------+
  |
  +--[SEQUENTIAL: Report Compilation]---------+
  |  report-generator: Task 10.17              |
  |  (depends on ALL verification tasks)       |
  |  Reads all evidence, compiles final report |
  +--------------------------------------------+
  |
  v
  VG-30 FINAL: Review report -> Approve or iterate
```

**Task dependencies**:
- Task 10.1 (build baseline) must complete before any verification starts
- Tasks 10.2-10.14, 10.16 are sequential for requirements-verifier (each REQ done thoroughly before next)
- Task 10.15 (visual) runs in parallel with requirements verification (different teammate)
- Task 10.17 (report) depends on ALL prior tasks completing
- If any REQ fails: apply the fix, re-run the ios-validation-runner protocol for that REQ, then continue
- If a fix requires code changes: rebuild iOS before continuing (auto-build hook handles this)

---

## Validation Gates

| Gate | Criteria | Evidence Required |
|------|----------|-------------------|
| VG-30 (FINAL) | All 15 requirements PASS with real-device screenshot evidence; zero P0/P1 bugs; clean builds on all targets; zero crashes; final report complete with traceability matrix | `evidence/phase-10-final/FINAL-REPORT.md` with per-REQ evidence references, video recordings, log files, API verification output, build logs |

### PASS Thresholds for VG-30

| Verdict | Criteria | Confidence |
|---------|----------|------------|
| **PASS** | 15/15 REQs pass, zero P0/P1 bugs, clean builds, zero crashes | HIGH |
| **CONDITIONAL PASS** | 13-14/15 REQs pass, remaining are P2 (cosmetic) with documented workarounds, zero crashes | MEDIUM |
| **FAIL** | Any P0 bug, or < 13/15 REQs pass, or any crash during validation | LOW |

---

## Evidence Requirements

### Directory Structure
```
evidence/phase-10-final/
  00-build-baseline.md               # Build verification summary
  00-ios-build.log                   # iOS build output
  00-macos-build.log                 # macOS build output
  00-backend-build.log               # Backend build output
  00-backend-check.log               # Backend binary + health check
  00-fresh-launch.png                # Fresh install screenshot
  req-01-home-initial.png            # REQ-01: Home before sidebar
  req-01-sidebar-open.png            # REQ-01: Sidebar open
  req-01-nav-home.png                # REQ-01: Navigate to Home
  req-01-nav-sysmon.png              # REQ-01: Navigate to System Monitor
  req-01-nav-browse.png              # REQ-01: Navigate to Browse
  req-01-nav-teams.png               # REQ-01: Navigate to Agent Teams
  req-01-nav-fleet.png               # REQ-01: Navigate to Fleet/Profiles
  req-01-nav-settings.png            # REQ-01: Navigate to Settings
  req-01-deeplink-settings.png       # REQ-01: Deep link ils://settings
  req-01-deeplink-system.png         # REQ-01: Deep link ils://system
  req-02-settings-full.png           # REQ-02: Settings with inheritance badges
  req-02-general-section.png         # REQ-02: General section badges
  req-02-thinking-section.png        # REQ-02: Thinking section badges
  req-02-permissions-section.png     # REQ-02: Permissions section badges
  req-02-toggled-custom.png          # REQ-02: After toggling to Custom
  req-02-toggled-back.png            # REQ-02: After toggling back to Host Default
  req-03-config-response.json        # REQ-03: Backend config API response
  req-03-model-picker.png            # REQ-03: Model picker showing default
  req-03-model-picker-open.png       # REQ-03: Model picker expanded
  req-04-skills-api.json             # REQ-04: Skills API response
  req-04-node-modules-check.txt      # REQ-04: node_modules grep result
  req-04-skills-list.png             # REQ-04: Skills tab
  req-04-skills-scrolled.png         # REQ-04: Skills scrolled
  req-04-skill-detail.png            # REQ-04: Skill detail view
  req-05-plugins-api.json            # REQ-05: Plugins API response
  req-05-plugins-list.png            # REQ-05: Plugins tab
  req-05-plugin-detail.png           # REQ-05: Plugin detail/config view
  req-05-github-action.png           # REQ-05: GitHub browse action
  req-06-hooks-api.json              # REQ-06: Hooks config from API
  req-06-hooks-display.png           # REQ-06: Hooks management display
  req-06-hooks-full.png              # REQ-06: Full hooks view (if exists)
  req-06-hooks-toggled.png           # REQ-06: Hook toggle (if available)
  req-07-sysmon-t0.png               # REQ-07: System monitor at T=0
  req-07-sysmon-t12.png              # REQ-07: System monitor at T=12s
  req-07-process-list.png            # REQ-07: Process list
  req-07-file-browser.png            # REQ-07: File browser
  req-08-fleet-grep-ios.txt          # REQ-08: grep "fleet" in iOS views
  req-08-fleet-grep-macos.txt        # REQ-08: grep "fleet" in macOS views
  req-08-fleet-screen.png            # REQ-08: Fleet/Profiles screen
  req-08-fleet-title.png             # REQ-08: Navigation title
  req-08-sidebar-label.png           # REQ-08: Sidebar label for Fleet
  req-09-home-full.png               # REQ-09: Home with quick actions + sessions
  req-09-new-session-tap.png         # REQ-09: After tapping New Session
  req-09-skills-tap.png              # REQ-09: After tapping Skills action
  req-10-tooltip-1.png               # REQ-10: First tooltip popover
  req-10-tooltip-2.png               # REQ-10: Second tooltip popover
  req-10-tooltip-3.png               # REQ-10: Third tooltip popover
  req-10-tooltip-count.txt           # REQ-10: Code grep count of all tooltips
  req-11-themes-list.png             # REQ-11: Themes list with previews
  req-11-themes-scrolled.png         # REQ-11: Themes list scrolled
  req-11-theme-applied-1.png         # REQ-11: First theme applied
  req-11-theme-on-home.png           # REQ-11: Theme visible on Home screen
  req-11-theme-applied-2.png         # REQ-11: Second theme applied
  req-11-theme-editor.png            # REQ-11: Theme editor
  req-12-mcp-api.json                # REQ-12: MCP API response
  req-12-mcp-list.png                # REQ-12: MCP servers list
  req-12-mcp-detail.png              # REQ-12: MCP server detail
  req-12-mcp-tools.png               # REQ-12: MCP tools list
  req-13-api-verification.md         # REQ-13: All API endpoint results
  req-13-case-check.txt              # REQ-13: camelCase vs snake_case check
  req-14-visual-regression.md        # REQ-14: Visual comparison notes
  req-15-home-sessions.png           # REQ-15: Home recent sessions
  req-15-sidebar-sessions.png        # REQ-15: Sidebar sessions list
  req-15-sessions-api.json           # REQ-15: Sessions API response
  visual/                            # REQ-14: Full screenshot set
    ios-01-home.png
    ios-02-sidebar.png
    ios-03-sysmon.png
    ios-04-browse-mcp.png
    ios-05-browse-skills.png
    ios-06-browse-plugins.png
    ios-07-teams.png
    ios-08-fleet.png
    ios-09-settings-top.png
    ios-10-settings-scroll.png
    ios-11-themes.png
    ios-12-chat.png
    ios-13-new-session.png
  10.2-sidebar-recording.mp4         # Video recordings per task
  10.2-sidebar-logs.txt              # Log streams per task
  ... (one video + log per ios-validation-runner task)
  FINAL-REPORT.md                    # Complete final report
```

### Evidence Checklist
- [ ] Build logs (iOS, macOS, Backend) — zero errors
- [ ] Health endpoint — 200 OK
- [ ] Fresh install screenshot — app launches clean
- [ ] 15 REQ evidence sets (multiple screenshots per REQ, PASS criteria defined before capture)
- [ ] API verification log — all endpoints tested, camelCase confirmed
- [ ] Video recordings — one per ios-validation-runner task
- [ ] Log streams — one per ios-validation-runner task, grepped for errors
- [ ] Crash report check — zero crashes
- [ ] Visual regression set — 13 full-screen screenshots
- [ ] Final report — complete with traceability matrix, confidence level, known issues

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| REQ-08 (Fleet->Profiles) may not be fully renamed | FAIL on REQ-08 | Assessment in Task 10.9 quantifies the gap with grep. If rename is incomplete, document as CONDITIONAL PASS with remediation plan and severity. |
| REQ-06 (Hooks) may have incomplete management UI | FAIL on REQ-06 | Settings Advanced section shows hooks count. If full management is missing, document current state and gap. CONDITIONAL PASS if hooks are visible but not toggleable. |
| REQ-10 (Tooltips) may have fewer than 8 | FAIL on REQ-10 | Code grep in Task 10.11 provides exact count. If < 8, identify which settings need tooltips and add them before declaring FAIL. |
| Backend not running or wrong binary | Blocks all verification | ios-validation-runner SETUP phase verifies with `lsof -i :9999 -P -n` that binary is from `ils-ios`. Auto-restart if wrong. |
| Phase 9 bugs not fully fixed | Cascading failures | Check `evidence/phase-06-bughunt/bug-log.md` — all P0/P1 must show "fixed" status before starting Phase 10. |
| Simulator state drift | Inconsistent evidence | ios-validation-runner ACT phase does fresh uninstall + install before every verification task. UserDefaults reset guaranteed. |
| Video recording corrupted | Missing evidence | Always stop video with SIGINT (not kill -9). Verify .mp4 file size > 0 after stop. Re-record if corrupted. |
| Crash during validation | FAIL verdict | COLLECT phase checks `~/Library/Logs/DiagnosticReports/ILSApp*`. Any crash = automatic FAIL with crash report attached to evidence. |
| Report generated before all REQs verified | Incomplete report | Task 10.17 has explicit dependency on ALL verification tasks. report-generator must not start until all 16 prior tasks signal completion. |
| Stale DerivedData binary | Testing old code | ios-validation-runner ACT phase uses `find` to locate the latest .app. Verify binary timestamp matches latest build with `stat`. |

---

## Functional Validation Mandate — Enforcement

This phase strictly adheres to the project's functional validation mandate:

1. **NO mocks, stubs, test doubles, unit tests, or test files.** Zero test frameworks. Zero mock fallbacks.
2. **All validation through real user interfaces.** The real iOS app running on the real simulator with the real backend serving real data.
3. **Evidence is king.** Every PASS/FAIL claim must reference a specific file in `evidence/phase-10-final/`.
4. **PASS criteria defined BEFORE capture.** Each task above defines exactly what constitutes PASS before any screenshot is taken.
5. **If it is not evidenced, it did not happen.** No "code review shows it works" — the running app must prove it.
