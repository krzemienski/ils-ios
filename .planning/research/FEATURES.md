# Feature Landscape: ILS Comprehensive Audit

**Domain:** Native iOS/macOS client for Claude Code -- comprehensive audit & remediation
**Researched:** 2026-02-19
**Spec Source:** `docs/ils.md` (~4,300 lines, 5 phases with gate checks)
**Audit Plan:** `.omc/plans/ils-comprehensive-audit-remediation.md` (1,370 lines, 10 phases)

---

## Complete Feature Inventory

### Spec-Defined Screens (Phase 3 of `docs/ils.md`)

| # | Screen Name | Spec Task | SwiftUI File (iOS) | Backend Endpoint | Status |
|---|-------------|-----------|-------------------|------------------|--------|
| 1 | ServerConnectionView / Onboarding | 3.1 | `Views/Onboarding/ServerSetupSheet.swift`, `OnboardingView.swift`, `QuickConnectView.swift` | N/A (local connection) | IMPLEMENTED |
| 2 | DashboardView / Home | 3.2 | `Views/Home/HomeView.swift` | `GET /api/v1/stats` | IMPLEMENTED |
| 3 | SkillsListView (Browser > Skills tab) | 3.3 | `Views/Browser/BrowserView.swift` (Skills section) | `GET /api/v1/skills` | IMPLEMENTED |
| 4 | SkillDetailView | 3.3 | `Views/Browser/SkillDetailView.swift` | `GET /api/v1/skills/:id` | IMPLEMENTED |
| 5 | MCPServerListView (Browser > MCP tab) | 3.4 | `Views/Browser/BrowserView.swift` (MCP section) | `GET /api/v1/mcp` | IMPLEMENTED |
| 6 | **AddMCPServerView** | 3.4 | `Views/Browser/AddMCPServerView.swift` | `POST /api/v1/mcp` | **IMPLEMENTED** (was the ONE gap, now built) |
| 7 | PluginMarketplaceView (Browser > Plugins tab) | 3.5 | `Views/Browser/BrowserView.swift` (Plugins section) | `GET /api/v1/plugins` | IMPLEMENTED |
| 8 | SettingsEditorView / ConfigEditorView | 3.6 | `Views/Settings/ConfigEditorView.swift` | `GET /api/v1/config?scope=` | IMPLEMENTED |
| 9 | MainTabView / Sidebar Navigation | 3.7 | `Views/Root/SidebarRootView.swift`, `SidebarView.swift` | N/A | IMPLEMENTED |

### Beyond-Spec Screens (Implemented but not in original spec)

| # | Screen Name | SwiftUI File (iOS) | Backend Endpoint | Purpose |
|---|-------------|-------------------|------------------|---------|
| 10 | ChatView | `Views/Chat/ChatView.swift` + 8 sub-views | `POST /api/v1/chat/stream` | E2E chat with Claude via SDK |
| 11 | SystemMonitorView | `Views/System/SystemMonitorView.swift` | WebSocket `/system` | Live CPU/Memory/Disk/Network |
| 12 | ProcessListView | `Views/System/ProcessListView.swift` | WebSocket `/system` | Process listing |
| 13 | FileBrowserView | `Views/System/FileBrowserView.swift` | TBD | File system navigation |
| 14 | FleetManagementView (Hosts) | `Views/Fleet/FleetManagementView.swift` | `GET /api/v1/fleet` | Backend host management |
| 15 | FleetHostDetailView | `Views/Fleet/FleetHostDetailView.swift` | `GET /api/v1/fleet/:id` | Host detail |
| 16 | HooksManagementView | `Views/Settings/HooksManagementView.swift` | `GET /api/v1/config` | Hook event management |
| 17 | AgentTeamsListView | `Views/Teams/AgentTeamsListView.swift` | `GET /api/v1/teams` | Agent team coordination |
| 18 | AgentTeamDetailView | `Views/Teams/AgentTeamDetailView.swift` | `GET /api/v1/teams/:id` | Team detail |
| 19 | TeamMessagesView | `Views/Teams/TeamMessagesView.swift` | WebSocket `/teams/:id` | Team messaging |
| 20 | ThemeMarketplaceView | `Views/Themes/ThemeMarketplaceView.swift` | `GET /api/v1/themes` | Theme browsing |
| 21 | ThemeEditorView | `Views/Themes/ThemeEditorView.swift` | N/A (local) | Custom theme creation |
| 22 | ThemesListView | `Views/Themes/ThemesListView.swift` | `GET /api/v1/themes` | Theme listing |
| 23 | NewSessionView | `Views/Sessions/NewSessionView.swift` | `POST /api/v1/sessions` | Session creation |
| 24 | SessionInfoView | `Views/Sessions/SessionInfoView.swift` | `GET /api/v1/sessions/:id` | Session metadata |
| 25 | TunnelSettingsView | `Views/Settings/TunnelSettingsView.swift` | `POST /api/v1/tunnel` | Cloudflare tunnel config |
| 26 | LogViewerView | `Views/Settings/LogViewerView.swift` | N/A (local) | Log inspection |
| 27 | PremiumView | `Views/Premium/PremiumView.swift` | N/A | Subscription UI |
| 28 | CommandPaletteView | `Views/Chat/CommandPaletteView.swift` | N/A | Quick action palette |
| 29 | PermissionRequestModal | `Views/Chat/PermissionRequestModal.swift` | N/A | Tool permission UI |
| 30 | AdvancedOptionsSheet | `Views/Chat/AdvancedOptionsSheet.swift` | N/A | Chat options |

### macOS-Only Views (11 total)

| # | Screen Name | SwiftUI File | Purpose |
|---|-------------|-------------|---------|
| 1 | MacDashboardView | `ILSMacApp/Views/MacDashboardView.swift` | macOS dashboard |
| 2 | MacContentView | `ILSMacApp/Views/MacContentView.swift` | Main content area |
| 3 | MacChatView | `ILSMacApp/Views/MacChatView.swift` | macOS chat interface |
| 4 | MacSettingsView | `ILSMacApp/Views/MacSettingsView.swift` | macOS settings |
| 5 | SessionWindowView | `ILSMacApp/Views/SessionWindowView.swift` | Detachable session window |
| 6 | ILSMacApp | `ILSMacApp/ILSMacApp.swift` | App entry point |
| 7 | AppDelegate | `ILSMacApp/AppDelegate.swift` | macOS lifecycle |
| 8 | ILSCommands | `ILSMacApp/Commands/ILSCommands.swift` | Menu bar commands |
| 9 | WindowManager | `ILSMacApp/Managers/WindowManager.swift` | Window management |
| 10 | NotificationManager | `ILSMacApp/Managers/NotificationManager.swift` | Push notifications |
| 11 | SpotlightIndexer | `ILSMacApp/Services/SpotlightIndexer.swift` | Spotlight integration |

### Backend Controllers (14 total)

| # | Controller | Endpoints | Purpose |
|---|-----------|-----------|---------|
| 1 | HealthController | `GET /health` | Health check |
| 2 | StatsController | `GET /api/v1/stats` | Dashboard statistics |
| 3 | SessionsController | `GET/POST /api/v1/sessions` | Session management |
| 4 | ProjectsController | `GET /api/v1/projects` | Project listing |
| 5 | ChatController | `POST /api/v1/chat/stream` | Chat streaming (SSE) |
| 6 | SkillsController | `GET/POST/DELETE /api/v1/skills` | Skills CRUD + GitHub search |
| 7 | MCPController | `GET/POST/PUT/DELETE /api/v1/mcp` | MCP server management |
| 8 | PluginsController | `GET/POST /api/v1/plugins` | Plugin management |
| 9 | ConfigController | `GET/PUT /api/v1/config` | Config read/write |
| 10 | ThemesController | `GET/POST /api/v1/themes` | Theme management |
| 11 | SystemController | `WebSocket /api/v1/system` | System metrics |
| 12 | TeamsController | `GET/POST /api/v1/teams` | Agent teams |
| 13 | FleetController | `GET /api/v1/fleet` | Host management |
| 14 | TunnelController | `POST /api/v1/tunnel` | Cloudflare tunnel |

---

## Audit Phase-to-Feature Mapping

### Phase 0: Baseline Build Verification

**Objective:** Confirm all 3 build targets compile with zero errors.

| Target | Build Command | Evidence |
|--------|--------------|----------|
| iOS | `xcodebuild -scheme ILSApp -destination 'id=50523130...'` | `evidence_0.2_ios_build.txt` |
| macOS | `xcodebuild -scheme ILSMacApp -destination 'platform=macOS'` | `evidence_0.2_macos_build.txt` |
| Backend | `swift build` | `evidence_0.2_backend_build.txt` |

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("axiom:axiom-ios-build")` | Build error diagnosis | If any build fails |
| `axiom:build-fixer` agent | Build failure resolution | If errors persist |

**Features Verified:** Build system integrity, cross-platform compilation, dependency resolution.

---

### Phase 1: Screen Inventory & Before-State Evidence

**Objective:** Capture screenshot evidence of every spec-required screen BEFORE remediation.

| # | Screen | Navigation | Evidence File |
|---|--------|-----------|---------------|
| 01 | Home/Dashboard | Default launch | `evidence_1.3_01_home.png` |
| 02 | Sidebar | Left-edge swipe | `evidence_1.3_02_sidebar.png` |
| 03 | Browser > Skills | `ils://browser` + tab | `evidence_1.3_03_skills.png` |
| 04 | Skill Detail | Tap skill row | `evidence_1.3_04_skill_detail.png` |
| 05 | Browser > MCP | Browser MCP tab | `evidence_1.3_05_mcp.png` |
| 06 | Browser > Plugins | Browser Plugins tab | `evidence_1.3_06_plugins.png` |
| 07 | Settings | `ils://settings` | `evidence_1.3_07_settings.png` |
| 08 | Config Editor | Settings > Edit User Settings | `evidence_1.3_08_config_editor.png` |
| 09 | System Monitor | `ils://system` | `evidence_1.3_09_system.png` |
| 10 | Hosts (Fleet) | `ils://fleet` | `evidence_1.3_10_hosts.png` |

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("ios-simulator-control")` | Boot, install, screenshot | Simulator management |
| `Skill("xclaude-plugin:simulator-workflows")` | xclaude MCP screenshot capture | Screenshot workflows |
| `Skill("ios-ui-automation")` | idb tap/describe patterns | Navigation interaction |
| `Skill("xclaude-plugin:ui-automation-workflows")` | xclaude idb integration | Automation patterns |

**PASS Criteria per screen:**
- Home: Stats cards with real counts, Quick Actions 2x2 grid (4 items), Recent Sessions list
- Sidebar: All nav items: Home, System, Browse, Agent Teams, Hosts, Settings
- Skills: Scope filter pills, search bar, skill rows with active/inactive badges, GitHub search section
- Skill Detail: Source badge, description, Markdown content, edit/delete/toggle toolbar
- MCP: Server rows with name, command, health status dots, scope filter
- Plugins: Category pills, installed/enabled/disabled stats, GitHub search, enable/disable toggles
- Settings: Model picker, Extended Thinking + Host Default badge, Co-authored-by, Hooks count
- Config Editor: Monospace editor, JSON validation indicator, Save button
- System Monitor: CPU, Memory, Disk, Network metrics, process count
- Hosts: Host list with "Local Backend" showing Active status

**Features Verified:** 10 screens render correctly with real data.
**Evidence Total:** 10 screenshots + 1 video recording + 1 log file = 12 artifacts.

---

### Phase 2: Gap Remediation (Implementation)

**Objective:** Implement the ONE confirmed UI gap: AddMCPServerView.

**UPDATE:** AddMCPServerView has been implemented. File exists at `ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift` (207 lines). BrowserView.swift has `@State private var showingAddMCPServer = false` and presents the sheet with `AddMCPServerView(mcpVM: mcpVM)`.

**Implementation Details (already done):**
- Name field (required, validation: non-empty)
- Command field (required, validation: non-empty)
- Arguments field (space-separated, optional)
- Scope picker (User/Project/Local with descriptions)
- Save button (disabled until name and command are non-empty)
- Cancel button (dismisses sheet)
- Wired to `MCPViewModel.addServer(name:command:args:scope:)` at line 107
- GlassCard modifier, theme tokens, monospaced font for inputs
- Error message display on save failure
- No env vars field (design decision D3 -- security concern)

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("axiom:axiom-ios-ui")` | SwiftUI patterns | If UI adjustments needed |
| `Skill("axiom:axiom-swiftui-nav")` | Navigation integration | If sheet presentation issues |
| `Skill("axiom:axiom-hig")` | HIG compliance | Visual review |

**Features Verified:** MCP server creation end-to-end.
**Evidence Total:** 3 screenshots.

---

### Phase 3: Mandate Verification (All 9 Sub-Tasks)

**Objective:** Verify ALL mandate items with screenshot evidence. 8 are VERIFY-only, 1 was IMPLEMENT (now done).

| Sub-Task | Feature | Verified In Code | Evidence Files |
|----------|---------|-----------------|----------------|
| 3.1 | GitHub Skill Search/Install UI | `BrowserView.swift` lines 312-782, `SkillsViewModel.swift` lines 211-249 | 2 screenshots |
| 3.2 | MCP Server Creation UI | `AddMCPServerView.swift` (Phase 2) | 3 screenshots (from Phase 2) |
| 3.3 | ConfigEditorView Scope + JSON Validation | `ConfigEditorView.swift` -- scope param, `isValidJSON()`, checkmark/xmark | 2 screenshots |
| 3.4 | SkillDetailView Features | `SkillDetailView.swift` -- Markdown (line 312), Delete (96-109), Edit (74-93), Toggle (59-72) | 2 screenshots |
| 3.5 | Settings Inheritance (Host Default badges) | `SettingsView.swift` -- `hostDefaultBadge` on model (133-138), color scheme (155-159), thinking (172-183), coauthor (187-200) | 1 screenshot |
| 3.6 | Fleet -> Hosts Rename | Commit `eb93856`. `SidebarView` shows `"Hosts"` | 1 screenshot |
| 3.7 | System Monitor Pipeline | 6 files: `SystemMonitorView.swift`, `MetricsWebSocketClient.swift`, `SystemMetricsViewModel.swift`, `ProcessListView.swift` | 1 screenshot |
| 3.8 | Hooks Management | `HooksManagementView.swift` -- all 5 event types at line 261 | 1 screenshot |
| 3.9 | Plugin GitHub Search/Install | `PluginsViewModel.swift` lines 250-290, 401 error at line 264 | 1 screenshot |

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("functional-validation")` | No-mock validation protocol | Every sub-task |
| `Skill("ios-validation-gate")` | 3-gate protocol | Evidence collection |
| `Skill("gate-validation-discipline")` | Evidence-based completion | PASS/FAIL determination |
| `Skill("verification-before-completion")` | Pre-completion checks | Before marking complete |

**Features Verified:** All 9 mandate items.
**Evidence Total:** 14 screenshots.

---

### Phase 4: Visual Audit (iPhone + iPad + macOS)

**Objective:** Comprehensive visual inspection across all platforms.

**iPhone Screenshots (19 screens):**

| # | Screen | Evidence File |
|---|--------|---------------|
| 01 | Home (stats loaded) | `evidence_4.1_iphone_01_home.png` |
| 02 | Sidebar (expanded) | `evidence_4.1_iphone_02_sidebar.png` |
| 03 | Browser > MCP | `evidence_4.1_iphone_03_mcp.png` |
| 04 | Browser > Skills | `evidence_4.1_iphone_04_skills.png` |
| 05 | Browser > Plugins | `evidence_4.1_iphone_05_plugins.png` |
| 06 | Skill Detail | `evidence_4.1_iphone_06_skill_detail.png` |
| 07 | MCP Server Detail | `evidence_4.1_iphone_07_mcp_detail.png` |
| 08 | Add MCP Server | `evidence_4.1_iphone_08_add_mcp.png` |
| 09 | Plugin Detail | `evidence_4.1_iphone_09_plugin_detail.png` |
| 10 | Settings (top) | `evidence_4.1_iphone_10_settings_top.png` |
| 11 | Settings (bottom) | `evidence_4.1_iphone_11_settings_bottom.png` |
| 12 | Config Editor | `evidence_4.1_iphone_12_config_editor.png` |
| 13 | Hooks Management | `evidence_4.1_iphone_13_hooks.png` |
| 14 | Themes List | `evidence_4.1_iphone_14_themes.png` |
| 15 | System Monitor | `evidence_4.1_iphone_15_system.png` |
| 16 | Hosts | `evidence_4.1_iphone_16_hosts.png` |
| 17 | Chat View | `evidence_4.1_iphone_17_chat.png` |
| 18 | New Session | `evidence_4.1_iphone_18_new_session.png` |
| 19 | Onboarding/Setup | `evidence_4.1_iphone_19_onboarding.png` |

**iPad Screenshots (4 screens):** Home, Browser, Settings, Chat/Sessions
**macOS Screenshots (5 screens):** Dashboard, Content, Chat, Settings, Session Window

**Visual Checklist (every screenshot):**
- Text readable (no truncation, no overlap)
- Safe areas respected (no content under notch/home indicator)
- Dark theme applied consistently (no white flashes)
- Hot Orange accent visible on interactive elements
- Entity colors correct (sessions, skills, MCP, plugins each distinct)
- GlassCard modifier rendering correctly
- Empty states have icon + title + subtitle

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("axiom:axiom-ios-ui")` | SwiftUI issue identification | Visual defects |
| `Skill("axiom:axiom-hig")` | HIG compliance check | Every screenshot |
| `Skill("axiom:axiom-ios-accessibility")` | Accessibility audit | Touch targets, labels |
| `Skill("axiom:axiom-swiftui-layout")` | Layout validation | Overflow, truncation |
| `axiom:accessibility-auditor` agent | Comprehensive a11y scan | Full audit pass |
| `axiom:swiftui-layout-auditor` agent | Layout issue detection | All 19 screens |

**Features Verified:** Visual integrity across 3 platforms, 28 total screenshots.
**Evidence Total:** 28 screenshots + 1 fixes log = 29 artifacts.

---

### Phase 5: Functional Audit

**Objective:** Verify every interactive element works with real data.

**Data Loading Verification:**

| Screen | Endpoint | Expected |
|--------|----------|----------|
| Home | `GET /stats` | Stats cards show real counts |
| Home | `GET /sessions` | Recent sessions with names, models |
| Browser > MCP | `GET /mcp` | Server list with health indicators |
| Browser > Skills | `GET /skills` | Skill list with active/inactive |
| Browser > Plugins | `GET /plugins` | Plugin list with enabled/disabled |
| Settings | `GET /config?scope=user` | Config values displayed |
| System Monitor | WebSocket `/system` | CPU, memory, disk, network |
| Hosts | Local backend | "Local Backend" Active |

**User Interaction Verification:**

| Interaction | Expected Result |
|-------------|-----------------|
| Skill scope filter | Only matching skills shown |
| MCP scope filter | Only matching servers shown |
| Plugin category filter | Only matching plugins shown |
| Search (any tab) | Results filter in real-time |
| Pull to refresh | Data reloads from backend |
| Skill toggle | Active/inactive state changes |
| Config editor save | Config saved via backend |
| Sidebar navigation | Correct screen loads for each item |
| Deep links | `ils://home`, `ils://browser`, `ils://settings`, `ils://system`, `ils://fleet`, `ils://themes` all navigate correctly |

**Error State Verification:**

| Scenario | Expected UI |
|----------|-------------|
| Backend offline | Connection banner or "Not Connected" |
| Invalid JSON in editor | Red "Invalid JSON" indicator, Save disabled |
| Empty data | Empty state with icon + title + subtitle |

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("ios-ui-automation")` | idb tap/describe for interactions | All interaction tests |
| `Skill("axiom:axiom-swiftui-nav")` | Navigation correctness | Sidebar + deep links |
| `axiom:swiftui-nav-auditor` agent | Nav architecture review | Navigation defects |

**Features Verified:** All interactive elements, data loading, error states, deep links.
**Evidence Total:** 7+ screenshots + 1 text file + 1 fixes log = 9+ artifacts.

---

### Phase 6: Backend Audit Against Spec

**Objective:** Verify every spec-defined endpoint returns correct JSON.

| # | Endpoint | Expected Structure | Key Checks |
|---|----------|-------------------|------------|
| 1 | `GET /health` | `{status: "ok"}` | Status present |
| 2 | `GET /api/v1/stats` | `{success, data: {sessions, skills, mcpServers, plugins}}` | All counts numeric |
| 3 | `GET /api/v1/skills` | `{success, data: {items, total}}` | Items have: name, description, isActive |
| 4 | `GET /api/v1/skills/search?q=` | `{success, data: {items}}` | Items have: name, repository, stars |
| 5 | `GET /api/v1/mcp` | `{success, data: {items, total}}` | Env values MASKED (`***masked***`) |
| 6 | `GET /api/v1/plugins` | `{success, data: {items, total}}` | Items have: name, isEnabled |
| 7 | `GET /api/v1/plugins/marketplace` | `{success, data}` | Marketplace data present |
| 8 | `GET /api/v1/config?scope=user` | `{success, data: {scope, content}}` | Content has: model, permissions |
| 9 | `GET /api/v1/sessions` | `{success, data: {items, total}}` | Session objects |
| 10 | `GET /api/v1/projects` | `{success, data: {items, total}}` | Project objects |

**CRITICAL: MCP Env Masking Verification:**
`MCPController.swift` lines 21-43 implement `maskSensitiveEnv()` which replaces ALL env values with `***masked***`. Must verify no raw API keys appear in ANY MCP response.

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("axiom:axiom-ios-networking")` | Networking patterns | API response issues |
| `axiom:security-privacy-scanner` agent | Security review | Env masking verification |
| `axiom:networking-auditor` agent | Deprecated API check | Endpoint validation |

**Features Verified:** All 10 endpoints, MCP env masking, data consistency.
**Evidence Total:** 10 JSON files + 1 env masking text = 11 artifacts.

---

### Phase 7: Integration Validation (Spec Phase 4 Gate)

**Objective:** Verify complete data flow: backend -> iOS app -> user interactions -> mutations -> UI updates.

**Correlated Evidence Pairs:**

| Flow | Backend Evidence | App Evidence |
|------|-----------------|--------------|
| Stats | `curl /stats` JSON | Home screenshot |
| Skills | `curl /skills` JSON | Browser Skills screenshot |
| MCP | `curl /mcp` JSON | Browser MCP screenshot |
| Config | `curl /config?scope=user` JSON | Settings screenshot |

**Mutation Flows:**
- Config save: Edit + save user config -> `curl /config` shows new value -> Settings shows new value
- MCP create: Create server via AddMCPServerView -> `curl /mcp` shows new server -> MCP list shows new server

**Mock Data Check:** Search for `mock|Mock|hardcode|placeholder.*data|sample.*data` in Views -- must return 0 results outside previews/comments.

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("spec-compliance")` | Spec adherence check | Correlated pairs |
| `Skill("functional-validation")` | Real data validation | Every flow |

**Features Verified:** End-to-end data flows, mutation consistency, zero mocks.
**Evidence Total:** 8 correlated files + 2 mutation files + 1 mock check = 11 artifacts.

---

### Phase 8: Proactive Bug Hunt

**Objective:** Beyond spec, actively search for undiscovered problems.

**Empty State Testing:**

| # | Screen | Trigger | Expected |
|---|--------|---------|----------|
| 01 | Skills (empty filter) | Filter to scope with 0 results | Empty state icon + message |
| 02 | MCP (empty filter) | Filter to scope with 0 results | Empty state icon + message |
| 03 | Plugins (empty category) | Filter to category with 0 results | "No results" feedback |
| 04 | Search (no results) | Type nonsense string | "No results" feedback |

**Edge Case Testing:**

| Test | Expected |
|------|----------|
| Long skill name | Text truncates cleanly |
| Special characters (XSS attempt) | Graceful display, no injection |
| Rapid navigation (5+ screens) | No crash, no stale data |
| Double pull-to-refresh | No duplicate entries |
| Large config JSON | Editor handles without lag |

**Accessibility Quick Check:**
- VoiceOver labels on key interactive elements (via `idb_describe`)
- Dynamic Type at largest size: layouts should not break critically

**Offline Recovery:**
- Kill backend -> verify app shows disconnected state
- Restart backend -> verify app recovers without restart

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("axiom:axiom-ios-accessibility")` | Accessibility testing | A11y check |
| `Skill("axiom:axiom-ios-performance")` | Performance | Large data/rapid nav |
| `axiom:energy-auditor` agent | Battery drain | Background tasks |
| `axiom:memory-auditor` agent | Memory leaks | Rapid navigation |
| `axiom:concurrency-auditor` agent | Swift 6 compliance | Task/actor safety |

**Features Verified:** Empty states, edge cases, accessibility, offline recovery.
**Evidence Total:** 4 + 5 + 2 + 2 = 13 artifacts.

---

### Phase 9: Documentation & Audit Report

**Objective:** Comprehensive audit report with all 12 sections.

**Report Sections:**
1. Executive Summary -- total artifacts, issues found/fixed, pass rate
2. Gap Analysis Results -- Verified Codebase State table
3. Implementation Summary -- AddMCPServerView details
4. Mandate Verification Results -- 9/9 sub-task verdicts
5. Visual Audit Results -- iPhone (19), iPad (4), macOS (5) verdicts
6. Functional Audit Results -- data loading, interactions, errors, deep links
7. Backend Audit Results -- 10 endpoints, env masking, consistency
8. Integration Validation Results -- correlated pairs, mutations, mock check
9. Proactive Bug Hunt Results -- empty states, edge cases, a11y, offline
10. Design Decisions -- D1-D6 with rationale
11. Recommendations -- future work
12. Evidence Index -- complete file list with PASS/FAIL

**Required Skills:**
| Skill | Purpose | When |
|-------|---------|------|
| `Skill("verification-before-completion")` | Final checks | Before report |

**Features Verified:** Report completeness and accuracy.
**Evidence Total:** 1 artifact (AUDIT_REPORT.md).

---

## Existing Audit Backlog (39 Findings)

Source: `.claude/skills/ils-ios-project/references/audit-backlog.md`

### CRITICAL (9 issues -- fix before App Store)

| # | File | Issue | Impact |
|---|------|-------|--------|
| C1 | `ILSAppApp.swift:56` | Launch animation ignores reduce motion | Accessibility violation |
| C2 | `ProgressRing.swift:44` | Ring animation ignores reduce motion | Accessibility violation |
| C3 | `StatCard.swift:59` | Press scale animation ignores reduce motion | Accessibility violation |
| C4 | `UserMessageCard.swift:15` | `UIScreen.main.bounds` breaks iPad Split View | iPad layout broken |
| C5 | `MessageView.swift:226` | `MarkdownParser.parse()` runs every body eval | Performance regression |
| C6 | `ThemeMarketplaceView.swift:230` | `filteredThemes` computed every body eval | Performance regression |
| C7 | `ILSAppApp.swift` | Forced `.colorScheme(.dark)` throughout app | System integration broken |
| C8 | `SidebarRootView.swift` | Custom hamburger sidebar blocks system gestures | UX violation |
| C9 | Multiple files | Inconsistent `navigationBarTitleDisplayMode` | Visual inconsistency |

### HIGH (13 issues -- fix for quality)

| # | File | Issue |
|---|------|-------|
| H1 | `BrowserView.swift:82` | Custom segmented control not accessible |
| H2 | `SidebarSessionRow.swift:52` | Touch target ~24pt, below 44pt HIG minimum |
| H3 | `HomeView.swift:242` | Custom `relativeTime()` not localized |
| H4 | 50+ files | Hardcoded font sizes bypass theme typography |
| H5 | `SidebarRootView.swift` | Size class fork mishandles iPhone Pro Max landscape |
| H6 | `BrowserView.swift` | `.contains()` on arrays -- O(n) lookup |
| H7 | `ThemePickerView.swift` | O(n^2) contains check |
| H8 | `MetricsWebSocketClient.swift:30-32` | `nonisolated(unsafe)` Task properties -- data race risk |
| H9 | `SubscriptionManager.swift:80` | Fire-and-forget init Task with no handle |
| H10 | `PluginsViewModel.swift:27` | `nonisolated(unsafe)` search task |
| H11 | `SkillsViewModel.swift:43` | `nonisolated(unsafe)` search task |
| H12 | `ScreenshotProtectionModifier.swift` | Animation without reduce motion check |
| H13 | `ShimmerModifier.swift` | GeometryReader in overlay |

### MEDIUM (15 issues -- address for polish)

Key items: `SSEClient` still using `ObservableObject` (M5), `HooksManagementView` 8pt font (M9), `SystemMonitorView` using `onAppear { Task {} }` instead of `.task` (M11), 109 VStack/HStack without explicit spacing (M14).

### LOW (2 issues)

L1: `NotificationManager.swift` UNUserNotificationCenter delegate (benign). L2: `SSHSetupView` raw color values.

---

## Design Decisions (Resolved)

These are NOT audit tasks -- they are resolved decisions that inform VERIFY vs IMPLEMENT.

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Extended Thinking toggle: editable? | **Read-only** with "Host Default" badge | CLI-level setting; mobile reflects, does not control |
| D2 | Co-authored-by toggle: editable? | **Read-only** with "Host Default" badge | Same as D1 |
| D3 | MCP creation UI: include env vars? | **Omit** env vars | Security-sensitive; configure via CLI/Config Editor |
| D4 | Quick Actions: "New Session" vs spec's "Claude Settings"? | **Keep "New Session"** | Settings accessible from sidebar; "New Session" is primary UX action |
| D5 | iPad layout: dedicated pass? | **OUT OF SCOPE** | Adaptive iPhone layout sufficient; verify no broken layouts |
| D6 | macOS feature parity? | **OUT OF SCOPE** | Spec defines iOS views only; verify existing 11 macOS views |

---

## Evidence Manifest Summary

| Phase | Screenshots | JSON/Text | Other | Total |
|-------|-----------|-----------|-------|-------|
| 0 - Build | 0 | 3 | 0 | 3 |
| 1 - Inventory | 10 | 0 | 2 (video+logs) | 12 |
| 2 - Gap Fix | 3 | 0 | 0 | 3 |
| 3 - Mandates | 14 | 0 | 0 | 14 |
| 4 - Visual | 28 (19+4+5) | 0 | 1 (fixes log) | 29 |
| 5 - Functional | 7+ | 1 | 1 (fixes log) | 9+ |
| 6 - Backend | 0 | 11 | 0 | 11 |
| 7 - Integration | 5 | 5 | 0 | 10 |
| 8 - Bug Hunt | 11 | 1 | 1 (bugfix log) | 13 |
| 9 - Report | 0 | 1 | 0 | 1 |
| **Total** | **78+** | **22** | **5** | **105+** |

---

## Anti-Features (Do NOT Build During Audit)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Unit tests / test files | CLAUDE.md global mandate -- no mocks/stubs/tests | Validate through real UI + screenshots |
| iPad dedicated layout | OUT OF SCOPE (D5) -- separate initiative | Verify no broken layouts only |
| macOS feature parity | OUT OF SCOPE (D6) -- separate initiative | Verify existing 11 views only |
| MCP env var editor | Security concern (D3) -- API keys in UI | Configure via CLI or Config Editor |
| Extended Thinking toggle edit | CLI-level setting (D1) | Keep read-only with Host Default badge |
| Architecture redesign | Audit is verify + targeted fixes only | Fix specific issues, not structure |
| New dependencies | Unless strictly required for a gap fix | Use existing patterns |

---

## MVP Recommendation (Audit Execution Order)

The audit plan is already well-ordered. The critical path is:

1. **Phase 0** -- Build verification (GATE: all 3 targets compile)
2. **Phase 1** -- Before-state screenshots (establishes baseline)
3. **Phase 2** -- AddMCPServerView (NOW DONE -- verify only)
4. **Phase 3** -- Mandate verification (9 sub-tasks with evidence)
5. **Phase 4** -- Visual audit (19 + 4 + 5 = 28 screenshots)
6. **Phase 5** -- Functional audit (interactions, data, errors)
7. **Phase 6** -- Backend audit (10 endpoints, env masking)
8. **Phase 7** -- Integration validation (correlated evidence)
9. **Phase 8** -- Proactive bug hunt (edge cases, a11y, offline)
10. **Phase 9** -- Report generation (12-section document)

**Defer:** Audit backlog fixes (39 items) should be addressed opportunistically during Phases 4-8 when the relevant screen is being audited. Do NOT create a separate remediation pass -- fix issues as you encounter them during the audit.

---

## Sources

- `docs/ils.md` -- Master Build Orchestration Specification (4,300+ lines)
- `.omc/plans/ils-comprehensive-audit-remediation.md` -- Audit plan v3 (1,370 lines)
- `.claude/skills/ils-ios-project/references/audit-backlog.md` -- 39 prioritized findings
- `ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift` -- Implemented gap (207 lines)
- `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` -- `addServer()` at line 107
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift` -- Add button + sheet integration
- Glob results: 65 iOS view files, 11 macOS view files, 14 backend controllers
