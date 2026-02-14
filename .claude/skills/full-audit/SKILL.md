---
name: full-audit
description: Use when auditing the entire ILS application stack - comprehensive cross-platform UI inspection, backend API validation, shell script testing, deep link verification, accessibility checks, and every component end-to-end across iPhone, iPad, and macOS
---

# Full-Stack Audit — ILS Application

## Overview
Comprehensive audit coordinator that validates EVERY component of the ILS application: UI across all Apple platforms, backend API endpoints, shell scripts, deep links, accessibility, and data integrity. This goes far beyond visual inspection — it tests actual functionality.

## When to Use
- Pre-release validation
- After major refactors
- Before App Store submission
- When asked to "audit everything" or "test the whole app"

## Architecture

```
Full Audit
├── Phase 1: Environment & Infrastructure
├── Phase 2: Backend API Validation
├── Phase 3: Shell Script Testing
├── Phase 4: iOS UI Audit (iPhone 16 Pro Max)
├── Phase 5: iPad UI Audit (iPad Pro 13")
├── Phase 6: macOS UI Audit
├── Phase 7: Cross-Platform Consistency
├── Phase 8: Deep Link & Navigation
├── Phase 9: Accessibility & Dynamic Type
└── Phase 10: Data Integrity & Edge Cases
```

## Execution

Use **parallel sub-tasks** where phases are independent. Phases 1-3 can run in parallel. Phases 4-6 can run in parallel (different simulators). Phases 7-10 run after 4-6 complete.

### Evidence Directory
`specs/full-audit/evidence/{date}/`

### Report Output
`specs/full-audit/report-{date}.md`

---

## Phase 1: Environment & Infrastructure

**Validates:** Build toolchain, simulators, dependencies

```bash
# 1.1 Swift toolchain
swift --version

# 1.2 Xcode version
xcodebuild -version

# 1.3 Dedicated simulator exists and boots
xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null || true
xcrun simctl list devices | grep 50523130

# 1.4 SPM dependencies resolve
cd /Users/nick/Desktop/ils-ios && swift package resolve

# 1.5 iOS build (clean)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' \
  clean build -quiet 2>&1 | tail -10

# 1.6 macOS build (clean)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' \
  clean build -quiet 2>&1 | tail -10

# 1.7 Backend build
swift build 2>&1 | tail -10

# 1.8 No build warnings (check for yellow)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' \
  build 2>&1 | grep -c "warning:" || echo "0 warnings"
```

**Pass criteria:** All builds succeed with 0 errors. Warnings documented.

---

## Phase 2: Backend API Validation

**Validates:** Every API endpoint returns correct data with proper structure

```bash
# Start backend
PORT=9999 swift run ILSBackend &
BACKEND_PID=$!
# Wait for health
for i in $(seq 1 30); do
  curl -sf http://localhost:9999/health > /dev/null 2>&1 && break
  sleep 2
done
```

### Endpoint Checklist

| # | Endpoint | Method | Validation |
|---|----------|--------|------------|
| 2.1 | `/health` | GET | Returns "OK", HTTP 200 |
| 2.2 | `/api/v1/sessions` | GET | Returns APIResponse with `items` array, `total` count |
| 2.3 | `/api/v1/sessions/{id}` | GET | Returns single session with `id`, `model`, `messages` |
| 2.4 | `/api/v1/projects` | GET | Returns APIResponse with project items |
| 2.5 | `/api/v1/skills` | GET | Returns APIResponse with skill items |
| 2.6 | `/api/v1/mcp` | GET | Returns APIResponse with MCP server items |
| 2.7 | `/api/v1/plugins` | GET | Returns APIResponse with plugin items |
| 2.8 | `/api/v1/config` | GET | Returns configuration data |
| 2.9 | `/api/v1/stats` | GET | Returns statistics (sessions, projects, skills counts) |
| 2.10 | `/api/v1/themes` | GET | Returns 12 theme definitions |
| 2.11 | `/api/v1/chat` | POST | Accepts message, returns SSE stream (test with timeout) |
| 2.12 | `/api/v1/chat/cancel` | POST | Returns success for cancel request |

### Validation Script

```bash
# For each endpoint:
RESPONSE=$(curl -sf http://localhost:9999/api/v1/sessions)
echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'items' in d or 'total' in d, 'Missing expected fields'"
# Check camelCase (not snake_case — indicates wrong backend binary)
echo "$RESPONSE" | grep -q "snake_case_field" && echo "FAIL: Wrong backend binary!" || echo "PASS: Correct API format"
```

### Backend Binary Verification (CRITICAL)
```bash
lsof -i :9999 -P -n | grep LISTEN
# MUST show path containing "ils-ios", NOT "ils/ILSBackend"
```

**Pass criteria:** All endpoints return HTTP 200 with correct JSON structure. CamelCase keys. No snake_case.

---

## Phase 3: Shell Script Testing

**Validates:** All scripts in `scripts/` work correctly

### 3.1 setup.sh
```bash
# Test in a temp clone (non-destructive)
TEMP_DIR=$(mktemp -d)
cp -r /Users/nick/Desktop/ils-ios "$TEMP_DIR/ils-test"
cd "$TEMP_DIR/ils-test"
bash scripts/setup.sh
EXIT_CODE=$?
rm -rf "$TEMP_DIR"
# Pass: exit 0, all [OK] messages, no [FAIL]
```

**Check for known bugs:**
- `PIPESTATUS[0]` used correctly (not `tail` exit code)
- Health check polling (not fixed sleep)
- `set -o pipefail` present

### 3.2 install-backend-service.sh
```bash
# Dry-run validation (check syntax and logic without installing)
bash -n scripts/install-backend-service.sh
# Check health polling (not fixed 3s sleep)
grep -n "sleep" scripts/install-backend-service.sh
# Should use polling loop, not fixed sleep
```

### 3.3 run_regression_tests.sh
```bash
bash -n scripts/run_regression_tests.sh
# Validate it references correct simulator UDID
grep "50523130" scripts/run_regression_tests.sh
```

### 3.4 reinstall-plugins.sh
```bash
bash -n scripts/reinstall-plugins.sh
```

**Pass criteria:** All scripts pass syntax check. setup.sh runs end-to-end. No hardcoded sleep for health checks.

---

## Phase 4: iOS UI Audit (iPhone 16 Pro Max)

**Simulator:** `50523130-57AA-48B0-ABD0-4D59CE455F14`

For EACH screen below:
1. Navigate to the screen (deep link or `idb_tap` using `idb_describe` coordinates)
2. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot {path}.png`
3. Verify visually: text readability, color contrast, button sizing (44pt min), layout correctness
4. Test interaction: taps register, navigation works, scroll functions

### Screen Checklist (34 screens)

#### App Launch & Onboarding
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 1 | Server Setup Sheet | ServerSetupSheet.swift / OnboardingView.swift | Branding visible, cards readable, non-dismissible |
| 2 | Quick Connect | QuickConnectView.swift | URL field, connect button, error states |
| 3 | Connected Transition | — | Dismisses to Home, no flash of broken state |

#### Dashboard & Navigation
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 4 | Dashboard (connected) | HomeView.swift | Stats cards, recent sessions, entity colors |
| 5 | Dashboard (disconnected) | HomeView.swift | Banner visible, Configure/Retry button |
| 6 | Sidebar | SidebarView.swift | All nav items, session search, new session button |

#### Chat
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 7 | New Session Sheet | NewSessionView.swift | All form fields, model picker, create button |
| 8 | Chat (empty) | ChatView.swift | Input bar, command palette button, menu button |
| 9 | Chat (with messages) | ChatView.swift | Markdown, code blocks, tool calls, thinking |
| 10 | Chat (streaming) | ChatView.swift | Dots animation, stop button, status text |
| 11 | Session Info | SessionInfoView.swift | All metadata fields, export/copy buttons |
| 12 | Command Palette | CommandPaletteView.swift | Search, commands listed, tap targets |
| 13 | Advanced Options | AdvancedOptionsSheet.swift | System prompt, model picker, toggles |
| 14 | Chat Menu | ChatView.swift | Rename, Fork, Export, Delete (red) |

#### Browser
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 15 | MCP Servers tab | BrowserView.swift | Segment control, scope filter, search, list |
| 16 | Skills tab | BrowserView.swift | Skill list, source badges, count |
| 17 | Plugins tab | BrowserView.swift | Plugin list, categories, install status |
| 18 | MCP Detail | MCPServerDetailView.swift | Command display, env vars, copy button |
| 19 | Skill Detail | SkillDetailView.swift | Tags, metadata, markdown content |

#### System Monitor
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 20 | System Main | SystemMonitorView.swift | CPU/Memory/Disk charts, network, live indicator |
| 21 | Process List | ProcessListView.swift | Sort options, search, PID/CPU/Memory columns |
| 22 | File Browser | FileBrowserView.swift | Breadcrumbs, icons, file sizes, drill-down |

#### Teams
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 23 | Teams List | AgentTeamsListView.swift | Team cards, create button, empty state |
| 24 | Team Detail | AgentTeamDetailView.swift | Members/Tasks/Messages tabs, status badges |
| 25 | Create Team | CreateTeamView.swift | Form fields, create button |
| 26 | Spawn Teammate | SpawnTeammateView.swift | Role selector, config fields |

#### Settings
| # | Screen | SwiftUI File | Key Checks |
|---|--------|-------------|------------|
| 27 | Settings (top) | SettingsView.swift | Connection, Remote Access, Appearance |
| 28 | Settings (middle) | SettingsView.swift | Model, API Key, Permissions |
| 29 | Settings (bottom) | SettingsView.swift | Debug, Statistics, About |
| 30 | Theme Picker | ThemePickerView.swift | 12 themes grid, active highlight, color swatches |
| 31 | Tunnel Settings | TunnelSettingsView.swift | Cloudflare config, toggle, status |
| 32 | Log Viewer | LogViewerView.swift | Monospace, timestamps, scroll |

#### Cross-Cutting
| # | Check | Scope |
|---|-------|-------|
| 33 | Dark mode: no white flashes, all theme colors applied | All screens |
| 34 | Entity colors: Sessions=blue, Projects=green, Skills=purple, MCP=orange, Plugins=pink | All entity views |

### Navigation Strategy
- Use `idb_describe operation:all` to get accessibility tree with exact coordinates
- Use `idb_tap` at those coordinates for navigation
- For toolbar buttons (unreachable via tap): modify `@State` defaults, rebuild, capture, revert
- Deep links: `xcrun simctl openurl booted 'ils://sessions/{lowercase-uuid}'`
- If gesture times out after 60s, skip and log

**Pass criteria:** All 34 screens captured and verified. No text truncation, no broken layouts, all interactive elements have 44pt+ tap targets.

---

## Phase 5: iPad UI Audit (iPad Pro 13")

**Simulator:** Boot `iPad Pro 13-inch (M4)` or create one

Same 34-screen checklist as Phase 4, but additionally check:
- **Size class adaptations**: Does the layout use available width?
- **Split view**: Does NavigationSplitView show sidebar + detail?
- **Touch targets**: Still 44pt minimum on larger display?
- **Text scaling**: Content fills space appropriately (not phone-sized in center)

Save screenshots to `specs/full-audit/evidence/{date}/ipad/`

---

## Phase 6: macOS UI Audit

Build and run `ILSMacApp` scheme. Check:
- **Window management**: Resizable, minimum size enforced
- **NavigationSplitView**: 3-column layout works
- **Menu bar**: App menu items present and functional
- **Keyboard shortcuts**: Cmd+N (new session), Cmd+, (settings)
- **All screens from Phase 4** adapted for macOS (no iOS-only patterns)
- **Window chrome**: Title bar, close/minimize/zoom buttons work

Save screenshots to `specs/full-audit/evidence/{date}/macos/`

---

## Phase 7: Cross-Platform Consistency

Compare Phase 4/5/6 results:
- Same data displayed on all platforms (session counts, project names)
- Entity colors consistent across platforms
- No platform has broken features that work on another
- Settings changes on one platform reflected when backend is shared

---

## Phase 8: Deep Link & Navigation Testing

```bash
SIMULATOR="50523130-57AA-48B0-ABD0-4D59CE455F14"

# Test each deep link scheme
xcrun simctl openurl $SIMULATOR 'ils://home'
xcrun simctl openurl $SIMULATOR 'ils://sessions'
xcrun simctl openurl $SIMULATOR 'ils://settings'
xcrun simctl openurl $SIMULATOR 'ils://browser'
xcrun simctl openurl $SIMULATOR 'ils://system'

# Test with session UUID (LOWERCASE!)
SESSION_ID=$(curl -sf http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; print(json.load(sys.stdin)['items'][0]['id'])" 2>/dev/null)
xcrun simctl openurl $SIMULATOR "ils://sessions/${SESSION_ID}"
```

Check:
- Each deep link navigates to correct screen
- No "Open in ILSApp?" system dialog (app already running)
- Back navigation works after deep link
- Invalid deep links don't crash

---

## Phase 9: Accessibility & Dynamic Type

```bash
# Enable larger text
xcrun simctl ui 50523130-57AA-48B0-ABD0-4D59CE455F14 content_size extra-extra-large

# Capture key screens at large text
# ... screenshot each screen ...

# Reset
xcrun simctl ui 50523130-57AA-48B0-ABD0-4D59CE455F14 content_size medium
```

Check:
- Text scales with Dynamic Type (no fixed font sizes)
- No text overlapping at XXL
- Buttons remain tappable at all sizes
- VoiceOver labels present on interactive elements (`accessibilityLabel`)

---

## Phase 10: Data Integrity & Edge Cases

### 10.1 Empty State Testing
- Disconnect backend, verify all screens show graceful empty states
- No crashes, no infinite spinners, no raw error dumps

### 10.2 Large Data Sets
- Backend has 22K+ sessions — verify pagination/scrolling handles this
- Skills list (1483) — verify search and scroll performance

### 10.3 Network Resilience
- Kill backend mid-request — verify error handling
- Start app without backend — verify onboarding/reconnection flow

### 10.4 State Persistence
- Create a session, force-quit app, relaunch — session persists
- Change settings, force-quit, relaunch — settings persist
- Select theme, force-quit, relaunch — theme persists

### 10.5 Concurrent Operations
- Send a chat message while navigating away — no crash
- Open command palette while streaming — no crash
- Cancel streaming while receiving data — graceful stop

---

## Report Format

Generate `specs/full-audit/report-{date}.md`:

```markdown
# Full-Stack Audit Report — {date}

## Summary
- Total checks: X
- PASS: X
- FAIL: X
- SKIP: X

## Phase Results

### Phase 1: Environment
| Check | Result | Notes |
|-------|--------|-------|
| Swift version | PASS | 5.10 |
| ... | ... | ... |

### Phase 2: Backend API
| Endpoint | Status | Response Time | Notes |
|----------|--------|---------------|-------|
| /health | PASS | 12ms | |
| ... | ... | ... | ... |

[... all phases ...]

## Failures Requiring Action
1. [FAIL] Description — **Impact:** High — **Fix:** ...
2. ...

## Screenshots
See `specs/full-audit/evidence/{date}/`
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using wrong simulator | Always use UDID 50523130-57AA-48B0-ABD0-4D59CE455F14 |
| Uppercase UUIDs in deep links | Always lowercase |
| Guessing tap coordinates | Use `idb_describe operation:all` for exact coords |
| Testing against wrong backend | Verify with `lsof -i :9999 -P -n` — must be ils-ios binary |
| Skipping backend start | Backend MUST be running for any UI testing |
| Batch screenshots without verification | View EACH screenshot before marking PASS |
