# Phase 56: Functional Audit & Bug Hunt - Research

**Researched:** 2026-02-28
**Domain:** End-to-end feature verification, edge case testing, cross-platform functional validation
**Confidence:** HIGH

## Summary

Phase 56 is the final phase of the v5.0 milestone. It validates that every feature area implemented in Phases 49-54 works end-to-end across platforms (iPhone, iPad, macOS), and systematically tests 20+ edge case scenarios. This is a pure verification phase -- the primary output is evidence artifacts (screenshots, curl output, logs) and bug fixes for any CRITICAL issues found.

The app has 13 top-level screens routed via `ActiveScreen` enum, navigable through deep links (`ils://`). The backend runs on port 9999 with 16 controllers serving real data (22,432 sessions, 964 skills, 16 MCP servers). Key features to verify: config inheritance badges (`InheritanceBadge` in `SettingsConfigSection.swift`), hooks CRUD (16 event types, 4 handler types), host profile switching with confirmation banner, GitHub browse/install for skills and plugins, and real-time system metrics via WebSocket.

Phase 55 already captured 30 visual screenshots (15 iPhone, 15 iPad) confirming layout correctness. Phase 56 goes deeper: does the data flow work? Do mutations persist? Do edge cases crash or degrade gracefully? The verification approach is functional validation -- running the real app against the real backend and documenting behavior with evidence.

**Primary recommendation:** Structure the audit into two plans: (1) feature-area functional verification across platforms (data flows, CRUD, config inheritance, persistence), and (2) edge case bug hunt (offline, empty states, rapid navigation, accessibility, memory pressure, large data, malformed API responses). Fix CRITICAL bugs inline during execution.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GATE-04 | Functional audit -- end-to-end verification of all feature areas across platforms | 13 screens identified via `ActiveScreen` enum. Each has a ViewModel with `loadX()` methods hitting `/api/v1/*` endpoints. Verification: navigate to each screen, confirm real data loads, perform CRUD operations where applicable, verify persistence after navigation and app restart. Cross-platform: same flows on iPhone (compact), iPad (split view), macOS (3-column). |
| GATE-05 | Bug hunt -- >=20 edge case scenarios tested (offline, empty states, accessibility, memory) | 24 concrete edge case scenarios identified (see Edge Case Inventory below). Each scenario has a trigger method, expected behavior, and evidence capture approach. NetworkMonitor provides offline detection; OfflineIndicator renders cached-data banner. Accessibility: 138 `accessibilityLabel` occurrences across 39 view files. Memory: NSCache in APIClient with TTL-based eviction. |
</phase_requirements>

## Standard Stack

### Core Tools

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `xcrun simctl openurl` | Xcode 16+ | Deep-link navigation on simulators | Triggers `ils://` URL handler deterministically |
| `xcrun simctl io screenshot` | Xcode 16+ | Evidence capture on simulators | Apple's official simulator screenshot API |
| `curl` | System | Backend API verification | Direct HTTP testing of all `/api/v1/*` endpoints |
| `idb_describe` | idb companion | Accessibility tree inspection | Gets exact element coordinates for VoiceOver testing |
| `xcrun simctl status_bar` | Xcode 16+ | Override status bar for clean screenshots | Consistent evidence artifacts |
| `lsof` | System | Backend process verification | Confirms correct binary on port 9999 |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `python3 -c "import json..."` | Parse curl JSON output | Verify API response structures and data counts |
| `xcrun simctl privacy` | Toggle permissions | Test permission-denied states |
| `open ils://...` | macOS deep link navigation | Navigate macOS app to specific screens |
| `screencapture -l` | macOS window capture | Evidence for macOS functional verification |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| curl for API testing | Swift test target | curl is simpler, no build dependency, matches project rules (no test frameworks) |
| idb_tap for interactions | XCTest UI tests | Project rules prohibit test frameworks; idb_tap is adequate for functional taps |
| Manual edge case testing | Automated scripts | Scripts are reproducible, but some edge cases (VoiceOver, memory pressure) require manual triggers + screenshot evidence |

## Architecture Patterns

### Evidence Directory Structure

```
evidence/phase-56-functional-audit/
├── feature-verification/
│   ├── 01-sessions-load.png
│   ├── 02-chat-opens.png
│   ├── 03-browser-skills.png
│   ├── 04-browser-plugins.png
│   ├── 05-browser-mcp.png
│   ├── 06-browser-discover.png
│   ├── 07-settings-badges.png
│   ├── 08-config-inheritance-curl.txt
│   ├── 09-config-cli-comparison.txt
│   ├── 10-host-profile-switch.png
│   ├── 11-hooks-create.png
│   ├── 12-hooks-edit.png
│   ├── 13-hooks-delete.png
│   ├── 14-system-monitor-live.png
│   ├── 15-github-browse.png
│   └── (16+ additional screens and flows)
├── edge-cases/
│   ├── EC-01-offline-banner.png
│   ├── EC-02-empty-state-hooks.png
│   ├── EC-03-rapid-nav.png
│   ├── ...
│   └── EC-24-malformed-api.txt
├── cross-platform/
│   ├── ipad-settings-badges.png
│   ├── mac-settings-badges.png
│   ├── ipad-hooks-crud.png
│   └── mac-hooks-crud.png
└── bugs-found/
    ├── BUG-001-description.md
    └── BUG-001-fix-evidence.png
```

### Pattern 1: Feature Area Verification Flow

**What:** For each feature area, navigate to the screen, verify data loads from backend, perform mutations (if applicable), verify persistence, and capture evidence.
**When to use:** Every feature area in the app.
**Example:**

```bash
# 1. Verify backend returns real data
curl -s http://localhost:9999/api/v1/sessions | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(f'Sessions: {len(d.get(\"data\",[]))} total')
print(f'First: {d[\"data\"][0][\"name\"] if d.get(\"data\") else \"none\"}')"

# 2. Navigate app to screen
UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
xcrun simctl openurl "$UDID" "ils://sessions"
sleep 2

# 3. Capture evidence
xcrun simctl io "$UDID" screenshot evidence/phase-56-functional-audit/feature-verification/01-sessions-load.png

# 4. Verify data matches (compare curl count to on-screen count)
```

### Pattern 2: Config Inheritance Badge Verification

**What:** Compare `GET /config/effective` API response with `claude config show` CLI output. Verify badges in app UI match the winning scope from the API.
**When to use:** Settings screen config badge verification (Success Criterion #2).
**Example:**

```bash
# 1. Get effective config from backend
curl -s http://localhost:9999/api/v1/config/effective | python3 -c "
import json,sys; d=json.load(sys.stdin)
for override in d.get('data',{}).get('overrides',[]):
    print(f'{override[\"key\"]}: scope={override[\"winningScope\"]}, value={override[\"winningValue\"]}')
"

# 2. Get CLI config for comparison
claude config show 2>/dev/null || echo 'CLI not available in this context'

# 3. Navigate to Settings and screenshot the badges
xcrun simctl openurl "$UDID" "ils://settings"
sleep 2
xcrun simctl io "$UDID" screenshot evidence/phase-56-functional-audit/feature-verification/07-settings-badges.png

# 4. Compare: for each key where winningScope != "user", UI should show "Host Default" badge
# For keys where winningScope == "user", UI should show "Custom" badge
```

### Pattern 3: CRUD Verification (Hooks)

**What:** Create a hook, verify it appears, edit it, verify the edit persists, delete it, verify deletion. All via the app UI with backend API cross-checks.
**When to use:** Hooks management (SKILL-05, SKILL-06).
**Example:**

```bash
# 1. Check current hooks count
curl -s http://localhost:9999/api/v1/config?scope=user | python3 -c "
import json,sys; d=json.load(sys.stdin)
hooks = d.get('data',{}).get('content',{}).get('hooks',{})
total = sum(len(v) for v in hooks.get('events',{}).values() if isinstance(v, list))
print(f'Current hooks: {total}')
"

# 2. Navigate to Hooks screen
xcrun simctl openurl "$UDID" "ils://hooks"
sleep 2

# 3. Use idb_tap to create a new hook (tap + button)
# Capture before/after screenshots as evidence

# 4. Verify via API that hook count increased
```

### Pattern 4: Edge Case Triggering

**What:** Systematically trigger edge conditions and document behavior.
**When to use:** Each of the 20+ edge case scenarios.
**Example (offline mode):**

```bash
# 1. Capture app in connected state
xcrun simctl io "$UDID" screenshot evidence/phase-56-functional-audit/edge-cases/EC-01a-connected.png

# 2. Kill backend to simulate offline
pkill -f "ILSBackend" || true
sleep 3

# 3. Navigate to a data screen
xcrun simctl openurl "$UDID" "ils://home"
sleep 2

# 4. Capture evidence of offline indicator
xcrun simctl io "$UDID" screenshot evidence/phase-56-functional-audit/edge-cases/EC-01b-offline-banner.png

# 5. Restart backend
cd /Users/nick/Desktop/ils-ios && PORT=9999 swift run ILSBackend &
sleep 5

# 6. Capture evidence of reconnection
xcrun simctl io "$UDID" screenshot evidence/phase-56-functional-audit/edge-cases/EC-01c-reconnected.png
```

### Anti-Patterns to Avoid

- **Claiming PASS without evidence:** Every verification must produce a screenshot or curl output artifact. No "I verified it works" without a file in `evidence/`.
- **Testing only the happy path:** The bug hunt requires adversarial edge cases -- not just "does it work when everything is perfect."
- **Fixing bugs without re-verifying:** After fixing a CRITICAL bug, re-run the verification that found it and capture new evidence showing the fix.
- **Skipping cross-platform:** A feature that works on iPhone but crashes on iPad is still a bug. Config badges, hooks CRUD, and profile switching must be verified on at least 2 platforms.
- **Running stale app binary:** Always build fresh and install before starting verification.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API response verification | Custom Swift test harness | `curl` + `python3 -c` JSON parsing | No test framework, reproducible, immediate |
| UI element interaction | XCTest UI automation | `idb_describe` + `idb_tap` | Project rules prohibit test frameworks |
| Accessibility verification | Custom accessibility scanner | VoiceOver on simulator + `idb_describe operation:all` | Real screen reader testing > synthetic checks |
| Network condition simulation | Charles proxy or Network Link Conditioner | Kill/restart backend process | Simpler, deterministic, no external tools |
| Memory pressure testing | Custom memory allocation code | Xcode Instruments Allocations or `xcrun simctl memory` | Standard Apple diagnostic tools |
| Config comparison | Custom diff script | Side-by-side curl output + screenshot | Human-readable evidence for audit |

**Key insight:** This phase uses the real app against the real backend. The verification toolchain is `curl` + `xcrun simctl` + `idb` -- no custom code needed. Bug fixes (if CRITICAL issues are found) are the only code changes.

## Feature Area Inventory

Each feature area below must be functionally verified end-to-end:

### 1. Sessions & Chat

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Sessions list loads with real data | Deep link `ils://home` + screenshot | Screenshot showing session count |
| Chat opens for a real session | Deep link `ils://sessions/{uuid}` | Screenshot showing Claude messages |
| Session metadata visible (model, status, timestamps) | Inspect chat view details | Screenshot |
| Pull-to-refresh updates session list | Use `.refreshable` gesture or re-navigate | Screenshot showing updated data |

### 2. Browser (MCP, Skills, Plugins, Discover)

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| MCP servers list with status | Deep link `ils://mcp` | Screenshot with server names + health |
| Skills list loads | Deep link `ils://skills` | Screenshot with skill count |
| Plugins list loads | Deep link `ils://plugins` | Screenshot with plugin count |
| Discover tab shows GitHub search | Navigate to Browser, switch to Discover tab | Screenshot of search UI |
| Skill detail view opens | Tap a skill item | Screenshot of detail |
| GitHub preview loads README | Search and tap a result in Discover | Screenshot of preview + install button |

### 3. Settings & Config Inheritance

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Settings loads config from backend | Deep link `ils://settings` | Screenshot showing config values |
| `InheritanceBadge` shows "Host Default" for inherited keys | Compare with `/config/effective` API | Screenshot + curl output side-by-side |
| `InheritanceBadge` shows "Custom" for user-overridden keys | Toggle a setting, verify badge changes | Screenshot before/after |
| Info tooltips show explanatory text (20+ words) | Tap info icons | Screenshot of popover |
| Config persists after navigation away and back | Change setting, navigate away, return | Screenshot showing persisted value |
| Model picker shows inherited model from host | Verify with `/config/effective` | Screenshot + curl output |

### 4. Host Profiles

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Profiles list loads | Deep link `ils://host-profiles` | Screenshot showing profile list |
| Active host badge visible | Inspect profile list | Screenshot with "Active" indicator |
| Profile switch shows confirmation banner | Tap a non-active profile | Screenshot of banner + `lastActivatedHostName` |
| Settings context updates after switch | Switch profile, check Settings | Screenshot of settings after switch |

### 5. Hooks Management

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Hooks list loads grouped by event type | Deep link `ils://hooks` | Screenshot showing grouped hooks |
| All 16 event types available in create sheet | Open create hook sheet | Screenshot of event type picker |
| Create hook with command handler | Fill form, save | Screenshot + curl verification |
| Edit existing hook | Tap edit on a hook | Screenshot of edit sheet |
| Delete hook | Swipe-to-delete or tap delete | Screenshot + curl verification |
| 4 handler types available (command, prompt, agent, http) | Open create sheet | Screenshot of handler type picker |

### 6. System Monitor

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Real-time metrics display | Deep link `ils://system` | Screenshot showing CPU/memory/disk/network |
| Metrics update while screen visible | Wait 5-10 seconds, capture two screenshots | Two screenshots at different times showing different values |
| WebSocket connection active | Check `MetricsWebSocketClient` state | Log output or screenshot |

### 7. Themes

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| Theme list loads | Deep link `ils://themes` | Screenshot showing theme names |
| Theme editor opens | Tap a theme | Screenshot of editor form |
| Theme change applies globally | Select a different theme | Screenshot showing updated colors |

### 8. Deep Links

| Verification | Method | Evidence Type |
|-------------|--------|---------------|
| All registered deep links route correctly | Test each `ils://` URL | Log of all 12 deep link routes |
| `ils://fleet` backward compatibility | Navigate via old URL | Screenshot showing Host Profiles screen |
| `ils://sessions/{uuid}` with valid UUID | Navigate to real session | Screenshot of chat view |
| `ils://sessions/{uuid}` with invalid UUID | Navigate with fake UUID | Screenshot showing graceful fallback |

## Edge Case Inventory (24 Scenarios)

### Offline / Network (4 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-01 | Backend offline | Kill ILSBackend process | OfflineIndicator banner appears, cached data shown, no crash | Screenshot of offline banner |
| EC-02 | Backend reconnect | Restart ILSBackend after offline | Banner disappears, data refreshes automatically via `networkDidBecomeAvailable` notification | Screenshot of restored state |
| EC-03 | Slow backend response | Add artificial delay (not practical -- skip or test with large data set) | Loading indicators appear, no timeout crash | Screenshot of loading state |
| EC-04 | Backend returns HTTP 500 | Curl with invalid endpoint to verify error handling | Error state shown, no crash, retry possible | Screenshot of error state |

### Empty States (4 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-05 | No hooks configured | Delete all hooks from config | HooksManagementView shows `emptyState` view | Screenshot |
| EC-06 | No host profiles | Remove all registered profiles | HostProfilesView shows empty state | Screenshot |
| EC-07 | No teams | Ensure no active teams | AgentTeamsListView shows empty state | Screenshot |
| EC-08 | Empty search results in Discover | Search for gibberish string | GitHub search returns no results, graceful empty state | Screenshot |

### Rapid Navigation (3 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-09 | Rapid screen switching | Deep-link to 5+ screens in quick succession (< 1s each) | No crash, final screen renders correctly | Screenshot of final screen |
| EC-10 | Rapid sidebar open/close | Swipe sidebar open and closed repeatedly | No animation glitch, no crash | Screenshot or note |
| EC-11 | Navigate during data load | Switch screens while a ViewModel is still loading | Previous load cancelled (Task cancellation), new screen loads correctly | Screenshot |

### Accessibility (3 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-12 | VoiceOver on Home screen | Enable VoiceOver, navigate to Home | All elements have labels, Quick Actions are focusable, session count announced | `idb_describe` output |
| EC-13 | VoiceOver on Settings (badges) | Enable VoiceOver, navigate to Settings | InheritanceBadge readable as "Host Default" or "Custom", info buttons accessible | `idb_describe` output |
| EC-14 | Dynamic Type (largest size) | Set accessibility text size to maximum | Text does not clip or overlap, layouts remain usable | Screenshot at largest text size |

### Memory & Performance (3 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-15 | Large session list (22K+) | Navigate to Sessions -- backend has 22,432 sessions | List scrolls smoothly (LazyVStack), no excessive memory | Screenshot + note on scroll behavior |
| EC-16 | Cache eviction | Navigate across many screens (fills NSCache), then revisit | Cached data serves or refetches gracefully, no stale display | Screenshot |
| EC-17 | Low memory warning | Simulate memory pressure via Xcode Instruments or `xcrun simctl memory` | App does not crash, cache clears, UI remains functional | Screenshot or log |

### Data Integrity (4 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-18 | Config round-trip | Save a setting via Settings UI, reload, verify value matches | Value persists correctly through save-and-reload cycle | curl before/after |
| EC-19 | Hook create round-trip | Create hook, reload hooks list, verify hook present | Hook appears in list with correct event type and handler | Screenshot + curl |
| EC-20 | Profile activation persistence | Activate a profile, kill and relaunch app | Active profile persists (stored in UserDefaults) | Screenshot after relaunch |
| EC-21 | Deep link with lowercase UUID | Navigate to `ils://sessions/{lowercase-uuid}` | Session opens correctly (UUIDs are case-sensitive) | Screenshot |

### Malformed Input / Error Handling (3 scenarios)

| # | Scenario | Trigger | Expected Behavior | Evidence |
|---|----------|---------|-------------------|----------|
| EC-22 | Invalid deep link host | Open `ils://nonexistent` | No crash, app stays on current screen (default case in switch) | Screenshot showing no change |
| EC-23 | Backend returns malformed JSON | Difficult to trigger in practice -- verify error handling in APIClient | `DecodingError` caught, error state shown | Code review or curl with bad endpoint |
| EC-24 | Config PUT with invalid model | Via curl: send model="invalid-model" to `/config/validate` | Validation error returned, not 200-with-error | curl output showing error response |

## Common Pitfalls

### Pitfall 1: Backend Binary Mismatch

**What goes wrong:** Functional tests show wrong data or incorrect API response format.
**Why it happens:** Old backend at `/Users/nick/ils/ILSBackend/` returns raw arrays instead of `APIResponse` wrappers.
**How to avoid:** Pre-flight check: `lsof -i :9999 -P -n` must show a binary path containing `ils-ios/`. Kill any other backend first.
**Warning signs:** Raw JSON arrays without `data` wrapper, snake_case field names, HTTP 200 for everything.

### Pitfall 2: Stale Simulator Binary

**What goes wrong:** App shows UI from before Phases 49-54 changes (e.g., "Fleet" instead of "Host Profiles").
**Why it happens:** Old binary still installed on simulator from a previous session.
**How to avoid:** Build fresh and install before starting verification:
```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ILSApp.app" -path "*/Debug-iphonesimulator/*" | head -1)
xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP"
```
**Warning signs:** "Fleet" text visible, missing config badges, missing Discover tab.

### Pitfall 3: idb_tap Coordinate Drift

**What goes wrong:** Taps land on wrong UI elements because coordinates changed between app versions.
**Why it happens:** Layout changes from Phases 49-54 shifted element positions.
**How to avoid:** Always run `idb_describe operation:all` BEFORE tapping to get current accessibility tree coordinates. Never reuse coordinates from previous sessions.
**Warning signs:** Wrong sheet opens, nothing happens on tap, unexpected navigation.

### Pitfall 4: Config Badge Test Conflation

**What goes wrong:** All badges show "Host Default" because no user-scope overrides exist to compare against.
**Why it happens:** The effective config cascade falls through to user scope for everything when only user-scope config exists.
**How to avoid:** Before testing, ensure at least one setting has a user-scope override (save a model change via Settings) AND at least one setting comes from a different scope (or has no user value). This creates a mix of "Host Default" and "Custom" badges to verify.
**Warning signs:** Every badge shows the same type -- either all "Host Default" or all "Custom."

### Pitfall 5: Claiming Accessibility PASS Without Real VoiceOver

**What goes wrong:** Accessibility is "verified" by reading code, not by actually enabling VoiceOver.
**Why it happens:** VoiceOver testing is harder to automate than visual screenshots.
**How to avoid:** Use `idb_describe operation:all` to dump the accessibility tree and verify labels exist for interactive elements. For manual VoiceOver testing, enable it on the simulator via Settings > Accessibility.
**Warning signs:** Accessibility evidence is just "I see accessibilityLabel in the code" without runtime verification.

### Pitfall 6: Edge Cases Tested Only on iPhone

**What goes wrong:** Edge case passes on iPhone but crashes on iPad (different size class) or macOS (AppKit host).
**Why it happens:** iPad uses NavigationSplitView and macOS uses a completely different view hierarchy (MacContentView.swift).
**How to avoid:** Run critical edge cases (offline, rapid navigation, empty states) on at least iPhone + iPad. macOS is lower priority but config badges should be spot-checked.
**Warning signs:** All evidence is from a single simulator UDID.

## Cross-Platform Verification Strategy

| Platform | Simulator/App | Verification Scope | Priority |
|----------|---------------|-------------------|----------|
| iPhone 16 Pro Max | UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14` | Full feature verification + full edge case testing | PRIMARY |
| iPad Pro 13 | UDID: `C074375B-2CB2-4F95-A55C-972F2FF35041` | Feature verification (config badges, hooks, profiles) + key edge cases (offline, empty states) | SECONDARY |
| macOS (ILSMacApp) | `ILSMacApp` scheme, `platform=macOS` | Spot-check config badges, deep links, hooks list. Full verification only if Screen Recording permission available | TERTIARY (best-effort) |

### iOS/iPad Feature Differences

- **iPhone**: Compact width, overlay sidebar (ZStack), single-column navigation
- **iPad**: Regular width, NavigationSplitView with persistent sidebar, detail pane always visible
- **macOS**: 3-column NavigationSplitView, keyboard shortcuts (Cmd+1..4, Cmd+,), custom menu bar, `MacContentView` + `MacSettingsView` separate from iOS views

### Shared Code Paths (lower cross-platform risk)

- `AppState.handleURL()` -- same deep link handler for all platforms
- `SettingsViewModel`, `HooksViewModel`, `HostProfilesViewModel` -- shared ViewModels
- `APIClient` -- shared networking layer
- `SettingsConfigSection`, `InheritanceBadge` -- shared config badge UI

### Platform-Specific Code Paths (higher risk, need explicit verification)

- `MacContentView.swift` -- macOS sidebar, navigation, browser segment routing
- `MacSettingsView.swift` -- macOS settings (may or may not use `SettingsConfigSection`)
- `SidebarRootView.swift` (iOS) vs `MacContentView` (macOS) -- different navigation containers

## Config Inheritance Badge Verification Protocol

The config inheritance badge system is specifically called out in Success Criterion #2. Here is the precise verification protocol:

1. **Get effective config from API:**
   ```bash
   curl -s http://localhost:9999/api/v1/config/effective | python3 -c "
   import json,sys
   d=json.load(sys.stdin)
   for o in d.get('data',{}).get('overrides',[]):
       scope = o['winningScope']
       badge = 'Custom' if scope == 'user' else 'Host Default'
       print(f'  {o[\"key\"]}: winningScope={scope} -> expected badge: {badge}')
   "
   ```

2. **Get CLI config for comparison (if available):**
   ```bash
   claude config show --json 2>/dev/null || echo "CLI not in path"
   ```

3. **Navigate to Settings in app and capture badge screenshots.**

4. **Cross-reference:** For each key in the API overrides list, verify the corresponding badge in the UI matches. Save both the curl output and the screenshot as evidence artifacts.

5. **Verify "Custom" badge path:** Change a setting (e.g., toggle Extended Thinking), verify the badge updates from "Host Default" to "Custom" immediately (SettingsViewModel calls `loadEffectiveConfig(bypassCache: true)` after save).

## Hooks CRUD Verification Protocol

The hooks system supports all 16 Claude Code event types and 4 handler types. Verification protocol:

**16 Event Types** (from `HookEventTypeInfo` in `HooksViewModel.swift`):
PreToolUse, PostToolUse, Notification, Stop, SubagentStart, SubagentStop, SessionStart, SessionEnd, ToolError, ToolResult, ModelResponse, UserMessage, ContextExceeded, RateLimitError, TaskStart, TaskComplete

**4 Handler Types:** command, prompt, agent, http

**CRUD Flow:**
1. Verify hooks list loads (may be empty or populated from host config)
2. Tap "+" to open create sheet
3. Select an event type (e.g., PostToolUse)
4. Select handler type (e.g., command)
5. Enter handler value (e.g., `echo "hook fired"`)
6. Save -- verify hook appears in list AND in API response
7. Tap hook to edit -- change handler value
8. Save edit -- verify updated value in list AND API
9. Delete hook -- verify removal from list AND API
10. Verify remaining hooks are unaffected

## Open Questions

1. **macOS Screen Recording permission**
   - What we know: Phase 55 was unable to capture macOS screenshots due to Screen Recording permission being denied for the current process
   - What's unclear: Whether this has been resolved or if manual macOS screenshots are needed
   - Recommendation: Attempt automated macOS capture first. If blocked, capture manually for the 3-4 most critical functional verifications (config badges, hooks list, deep links). Document the constraint.

2. **GitHub Browse/Install functional test depth**
   - What we know: `GitHubPreviewView` and `BrowserView` Discover tab exist. `SkillsViewModel.fetchPreview()` calls the backend.
   - What's unclear: Whether GitHub API rate limits will block functional testing of search and install flows
   - Recommendation: Test with a single known-good repository (e.g., an official Claude Code skill). If rate-limited, document the rate limit error handling (which is itself an edge case verification).

3. **How to verify "20+ edge case scenarios" count**
   - What we know: 24 scenarios are identified in the Edge Case Inventory above
   - What's unclear: Whether all 24 are practically testable in a single verification session
   - Recommendation: Target all 24. If some are impractical (e.g., EC-03 slow backend, EC-17 low memory), document why they were skipped and replace with equivalent scenarios. The 20 minimum is achievable from the 24 candidates.

4. **Chat streaming E2E**
   - What we know: Chat requires Python SDK wrapper (`scripts/sdk-wrapper.py`) which spawns Claude CLI
   - What's unclear: Whether chat streaming works in the current session context (env var stripping for nesting detection was fixed in Phase 54)
   - Recommendation: Test chat by opening an existing session with messages (read-only verification). Sending new messages requires Claude CLI availability -- document if this constraint prevents full E2E chat verification.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- Direct reading of AppState.swift (deep link handler), SettingsConfigSection.swift (InheritanceBadge), HooksManagementView.swift (CRUD), HooksViewModel.swift (16 event types, save/delete), HostProfilesViewModel.swift (activate with banner), NetworkMonitor.swift (offline detection), OfflineIndicator.swift (banner UI), APIClient.swift (caching, error handling)
- **Phase 55 evidence** -- `evidence/phase-55-visual-audit/MANIFEST.md` (30 screenshots confirming visual layout)
- **Backend controllers** -- ConfigController.swift (GET /config/effective, PUT /config), ConfigFileService.swift (readEffectiveConfig merge logic with 4-scope cascade)
- **ILSShared DTOs** -- EffectiveConfig, ConfigOverride, ConfigScope, HostProfile, HookGroup structs define the data contracts

### Secondary (MEDIUM confidence)
- **Previous functional validation** -- MEMORY.md documents v3.5 functional validation (13/13 PASS, 30 evidence files). Same methodology applies to Phase 56 with expanded scope.
- **idb automation patterns** -- MEMORY.md documents successful idb_describe + idb_tap patterns for simulator interaction

## Metadata

**Confidence breakdown:**
- Feature area inventory: HIGH - All 8 feature areas identified from codebase analysis with specific ViewModels, Views, and API endpoints traced
- Edge case scenarios: HIGH - 24 concrete scenarios derived from actual code patterns (NetworkMonitor, NSCache, error handling, accessibility labels)
- Cross-platform strategy: HIGH - Platform differences documented from MacContentView.swift vs SidebarRootView.swift analysis
- Config badge protocol: HIGH - Complete trace from ConfigFileService.readEffectiveConfig() through EffectiveConfig DTO through SettingsViewModel.isInherited() to InheritanceBadge view

**Research date:** 2026-02-28
**Valid until:** 2026-03-14 (14 days -- verification phase, findings tied to current codebase state)
