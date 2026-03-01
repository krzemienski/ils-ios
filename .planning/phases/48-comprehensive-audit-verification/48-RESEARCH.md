# Phase 48: Comprehensive Audit & Verification - Research

**Researched:** 2026-02-27
**Domain:** iOS/iPad/Backend visual + functional + integration audit with evidence collection
**Confidence:** HIGH

## Summary

Phase 48 is the capstone verification phase for v4.0. All remediation phases (43-47) are complete, having closed 29 requirements across UI gaps, platform compliance, data hardening, security, and ecosystem polish. This phase produces the evidence portfolio proving everything works: numbered screenshots on iPhone and iPad, cURL transcripts for every backend endpoint, correlated frontend-backend data flow pairs, and a proactive bug hunt targeting edge cases.

The audit is purely verification and evidence collection -- no new features are built. The primary technical challenge is automation: capturing 20+ screenshots across two devices, driving deep-link navigation, running 70+ cURL commands against the backend, and correlating outputs. The secondary challenge is iPad validation, which was deferred from v3.5 and is now required. The iPad simulator (C074375B) is currently shut down and must be booted, with `screencapture -l` used as the screenshot method (simctl io screenshot fails with error 60 on this environment).

**Primary recommendation:** Structure as 5 plans: (1) environment setup + iPhone visual audit, (2) iPad visual audit, (3) backend endpoint cURL audit, (4) correlated integration evidence, (5) proactive bug hunt + edge cases. Keep each plan autonomous and evidence-heavy.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUDIT-01 | Visual audit -- iPhone and iPad screens with numbered screenshot evidence (20+ artifacts) | Screen inventory (23 screens), deep link routes (15), screenshot methodology (screencapture -l for iPad, simctl io for iPhone), PASS criteria from v3.5 Phase 40 |
| AUDIT-02 | Functional audit -- real data verification on iPhone and iPad with evidence | Backend has real data (22K+ sessions, 3015 skills, 15 MCP, 84 plugins), functional flows documented, deep link navigation for automated screen driving |
| AUDIT-03 | Backend audit -- cURL every endpoint, verify JSON structure matches spec contract | Complete endpoint registry (70+ routes across 15 controllers), APIResponse wrapper format, admin vs public route distinction, expected field names/types |
| AUDIT-04 | Integration validation -- correlated backend+frontend evidence showing data flows | Key flows identified: POST session -> session appears in list, skill search -> results in browser, config update -> settings reflect change, stats endpoint -> home dashboard |
| AUDIT-05 | Proactive bug hunt -- edge cases, offline behavior, accessibility, memory profiling | Edge case categories identified: empty states, offline mode, accessibility (VoiceOver, Dynamic Type), memory (Instruments leak check), error states, boundary values |
</phase_requirements>

## Standard Stack

### Core Tools

| Tool | Version/Command | Purpose | Why Standard |
|------|----------------|---------|--------------|
| `xcrun simctl` | Xcode 16+ | Simulator control, deep links, app install/launch | Apple's official simulator CLI; used in all prior phases |
| `screencapture -l` | macOS built-in | Screenshot capture via Quartz window ID | Required workaround -- `simctl io screenshot` fails with error 60 on this env |
| `curl` | macOS built-in | Backend endpoint verification | Standard HTTP testing tool; outputs JSON for validation |
| `python3 -c` | macOS built-in | JSON structure validation, field extraction | Inline JSON parsing for cURL output verification |
| `idb_describe` | idb companion | Accessibility tree inspection | Gives exact centerX/centerY for tap targets; validated approach from v3.5 |
| `idb_tap` | idb companion | Simulated tap input | Use with coordinates from idb_describe, not guessed pixels |

### Supporting Tools

| Tool | Command | Purpose | When to Use |
|------|---------|---------|-------------|
| `xcrun simctl openurl` | `xcrun simctl openurl {UDID} "ils://{route}"` | Deep link navigation | Driving to specific screens without manual taps |
| `xcrun simctl status_bar` | `xcrun simctl status_bar {UDID} override` | Clean status bar for evidence | Set 9:41, full battery, full signal before screenshots |
| `lsof -i :9999` | macOS built-in | Backend binary verification | Confirm correct backend path (must contain `ils-ios/`) |
| `leaks` / `vmmap` | macOS dev tools | Memory profiling for bug hunt | AUDIT-05 memory edge case |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `screencapture -l` | `xcrun simctl io screenshot` | simctl fails with error 60 in this env; screencapture works reliably |
| Manual `idb_tap` navigation | Deep links (`xcrun simctl openurl`) | Deep links are faster and more reliable for screen-to-screen navigation; use idb_tap only for in-screen interactions |
| Fastlane `capture_screenshots` | `xcrun simctl io screenshot` | Fastlane requires XCUITest scheme; simctl/screencapture works on any booted simulator |

## Architecture Patterns

### Evidence Directory Structure

```
/tmp/v4.0-audit/
├── iphone/                    # AUDIT-01: iPhone screenshots (numbered)
│   ├── 01-home.png
│   ├── 02-sessions.png
│   ├── ...
│   └── 23-launch-screen.png
├── ipad/                      # AUDIT-01: iPad screenshots (numbered)
│   ├── 01-home.png
│   ├── 02-sessions.png
│   ├── ...
│   └── 23-launch-screen.png
├── backend/                   # AUDIT-03: cURL transcripts
│   ├── 01-health.json
│   ├── 02-sessions-list.json
│   ├── ...
│   └── summary.md
├── integration/               # AUDIT-04: Correlated pairs
│   ├── flow-01-create-session/
│   │   ├── curl-post.json
│   │   └── iphone-sessions-list.png
│   ├── flow-02-stats-to-dashboard/
│   │   ├── curl-stats.json
│   │   └── iphone-home.png
│   └── ...
├── edge-cases/                # AUDIT-05: Bug hunt evidence
│   ├── offline-mode.png
│   ├── empty-states.png
│   ├── accessibility-voiceover.png
│   ├── memory-profile.txt
│   └── ...
└── gate/                      # Final gate verdict
    └── verdict.md
```

### Pattern 1: Screenshot Capture Pipeline

**What:** Automated pipeline to navigate to each screen via deep link and capture numbered screenshot.
**When to use:** Every screen in the visual audit (AUDIT-01).

```bash
# iPhone screenshot pipeline
IPHONE="50523130-57AA-48B0-ABD0-4D59CE455F14"

# Navigate via deep link
xcrun simctl openurl "$IPHONE" "ils://home"
sleep 3  # Wait for data load

# Capture screenshot
xcrun simctl io "$IPHONE" screenshot /tmp/v4.0-audit/iphone/01-home.png

# iPad screenshot pipeline (uses screencapture -l workaround)
IPAD="C074375B-2CB2-4F95-A55C-972F2FF35041"

# Get Simulator window ID for iPad
IPAD_WID=$(python3 -c "
import subprocess, json
out = subprocess.check_output(['python3', '-c', '''
import Quartz
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
for w in windows:
    name = w.get('kCGWindowName', '')
    owner = w.get('kCGWindowOwnerName', '')
    if owner == 'Simulator' and 'iPad' in str(name):
        print(w['kCGWindowNumber'])
        break
'''])
print(out.decode().strip())
")
screencapture -l "$IPAD_WID" /tmp/v4.0-audit/ipad/01-home.png
```

### Pattern 2: Backend cURL Audit Template

**What:** Structured cURL command with JSON validation for each endpoint.
**When to use:** Every backend endpoint (AUDIT-03).

```bash
# Template for each endpoint
echo "=== GET /api/v1/sessions ===" > /tmp/v4.0-audit/backend/02-sessions-list.json
curl -s http://localhost:9999/api/v1/sessions | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Verify APIResponse wrapper
assert 'data' in d, 'Missing APIResponse wrapper'
# Verify field names (camelCase, not snake_case)
if d['data']:
    item = d['data'][0]
    assert 'id' in item, 'Missing id field'
    assert 'createdAt' in item or 'name' in item, 'Missing expected fields'
    print(json.dumps({'status': 'PASS', 'count': len(d['data']),
                      'fields': list(item.keys())[:10]}, indent=2))
" >> /tmp/v4.0-audit/backend/02-sessions-list.json 2>&1
```

### Pattern 3: Correlated Integration Evidence

**What:** Backend response + frontend screenshot side-by-side proving data flows end-to-end.
**When to use:** Integration validation pairs (AUDIT-04).

```bash
# Flow: stats endpoint -> home dashboard
# Step 1: Capture backend response
curl -s http://localhost:9999/api/v1/stats > /tmp/v4.0-audit/integration/flow-02/curl-stats.json

# Step 2: Navigate to Home and screenshot
xcrun simctl openurl "$IPHONE" "ils://home"
sleep 3
xcrun simctl io "$IPHONE" screenshot /tmp/v4.0-audit/integration/flow-02/iphone-home.png

# Step 3: Verify correlation (stats counts match dashboard cards)
python3 -c "
import json
with open('/tmp/v4.0-audit/integration/flow-02/curl-stats.json') as f:
    stats = json.load(f)
print(f'Backend reports: {json.dumps(stats.get(\"data\", {}), indent=2)[:200]}')
print('Visual verification: compare counts in screenshot with backend values')
"
```

### Anti-Patterns to Avoid

- **Guessing pixel coordinates:** Never guess tap coordinates from screenshots. Always use `idb_describe operation:all` to get the accessibility tree with exact centerX/centerY, then use those for `idb_tap`.
- **Batching screenshots without data verification:** Each screenshot must be visually inspected (via Read tool) to confirm real data is displayed, not loading spinners or empty states.
- **Using wrong backend binary:** ALWAYS verify `lsof -i :9999 -P -n` shows binary path containing `ils-ios/`, not `ils/ILSBackend/`.
- **Skipping deep link warm-up:** The app must be launched at least once before deep links work without system confirmation dialog. Always launch via `xcrun simctl launch` first.
- **iPad compact layout assumption:** iPad Pro 13 should show NavigationSplitView with persistent sidebar. If it shows hamburger button, the Simulator window is resized -- this is a genuine FAIL, not just a window issue.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screenshot capture | Custom screengrab tool | `xcrun simctl io screenshot` (iPhone) + `screencapture -l` (iPad) | OS-level capture is pixel-perfect; custom solutions miss status bar, overlays |
| JSON validation | Manual field-by-field string matching | `python3 -c` with `json.load()` + assertions | Structured parsing catches type errors, missing fields, wrong nesting |
| Accessibility audit | Manual VoiceOver walkthrough | `idb_describe operation:all` tree dump | Complete accessibility tree in machine-readable format |
| Memory profiling | Manual Instruments session | `leaks --atExit` or `vmmap` CLI | CLI tools produce text evidence; Instruments requires GUI interaction |
| Screen navigation | Manual idb_tap sequences | Deep links (`xcrun simctl openurl`) | Deep links are deterministic; tap sequences break on layout changes |

**Key insight:** This phase is evidence collection, not feature development. Every tool should produce a persisted artifact (file) that proves the audit finding.

## Common Pitfalls

### Pitfall 1: simctl io screenshot Error 60

**What goes wrong:** `xcrun simctl io screenshot` fails with "Timeout waiting for screen surfaces" (error code 60).
**Why it happens:** Known macOS/Simulator GPU rendering issue where screen surface is unavailable to simctl io.
**How to avoid:** Use `screencapture -l <windowID>` to capture Simulator windows via Quartz. Get window IDs via `CGWindowListCopyWindowInfo` through Python.
**Warning signs:** Error message mentioning "screen surfaces" or timeout in simctl output.

### Pitfall 2: iPad Simulator Not Booted

**What goes wrong:** iPad simulator (C074375B) is currently shut down. Attempting screenshots or deep links will fail silently.
**Why it happens:** iPad was deferred from v3.5; simulator was not used since initial setup.
**How to avoid:** First task must boot iPad simulator: `xcrun simctl boot C074375B-2CB2-4F95-A55C-972F2FF35041`. Build and install app. Wait for home screen.
**Warning signs:** `xcrun simctl list devices | grep C074375B` shows (Shutdown) instead of (Booted).

### Pitfall 3: Stale App Binary on iPad

**What goes wrong:** iPad has an old app binary from weeks ago that does not include Phases 43-47 changes.
**Why it happens:** Only iPhone simulator was used during v4.0 remediation phases.
**How to avoid:** Fresh build, `xcrun simctl uninstall` old binary, `xcrun simctl install` from latest DerivedData path. Verify binary timestamp matches build time.
**Warning signs:** iPad UI missing Quick Actions, Quick Settings, or other v4.0 features.

### Pitfall 4: Backend Not Running or Wrong Binary

**What goes wrong:** cURL commands return connection refused or wrong JSON format.
**Why it happens:** Backend not started, or old binary at `/Users/nick/ils/ILSBackend/` is running instead.
**How to avoid:** Three-point verification: (1) `lsof -i :9999 -P -n` path contains `ils-ios/`, (2) `curl -sf http://localhost:9999/health`, (3) `curl -s http://localhost:9999/api/v1/sessions` has `data` wrapper (not bare array).
**Warning signs:** Bare JSON arrays instead of `{"data": [...]}` wrapper, snake_case field names instead of camelCase.

### Pitfall 5: Admin-Protected Endpoints Return 403

**What goes wrong:** cURL to `/api/v1/config`, `/api/v1/system/*`, `/api/v1/fleet/*`, `/api/v1/tunnel/*`, `/api/v1/data/all` returns 403.
**Why it happens:** These routes are behind `AdminMiddleware` (added in Phase 46). They require `X-Admin-Token` header when `ILS_ADMIN_KEY` env var is set.
**How to avoid:** Either run backend without `ILS_ADMIN_KEY` set (disables admin auth), or pass the matching `X-Admin-Token` header in cURL. Document which routes require admin.
**Warning signs:** 403 Forbidden on routes that worked before Phase 46.

### Pitfall 6: Deep Links Show System Dialog

**What goes wrong:** `xcrun simctl openurl` shows "Open in ILSApp?" confirmation instead of navigating.
**Why it happens:** App was freshly installed but never launched -- iOS requires at least one launch before honoring URL schemes silently.
**How to avoid:** Always `xcrun simctl launch {UDID} com.ils.app` and wait 5 seconds before using deep links.
**Warning signs:** Screenshot shows system alert dialog overlay instead of the target screen.

### Pitfall 7: Screenshots Show Loading State Instead of Data

**What goes wrong:** Captured screenshot shows skeleton/shimmer loading state, not real data.
**Why it happens:** Deep link navigation + immediate screenshot is too fast; SwiftUI needs 1-3 seconds to fetch from backend.
**How to avoid:** `sleep 3` after deep link before screenshot. For data-heavy screens (Home with stats, Browser with 1000+ items), use `sleep 5`.
**Warning signs:** Shimmer effects, "Loading..." text, or empty card placeholders visible in captured screenshot.

### Pitfall 8: Forgetting New Screens from Phases 43-47

**What goes wrong:** Audit only covers the 13 screens from v3.5 PASS criteria, missing new UI elements.
**Why it happens:** Phases 43-47 added Quick Actions (HomeView), Quick Settings (Settings), rate limit countdown, TipKit tips, cache freshness indicators, GDPR deletion UI, MeshGradient editor, etc.
**How to avoid:** Audit checklist must include ALL v4.0 additions: Quick Actions grid on Home, Quick Settings toggles in Settings, GitHub search section in Browser, session overflow menu in Chat, "Last updated" indicators, GDPR "Delete All Data" in Settings, MeshGradient section in Theme Editor.
**Warning signs:** High PASS rate on all screens but missing verification of v4.0-specific features.

## Complete Screen Inventory (AUDIT-01 / AUDIT-02)

23 screens requiring visual verification on both iPhone and iPad:

| # | Screen | Deep Link | Source File | iPhone Evidence (v3.5) | iPad Evidence (v3.5) | v4.0 New Elements |
|---|--------|-----------|-------------|----------------------|---------------------|-------------------|
| 01 | Home / Dashboard | `ils://home` | `Views/Home/HomeView.swift` | Yes | Setup only | Quick Actions grid (UI-01) |
| 02 | Sessions List | `ils://sessions` | `Views/Root/SidebarView.swift` | Yes | No | -- |
| 03 | Chat View | `ils://sessions/{uuid}` | `Views/Chat/ChatView.swift` | Yes | No | Session overflow menu (UI-04) |
| 04 | Browser: MCP | `ils://mcp` | `Views/Browser/BrowserView.swift` | Yes | No | -- |
| 05 | Browser: Skills | `ils://skills` | `Views/Browser/BrowserView.swift` | Yes | No | GitHub search section (UI-03) |
| 06 | Browser: Plugins | `ils://plugins` | `Views/Browser/BrowserView.swift` | Yes | No | -- |
| 07 | System Monitor | `ils://system` | `Views/System/SystemMonitorView.swift` | Yes | No | -- |
| 08 | Settings | `ils://settings` | `Views/Settings/SettingsView.swift` | Yes | No | Quick Settings (UI-02), GDPR delete, cellular data pref |
| 09 | Host Profiles / Fleet | `ils://fleet` | `Views/Fleet/HostProfilesView.swift` | Yes | No | -- |
| 10 | Agent Teams | `ils://teams` | `Views/Teams/AgentTeamsListView.swift` | Yes | No | -- |
| 11 | Themes | `ils://themes` | `Views/Themes/ThemesListView.swift` | Yes | No | MeshGradient (ECO-03) |
| 12 | Hooks | `ils://hooks` | `Views/Hooks/HooksManagementView.swift` | Yes | No | -- |
| 13 | Sidebar | Swipe from left edge | `Views/Root/SidebarView.swift` | Yes | No | -- |
| 14 | New Session | In-app modal | `Views/Sessions/NewSessionView.swift` | Code-verified | No | -- |
| 15 | Session Info | In-app navigation | `Views/Sessions/SessionInfoView.swift` | Code-verified | No | -- |
| 16 | Command Palette | In-app modal | `Views/Chat/CommandPaletteView.swift` | Code-verified | No | -- |
| 17 | Config Editor | In-app navigation | `Views/Settings/ConfigEditorView.swift` | Code-verified | No | -- |
| 18 | Theme Editor | In-app navigation | `Views/Themes/ThemeEditorView.swift` | Code-verified | No | MeshGradient section (ECO-03) |
| 19 | Onboarding | First launch | `Views/Onboarding/OnboardingView.swift` | Code-verified | No | -- |
| 20 | Tunnel Settings | In-app navigation | `Views/Settings/TunnelSettingsView.swift` | Code-verified | No | -- |
| 21 | Log Viewer | In-app navigation | `Views/Settings/LogViewerView.swift` | Code-verified | No | -- |
| 22 | Skill Detail | In-app navigation | `Views/Browser/SkillDetailView.swift` | Code-verified | No | -- |
| 23 | MCP Server Detail | In-app navigation | `Views/Browser/MCPServerDetailView.swift` | Code-verified | No | -- |

**Minimum for AUDIT-01:** 20+ numbered artifacts. With 23 screens x 2 devices = 46 potential screenshots. Prioritize deep-linkable screens (01-13) on both devices = 26, plus key in-app screens (14-18) on iPhone = 31 total.

## Complete Backend Endpoint Registry (AUDIT-03)

15 controllers, 70+ endpoints. Grouped by access level:

### Public Routes (API key only)

| # | Method | Path | Controller | Expected Response |
|---|--------|------|------------|-------------------|
| 1 | GET | `/health` | HealthController | `{status, database, uptime}` |
| 2 | GET | `/health/ready` | HealthController | `{ready: bool}` |
| 3 | GET | `/health/live` | HealthController | `{live: bool}` |
| 4 | GET | `/api/v1/sessions` | SessionsController | `{data: [Session]}` |
| 5 | GET | `/api/v1/sessions/projects` | SessionsController | `{data: [ProjectGroup]}` |
| 6 | POST | `/api/v1/sessions` | SessionsController | `{data: Session}` |
| 7 | GET | `/api/v1/sessions/scan` | SessionsController | `{data: ...}` |
| 8 | GET | `/api/v1/sessions/search?q=` | SessionsController | `{data: [Session]}` |
| 9 | GET | `/api/v1/sessions/:id` | SessionsController | `{data: Session}` |
| 10 | PUT | `/api/v1/sessions/:id` | SessionsController | `{data: Session}` |
| 11 | DELETE | `/api/v1/sessions/:id` | SessionsController | `{data: ...}` |
| 12 | POST | `/api/v1/sessions/bulk-delete` | SessionsController | `{data: ...}` |
| 13 | POST | `/api/v1/sessions/:id/fork` | SessionsController | `{data: Session}` |
| 14 | GET | `/api/v1/sessions/:id/messages` | SessionsController | `{data: [Message]}` |
| 15 | GET | `/api/v1/sessions/:id/messages/search?q=` | SessionsController | `{data: [Message]}` |
| 16 | GET | `/api/v1/sessions/:id/export` | SessionsController | `{data: ExportData}` |
| 17 | GET | `/api/v1/sessions/transcript/:path/:id` | SessionsController | `{data: ...}` |
| 18 | GET | `/api/v1/projects` | ProjectsController | `{data: [Project]}` |
| 19 | POST | `/api/v1/projects` | ProjectsController | `{data: Project}` |
| 20 | POST | `/api/v1/projects/bulk-delete` | ProjectsController | `{data: ...}` |
| 21 | GET | `/api/v1/projects/:id` | ProjectsController | `{data: Project}` |
| 22 | PUT | `/api/v1/projects/:id` | ProjectsController | `{data: Project}` |
| 23 | DELETE | `/api/v1/projects/:id` | ProjectsController | `{data: ...}` |
| 24 | GET | `/api/v1/projects/:id/sessions` | ProjectsController | `{data: [Session]}` |
| 25 | POST | `/api/v1/chat/stream` | ChatController | SSE stream |
| 26 | POST | `/api/v1/chat/permission/:sessionId/:requestId` | ChatController | `{data: ...}` |
| 27 | POST | `/api/v1/chat/cancel/:sessionId` | ChatController | `{data: ...}` |
| 28 | GET | `/api/v1/skills` | SkillsController | `{data: [Skill]}` |
| 29 | GET | `/api/v1/skills/search?q=` | SkillsController | `{data: [GitHubSearchResult]}` |
| 30 | POST | `/api/v1/skills` | SkillsController | `{data: Skill}` |
| 31 | POST | `/api/v1/skills/install` | SkillsController | `{data: Skill}` |
| 32 | GET | `/api/v1/skills/:name` | SkillsController | `{data: Skill}` |
| 33 | PUT | `/api/v1/skills/:name` | SkillsController | `{data: Skill}` |
| 34 | DELETE | `/api/v1/skills/:name` | SkillsController | `{data: ...}` |
| 35 | POST | `/api/v1/skills/:name/enable` | SkillsController | `{data: Skill}` |
| 36 | POST | `/api/v1/skills/:name/disable` | SkillsController | `{data: Skill}` |
| 37 | GET | `/api/v1/mcp` | MCPController | `{data: [MCPServer]}` |
| 38 | POST | `/api/v1/mcp` | MCPController | `{data: MCPServer}` |
| 39 | GET | `/api/v1/mcp/:name` | MCPController | `{data: MCPServer}` |
| 40 | PUT | `/api/v1/mcp/:name` | MCPController | `{data: MCPServer}` |
| 41 | DELETE | `/api/v1/mcp/:name` | MCPController | `{data: ...}` |
| 42 | GET | `/api/v1/mcp/:name/health` | MCPController | `{data: HealthStatus}` |
| 43 | POST | `/api/v1/mcp/:name/restart` | MCPController | `{data: ...}` |
| 44 | GET | `/api/v1/mcp/:name/logs` | MCPController | `{data: [LogEntry]}` |
| 45 | GET | `/api/v1/plugins` | PluginsController | `{data: [Plugin]}` |
| 46 | GET | `/api/v1/plugins/search?q=` | PluginsController | `{data: [Plugin]}` |
| 47 | GET | `/api/v1/plugins/github-search?q=` | PluginsController | `{data: [GitHubSearchResult]}` |
| 48 | GET | `/api/v1/plugins/marketplace` | PluginsController | `{data: ...}` |
| 49 | POST | `/api/v1/plugins/marketplaces` | PluginsController | `{data: ...}` |
| 50 | POST | `/api/v1/plugins/install` | PluginsController | `{data: Plugin}` |
| 51 | POST | `/api/v1/plugins/:name/enable` | PluginsController | `{data: Plugin}` |
| 52 | POST | `/api/v1/plugins/:name/disable` | PluginsController | `{data: Plugin}` |
| 53 | DELETE | `/api/v1/plugins/:name` | PluginsController | `{data: ...}` |
| 54 | GET | `/api/v1/plugins/:name/check-update` | PluginsController | `{data: UpdateInfo}` |
| 55 | GET | `/api/v1/stats` | StatsController | `{data: DashboardStats}` |
| 56 | GET | `/api/v1/stats/recent` | StatsController | `{data: [Session]}` |
| 57 | GET | `/api/v1/settings` | StatsController | `{data: Settings}` |
| 58 | GET | `/api/v1/server/status` | StatsController | `{data: ServerStatus}` |
| 59 | GET | `/api/v1/themes` | ThemesController | `{data: [Theme]}` |
| 60 | POST | `/api/v1/themes` | ThemesController | `{data: Theme}` |
| 61 | GET | `/api/v1/themes/:id` | ThemesController | `{data: Theme}` |
| 62 | PUT | `/api/v1/themes/:id` | ThemesController | `{data: Theme}` |
| 63 | DELETE | `/api/v1/themes/:id` | ThemesController | `{data: ...}` |
| 64 | GET | `/api/v1/teams` | TeamsController | `{data: [Team]}` |
| 65 | POST | `/api/v1/teams` | TeamsController | `{data: Team}` |
| 66 | GET | `/api/v1/teams/:name` | TeamsController | `{data: Team}` |
| 67 | DELETE | `/api/v1/teams/:name` | TeamsController | `{data: ...}` |
| 68 | POST | `/api/v1/teams/:name/spawn` | TeamsController | `{data: ...}` |
| 69 | POST | `/api/v1/teams/:name/shutdown` | TeamsController | `{data: ...}` |
| 70 | GET | `/api/v1/teams/:name/tasks` | TeamsController | `{data: [Task]}` |
| 71 | POST | `/api/v1/teams/:name/tasks` | TeamsController | `{data: Task}` |
| 72 | PUT | `/api/v1/teams/:name/tasks/:taskId` | TeamsController | `{data: Task}` |
| 73 | GET | `/api/v1/teams/:name/messages` | TeamsController | `{data: [Message]}` |
| 74 | POST | `/api/v1/teams/:name/messages` | TeamsController | `{data: ...}` |
| 75 | DELETE | `/api/v1/teams/:name/members/:memberName` | TeamsController | `{data: ...}` |

### Admin-Protected Routes (require X-Admin-Token)

| # | Method | Path | Controller | Expected Response |
|---|--------|------|------------|-------------------|
| 76 | GET | `/api/v1/config` | ConfigController | `{data: Config}` |
| 77 | PUT | `/api/v1/config` | ConfigController | `{data: Config}` |
| 78 | POST | `/api/v1/config/validate` | ConfigController | `{data: ValidationResult}` |
| 79 | GET | `/api/v1/system/metrics` | SystemController | `{data: SystemMetrics}` |
| 80 | GET | `/api/v1/system/processes` | SystemController | `{data: [Process]}` |
| 81 | GET | `/api/v1/system/files` | SystemController | `{data: [FileEntry]}` |
| 82 | GET | `/api/v1/system/metrics/source` | SystemController | `{data: ...}` |
| 83 | GET | `/api/v1/fleet` | FleetController | `{data: [FleetHost]}` |
| 84 | POST | `/api/v1/fleet/register` | FleetController | `{data: FleetHost}` |
| 85 | POST | `/api/v1/fleet/:id/activate` | FleetController | `{data: FleetHost}` |
| 86 | DELETE | `/api/v1/fleet/:id` | FleetController | `{data: ...}` |
| 87 | GET | `/api/v1/fleet/:id/health` | FleetController | `{data: HealthStatus}` |
| 88 | POST | `/api/v1/tunnel/start` | TunnelController | `{data: TunnelStatus}` |
| 89 | POST | `/api/v1/tunnel/stop` | TunnelController | `{data: ...}` |
| 90 | GET | `/api/v1/tunnel/status` | TunnelController | `{data: TunnelStatus}` |
| 91 | DELETE | `/api/v1/data/all` | DataErasureController | `{data: ErasureResult}` |

**Total: 91 endpoints across 15 controllers + health.**
**Minimum for AUDIT-03:** cURL every GET endpoint (at least 50+), test representative POST/PUT/DELETE for mutation verification.

## Integration Flow Pairs (AUDIT-04)

Minimum correlated evidence pairs:

| # | Flow | Backend Step | Frontend Step | Proves |
|---|------|-------------|---------------|--------|
| 1 | Stats -> Dashboard | `GET /api/v1/stats` | iPhone Home screenshot | Stat counts match dashboard cards |
| 2 | Sessions -> List | `GET /api/v1/sessions` | iPhone sessions via sidebar | Session count/names match |
| 3 | Session -> Chat | `GET /api/v1/sessions/:id/messages` | iPhone chat deep link | Messages visible in chat match API |
| 4 | Skills -> Browser | `GET /api/v1/skills` | iPhone skills browser tab | Skill count matches |
| 5 | MCP -> Browser | `GET /api/v1/mcp` | iPhone MCP browser tab | Server count/names match |
| 6 | Plugins -> Browser | `GET /api/v1/plugins` | iPhone plugins browser tab | Plugin count matches |
| 7 | System -> Monitor | `GET /api/v1/system/metrics` | iPhone system monitor | CPU/Memory values correlate |
| 8 | Fleet -> Profiles | `GET /api/v1/fleet` | iPhone fleet screen | Host list matches |
| 9 | Config -> Settings | `GET /api/v1/config` | iPhone settings screen | Config values reflect in UI |
| 10 | Themes -> List | `GET /api/v1/themes` | iPhone themes screen | Theme count matches |

## Edge Case Categories (AUDIT-05)

| Category | Test Cases | Evidence Type |
|----------|-----------|---------------|
| **Empty states** | New install with no sessions; backend with empty database; search with no results | Screenshots of empty state UI |
| **Offline mode** | Kill backend, verify offline indicators; check cached data still displays | Screenshots of offline UI + "Last updated" indicators |
| **Accessibility** | VoiceOver on (via `xcrun simctl` accessibility), Dynamic Type at largest size | `idb_describe` tree dump + screenshots |
| **Memory** | Navigate all screens, check for leaks via `leaks` command | `leaks` output text + vmmap summary |
| **Error states** | Malformed deep links, invalid session UUIDs, network timeout | Screenshots of error handling UI |
| **Boundary values** | Very long session names, special characters in search, rapid navigation | Screenshots or crash log absence |
| **iPad layout** | All screens verified for persistent sidebar, no compact-layout fallback | iPad screenshots showing NavigationSplitView |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `xcrun simctl io screenshot` | `screencapture -l <windowID>` | v3.5 Phase 40 (2026-02-25) | Workaround for error 60; captures with device bezel |
| Manual screen-by-screen verification | Deep link pipeline + numbered screenshots | v3.5 Phase 40-41 | Automated, repeatable, 23 screens in minutes |
| Backend verification via browser | cURL + python3 JSON validation | v3.5 Phase 42 (planned) | Machine-parseable evidence |
| Global API key auth | Admin vs public route distinction | v4.0 Phase 46 (2026-02-27) | Admin routes need X-Admin-Token header |

## Open Questions

1. **Admin token for cURL audit**
   - What we know: AdminMiddleware protects config, system, fleet, tunnel, data-erasure routes. When `ILS_ADMIN_KEY` env var is set, requests need `X-Admin-Token` header.
   - What's unclear: What token value is configured in the current backend instance? Is `ILS_ADMIN_KEY` currently set?
   - Recommendation: Check if `ILS_ADMIN_KEY` is set in the running backend. If not set, AdminMiddleware likely passes all requests through (no-op). If set, either use the matching token or restart backend without it for audit purposes.

2. **iPad Simulator window sizing**
   - What we know: iPad Pro 13 should show regular-width NavigationSplitView. v3.5 noted that resized Simulator windows can trigger compact layout.
   - What's unclear: Whether iPad Simulator window will be correctly sized after boot.
   - Recommendation: After booting iPad, open Simulator.app and verify window shows landscape-capable iPad layout. Use Window > Physical Size if needed.

3. **Chat streaming E2E**
   - What we know: Chat requires Claude CLI subprocess, which needs env var stripping (CLAUDECODE=1 removal). This was fixed in Phase 46 but is an environment constraint.
   - What's unclear: Whether chat streaming will work in the current environment (active Claude Code session).
   - Recommendation: For AUDIT-02/04, verify existing messages load correctly (read-only). Mark chat sending as "environment-constrained" if subprocess spawning fails due to nesting detection.

## Recommended Plan Structure

Based on the 5 requirements, recommended plan decomposition:

| Plan | Focus | Requirements | Est. Tasks | Key Challenge |
|------|-------|-------------|-----------|---------------|
| **48-01** | Environment setup + iPhone visual audit | AUDIT-01 (iPhone half), AUDIT-02 (iPhone half) | 3-4 | Boot backend, fresh build, 23 iPhone screenshots with v4.0 element verification |
| **48-02** | iPad visual audit | AUDIT-01 (iPad half), AUDIT-02 (iPad half) | 3-4 | Boot iPad sim, install app, 23 iPad screenshots, NavigationSplitView verification |
| **48-03** | Backend endpoint cURL audit | AUDIT-03 | 3-4 | 91 endpoints, JSON validation, admin token handling, summary document |
| **48-04** | Integration correlation evidence | AUDIT-04 | 2-3 | 10 backend+frontend pairs with visual correlation proofs |
| **48-05** | Proactive bug hunt + final gate | AUDIT-05 | 3-4 | Edge cases (offline, empty, accessibility, memory), gate verdict |

**Total: ~15-19 tasks across 5 plans.** Plans 01-03 can run in parallel. Plan 04 depends on 01 + 03. Plan 05 depends on 01 + 02.

## Sources

### Primary (HIGH confidence)

- **Gap analysis:** `.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md` (673 lines) -- comprehensive codebase audit, all 3 specs
- **PASS criteria:** `.planning/phases/40-environment-setup-screen-inventory/PASS-CRITERIA.md` -- per-screen verification checklist from v3.5
- **Routes.swift:** `Sources/ILSBackend/App/routes.swift` -- complete controller registration, admin vs public split
- **Controller route definitions:** Grep of all `.get()/.post()/.put()/.delete()` calls across 15 controllers
- **SidebarRootView.swift ActiveScreen enum:** 9 cases (home, chat, system, settings, browser, teams, hostProfiles, themes, hooks)
- **Prior phase plans:** `.planning/phases/40-*/40-01-PLAN.md` -- environment setup methodology, screenshot workarounds
- **Prior phase summaries:** `.planning/phases/40-*/40-01-SUMMARY.md` -- confirmed simctl io failure and screencapture workaround

### Secondary (MEDIUM confidence)

- **v3.5 evidence directory:** `/tmp/v3.5-evidence/iphone/` -- 25+ existing iPhone screenshots (confirm format and naming)
- **Simulator status:** Live check confirmed iPhone booted, iPad shutdown as expected

### Tertiary (LOW confidence)

- None. All findings verified against actual codebase and prior phase artifacts.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools are macOS built-ins or established project tooling, verified working in prior phases
- Architecture: HIGH - evidence directory structure and capture patterns are direct extensions of v3.5 Phase 40 methodology
- Pitfalls: HIGH - all 8 pitfalls are documented from actual prior-phase failures with confirmed workarounds
- Endpoint registry: HIGH - extracted directly from source code via grep, cross-referenced with routes.swift

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable -- no external dependencies, all tools are OS-level)
