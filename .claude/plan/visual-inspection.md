# Visual Inspection Plan - ILS iOS App

## Objective
Systematically inspect every screen in the ILS iOS app on the dedicated simulator (iPhone 16 Pro Max, UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14) to verify:
- **Text readability**: All text is legible, proper contrast, no truncation/overlap
- **Color correctness**: Theme colors applied consistently, entity colors match, no invisible text
- **Button placement**: All interactive elements are reachable, properly sized (44pt minimum), visually distinct
- **Usability**: Navigation works, no dead taps, scroll areas function, modals dismiss properly

## Prerequisites
- [ ] Build iOS app: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet`
- [ ] Boot simulator if needed: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14`
- [ ] Install app to simulator
- [ ] Start backend: `PORT=9999 swift run ILSBackend` (from `/Users/nick/Desktop/ils-ios/`)
- [ ] Verify backend health: `curl -s http://localhost:9999/api/v1/health`

## Evidence Directory
`specs/visual-inspection-v2/evidence/`

## Inspection Checklist

### Phase 1: App Launch & Onboarding (3 screens)

#### 1.1 First Launch / Server Setup Sheet (`ServerSetupSheet.swift` / `OnboardingView.swift`)
- [ ] Screenshot: `01-onboarding.png`
- [ ] Branding header visible and centered
- [ ] "Quick Connect" and "Set Up New Server" cards readable
- [ ] Card text contrast sufficient against background
- [ ] Buttons have clear tap targets (44pt+)
- [ ] Modal is non-dismissible (swipe down blocked)

#### 1.2 Quick Connect (`QuickConnectView.swift`)
- [ ] Screenshot: `02-quick-connect.png`
- [ ] Server URL text field visible with placeholder
- [ ] Connect button clearly styled and tappable
- [ ] Input text readable against field background
- [ ] Error states display correctly (wrong URL)

#### 1.3 Connected State Transition
- [ ] Screenshot: `03-connected-transition.png`
- [ ] Onboarding dismisses after successful connection
- [ ] App navigates to Home screen
- [ ] No flash of empty/broken state during transition

---

### Phase 2: Home / Dashboard (1 screen, multiple states)

#### 2.1 Home Screen - Connected (`HomeView.swift`)
- [ ] Screenshot: `04-home-connected.png`
- [ ] Welcome section text readable
- [ ] Server connection status badge visible and correct color (green)
- [ ] Recent sessions list shows items with readable text
- [ ] Session titles not truncated (or truncated with ellipsis)
- [ ] Quick action grid: all 4 buttons (New Session, Skills, MCP Servers, Plugins) visible
- [ ] Quick action icons render correctly
- [ ] Overview stat cards: numbers readable, sparklines visible
- [ ] Entity colors on stat cards match entity type (sessions=blue, projects=green, skills=purple, MCP=orange)
- [ ] All text passes contrast check against card backgrounds

#### 2.2 Home Screen - Disconnected State
- [ ] Screenshot: `05-home-disconnected.png`
- [ ] Disconnected banner visible with appropriate color (red/warning)
- [ ] "Configure" or "Retry" button visible and tappable
- [ ] Empty states for sessions/stats are graceful (not broken)

---

### Phase 3: Sidebar Navigation (1 overlay)

#### 3.1 Sidebar (`SidebarView.swift`)
- [ ] Screenshot: `06-sidebar.png`
- [ ] App branding at top readable
- [ ] Connection status indicator (green dot or text)
- [ ] All 6 nav items visible: Home, System, Browse, Teams, Fleet, Settings
- [ ] Nav item icons render correctly
- [ ] Active nav item has visual highlight
- [ ] Sessions section header with count visible
- [ ] Session search bar functional and readable
- [ ] Project disclosure groups expand/collapse
- [ ] Session rows: title + timestamp readable, not truncated
- [ ] "New Session" button at bottom visible and tappable
- [ ] Sidebar background doesn't bleed through to main content

---

### Phase 4: Chat / Sessions (5 screens)

#### 4.1 New Session Sheet (`NewSessionView.swift`)
- [ ] Screenshot: `07-new-session.png`
- [ ] Session name field with placeholder text
- [ ] Project picker dropdown readable
- [ ] Model selection (Sonnet/Opus/Haiku) buttons clearly labeled
- [ ] Permission mode picker readable
- [ ] System prompt editor area visible
- [ ] Budget/turn limit controls functional
- [ ] "Create" button prominent and tappable
- [ ] Cancel/dismiss button accessible

#### 4.2 Chat View - Empty State (`ChatView.swift`)
- [ ] Screenshot: `08-chat-empty.png`
- [ ] Session title in nav bar readable
- [ ] Empty state message/illustration visible
- [ ] Input bar at bottom: text field + send button visible
- [ ] Command palette button (/) accessible
- [ ] Menu button (...) accessible
- [ ] Input field placeholder text readable

#### 4.3 Chat View - With Messages
- [ ] Screenshot: `09-chat-messages.png`
- [ ] User message card: text readable, proper alignment (right-aligned or styled)
- [ ] Assistant message card: markdown renders correctly
- [ ] Code blocks: syntax highlighting visible, copy button works
- [ ] Tool call accordions: header text readable, expand/collapse works
- [ ] Thinking sections: collapsible, text readable when expanded
- [ ] Message timestamps readable
- [ ] Scroll behavior correct (newest at bottom)
- [ ] Input bar remains visible above keyboard area

#### 4.4 Chat View - Streaming State
- [ ] Screenshot: `10-chat-streaming.png`
- [ ] Streaming indicator (dots) visible and animated
- [ ] "Taking longer than expected" text appears if applicable
- [ ] Stop button (red) clearly visible and tappable
- [ ] Send button disabled during streaming

#### 4.5 Session Info Sheet (`SessionInfoView.swift`)
- [ ] Screenshot: `11-session-info.png`
- [ ] Session name header readable
- [ ] Details section: Model, Status, Message count all labeled and readable
- [ ] Cost & usage: values formatted correctly
- [ ] Timestamps: Created, Last Active in readable format
- [ ] Configuration: Permission mode, Source, Project displayed
- [ ] Export and Copy ID buttons accessible
- [ ] Close/dismiss button visible

#### 4.6 Command Palette (`CommandPaletteView.swift`)
- [ ] Screenshot: `12-command-palette.png`
- [ ] Search bar visible with placeholder
- [ ] Built-in commands (15) listed with readable labels
- [ ] Skills section loads (or shows loading indicator)
- [ ] Model switching shortcuts visible
- [ ] Each command has clear icon + label + description
- [ ] Tap targets are sufficient size

#### 4.7 Advanced Options (`AdvancedOptionsSheet.swift`)
- [ ] Screenshot: `13-advanced-options.png`
- [ ] System prompt text area readable
- [ ] Model picker labels clear
- [ ] Permission mode selector readable
- [ ] Max turns stepper control functional
- [ ] Tool allow/disallow list sections visible
- [ ] Toggles (Continue session, Debug mode) labeled and functional

#### 4.8 Chat Ellipsis Menu
- [ ] Screenshot: `14-chat-menu.png`
- [ ] Menu items visible: Rename, Fork, Export, Session Info, Delete
- [ ] Each item has readable text and proper icon
- [ ] Destructive items (Delete) styled in red
- [ ] Menu dismisses on outside tap

---

### Phase 5: Browser (3 screens + 2 detail screens)

#### 5.1 Browser - MCP Servers Tab (`BrowserView.swift`)
- [ ] Screenshot: `15-browser-mcp.png`
- [ ] Segmented control: MCP Servers / Skills / Plugins with counts
- [ ] Active segment clearly highlighted
- [ ] Scope filter buttons (All/User/Project/Local) visible
- [ ] Search bar visible
- [ ] MCP server list items: name + command readable
- [ ] Entity count badge correct color (orange for MCP)
- [ ] List scrolls smoothly with many items

#### 5.2 Browser - Skills Tab
- [ ] Screenshot: `16-browser-skills.png`
- [ ] Skills list with name + source badge
- [ ] Skill count in segment header
- [ ] Tags visible on skill rows (if present)
- [ ] Search filters skills correctly

#### 5.3 Browser - Plugins Tab
- [ ] Screenshot: `17-browser-plugins.png`
- [ ] Plugin list with name + category
- [ ] Category filter buttons visible and functional
- [ ] Plugin count in segment header
- [ ] Install status indicator on each plugin

#### 5.4 MCP Server Detail (`MCPServerDetailView.swift`)
- [ ] Screenshot: `18-mcp-detail.png`
- [ ] Server name header readable
- [ ] Command and arguments display (monospace/code style)
- [ ] Environment variables section
- [ ] Configuration metadata (Scope, Status, Config path)
- [ ] "Copy Full Command" button accessible
- [ ] Back navigation works

#### 5.5 Skill Detail (`SkillDetailView.swift`)
- [ ] Screenshot: `19-skill-detail.png`
- [ ] Skill name header with source badge and active status
- [ ] Tags section with colored chips
- [ ] Metadata (Version, Path, Last updated) readable
- [ ] Markdown content renders correctly with syntax highlighting
- [ ] Edit mode toggle works (if applicable)
- [ ] Back navigation works

---

### Phase 6: System Monitor (3 screens)

#### 6.1 System Monitor Main (`SystemMonitorView.swift`)
- [ ] Screenshot: `20-system-monitor.png`
- [ ] CPU usage chart renders with readable labels and values
- [ ] Load average values (1m, 5m, 15m) displayed
- [ ] Memory progress ring with percentage label readable
- [ ] Disk progress ring with used/total text
- [ ] Network chart (in/out dual lines) with legend
- [ ] "Live" connection indicator visible
- [ ] Process list section visible below charts
- [ ] File browser link accessible

#### 6.2 Process List (`ProcessListView.swift`)
- [ ] Screenshot: `21-process-list.png`
- [ ] Sort options (CPU/Memory/Name) visible and tappable
- [ ] Search bar functional
- [ ] Process rows: Name, PID, CPU%, Memory all readable
- [ ] Classification badges (if any) colored correctly
- [ ] Top 50 processes display without truncation issues

#### 6.3 File Browser (`FileBrowserView.swift`)
- [ ] Screenshot: `22-file-browser.png`
- [ ] Breadcrumb navigation at top readable
- [ ] Directory/file icons distinct
- [ ] File names not truncated (or properly ellipsized)
- [ ] File sizes displayed in readable format
- [ ] Directory drill-down navigation works
- [ ] File preview sheet shows content (for text files)

---

### Phase 7: Agent Teams (6 screens)

#### 7.1 Agent Teams List (`AgentTeamsListView.swift`)
- [ ] Screenshot: `23-teams-list.png`
- [ ] Team cards with name + member count
- [ ] Create team button visible
- [ ] Empty state message if no teams
- [ ] Card text readable against background

#### 7.2 Agent Team Detail (`AgentTeamDetailView.swift`)
- [ ] Screenshot: `24-team-detail.png`
- [ ] Team header with description
- [ ] 3-tab interface: Members / Tasks / Messages tabs labeled
- [ ] Active tab clearly indicated
- [ ] Member cards with status badges (colored)
- [ ] Spawn/shutdown buttons accessible

#### 7.3 Create Team (`CreateTeamView.swift`)
- [ ] Screenshot: `25-create-team.png`
- [ ] Form fields readable with labels
- [ ] Create button prominent

#### 7.4 Spawn Teammate (`SpawnTeammateView.swift`)
- [ ] Screenshot: `26-spawn-teammate.png`
- [ ] Agent type/role selector readable
- [ ] Configuration fields visible

---

### Phase 8: Fleet Management (2 screens)

#### 8.1 Fleet List (`FleetManagementView.swift`)
- [ ] Screenshot: `27-fleet-list.png`
- [ ] Fleet host cards with health badges (color-coded)
- [ ] Active host indicator visible
- [ ] "Add Host" button accessible
- [ ] Empty state if no hosts configured

#### 8.2 Fleet Host Detail (`FleetHostDetailView.swift`)
- [ ] Screenshot: `28-fleet-detail.png`
- [ ] Host info: Address, Port, SSH User, Platform readable
- [ ] Health status with last-check timestamp
- [ ] Lifecycle controls (Start, Stop, Restart) buttons accessible
- [ ] Log viewer section with refresh button

---

### Phase 9: Settings (6 screens)

#### 9.1 Settings Main (`SettingsView.swift`) - Top
- [ ] Screenshot: `29-settings-top.png`
- [ ] Connection section: Server URL readable, Test Connection button
- [ ] Remote Access section: Tunnel config link
- [ ] Appearance section: Current theme name, navigation to picker
- [ ] All section headers readable with proper contrast

#### 9.2 Settings Main - Middle (scroll down)
- [ ] Screenshot: `30-settings-middle.png`
- [ ] General Settings: Default model label, Color scheme picker
- [ ] API Key section: Key masked, reveal/edit buttons
- [ ] Permissions section: Default permission mode

#### 9.3 Settings Main - Bottom (scroll to end)
- [ ] Screenshot: `31-settings-bottom.png`
- [ ] Advanced section: Debug toggles labeled
- [ ] Statistics section: Usage numbers readable
- [ ] Diagnostics section: Health check button, logs link
- [ ] About section: App version, backend info

#### 9.4 Theme Picker (`ThemePickerView.swift`)
- [ ] Screenshot: `32-theme-picker.png`
- [ ] Grid of 12 themes displayed
- [ ] Theme preview cards show mini UI correctly
- [ ] Active theme has clear checkmark/highlight
- [ ] Color swatches visible on each card
- [ ] Theme names readable below cards
- [ ] 10 dark + 2 light themes distinguishable

#### 9.5 Tunnel Settings (`TunnelSettingsView.swift`)
- [ ] Screenshot: `33-tunnel-settings.png`
- [ ] Cloudflare tunnel configuration fields readable
- [ ] Toggle/switch labels clear
- [ ] Status indicator visible

#### 9.6 Log Viewer (`LogViewerView.swift`)
- [ ] Screenshot: `34-log-viewer.png`
- [ ] Log entries in monospace font
- [ ] Timestamps readable
- [ ] Log levels color-coded (if applicable)
- [ ] Scroll works with many entries
- [ ] Refresh button accessible

---

### Phase 10: Cross-Cutting Checks

#### 10.1 Dark Mode Consistency
- [ ] All screens use theme colors (not system defaults)
- [ ] No white backgrounds flashing in dark mode
- [ ] Text contrast minimum 4.5:1 on all backgrounds
- [ ] Dividers/separators visible but not harsh

#### 10.2 Entity Color Consistency
- [ ] Sessions: blue tint everywhere (sidebar, home, browser)
- [ ] Projects: green tint everywhere
- [ ] Skills: purple tint everywhere
- [ ] MCP Servers: orange tint everywhere
- [ ] Plugins: pink/magenta tint everywhere
- [ ] Teams: teal tint (if applicable)

#### 10.3 Interactive Element Sizing
- [ ] All buttons minimum 44x44pt tap target
- [ ] Text fields have adequate padding
- [ ] Segmented controls have adequate tap areas
- [ ] Disclosure triangles/chevrons tappable

#### 10.4 Navigation Consistency
- [ ] Back buttons present on all drill-down screens
- [ ] Sheet dismiss buttons (X or swipe) work
- [ ] No dead-end screens (can always navigate away)
- [ ] Active sidebar item matches current screen

---

## Execution Strategy

### Approach
Use `idb_describe operation:all` for accessibility tree + coordinates, then `idb_tap` for navigation. Capture screenshots with `simulator_screenshot` after each navigation.

### Screen Navigation Order
1. Fresh install → Onboarding flow (Phase 1)
2. Connect to backend → Home (Phase 2)
3. Open sidebar → inspect (Phase 3)
4. Navigate to each tab via sidebar:
   - Chat/Sessions (Phase 4): Create new session, send message, check streaming, inspect menus
   - Browser (Phase 5): Switch segments, drill into details
   - System Monitor (Phase 6): Charts, process list, file browser
   - Agent Teams (Phase 7): List, detail, create
   - Fleet (Phase 8): List, detail
   - Settings (Phase 9): Scroll through sections, drill into sub-screens

### Evidence Naming
`{NN}-{screen-name}.png` (e.g., `01-onboarding.png`, `15-browser-mcp.png`)

### Pass/Fail Criteria per Screen
- **PASS**: All text readable, colors correct, buttons usable, no visual defects
- **NEEDS FIX**: Minor issues (slight truncation, color inconsistency) that don't block usage
- **FAIL**: Text unreadable, buttons unreachable, broken layout, missing content

## Validation
- [ ] Build and run actual application on simulator
- [ ] Test through user interface (every screen)
- [ ] Capture screenshots as evidence (34+ screenshots)
- [ ] Verify evidence shows expected behavior
- [ ] Generate findings report with PASS/NEEDS FIX/FAIL per screen
