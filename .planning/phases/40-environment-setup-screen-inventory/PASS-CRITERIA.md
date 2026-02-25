# PASS Criteria: v3.5 Comprehensive Functional Validation

**Date:** 2026-02-25
**Purpose:** Define exactly what success looks like for every screen on both iPhone and iPad. This is the reference document that Phase 41 and Phase 42 agents validate against.

**How to use:** For each screen, verify ALL numbered criteria. Mark PASS only if every criterion is met. Any single FAIL makes the screen FAIL.

**Simulators:**
- iPhone: 50523130-57AA-48B0-ABD0-4D59CE455F14 (iPhone 16 Pro Max, iOS 18.6)
- iPad: C074375B-2CB2-4F95-A55C-972F2FF35041 (iPad Pro 13, iOS 18.6)

---

## 01 - Home / Dashboard

**Deep link:** `ils://home`
**ActiveScreen case:** `.home`

### iPhone PASS Criteria

1. Stats cards visible showing counts > 0 for: Sessions, Skills, MCP Servers, Plugins
2. Quick Actions section visible with action buttons
3. Recent Sessions section visible with at least one session row
4. Sparkline charts render (not empty/missing) in stats cards
5. No loading spinners stuck on screen (data fully loaded)
6. Navigation bar title shows "Home" or app name
7. Pull-to-refresh gesture is functional (data reloads)

### iPad Additional Criteria

1. NavigationSplitView: persistent sidebar visible on left (~260-380pt width)
2. Home content fills the detail column without white bands or horizontal compression
3. Sidebar "Home" item is highlighted/selected with accent color
4. Stats cards layout adapts to wider detail column (not squished to iPhone width)

### Common FAIL Indicators

- Loading spinner stuck indefinitely
- Stats cards show 0 when backend has data
- Blank or white screen instead of dashboard content
- iPad shows hamburger button (compact/iPhone layout instead of split view)

---

## 02 - Sessions List

**Deep link:** `ils://sessions`
**ActiveScreen case:** `.home` (sessions section)

### iPhone PASS Criteria

1. Session rows visible with cleaned session names (not raw UUIDs, no `##` markdown prefixes)
2. Each row shows model tag (e.g., "claude-3.5-sonnet") and timestamp
3. Session count visible and > 0
4. Search bar present at top of the list
5. Tapping a session row navigates to chat view (screen 03)
6. Session rows are scrollable if list exceeds screen height

### iPad Additional Criteria

1. Sessions list renders in content area; detail column shows placeholder or selected session
2. Sidebar "Sessions" or equivalent navigation item is highlighted
3. Session list width is appropriate for split-view layout

### Common FAIL Indicators

- Session names show raw UUIDs instead of human-readable titles
- Model tags missing or showing "unknown"
- Empty list despite backend having 22,000+ sessions
- Search bar missing or non-functional

---

## 03 - Chat View

**Deep link:** `ils://sessions/{uuid}` (UUID must be lowercase)
**ActiveScreen case:** `.chat(session)`

### iPhone PASS Criteria

1. Real messages displayed (not placeholder text or empty bubbles)
2. Session title visible in navigation bar (cleaned, no `##` prefixes)
3. Back button present and functional (returns to sessions list)
4. No stuck loading spinner
5. Messages are properly formatted (markdown rendered, not raw markdown/JSON)
6. Message bubbles distinguish between user and assistant messages (different alignment or color)
7. Input area visible at bottom for composing new messages

### iPad Additional Criteria

1. Chat fills the detail column width appropriately (not narrow iPhone-width column)
2. Message bubbles sized for wider layout with comfortable reading width
3. Session highlighted in sidebar if sidebar is visible

### Common FAIL Indicators

- Blank chat view with no messages
- Raw JSON or unformatted markdown displayed
- Stuck "Loading..." or spinning indicator
- Navigation bar shows UUID instead of session name
- Messages all same alignment (no user/assistant distinction)

---

## 04 - Browser: MCP Servers

**Deep link:** `ils://mcp`
**ActiveScreen case:** `.browser` (segment: .mcp)

### iPhone PASS Criteria

1. MCP server list visible with server names
2. Health status indicators (badges/icons) per server showing healthy/unhealthy state
3. Server count > 0 (expect 15+ servers)
4. Browser tab/segment bar visible showing MCP is the active selection
5. Tapping a server row shows detail view or expands info

### iPad Additional Criteria

1. Browser tab bar and MCP content render in the detail column
2. Sidebar visible alongside browser content
3. Content width fills detail column appropriately

### Common FAIL Indicators

- Empty server list despite backend having MCP data
- Health badges missing (just plain text list)
- Tab/segment bar not visible or MCP not selected
- Crash when navigating to MCP tab

---

## 05 - Browser: Skills

**Deep link:** `ils://skills`
**ActiveScreen case:** `.browser` (segment: .skills)

### iPhone PASS Criteria

1. Skills list visible with skill names
2. Active/Inactive status badges visible per skill
3. Search bar or search placeholder text present
4. Skill count > 0 (expect 1000+ skills)
5. Skills are scrollable

### iPad Additional Criteria

1. Skills content renders in the detail column with sidebar visible
2. Layout adapts to wider screen (not narrow single-column)

### Common FAIL Indicators

- Empty skills list
- Missing status badges
- No search capability
- Skills count shows 0 when backend has data

---

## 06 - Browser: Plugins

**Deep link:** `ils://plugins`
**ActiveScreen case:** `.browser` (segment: .plugins)

### iPhone PASS Criteria

1. Plugins list visible with plugin names
2. Enable/Disable state badges visible per plugin
3. Category filters or section headers present for organization
4. Plugin count > 0 (expect 50+ plugins)
5. Plugins are scrollable

### iPad Additional Criteria

1. Plugins content renders in the detail column with sidebar visible
2. Layout fills detail column width appropriately

### Common FAIL Indicators

- Empty plugins list
- Missing enable/disable badges
- No category organization
- Plugin count shows 0 when backend has data

---

## 07 - System Monitor

**Deep link:** `ils://system`
**ActiveScreen case:** `.system`

### iPhone PASS Criteria

1. CPU metric displayed with percentage value
2. Memory metric displayed with usage value (e.g., "8.2 GB / 16 GB")
3. Disk metric displayed with usage value
4. Network metric displayed (bytes sent/received or transfer rate)
5. Process count > 0 (expect 1000+ processes)
6. "Live" indicator or WebSocket connected status visible
7. Metrics update in real-time (not static/stale values)

### iPad Additional Criteria

1. Metrics cards render in the detail column with sidebar visible
2. No compressed or overlapping metric cards (layout adapts to wider screen)
3. Cards may use a grid layout taking advantage of extra width

### Common FAIL Indicators

- All metrics showing 0 or "--"
- "Disconnected" or no live indicator
- Metrics cards overlapping or compressed
- Screen crashes or shows error state
- Process count is 0

---

## 08 - Settings

**Deep link:** `ils://settings`
**ActiveScreen case:** `.settings`

### iPhone PASS Criteria

1. Settings sections render with real config values (not empty/placeholder text)
2. InheritanceBadge indicators visible (e.g., "Host Default" badges)
3. Info tooltip buttons (i) present and tappable (shows explanatory popover)
4. Connection status section visible showing connected host
5. PERMISSIONS section visible (may require scrolling down)
6. Form sections have proper headers and grouping

### iPad Additional Criteria

1. Full-width detail column for settings form (not narrow column)
2. All sections visible without horizontal compression
3. Settings form fills available width appropriately

### Common FAIL Indicators

- Empty settings values or placeholder text
- Missing InheritanceBadge indicators
- Tooltip buttons missing or non-functional
- Connection status not shown
- Settings form is empty or crashes

---

## 09 - Host Profiles

**Deep link:** `ils://fleet` (alias: `ils://profiles`)
**ActiveScreen case:** `.hostProfiles`

### iPhone PASS Criteria

1. At least one host profile visible (localhost / "Local Backend")
2. Health badge visible (green/healthy indicator for connected host)
3. Active indicator on the currently connected host
4. Host details show address/port information

### iPad Additional Criteria

1. Host profiles list renders in the detail column with sidebar visible
2. Layout fills detail column appropriately

### Common FAIL Indicators

- Empty host list
- No health badge or connection status
- Missing active indicator on connected host
- Screen crashes or shows error

---

## 10 - Agent Teams

**Deep link:** `ils://teams`
**ActiveScreen case:** `.teams`

### iPhone PASS Criteria

1. Screen renders without crash
2. Team list visible OR empty state with explanatory text
3. Navigation bar title shows "Agent Teams" or similar
4. No stuck loading indicator

### iPad Additional Criteria

1. Content renders in the detail column with sidebar visible
2. Empty state or team list fills detail column appropriately

### Common FAIL Indicators

- Screen crashes on navigation
- Infinite loading spinner
- Blank screen with no content and no empty state message

---

## 11 - Themes

**Deep link:** `ils://themes`
**ActiveScreen case:** `.themes`

### iPhone PASS Criteria

1. Built-in themes listed (expect 12+ themes)
2. Current/active theme indicated (checkmark, highlight, or "Active" badge)
3. Theme previews visible (color swatches or preview cards)
4. Themes are scrollable if list exceeds screen height
5. Tapping a theme applies it (visual change observed)

### iPad Additional Criteria

1. Theme list renders in the detail column with sidebar visible
2. Theme preview cards may use grid layout for wider screen

### Common FAIL Indicators

- Empty theme list
- No indication of which theme is active
- Missing theme previews (just text names)
- Theme selection does not visually change the app

---

## 12 - Hooks

**Deep link:** `ils://hooks`
**ActiveScreen case:** `.hooks`

### iPhone PASS Criteria

1. Screen renders without crash
2. Hook list visible OR empty state with config path shown
3. "Edit Config" and/or "Copy Path" buttons present
4. Event type labels visible if hooks exist
5. Navigation bar title shows "Hooks" or similar

### iPad Additional Criteria

1. Content renders in the detail column with sidebar visible
2. Empty state or hook list fills detail column appropriately

### Common FAIL Indicators

- Screen crashes on navigation
- No empty state message when no hooks configured
- Missing config path or action buttons
- Blank screen with no content

---

## 13 - Sidebar

**Navigation:** Swipe from left edge on iPhone / persistent on iPad
**ActiveScreen case:** (navigation chrome, not a dedicated ActiveScreen)

### iPhone PASS Criteria

1. All navigation items visible: Home, System Monitor, Browser, Agent Teams, Host Profiles, Settings, Themes, Hooks
2. Active screen highlighted with accent color tint
3. Session list visible within sidebar (grouped by project or flat list)
4. Host name or connection indicator displayed
5. Sidebar dismisses when tapping outside or selecting an item
6. Sidebar opens via swipe from left edge

### iPad PASS Criteria (different from iPhone -- persistent sidebar)

1. Sidebar is PERSISTENT (always visible), NOT an overlay or sheet
2. Width between ~260-380pt
3. All navigation items visible without requiring scrolling
4. Selection highlight syncs with detail column content (active screen)
5. No hamburger/menu button needed (that is iPhone-only)
6. Session list visible in sidebar
7. Sidebar and detail column coexist without overlap

### Common FAIL Indicators

- iPhone: sidebar does not open on swipe
- iPad: sidebar is an overlay/sheet instead of persistent column
- iPad: hamburger button visible (indicates compact/iPhone layout)
- Navigation items missing from sidebar
- No highlight on active screen
- Sidebar covers entire screen on iPad (should be side column)

---

## Deep Link Routes

All routes use the `ils://` scheme. The app must have been launched at least once before deep links work without a system confirmation dialog.

| Route | Expected Navigation | ActiveScreen |
|-------|-------------------|--------------|
| `ils://home` | Home / Dashboard screen | `.home` |
| `ils://sessions` | Sessions list | `.home` (sessions) |
| `ils://sessions/{uuid}` | Specific chat session (UUID must be lowercase) | `.chat(session)` |
| `ils://browser` | Browser (default tab) | `.browser` |
| `ils://projects` | Browser (alias for browser) | `.browser` |
| `ils://mcp` | Browser - MCP Servers tab | `.browser` (segment: .mcp) |
| `ils://skills` | Browser - Skills tab | `.browser` (segment: .skills) |
| `ils://plugins` | Browser - Plugins tab | `.browser` (segment: .plugins) |
| `ils://settings` | Settings screen | `.settings` |
| `ils://system` | System Monitor screen | `.system` |
| `ils://fleet` | Host Profiles screen | `.hostProfiles` |
| `ils://profiles` | Host Profiles (alias for fleet) | `.hostProfiles` |
| `ils://themes` | Themes screen | `.themes` |
| `ils://teams` | Agent Teams screen | `.teams` |
| `ils://hooks` | Hooks screen | `.hooks` |

### Deep Link PASS Criteria

1. Navigation completes within 2 seconds of `xcrun simctl openurl`
2. Correct screen is displayed after navigation (matches table above)
3. No system confirmation dialog ("Open in ILSApp?") appears
4. Console shows zero crashes during deep link sequence
5. Deep links work on both iPhone and iPad simulators
6. `ils://sessions/{uuid}` with a valid lowercase UUID opens the correct chat session

---

## General iPad Criteria (applies to ALL screens)

These criteria apply to every screen when viewed on the iPad simulator:

1. **Persistent sidebar:** NavigationSplitView sidebar is always visible on the left side
2. **Detail column content:** Screen content fills the detail column (right side) without white bands
3. **Sidebar highlight:** The active screen's sidebar item is highlighted with accent color
4. **No compact layout:** No hamburger/menu button visible (that indicates iPhone-compact layout)
5. **Appropriate width:** Content adapts to wider detail column, not squished to iPhone dimensions

---

**Footer:** Any screen that FAILS any criterion must be fixed, rebuilt, and re-validated before the phase can pass. Fixes are applied to the codebase, the app is rebuilt and reinstalled, and the screen is re-screenshotted and re-evaluated against these criteria.
