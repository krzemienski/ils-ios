# Phase 8: Full Platform Validation — PLAN

## Objective

Execute a parallel visual and functional audit across all 4 Apple platform targets — iPhone 16 Pro (compact), iPhone 16 Pro Max (large phone), iPad Pro 13" (regular width with split view), and Mac (native macOS app with multi-window) — using the **ios-validation-runner protocol** (SETUP -> RECORD -> ACT -> COLLECT -> VERIFY) for every validation task. All validation is through **real user interfaces only** — no mocks, stubs, test doubles, or test files.

## Functional Validation Mandate

This phase operates under the **functional-validation mandate**:

- **NEVER** write mocks, stubs, test doubles, unit tests, or test files. No test frameworks. No mock fallbacks.
- **ALWAYS** build and run the real system. Validate through actual user interfaces. Capture and verify evidence before claiming completion.
- **Define specific PASS criteria BEFORE capturing evidence** — not "app works" but specific observable states (e.g., "sidebar width is between 260-380pt", "CPU chart renders with at least 2 data points", "session count label shows a number > 0").
- **Evidence directory**: `evidence/phase-08-platforms/`
- **Every claim requires proof**: a screenshot, a log excerpt, or a video frame. No claim without evidence.

## ios-validation-runner Protocol

Every task that validates iOS or macOS UI MUST follow this 5-phase protocol:

### SETUP
1. Boot target simulator (or confirm macOS app environment)
2. Override status bar for clean screenshots: `xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4`
3. Verify backend health: `curl -sf http://localhost:9999/health` (must return 200)
4. Verify backend binary is correct: `lsof -i :9999 -P -n` (path must contain `ils-ios/`)
5. Clean install: `xcrun simctl uninstall <UDID> com.ils.app` then fresh install from DerivedData

### RECORD
1. Start video recording BEFORE app launch: `xcrun simctl io <UDID> recordVideo --codec h264 evidence/phase-08-platforms/<platform>/recording.mp4 &`
2. Start log streaming BEFORE app launch: `xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "com.ils.app"' > evidence/phase-08-platforms/<platform>/app.log 2>&1 &`
3. Record PIDs of both background processes for cleanup

### ACT
1. Install from DerivedData: `xcrun simctl install <UDID> ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app`
2. Launch: `xcrun simctl launch <UDID> com.ils.app`
3. Wait for app to settle (2-3 seconds)
4. Navigate to each screen, interact, and capture screenshots at each state:
   `xcrun simctl io <UDID> screenshot evidence/phase-08-platforms/<platform>/<item-id>.png`
5. Use `idb_describe operation:all` for accessibility tree coordinates before tapping
6. Use `idb_tap` with coordinates from accessibility tree — never guess pixels

### COLLECT
1. Stop log streaming: `kill <LOG_PID>`
2. Stop video recording with SIGINT (NOT kill -9): `kill -INT <VIDEO_PID>` then wait 2s
3. Check for crash reports: `xcrun simctl spawn <UDID> log show --predicate 'eventMessage contains "crash"' --last 5m`
4. Collect console warnings: `grep -i "warning\|error\|fault" evidence/phase-08-platforms/<platform>/app.log`

### VERIFY
1. Read every screenshot captured (use Read tool on each .png)
2. Grep logs for errors: any `[error]` or `[fault]` entries are FAIL unless explicitly expected
3. Check for crashes: any crash report is automatic FAIL
4. Write PASS/FAIL verdict for each checklist item with evidence reference
5. Produce `validation-log.md` with: item ID, PASS/FAIL, evidence filename, notes

For **macOS validation**, the protocol adapts:
- No simulator — build and launch the real macOS app
- Build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet`
- Launch: `open ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app`
- Screenshots: `screencapture -x evidence/phase-08-platforms/mac/<item-id>.png`
- Video: `screencapture -v evidence/phase-08-platforms/mac/recording.mov` (stop with Ctrl+C / SIGINT)
- Logs: `log stream --predicate 'subsystem == "com.ils.mac"' > evidence/phase-08-platforms/mac/app.log 2>&1 &`

## Prerequisites

| Prerequisite | Source |
|-------------|--------|
| Phase 7 (Convergence) complete | VG-25 (all sub-gates a-g) PASS |
| All 3 targets build with 0 errors | VG-25a confirmed in Phase 7 |
| Backend running on port 9999 from `ils-ios/` directory | Verified in Phase 7, Task 7.1 |
| All CRITICAL and HIGH regressions fixed | VG-25g confirmed in Phase 7 |
| Dedicated iPhone 16 Pro Max simulator booted | UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14` |
| Evidence directory exists | `mkdir -p evidence/phase-08-platforms/{iphone-16-pro,iphone-16-pro-max,ipad-pro-13,mac}` |

## Team Composition

| Teammate | Agent Type | Model | Responsibilities |
|----------|-----------|-------|------------------|
| iphone-validator | oh-my-claudecode:verifier | opus | iPhone 16 Pro (compact width) — all screens, compact layout verification, overlay sidebar behavior, edge swipe gestures |
| iphone-max-validator | oh-my-claudecode:verifier | opus | iPhone 16 Pro Max (large phone) — all screens on dedicated simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`, same checks as iPhone 16 Pro but on larger display |
| ipad-validator | oh-my-claudecode:verifier | opus | iPad Pro 13" (regular width) — persistent NavigationSplitView sidebar, split view proportions, pointer/trackpad interaction, multitasking readiness |
| mac-validator | oh-my-claudecode:verifier | opus | Mac (native macOS app) — 3-column NavigationSplitView, keyboard shortcuts, menu bar commands, multi-window, Touch Bar, Spotlight indexing, window resize behavior |
| platform-merge-auditor | oh-my-claudecode:quality-reviewer | opus | Merge all 4 platform reports, identify platform-specific regressions vs universal issues, produce final consolidated validation report |

## Task Breakdown

---

### Task 8.1: iPhone 16 Pro Validation (Compact Width)

- **Owner**: iphone-validator
- **Description**: Full visual audit on iPhone 16 Pro simulator (compact width, ~393pt wide) using the ios-validation-runner protocol. Every screen must render correctly within compact constraints. Sidebar must be an overlay sheet triggered by hamburger button. No content clipping, no horizontal scroll where not intended. NO mocks or test files — real app, real backend, real data.

- **ios-validation-runner Protocol Execution**:

  **SETUP**:
  ```bash
  # Create iPhone 16 Pro simulator if not exists
  xcrun simctl list devices | grep "iPhone 16 Pro,"
  # If missing: xcrun simctl create "ILS-iPhone16Pro" "iPhone 16 Pro" iOS18.6
  xcrun simctl boot <UDID>
  xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4
  # Verify backend health
  curl -sf http://localhost:9999/health  # Must return 200
  lsof -i :9999 -P -n  # Path must contain ils-ios/
  # Build fresh
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination "id=<UDID>" -quiet
  # Clean install
  xcrun simctl uninstall <UDID> com.ils.app
  ```

  **RECORD**:
  ```bash
  mkdir -p evidence/phase-08-platforms/iphone-16-pro
  xcrun simctl io <UDID> recordVideo --codec h264 evidence/phase-08-platforms/iphone-16-pro/recording.mp4 &
  VIDEO_PID=$!
  xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "com.ils.app"' > evidence/phase-08-platforms/iphone-16-pro/app.log 2>&1 &
  LOG_PID=$!
  ```

  **ACT**:
  ```bash
  xcrun simctl install <UDID> ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app
  xcrun simctl launch <UDID> com.ils.app
  sleep 3  # Wait for app to settle
  # Navigate and screenshot each state per checklist below
  # Use idb_describe operation:all for accessibility coordinates before every tap
  ```

  **COLLECT**:
  ```bash
  kill $LOG_PID
  kill -INT $VIDEO_PID  # SIGINT, NOT kill -9
  sleep 2
  xcrun simctl spawn <UDID> log show --predicate 'eventMessage contains "crash"' --last 30m
  grep -i "warning\|error\|fault" evidence/phase-08-platforms/iphone-16-pro/app.log > evidence/phase-08-platforms/iphone-16-pro/errors.log
  ```

  **VERIFY**:
  ```bash
  # Read every screenshot with Read tool
  # Grep logs for [error] or [fault] — any hit is FAIL unless expected
  # Any crash report = automatic FAIL
  # Write evidence/phase-08-platforms/iphone-16-pro/validation-log.md
  ```

- **Validation Checklist** (capture screenshot for each, define PASS criteria BEFORE capture):

  **Navigation & Chrome**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.01 | Launch screen renders | ILS logo visible, no blank frame, no crash |
  | 8.1.02 | Home screen loads | Stats cards visible with numeric values > 0, quick actions row present |
  | 8.1.03 | Hamburger button visible | Button in top-left toolbar area, tappable (accessibility tree confirms button element) |
  | 8.1.04 | Sidebar opens as overlay | Sidebar visible (~280pt wide), background dimmed, content behind sidebar partially visible |
  | 8.1.05 | Sidebar items present | All 7 items visible: Home, System Monitor, Browse, Agent Teams, Fleet, Themes, Settings |
  | 8.1.06 | Sidebar session list | At least 1 project group visible with expand/collapse chevron, session rows underneath |
  | 8.1.07 | Sidebar closes on outside tap | After tap outside sidebar: sidebar dismissed, main content fully visible |
  | 8.1.08 | Edge swipe opens sidebar | Swipe from x < 30pt opens sidebar (same state as 8.1.04) |
  | 8.1.09 | Offline indicator | When backend stopped: red/orange banner appears in safe area with "Offline" or "Disconnected" text |

  **Home Screen**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.10 | Welcome section | Greeting text visible (e.g., "Welcome" or time-based greeting) |
  | 8.1.11 | Connection banner | Green dot visible + URL text (e.g., "localhost:9999") |
  | 8.1.12 | Quick actions grid | At least 2 action buttons visible above recent sessions area |
  | 8.1.13 | Recent sessions | At least 1 session row with title text and timestamp |
  | 8.1.14 | Stats section | 4 stat values visible: sessions count (number > 0), skills, MCP, plugins |
  | 8.1.15 | Pull-to-refresh | Pull gesture triggers refresh indicator; stats update (timestamp or values change) |
  | 8.1.16 | TipKit tip | "Create Session" tip renders as a callout with dismiss button (or already dismissed) |

  **Chat Flow**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.17 | Session tap navigates | Tapping a session row pushes ChatView; back button appears in nav bar |
  | 8.1.18 | Message history | At least 1 user message card + 1 assistant message card visible in scroll view |
  | 8.1.19 | Code blocks | Code block visible with monospaced font, background color distinct from message bg |
  | 8.1.20 | Markdown rendering | Bold/italic/headers render with correct font weight/size (not raw `**text**`) |
  | 8.1.21 | Chat input bar | Text field at bottom of screen with send button; keyboard avoidance works |
  | 8.1.22 | Streaming indicator | When message is streaming: animated indicator visible with "Claude is responding" or similar text |
  | 8.1.23 | Command palette | Sheet opens with searchable command list; at least 3 commands visible |
  | 8.1.24 | Session info | Sheet opens showing session ID, project name, message count, timestamps |
  | 8.1.25 | Advanced options | Sheet opens with model picker and/or configuration toggles |
  | 8.1.26 | Error message view | When connection drops during chat: error view renders with retry option |

  **Browser**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.27 | Segmented control | 3 segments visible: MCP, Skills, Plugins — tappable, selected segment highlighted |
  | 8.1.28 | Search bar | Search field visible; typing filters list (fewer rows after typing 3+ chars) |
  | 8.1.29 | MCP servers list | At least 1 MCP server row with name + status indicator (green/red/yellow dot) |
  | 8.1.30 | MCP server detail | Push navigation to detail view with server name, tools list, status |
  | 8.1.31 | Skills list | At least 5 skill cards with name and description text |
  | 8.1.32 | Skill detail | Push navigation to detail with skill name, description, parameters section |
  | 8.1.33 | Plugins list | At least 1 plugin row with install/enable status badge |
  | 8.1.34 | Plugin config | Push navigation to config view with toggles or settings fields |

  **System Monitor**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.35 | CPU chart | Chart framework renders with at least 1 data point; Y-axis label shows percentage |
  | 8.1.36 | Load average badges | 3 badges visible labeled 1m, 5m, 15m with numeric values |
  | 8.1.37 | Memory + Disk rings | 2 circular progress indicators with percentage labels (values between 0-100%) |
  | 8.1.38 | Network stats | Upload/download values visible with unit labels (KB/s, MB/s, etc.) |
  | 8.1.39 | Process count | Numeric label showing total process count (number > 0) |
  | 8.1.40 | Process list detail | Push navigation shows scrollable list of process names with CPU/memory values |

  **Settings**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.41 | Form renders | SwiftUI Form with at least 3 visible section headers |
  | 8.1.42 | Connection section | Host field, port field (showing 9999), status indicator (green = connected) |
  | 8.1.43 | Appearance section | Color scheme picker (system/light/dark), theme name shown |
  | 8.1.44 | Config section | At least 1 config row with "Inherited from host" badge visible |
  | 8.1.45 | About section | App version string and build number visible |
  | 8.1.46 | Config editor | Push navigation to editor with key-value pairs |
  | 8.1.47 | Log viewer | Push navigation showing log entries with timestamps |
  | 8.1.48 | Tunnel settings | Push navigation with tunnel URL field and status |
  | 8.1.49 | Notification prefs | Push navigation with toggle switches for notification categories |

  **Remaining Screens**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.1.50 | Agent Teams list | Team cards with names OR empty state with "No teams" message and create button |
  | 8.1.51 | Team detail view | If teams exist: team name, member list, status. If not: skip (N/A) |
  | 8.1.52 | Create Team sheet | Sheet with team name field, agent type picker, create button |
  | 8.1.53 | Fleet management | Host list with at least "Local Backend" entry showing Active status, OR empty state |
  | 8.1.54 | Fleet host detail | Push navigation showing host URL (localhost:9999), connection status, metrics |
  | 8.1.55 | Themes list | At least 3 theme entries (built-in themes) with preview swatches |
  | 8.1.56 | Theme editor | Form with color picker fields (at least 5 color tokens editable) |
  | 8.1.57 | Theme preview | Preview card showing theme colors applied to sample UI elements |
  | 8.1.58 | Theme marketplace | List or grid of available themes with install/preview actions |
  | 8.1.59 | New Session sheet | 3 mode tabs/segments: Project, Fork, New Project — each with relevant form fields |
  | 8.1.60 | Server Setup sheet | Onboarding flow with server URL input, connect button, and status feedback |

- **Compact-Width Specific Checks** (PASS criteria for each):
  | Check | PASS Criteria |
  |-------|---------------|
  | No horizontal text clipping | All text labels fully visible (no `...` truncation on primary labels in any Form row) |
  | Cards fit within screen | All card views have >= 8pt margin from screen edges; no horizontal scroll indicators |
  | Navigation bar titles | `.inline` display mode on push destinations (title in center of bar, not large) |
  | Bottom safe area | No interactive content behind home indicator region |
  | Keyboard avoidance | When keyboard shown in ChatView: input bar rides above keyboard, last message still visible |
  | Dynamic Type default | All text renders without overflow at default system text size |

- **Files involved**: All 56 iOS view files from Screen Inventory (items 1-56)
- **Acceptance Criteria**:
  - 60 screenshots captured and saved to `evidence/phase-08-platforms/iphone-16-pro/`
  - `validation-log.md` with PASS/FAIL + evidence filename for each of 60 items
  - `app.log` and `errors.log` collected
  - `recording.mp4` video of full validation session
  - 0 layout clipping issues
  - 0 crashes during navigation (verified via crash report check)
  - All data-driven screens show real data (not empty/loading indefinitely)
  - Sidebar overlay behavior correct (not persistent)

---

### Task 8.2: iPhone 16 Pro Max Validation (Large Phone)

- **Owner**: iphone-max-validator
- **Description**: Full visual audit on the **dedicated** iPhone 16 Pro Max simulator (UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`, ~430pt wide) using the ios-validation-runner protocol. Same checklist as Task 8.1 but on the larger display. Key differences to verify: wider cards may show more content, no layout breakage from extra width while still in compact size class. NO mocks or test files — real app, real backend, real data.

- **ios-validation-runner Protocol Execution**:

  **SETUP**:
  ```bash
  # Boot dedicated simulator (NEVER use any other)
  xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14
  xcrun simctl status_bar 50523130-57AA-48B0-ABD0-4D59CE455F14 override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4
  # Verify backend health
  curl -sf http://localhost:9999/health  # Must return 200
  lsof -i :9999 -P -n  # Path must contain ils-ios/
  # Build fresh
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet
  # Clean install
  xcrun simctl uninstall 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
  ```

  **RECORD**:
  ```bash
  mkdir -p evidence/phase-08-platforms/iphone-16-pro-max
  xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 recordVideo --codec h264 evidence/phase-08-platforms/iphone-16-pro-max/recording.mp4 &
  VIDEO_PID=$!
  xcrun simctl spawn 50523130-57AA-48B0-ABD0-4D59CE455F14 log stream --predicate 'subsystem == "com.ils.app"' > evidence/phase-08-platforms/iphone-16-pro-max/app.log 2>&1 &
  LOG_PID=$!
  ```

  **ACT**:
  ```bash
  xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app
  xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
  sleep 3
  # Navigate and screenshot each state per checklist below
  # Use idb_describe operation:all for accessibility coordinates before every tap
  ```

  **COLLECT**:
  ```bash
  kill $LOG_PID
  kill -INT $VIDEO_PID  # SIGINT, NOT kill -9
  sleep 2
  xcrun simctl spawn 50523130-57AA-48B0-ABD0-4D59CE455F14 log show --predicate 'eventMessage contains "crash"' --last 30m
  grep -i "warning\|error\|fault" evidence/phase-08-platforms/iphone-16-pro-max/app.log > evidence/phase-08-platforms/iphone-16-pro-max/errors.log
  ```

  **VERIFY**:
  ```bash
  # Read every screenshot with Read tool
  # Grep logs for [error] or [fault]
  # Any crash report = automatic FAIL
  # Write evidence/phase-08-platforms/iphone-16-pro-max/validation-log.md
  ```

- **Validation Checklist**: Same 60-item checklist as Task 8.1 (items 8.1.01 through 8.1.60), re-numbered as 8.2.01 through 8.2.60, with identical PASS criteria.

- **Large Phone Specific Checks** (PASS criteria for each):
  | Check | PASS Criteria |
  |-------|---------------|
  | Cards use full width | Card views span to within 16pt of screen edges (no excessive centering gap > 40pt) |
  | No excessive line breaks | Body text paragraphs have same or fewer line breaks compared to iPhone 16 Pro at same font size |
  | Charts fill width | System Monitor charts span at least 90% of available content width |
  | Sidebar proportional | Sidebar overlay at ~280pt on 430pt screen (sidebar does not exceed 70% of screen width) |
  | Stats grid spacing | Home stats grid items have uniform spacing with no single item overflowing |
  | Size class is compact | `horizontalSizeClass == .compact` confirmed (iPhone Pro Max in portrait is still compact) |
  | Landscape rotation | If rotation supported: layout adapts without crash or clipping. If locked: rotation is locked without crash |

- **Files involved**: Same as Task 8.1
- **Acceptance Criteria**:
  - 60 screenshots captured and saved to `evidence/phase-08-platforms/iphone-16-pro-max/`
  - `validation-log.md` with PASS/FAIL + evidence filename for each of 60 items
  - `app.log`, `errors.log`, `recording.mp4` collected
  - 0 layout issues specific to larger phone width
  - 0 crashes (verified via crash report check)
  - All screens render identically to iPhone 16 Pro except for proportional width differences
  - Sidebar overlay behavior matches iPhone 16 Pro (overlay, not persistent)

---

### Task 8.3: iPad Pro 13" Validation (Regular Width)

- **Owner**: ipad-validator
- **Description**: Full visual audit on iPad Pro 13" simulator (regular width, ~1024pt in landscape / ~768pt in portrait) using the ios-validation-runner protocol. The key architectural difference: `horizontalSizeClass == .regular` triggers `NavigationSplitView` with persistent sidebar instead of overlay. Verify 2-column layout, sidebar/detail proportions, and split view behavior. NO mocks or test files — real app, real backend, real data.

- **ios-validation-runner Protocol Execution**:

  **SETUP**:
  ```bash
  # Create iPad Pro 13" simulator if not exists
  xcrun simctl list devices | grep "iPad Pro (13-inch)"
  # If missing: xcrun simctl create "ILS-iPadPro13" "iPad Pro 13-inch (M4)" iOS18.6
  IPAD_UDID=$(xcrun simctl list devices | grep "ILS-iPadPro13" | grep -oE '[A-F0-9-]{36}')
  xcrun simctl boot $IPAD_UDID
  xcrun simctl status_bar $IPAD_UDID override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3
  # Verify backend health
  curl -sf http://localhost:9999/health  # Must return 200
  lsof -i :9999 -P -n  # Path must contain ils-ios/
  # Build fresh (same ILSApp scheme, different destination)
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination "id=$IPAD_UDID" -quiet
  # Clean install
  xcrun simctl uninstall $IPAD_UDID com.ils.app
  ```

  **RECORD**:
  ```bash
  mkdir -p evidence/phase-08-platforms/ipad-pro-13
  xcrun simctl io $IPAD_UDID recordVideo --codec h264 evidence/phase-08-platforms/ipad-pro-13/recording.mp4 &
  VIDEO_PID=$!
  xcrun simctl spawn $IPAD_UDID log stream --predicate 'subsystem == "com.ils.app"' > evidence/phase-08-platforms/ipad-pro-13/app.log 2>&1 &
  LOG_PID=$!
  ```

  **ACT**:
  ```bash
  xcrun simctl install $IPAD_UDID ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app
  xcrun simctl launch $IPAD_UDID com.ils.app
  sleep 3
  # Navigate and screenshot each state per checklist below
  # Use idb_describe operation:all for accessibility coordinates before every tap
  ```

  **COLLECT**:
  ```bash
  kill $LOG_PID
  kill -INT $VIDEO_PID  # SIGINT, NOT kill -9
  sleep 2
  xcrun simctl spawn $IPAD_UDID log show --predicate 'eventMessage contains "crash"' --last 30m
  grep -i "warning\|error\|fault" evidence/phase-08-platforms/ipad-pro-13/app.log > evidence/phase-08-platforms/ipad-pro-13/errors.log
  ```

  **VERIFY**:
  ```bash
  # Read every screenshot with Read tool
  # Grep logs for [error] or [fault]
  # Any crash report = automatic FAIL
  # Write evidence/phase-08-platforms/ipad-pro-13/validation-log.md
  ```

- **Validation Checklist** (capture screenshot for each, define PASS criteria BEFORE capture):

  **iPad-Specific Layout**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.3.01 | NavigationSplitView persistent sidebar | Sidebar column visible without hamburger button; content and sidebar both visible simultaneously |
  | 8.3.02 | Sidebar column width | Sidebar column width between 260-380pt (measure via screenshot proportions against known device width) |
  | 8.3.03 | Detail column fills remaining | Detail column occupies remaining width after sidebar; no gap or dead space between columns |
  | 8.3.04 | Column visibility toggle | Tapping toggle collapses sidebar; detail expands to full width; toggle again restores sidebar |
  | 8.3.05 | No hamburger button | No hamburger/menu button in toolbar (iPad uses persistent sidebar, not overlay) |
  | 8.3.06 | Portrait: sidebar auto-hide | In portrait orientation: sidebar may auto-hide; swipe from left edge reveals it |
  | 8.3.07 | Landscape: sidebar persistent | In landscape: sidebar always visible alongside detail content |

  **All Screens (in persistent sidebar layout)**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.3.08 | Home in detail column | Dashboard content (stats, quick actions, sessions) renders in detail column with wide card layout; sidebar visible alongside |
  | 8.3.09 | Chat in detail column | Message bubbles render in detail column; bubble max-width does not exceed ~700pt; sidebar remains visible |
  | 8.3.10 | System Monitor charts | Charts scale to fill wider detail column (chart width > 500pt equivalent); data renders without truncation |
  | 8.3.11 | Settings form | Form renders in detail column; form width auto-constrains (SwiftUI Form behavior); not excessively stretched |
  | 8.3.12 | Browser with segments | Segmented control spans reasonable width; cards in LazyVStack use available detail width |
  | 8.3.13 | Agent Teams in detail | Team list or empty state renders entirely within detail column |
  | 8.3.14 | Fleet in detail | Host list renders in detail column; status indicators visible |
  | 8.3.15 | Themes in detail | Theme list with preview swatches renders in detail column |
  | 8.3.16 | Sidebar session list | Session list with project groups visible in sidebar column; groups expand/collapse with chevrons |
  | 8.3.17 | Session tap shows chat | Tapping session in sidebar opens chat in detail column (NOT full-screen push) |

  **iPad-Specific Interactions**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.3.18 | Pointer hover effects | If hover effects defined: visual feedback on interactive elements when pointer hovers. If not defined: N/A |
  | 8.3.19 | Context menu on session | Long press on session row shows context menu with at least: Open, Rename, Delete options |
  | 8.3.20 | Sheet sizing | NewSession and SessionInfo sheets present as centered form sheets (NOT full screen); sheet width < 80% of screen |
  | 8.3.21 | Keyboard shortcuts | Cmd+N triggers new session creation (keyboard must be attached to simulator) |
  | 8.3.22 | Split View multitasking | App renders without crash in 1/3, 1/2, and 2/3 multitasking widths; layout adapts at each width |
  | 8.3.23 | Slide Over | App renders in compact overlay (Slide Over panel) without crash; layout falls back to compact mode |

  **Push Navigation in Detail Column**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.3.24 | MCP Server Detail | Detail pushes within detail column; sidebar remains visible; back button returns to MCP list |
  | 8.3.25 | Skill Detail | Detail pushes within detail column; sidebar remains visible |
  | 8.3.26 | Fleet Host Detail | Detail pushes within detail column; sidebar remains visible |
  | 8.3.27 | Theme Editor | Editor pushes within detail column; color pickers render at iPad width |
  | 8.3.28 | Config Editor | Editor pushes within detail column; key-value pairs readable at wide width |
  | 8.3.29 | Log Viewer | Viewer pushes within detail column; log entries use full available width |

  **Full Screen Checklist** (same content checks as iPhone, adapted for wide layout):
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.3.30-8.3.60 | All remaining screen content | Same content PASS criteria as items 8.1.10 through 8.1.60, but verified to render correctly at regular width class within the detail column of NavigationSplitView |

- **Files with iPad-specific behavior**:
  - `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — `isRegularWidth` branch: `iPadLayout` vs `iPhoneLayout`
  - `ILSApp/ILSApp/Views/Root/SidebarView.swift` — shared sidebar content
  - `ILSApp/ILSApp/Views/Home/HomeView.swift` — stats grid may use wider columns
  - `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` — charts scale
  - `ILSApp/ILSApp/Views/Chat/ChatView.swift` — message bubbles max-width
  - `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift` — input bar width
- **Acceptance Criteria**:
  - 60 screenshots captured and saved to `evidence/phase-08-platforms/ipad-pro-13/`
  - `validation-log.md` with PASS/FAIL + evidence filename for each of 60 items
  - `app.log`, `errors.log`, `recording.mp4` collected
  - Persistent sidebar renders (NOT overlay) — confirmed in at least 5 screenshots showing simultaneous sidebar + detail
  - Sidebar column respects min/ideal/max width constraints (260-380pt)
  - Detail column content scales appropriately for regular width
  - No full-screen pushes that should be within-column navigation
  - Sheet presentations sized for iPad (not full screen unless intended)
  - Split View multitasking renders without crash in all 3 widths
  - 0 crashes, 0 blank screens (verified via crash report check)

---

### Task 8.4: macOS App Validation

- **Owner**: mac-validator
- **Description**: Full visual and functional audit of the native macOS app using the ios-validation-runner protocol (adapted for macOS). The macOS app uses a separate entry point (`ILSMacApp.swift`), a 3-column `NavigationSplitView` (`MacContentView.swift`), mac-specific views, menu bar commands, keyboard shortcuts, multi-window support, Spotlight indexing, and Touch Bar integration. NO mocks or test files — real app, real backend, real data.

- **ios-validation-runner Protocol Execution (macOS Adapted)**:

  **SETUP**:
  ```bash
  # Verify backend health
  curl -sf http://localhost:9999/health  # Must return 200
  lsof -i :9999 -P -n  # Path must contain ils-ios/
  # Build fresh macOS app
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet
  # Kill any existing instance
  pkill -f ILSMacApp || true
  ```

  **RECORD**:
  ```bash
  mkdir -p evidence/phase-08-platforms/mac
  # Start screen recording (macOS)
  screencapture -v evidence/phase-08-platforms/mac/recording.mov &
  VIDEO_PID=$!
  # Start log streaming
  log stream --predicate 'subsystem == "com.ils.mac"' > evidence/phase-08-platforms/mac/app.log 2>&1 &
  LOG_PID=$!
  ```

  **ACT**:
  ```bash
  # Launch macOS app from DerivedData
  open ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app
  sleep 3  # Wait for app to settle
  # Navigate and screenshot each state:
  screencapture -x evidence/phase-08-platforms/mac/<item-id>.png
  # For window-specific captures:
  screencapture -x -l <windowID> evidence/phase-08-platforms/mac/<item-id>.png
  ```

  **COLLECT**:
  ```bash
  kill $LOG_PID
  kill -INT $VIDEO_PID  # SIGINT, NOT kill -9
  sleep 2
  log show --predicate 'eventMessage contains "crash" AND subsystem == "com.ils.mac"' --last 30m
  grep -i "warning\|error\|fault" evidence/phase-08-platforms/mac/app.log > evidence/phase-08-platforms/mac/errors.log
  ```

  **VERIFY**:
  ```bash
  # Read every screenshot with Read tool
  # Grep logs for [error] or [fault]
  # Any crash report = automatic FAIL
  # Write evidence/phase-08-platforms/mac/validation-log.md
  ```

- **Validation Checklist** (capture screenshot for each, define PASS criteria BEFORE capture):

  **Window & Layout**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.01 | 3-column NavigationSplitView | Window shows 3 distinct columns: sidebar, sessions list, detail content |
  | 8.4.02 | Default window size | Window approximately 1200x800 points (within 10% tolerance) |
  | 8.4.03 | Sidebar column | Left column (150-400pt) shows ILS header text + navigation section list |
  | 8.4.04 | Middle column | Center column (250-500pt) shows "SESSIONS" header + session rows |
  | 8.4.05 | Detail column | Right column (min ~600pt) shows selected screen content (dashboard on first launch) |
  | 8.4.06 | Column visibility toggle | Sidebar collapse/expand via toolbar button or keyboard; columns redistribute |
  | 8.4.07 | Window resize | Dragging window edge redistributes columns proportionally; no column disappears until minimum |
  | 8.4.08 | Minimum window size | Window cannot be resized below minimum (no layout breakage at smallest allowed size) |

  **Sidebar Navigation**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.09 | Sidebar sections | All 7 sections visible: Home, System Monitor, Browse, Agent Teams (if enabled), Fleet, Themes, Settings |
  | 8.4.10 | Connection status | Green or red dot visible in sidebar + server URL text (e.g., "localhost:9999") |
  | 8.4.11 | Section selection | Clicking section highlights it (accent color background) and updates detail column content |
  | 8.4.12 | Agent Teams visibility | Agent Teams section appears/disappears based on `enableAgentTeams` AppStorage toggle |

  **Sessions List (Middle Column)**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.13 | Sessions header | "SESSIONS" text visible with total count number (e.g., "SESSIONS (41)") |
  | 8.4.14 | Search bar | Search field with magnifying glass icon visible at top of sessions column |
  | 8.4.15 | Search filters | Typing in search field reduces visible session count; clearing restores full list |
  | 8.4.16 | Project groups | At least 1 project group with disclosure triangle; clicking triangle expands/collapses sessions |
  | 8.4.17 | Session rows | Each row shows: session name/title, first prompt preview text (truncated), message count badge |
  | 8.4.18 | Session click | Clicking session row loads chat in detail column; clicked row shows selected state |
  | 8.4.19 | Load more button | For projects with many sessions: "Load more..." button visible at bottom of expanded group |
  | 8.4.20 | New Session button | "New Session" button visible at bottom of sessions list column |
  | 8.4.21 | `/` shortcut | Pressing `/` key focuses search field (cursor appears in search bar) |

  **Detail Content (All Screens)**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.22 | MacDashboardView | Welcome text, connection banner (green dot + URL), stats grid (4 values > 0), recent sessions list, quick action buttons |
  | 8.4.23 | MacChatView | Message list with user + assistant cards, input bar at bottom, toolbar actions (info, export, etc.) |
  | 8.4.24 | SystemMonitorView | CPU chart with data points, memory ring with percentage, disk ring, network stats with units |
  | 8.4.25 | BrowserView | MCP/Skills/Plugins segmented control, search field, content list with at least 3 items |
  | 8.4.26 | AgentTeamsListView | Team cards with names/status OR empty state with "No teams" + create button |
  | 8.4.27 | FleetManagementView | At least "Local Backend" host entry with Active status badge |
  | 8.4.28 | ThemesListView | At least 3 theme entries with name + preview color swatches |
  | 8.4.29 | SettingsView | Tabbed settings form with at least 3 sections visible |

  **Menu Bar Commands** (`ILSCommands.swift`):
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.30 | File > New Session (Cmd+N) | Pressing Cmd+N opens new session flow (new session view or chat view with empty state) |
  | 8.4.31 | Navigate > Home (Cmd+1) | Pressing Cmd+1 switches detail to dashboard; sidebar highlights Home |
  | 8.4.32 | Navigate > Sessions (Cmd+2) | Pressing Cmd+2 switches to sessions/home view |
  | 8.4.33 | Navigate > Browse (Cmd+3) | Pressing Cmd+3 switches detail to browser; sidebar highlights Browse |
  | 8.4.34 | Navigate > System Monitor (Cmd+4) | Pressing Cmd+4 switches detail to system monitor; sidebar highlights System Monitor |
  | 8.4.35 | Navigate > Settings (Cmd+,) | Pressing Cmd+, switches detail to settings; sidebar highlights Settings |
  | 8.4.36 | Session > Rename (Cmd+Shift+R) | With session selected: rename alert/sheet appears with text field and current name |
  | 8.4.37 | Session > Fork (Cmd+Shift+F) | With session selected: fork action triggers (new session created or confirmation dialog) |
  | 8.4.38 | Session > Export (Cmd+Shift+E) | With session selected: NSSavePanel appears with file type options |
  | 8.4.39 | Session > Toggle Tool Calls (Cmd+Option+E) | Tool call blocks in chat expand or collapse |
  | 8.4.40 | Session > Delete (Cmd+Delete) | With session selected: confirmation dialog appears before deletion |

  **Context Menus**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.41 | Right-click session row | Context menu appears with at least: Open, Open in New Window, Rename, Fork, Export JSON, Export Markdown, Delete |
  | 8.4.42 | Open in New Window | Clicking "Open in New Window" opens a new macOS window with the session's chat view |
  | 8.4.43 | Export JSON | Clicking "Export JSON" opens NSSavePanel with `.json` default file extension |
  | 8.4.44 | Export Markdown | Clicking "Export Markdown" opens NSSavePanel with `.md` default file extension |

  **Multi-Window Support**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.45 | Session window opens | `WindowGroup("Session", for: UUID.self)` creates a separate window with session content |
  | 8.4.46 | Session loads by UUID | New session window shows the correct session's messages (matching session name/content) |
  | 8.4.47 | Invalid session error | Opening window with non-existent UUID shows error state (not crash, not blank) |
  | 8.4.48 | Multiple windows | At least 2 session windows open simultaneously; each shows different session content |

  **macOS-Specific Features**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.49 | Spotlight indexing | After sessions load: `mdls -name kMDItemTitle` on indexed items shows session titles (or verify SpotlightIndexer code runs without error in logs) |
  | 8.4.50 | Touch Bar | If MacBook Pro with Touch Bar: chat controls visible. Otherwise: verify `ChatTouchBarProvider` compiles without error (N/A for hardware not present) |
  | 8.4.51 | Notification permission | On first launch or settings change: notification permission dialog appears (or already granted in logs) |
  | 8.4.52 | Color scheme | Switching system appearance (light/dark) via System Settings: app UI updates immediately without restart |
  | 8.4.53 | Dynamic Type | Increasing text size via System Settings > Accessibility: text scales up; no truncation at `.accessibility1` |
  | 8.4.54 | Server Setup sheet | Server setup/onboarding sheet renders correctly: URL field, connect button, status indicator |
  | 8.4.55 | Refresh (Cmd+R) | Pressing Cmd+R on dashboard: stats values refresh (loading indicator appears briefly, then updated values) |

  **MacSettingsView (Tabbed)**:
  | Item | Check | PASS Criteria |
  |------|-------|---------------|
  | 8.4.56 | Settings sidebar tabs | Left sidebar shows 5 tabs: General, Appearance, Connection, Advanced, About |
  | 8.4.57 | Tab switching | Clicking each tab renders corresponding content in settings detail area |
  | 8.4.58 | General tab | Model picker dropdown, agent teams toggle, debug mode toggle — all interactive |
  | 8.4.59 | Appearance tab | Color scheme picker (system/light/dark), theme selection list with current theme highlighted |
  | 8.4.60 | Connection tab | Server URL text field showing current URL, connection status indicator (green/red) |
  | 8.4.61 | Advanced tab | Cache management controls (clear cache button), log viewer access link/button |
  | 8.4.62 | About tab | App name "ILS", version string (e.g., "1.0"), build number visible |

- **Files involved**:
  - `ILSApp/ILSMacApp/ILSMacApp.swift` — app entry point, window groups, scene config
  - `ILSApp/ILSMacApp/Views/MacContentView.swift` — 3-column layout, session list, context menus
  - `ILSApp/ILSMacApp/Views/MacDashboardView.swift` — macOS dashboard
  - `ILSApp/ILSMacApp/Views/MacChatView.swift` — macOS chat view
  - `ILSApp/ILSMacApp/Views/MacSettingsView.swift` — tabbed settings
  - `ILSApp/ILSMacApp/Views/MacSessionsListView.swift` — sessions list component
  - `ILSApp/ILSMacApp/Views/SessionWindowView.swift` — multi-window session
  - `ILSApp/ILSMacApp/Commands/ILSCommands.swift` — menu bar + keyboard shortcuts
  - `ILSApp/ILSMacApp/AppDelegate.swift` — app lifecycle
  - `ILSApp/ILSMacApp/Managers/WindowManager.swift` — window management
  - `ILSApp/ILSMacApp/Managers/NotificationManager.swift` — notification permissions
  - `ILSApp/ILSMacApp/Services/SpotlightIndexer.swift` — Spotlight integration
  - `ILSApp/ILSMacApp/TouchBar/ChatTouchBarProvider.swift` — Touch Bar
- **Acceptance Criteria**:
  - 62 screenshots/evidence items captured and saved to `evidence/phase-08-platforms/mac/`
  - `validation-log.md` with PASS/FAIL + evidence filename for each of 62 items
  - `keyboard-shortcuts-log.md` documenting each shortcut tested with result
  - `app.log`, `errors.log`, `recording.mov` collected
  - 3-column layout renders with correct proportions (visible in screenshots)
  - All 11 menu bar keyboard shortcuts trigger correct actions (documented in shortcuts log)
  - Context menus fully functional (7 menu items verified)
  - Multi-window session support works (at least 2 windows open simultaneously)
  - No AppKit layout warnings in console (grep `errors.log` for "NSLayoutConstraint")
  - 0 crashes, 0 blank screens (verified via crash report check)

---

### Task 8.5: Cross-Platform Merge & Consolidated Report

- **Owner**: platform-merge-auditor
- **Description**: After all 4 platform validators complete, merge their findings into a consolidated report using the **functional-validation mandate** — every claim must have evidence backing. Categorize issues as platform-specific vs universal. Identify any screen that FAILS on one platform but PASSES on another. Produce the final VG-27 evidence package.

- **Validation Protocol**: This task does not use the SETUP/RECORD/ACT/COLLECT/VERIFY protocol directly (no simulator interaction), but it MUST:
  - **Read every screenshot** referenced by each platform's `validation-log.md` to verify PASS/FAIL claims
  - **Grep every `errors.log`** to cross-check error claims
  - **Never trust a sub-agent's PASS claim without reading the evidence yourself**
  - **Produce evidence-backed verdicts only** — if a screenshot is missing or ambiguous, mark as FAIL/INCONCLUSIVE

- **Steps**:
  1. Collect all evidence from:
     - `evidence/phase-08-platforms/iphone-16-pro/` (Task 8.1)
     - `evidence/phase-08-platforms/iphone-16-pro-max/` (Task 8.2)
     - `evidence/phase-08-platforms/ipad-pro-13/` (Task 8.3)
     - `evidence/phase-08-platforms/mac/` (Task 8.4)
  2. **Read every `validation-log.md`** and cross-reference against actual screenshots
  3. Build comparison matrix: every screen vs every platform (PASS/FAIL/N-A)
  4. Categorize failures:
     - **Universal** — fails on all platforms (likely code bug)
     - **Compact-only** — fails only on iPhone (layout constraint issue)
     - **Regular-only** — fails only on iPad (split view issue)
     - **Mac-only** — fails only on macOS (AppKit/catalyst bridge issue)
     - **Large-phone-only** — fails only on Pro Max (width edge case)
  5. Prioritize: CRITICAL (crash/blank screen) > HIGH (wrong data/broken nav) > MEDIUM (cosmetic)
  6. Produce consolidated report with:
     - Overall PASS/FAIL per platform with evidence summary
     - Screen-by-screen comparison matrix
     - Issue list with platform, severity, description, recommended fix, and evidence filename
     - Evidence index linking each finding to its screenshot
  7. If all platforms PASS with 0 CRITICAL and 0 HIGH issues: mark VG-27 as PASS
  8. If any platform has CRITICAL/HIGH issues: document specific blockers for Phase 9 fix pass

- **PASS Criteria for Consolidated Report**:
  | Check | PASS Criteria |
  |-------|---------------|
  | Evidence completeness | All 4 platform directories contain their full screenshot sets (60+60+60+62 = 242 items) |
  | Matrix coverage | Comparison matrix covers all 68 screens (56 iOS + 12 macOS-only) |
  | Failure documentation | Every FAIL cell in matrix has: screenshot filename, description of failure, severity rating |
  | Issue categorization | Every issue tagged with exactly one platform scope AND one severity level |
  | Cross-validation | At least 10% of PASS claims spot-checked by reading the actual screenshot |
  | No unsupported claims | Zero PASS verdicts without a corresponding evidence file |

- **Files to create**:
  - `evidence/phase-08-platforms/consolidated-report.md` — full report with evidence references
  - `evidence/phase-08-platforms/comparison-matrix.md` — screen x platform grid (PASS/FAIL/N-A)
  - `evidence/phase-08-platforms/issues.md` — prioritized issue list with evidence filenames
- **Acceptance Criteria**:
  - All 4 platform evidence directories contain complete screenshot sets
  - Comparison matrix covers all 68 screens (56 iOS + 12 macOS-only)
  - Every FAIL has a corresponding screenshot and description
  - Issues categorized by platform scope and severity
  - Final PASS/FAIL determination for each VG-26 sub-gate
  - VG-27 status determined (PASS only if all VG-26 sub-gates PASS with 0 CRITICAL issues)

---

### Task 8.6: Platform-Specific Fix Pass

- **Owner**: iphone-validator (iOS fixes), mac-validator (macOS fixes)
- **Description**: Fix any CRITICAL or HIGH issues discovered during platform validation. Each fix MUST be followed by the ios-validation-runner protocol on the affected platform to re-validate. NO mocks or test files — fix the real code, rebuild, re-run, re-screenshot.

- **ios-validation-runner Protocol for Fixes**:

  For each fix, execute the full protocol on the affected platform:

  **SETUP**: Verify backend still healthy, rebuild affected target
  ```bash
  curl -sf http://localhost:9999/health
  # iOS fix:
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=<AFFECTED_UDID>' -quiet
  # macOS fix:
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet
  ```

  **RECORD**: Start recording + logging for the re-validation session
  ```bash
  # iOS:
  xcrun simctl io <UDID> recordVideo --codec h264 evidence/phase-08-platforms/<platform>/fix-recording-<issue-id>.mp4 &
  # macOS:
  screencapture -v evidence/phase-08-platforms/mac/fix-recording-<issue-id>.mov &
  ```

  **ACT**: Clean install, launch, navigate to the affected screen, capture new screenshot
  ```bash
  # iOS:
  xcrun simctl uninstall <UDID> com.ils.app
  xcrun simctl install <UDID> ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app
  xcrun simctl launch <UDID> com.ils.app
  # Navigate to affected screen, capture:
  xcrun simctl io <UDID> screenshot evidence/phase-08-platforms/<platform>/fix-<item-id>.png
  # macOS:
  pkill -f ILSMacApp || true
  open ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app
  screencapture -x evidence/phase-08-platforms/mac/fix-<item-id>.png
  ```

  **COLLECT**: Stop recording, check for new crashes
  ```bash
  kill -INT $VIDEO_PID
  # Check crash reports for the fix session
  ```

  **VERIFY**: Read new screenshot, confirm the fix resolves the issue
  ```bash
  # Read the new screenshot — must show the issue resolved
  # Update validation-log.md: change FAIL -> PASS with new evidence filename
  ```

- **Steps**:
  1. Triage issues from Task 8.5 consolidated report — process CRITICAL first, then HIGH
  2. iOS fixes: iphone-validator fixes compact/regular width issues
  3. macOS fixes: mac-validator fixes macOS-specific issues
  4. After each fix: full ios-validation-runner protocol on affected platform
  5. After all fixes: update `validation-log.md` in each affected platform directory
  6. Update consolidated report with fix status

- **PASS Criteria for Fix Pass**:
  | Check | PASS Criteria |
  |-------|---------------|
  | All CRITICAL resolved | Zero CRITICAL issues remaining across all platforms (each has fix screenshot showing resolution) |
  | All HIGH resolved or documented | Zero HIGH issues remaining, OR each remaining HIGH has documented workaround with justification |
  | Evidence updated | New fix screenshots replace FAIL screenshots in evidence directories |
  | Consolidated report updated | `consolidated-report.md` updated with final status per platform |
  | No regressions | Fix screenshots show no new issues introduced (spot-check 3 adjacent screens per fix) |

- **Acceptance Criteria**:
  - All CRITICAL issues resolved across all platforms
  - All HIGH issues resolved or documented with workaround
  - Updated screenshots (`fix-<item-id>.png`) in evidence directories
  - Consolidated report updated with final status
  - No regressions introduced (verified by re-capturing adjacent screens)

---

## Parallel Execution Plan

```
Phase Start
    |
    +-- [PRE-FLIGHT]
    |       |
    |       +-- Verify backend health (port 9999, correct binary)
    |       +-- Build all 3 targets (ILSApp, ILSApp-iPad, ILSMacApp)
    |       +-- mkdir -p evidence/phase-08-platforms/{iphone-16-pro,iphone-16-pro-max,ipad-pro-13,mac}
    |       +-- Boot all simulators, override status bars
    |
    +-- [PARALLEL — 4 independent platform validators, each running full SETUP->RECORD->ACT->COLLECT->VERIFY]
    |       |
    |       +-- Task 8.1 (iphone-validator: iPhone 16 Pro — ios-validation-runner protocol)
    |       +-- Task 8.2 (iphone-max-validator: iPhone 16 Pro Max — ios-validation-runner protocol)
    |       +-- Task 8.3 (ipad-validator: iPad Pro 13" — ios-validation-runner protocol)
    |       +-- Task 8.4 (mac-validator: macOS — adapted ios-validation-runner protocol)
    |       |
    |       <-- all 4 validators complete with evidence packages -->
    |
    +-- [SEQUENTIAL] Task 8.5 (platform-merge-auditor: consolidated report with evidence cross-check)
    |       |
    |       v
    +-- [PARALLEL — if fixes needed, each fix follows ios-validation-runner protocol]
    |       |
    |       +-- Task 8.6a (iphone-validator: iOS fixes + re-validation)
    |       +-- Task 8.6b (mac-validator: macOS fixes + re-validation)
    |       |
    |       <-- all fixes complete with updated evidence -->
    |       |
    +-- [SEQUENTIAL] Task 8.5 re-run (update consolidated report with fix evidence)
    |
    v
Phase Complete (VG-26A/B/C/D + VG-27)
```

- Tasks 8.1, 8.2, 8.3, 8.4 run fully in parallel (each on independent simulator/platform)
- Each task independently runs the full ios-validation-runner protocol (SETUP through VERIFY)
- Task 8.5 runs after all 4 validators complete (needs all evidence to cross-check)
- Task 8.6 runs in parallel (iOS fixes and macOS fixes are independent)
- Task 8.6 fixes each follow the ios-validation-runner protocol for re-validation
- Task 8.5 re-runs after fixes to update the consolidated report with new evidence

## Validation Gates

| Gate | Criteria | PASS Definition | Evidence Required |
|------|----------|----------------|-------------------|
| VG-26A | iPhone 16 Pro | All 60 checklist items PASS per defined criteria; 0 crashes in logs; 0 `[error]` entries in app.log | `evidence/phase-08-platforms/iphone-16-pro/*.png` (60 screenshots) + `validation-log.md` + `app.log` + `recording.mp4` |
| VG-26B | iPhone 16 Pro Max | All 60 checklist items PASS per defined criteria; 0 crashes; identical behavior to VG-26A except proportional width | `evidence/phase-08-platforms/iphone-16-pro-max/*.png` (60 screenshots) + `validation-log.md` + `app.log` + `recording.mp4` |
| VG-26C | iPad Pro 13" | All 60 checklist items PASS; persistent sidebar confirmed in 5+ screenshots; split view works at 3 widths; 0 crashes | `evidence/phase-08-platforms/ipad-pro-13/*.png` (60 screenshots) + `validation-log.md` + `app.log` + `recording.mp4` |
| VG-26D | Mac | All 62 checklist items PASS; 11 keyboard shortcuts verified; context menus work; multi-window works; 0 crashes; 0 AppKit warnings | `evidence/phase-08-platforms/mac/*.png` (62 screenshots) + `keyboard-shortcuts-log.md` + `validation-log.md` + `app.log` + `recording.mov` |
| VG-27 | All Platforms | All 4 sub-gates PASS; consolidated report complete; comparison matrix covers 68 screens; 0 CRITICAL issues; 0 HIGH issues (or all fixed in Task 8.6) | `evidence/phase-08-platforms/consolidated-report.md` + `comparison-matrix.md` + `issues.md` |

## Evidence Requirements

All evidence stored in `evidence/phase-08-platforms/`:

```
evidence/phase-08-platforms/
  iphone-16-pro/
    8.1.01-launch-screen.png
    8.1.02-home-screen.png
    ...
    8.1.60-server-setup.png
    recording.mp4              # Full session video (SETUP->ACT)
    app.log                    # Full app log stream
    errors.log                 # Filtered errors/warnings
    validation-log.md          # PASS/FAIL per item + evidence filename
  iphone-16-pro-max/
    8.2.01-launch-screen.png
    ...
    8.2.60-server-setup.png
    recording.mp4
    app.log
    errors.log
    validation-log.md
  ipad-pro-13/
    8.3.01-split-view-sidebar.png
    ...
    8.3.60-server-setup.png
    recording.mp4
    app.log
    errors.log
    validation-log.md
  mac/
    8.4.01-three-column-layout.png
    ...
    8.4.62-about-tab.png
    recording.mov              # Full session video (screencapture -v)
    app.log
    errors.log
    keyboard-shortcuts-log.md  # Each shortcut: key combo, expected, actual, PASS/FAIL
    validation-log.md
  consolidated-report.md       # Final cross-platform report
  comparison-matrix.md         # Screen x platform grid
  issues.md                    # Prioritized issue list
```

Each platform directory contains:
- Numbered screenshot for every checklist item (named `<item-id>-<description>.png`)
- `recording.mp4` / `recording.mov` — video of the full validation session
- `app.log` — complete log stream from app launch to validation end
- `errors.log` — filtered errors/warnings/faults from app.log
- `validation-log.md` with PASS/FAIL for each item, evidence filename, timestamps, and notes
- Fix screenshots (`fix-<item-id>.png`) if Task 8.6 produced fixes

## Screen Inventory (Per Platform)

### Screens Shared Across All Platforms (iOS + macOS)

These views are compiled into both targets and must be validated on all 4 platforms:

| # | Screen | Source File |
|---|--------|------------|
| 1 | Home / Dashboard | `ILSApp/ILSApp/Views/Home/HomeView.swift` |
| 2 | Chat View | `ILSApp/ILSApp/Views/Chat/ChatView.swift` |
| 3 | Chat Input Bar | `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift` |
| 4 | Chat Message List | `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` |
| 5 | Message View | `ILSApp/ILSApp/Views/Chat/MessageView.swift` |
| 6 | User Message Card | `ILSApp/ILSApp/Views/Chat/UserMessageCard.swift` |
| 7 | Assistant Card | `ILSApp/ILSApp/Views/Chat/AssistantCard.swift` |
| 8 | Code Block View | `ILSApp/ILSApp/Views/Chat/CodeBlockView.swift` |
| 9 | Markdown Text View | `ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift` |
| 10 | Streaming Indicator | `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift` |
| 11 | Command Palette | `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift` |
| 12 | Advanced Options | `ILSApp/ILSApp/Views/Chat/AdvancedOptionsSheet.swift` |
| 13 | Permission Request | `ILSApp/ILSApp/Views/Chat/PermissionRequestModal.swift` |
| 14 | System Monitor | `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` |
| 15 | Process List | `ILSApp/ILSApp/Views/System/ProcessListView.swift` |
| 16 | File Browser | `ILSApp/ILSApp/Views/System/FileBrowserView.swift` |
| 17 | Settings | `ILSApp/ILSApp/Views/Settings/SettingsView.swift` |
| 18 | Browser | `ILSApp/ILSApp/Views/Browser/BrowserView.swift` |
| 19 | MCP Server Detail | `ILSApp/ILSApp/Views/Browser/MCPServerDetailView.swift` |
| 20 | Skill Detail | `ILSApp/ILSApp/Views/Browser/SkillDetailView.swift` |
| 21 | Agent Teams List | `ILSApp/ILSApp/Views/Teams/AgentTeamsListView.swift` |
| 22 | Agent Team Detail | `ILSApp/ILSApp/Views/Teams/AgentTeamDetailView.swift` |
| 23 | Create Team | `ILSApp/ILSApp/Views/Teams/CreateTeamView.swift` |
| 24 | Spawn Teammate | `ILSApp/ILSApp/Views/Teams/SpawnTeammateView.swift` |
| 25 | Team Task List | `ILSApp/ILSApp/Views/Teams/TeamTaskListView.swift` |
| 26 | Team Messages | `ILSApp/ILSApp/Views/Teams/TeamMessagesView.swift` |
| 27 | Fleet Management | `ILSApp/ILSApp/Views/Fleet/FleetManagementView.swift` |
| 28 | Fleet Host Detail | `ILSApp/ILSApp/Views/Fleet/FleetHostDetailView.swift` |
| 29 | Themes List | `ILSApp/ILSApp/Views/Themes/ThemesListView.swift` |
| 30 | Theme Editor | `ILSApp/ILSApp/Views/Themes/ThemeEditorView.swift` |
| 31 | Theme Preview | `ILSApp/ILSApp/Views/Themes/ThemePreviewView.swift` |
| 32 | Theme Marketplace | `ILSApp/ILSApp/Views/Themes/ThemeMarketplaceView.swift` |
| 33 | Theme Preview Card | `ILSApp/ILSApp/Views/Themes/ThemePreviewCard.swift` |
| 34 | New Session | `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift` |
| 35 | Session Info | `ILSApp/ILSApp/Views/Sessions/SessionInfoView.swift` |
| 36 | Plugin Config | `ILSApp/ILSApp/Views/Plugins/PluginConfigView.swift` |
| 37 | Server Setup Sheet | `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` |
| 38 | Offline Indicator | `ILSApp/ILSApp/Views/Components/OfflineIndicator.swift` |
| 39 | Launch Screen | `ILSApp/ILSApp/Views/LaunchScreenView.swift` |

### iOS-Only Screens

| # | Screen | Source File |
|---|--------|------------|
| 40 | Sidebar Root (iPhone/iPad) | `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` |
| 41 | Sidebar (iPhone overlay / iPad persistent) | `ILSApp/ILSApp/Views/Root/SidebarView.swift` |
| 42 | Sidebar Session Row | `ILSApp/ILSApp/Views/Root/SidebarSessionRow.swift` |
| 43 | Settings Sections (About, Connection, Appearance, Config) | `ILSApp/ILSApp/Views/Settings/Settings*Section.swift` |
| 44 | Config Editor | `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift` |
| 45 | Log Viewer | `ILSApp/ILSApp/Views/Settings/LogViewerView.swift` |
| 46 | Theme Picker | `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` |
| 47 | Tunnel Settings | `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` |
| 48 | Notification Prefs | `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift` |
| 49 | Onboarding | `ILSApp/ILSApp/Views/Onboarding/OnboardingView.swift` |
| 50 | Quick Connect | `ILSApp/ILSApp/Views/Onboarding/QuickConnectView.swift` |
| 51 | SSH Setup | `ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift` |
| 52 | Premium View | `ILSApp/ILSApp/Views/Premium/PremiumView.swift` |
| 53 | Feature Gate | `ILSApp/ILSApp/Views/Premium/FeatureGateView.swift` |
| 54 | Share Sheet | `ILSApp/ILSApp/Views/Shared/ShareSheet.swift` |
| 55 | Cache Status | `ILSApp/ILSApp/Views/Components/CacheStatusView.swift` |
| 56 | App Tips | `ILSApp/ILSApp/Views/Tips/AppTips.swift` |

### macOS-Only Screens

| # | Screen | Source File |
|---|--------|------------|
| 57 | Mac Content View (3-column) | `ILSApp/ILSMacApp/Views/MacContentView.swift` |
| 58 | Mac Dashboard | `ILSApp/ILSMacApp/Views/MacDashboardView.swift` |
| 59 | Mac Chat View | `ILSApp/ILSMacApp/Views/MacChatView.swift` |
| 60 | Mac Settings (Tabbed) | `ILSApp/ILSMacApp/Views/MacSettingsView.swift` |
| 61 | Mac Sessions List | `ILSApp/ILSMacApp/Views/MacSessionsListView.swift` |
| 62 | Session Window View | `ILSApp/ILSMacApp/Views/SessionWindowView.swift` |
| 63 | Menu Bar Commands | `ILSApp/ILSMacApp/Commands/ILSCommands.swift` |
| 64 | Window Manager | `ILSApp/ILSMacApp/Managers/WindowManager.swift` |
| 65 | Notification Manager | `ILSApp/ILSMacApp/Managers/NotificationManager.swift` |
| 66 | Spotlight Indexer | `ILSApp/ILSMacApp/Services/SpotlightIndexer.swift` |
| 67 | Touch Bar Provider | `ILSApp/ILSMacApp/TouchBar/ChatTouchBarProvider.swift` |
| 68 | App Delegate | `ILSApp/ILSMacApp/AppDelegate.swift` |

## Platform-Specific Behavior Matrix

| Behavior | iPhone (compact) | iPad (regular) | Mac |
|----------|-----------------|----------------|-----|
| Sidebar | Overlay (hamburger) | Persistent `NavigationSplitView` | 3-column `NavigationSplitView` |
| Sidebar open trigger | Hamburger button + edge swipe | Always visible (portrait: toggleable) | Always visible (column visibility) |
| Navigation style | `NavigationStack` | `NavigationSplitView` 2-column | `NavigationSplitView` 3-column |
| Sessions list | In sidebar | In sidebar | Middle column (dedicated) |
| Keyboard shortcuts | None | Limited (Cmd+N) | Full set (ILSCommands) |
| Context menus | Long press | Long press + secondary click | Right-click |
| Multi-window | Not supported | Not supported | Supported (SessionWindowView) |
| Spotlight indexing | No | No | Yes |
| Touch Bar | No | No | Yes (MacBook Pro) |
| Menu bar | No | No | Yes (ILSCommands) |
| Dynamic Type range | xSmall...accessibility3 | xSmall...accessibility3 | ...accessibility1 |
| Color scheme | system/light/dark | system/light/dark | system/light/dark |
| Deep links | `ils://` URL scheme | `ils://` URL scheme | `ils://` URL scheme |
| Sheet presentation | Full screen | Form sheet (centered) | Sheet (centered) |
| Export | Share sheet (UIActivityViewController) | Share sheet | NSSavePanel |
| Screenshot method | `xcrun simctl io <UDID> screenshot` | `xcrun simctl io <UDID> screenshot` | `screencapture -x` |
| Video recording | `xcrun simctl io <UDID> recordVideo` | `xcrun simctl io <UDID> recordVideo` | `screencapture -v` |
| Log streaming | `xcrun simctl spawn <UDID> log stream` | `xcrun simctl spawn <UDID> log stream` | `log stream --predicate` |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| iPad simulator not available in Xcode | Low | HIGH | Pre-check with `xcrun simctl list devicetypes`; download runtime if needed; create simulator in SETUP phase |
| macOS app crashes on launch (AppDelegate issue) | Low | HIGH | Task 8.4 captures console output + crash reports in COLLECT phase; AppDelegate was audited in prior phases |
| NavigationSplitView column width mismatch on iPad | Medium | MEDIUM | Task 8.3 explicitly checks column constraints with specific pixel measurements in screenshots |
| Touch Bar unavailable in simulator | Medium | LOW | Document as N/A if no physical MacBook Pro; verify code compiles; check logs for Touch Bar initialization |
| Spotlight indexing requires entitlements | Low | LOW | Verify entitlement in project.pbxproj; check logs for Spotlight errors; may only work on device |
| Split View multitasking breaks layout | Medium | MEDIUM | Task 8.3 tests all 3 multitasking widths with screenshots at each width |
| Sheet sizing wrong on iPad (full screen vs form) | Medium | MEDIUM | Task 8.3 checks sheet presentations with specific PASS criteria (width < 80% of screen) |
| DerivedData stale after Phase 7 fixes | Low | MEDIUM | Each validator runs fresh `xcodebuild` in SETUP phase; clean install via `xcrun simctl uninstall` |
| Video recording fails to stop cleanly | Medium | LOW | Use SIGINT (not kill -9) in COLLECT phase; wait 2s for file finalization; verify file size > 0 |
| Backend dies during validation | Low | HIGH | Health check in SETUP phase; if any screenshot shows "Offline" unexpectedly, re-check backend and restart if needed |
| Sub-agent PASS claims without evidence | Medium | HIGH | Task 8.5 auditor reads actual screenshots to cross-check; no claim accepted without evidence file |
