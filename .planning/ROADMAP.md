# Roadmap -- ILS iOS/macOS

## Milestones

- ✅ **v1.0 Cross-Platform Audit** - Phases 1-10 (shipped 2026-02-21)
- ✅ **v2.0 Performance Optimization Suite** - Phases 11-17 (shipped 2026-02-24)
- ✅ **v3.0 Comprehensive Audit Remediation** - Phases 18-24 (shipped 2026-02-23)
- ✅ **v1.5 All Audit Fixes** - Phases 25-32 (shipped 2026-02-24)
- ✅ **v3.1 Comprehensive Audit, Bug Fix & UX Overhaul** - Phases 33-39 (shipped 2026-02-25)
- ✅ **v3.5 Comprehensive Functional Validation** - Phases 40-42 (iPhone complete, iPad deferred)
- ✅ **v4.0 Comprehensive Spec Compliance Audit & Remediation** - Phases 43-48 (Gate PASS, 123 evidence artifacts)
- 🚧 **v5.0 Cross-Platform Feature Completion & 30-Gate Audit** - Phases 49-56 (in progress)

## Phases

<details>
<summary>v1.0 Cross-Platform Audit (Phases 1-10) -- SHIPPED 2026-02-21</summary>

Phases 1-10: Discovery, Navigation, Settings, Skills/Plugins/Hooks, System Monitor, Backend API, Visual Consistency, Sessions Deep Dive, macOS Parity, Final Validation. 15/15 REQs PASS.

</details>

<details>
<summary>v2.0 Performance Optimization Suite (Phases 11-17) -- SHIPPED 2026-02-24</summary>

Phases 11-17: Launch Performance, Network Optimization, Memory Optimization, Battery Optimization, Render Performance, Compatibility, Regression Tests. All performance targets met.

</details>

<details>
<summary>v3.0 Comprehensive Audit Remediation (Phases 18-24) -- SHIPPED 2026-02-23</summary>

Phases 18-24: 165 audit issues remediated across concurrency, energy, architecture, performance, navigation, Codable, build, accessibility, database, networking, security, memory, layout, modernization.

</details>

<details>
<summary>v1.5 All Audit Fixes (Phases 25-32) -- SHIPPED 2026-02-24</summary>

Phases 25-32: 50 REQs, 70/70 audit findings resolved. Code quality hardening.

</details>

<details>
<summary>v3.1 Comprehensive Audit, Bug Fix & UX Overhaul (Phases 33-39) -- SHIPPED 2026-02-25</summary>

Phases 33-39: Navigation overhaul, Home/Dashboard, Config/Settings, Browser, System Monitor, Cross-Platform, Final Validation. 31/31 REQs PASS.

</details>

<details>
<summary>v3.5 Comprehensive Functional Validation (Phases 40-42) -- iPhone COMPLETE, iPad deferred</summary>

Phases 40-42: iPhone validation 23/23 PASS. iPad deferred to v4.0 audit phase.

</details>

<details>
<summary>v4.0 Comprehensive Spec Compliance Audit & Remediation (Phases 43-48) -- COMPLETE 2026-02-28</summary>

Phases 43-48: iOS UI Gap Remediation, Platform & Performance Compliance, Data & Backend Hardening, Security & Compliance, Ecosystem Polish, Comprehensive Audit & Verification. 34/34 REQs PASS. Gate PASS. 123 evidence artifacts.

</details>

### v5.0 Cross-Platform Feature Completion & 30-Gate Audit

**Milestone Goal:** Implement all remaining features (config inheritance, GitHub browse/install, hooks CRUD, profile switching), achieve full cross-platform parity, and validate every screen on every platform through a rigorous 30-gate audit framework.

- [x] **Phase 49: Foundation -- Fleet-to-HostProfile Rename** - Rename "Fleet" to "Host Profiles" across all targets, API routes (with backward aliases), deep links, and UI; set up evidence pipeline (completed 2026-02-28)
- [ ] **Phase 50: Backend API -- Config Endpoint & Audit** - Add GET /config/effective endpoint with merged config and scope annotations; audit all endpoints for correct error codes and JSON structure
- [ ] **Phase 51: Settings & Config Inheritance** - Config cascade visualization with "inherited from host" vs "custom override" badges; system prompt and model defaults from host CLI; info tooltips on all settings
- [ ] **Phase 52: Hooks & Status Management** - Expand hooks to all 16 event types with CRUD editor (4 handler types); add active/inactive toggles for skills and plugins
- [ ] **Phase 53: GitHub Browse & Install** - GitHub skill/plugin browsing with search, category filtering, and preview; one-tap install with progress and error handling
- [ ] **Phase 54: Navigation, Profiles & Polish** - Home quick actions, recent sessions data consistency, profile switching with visual feedback, real-time system metrics, node_modules filtering
- [ ] **Phase 55: Visual Audit -- iPhone, iPad & Mac** - Screenshot evidence across all 3 platforms with numbered artifacts (15+ iPhone, 15+ iPad, 10+ Mac)
- [ ] **Phase 56: Functional Audit & Bug Hunt** - End-to-end feature verification across platforms; 20+ edge case scenarios tested

## Phase Details

### Phase 49: Foundation -- Fleet-to-HostProfile Rename
**Goal**: All traces of "Fleet" terminology are replaced with "Host Profiles" across every target, with backward-compatible API route aliases and deep link preservation
**Depends on**: Nothing (first v5.0 phase)
**Requirements**: FOUND-01, FOUND-03
**Success Criteria** (what must be TRUE):
  1. Every Swift file, UI label, and navigation item reads "Host Profiles" instead of "Fleet" -- no remnants of old terminology visible anywhere in the app
  2. Old API routes (`/api/v1/fleet/*`) still return valid responses (backward-compatible aliases exist alongside new `/api/v1/host-profiles/*` routes)
  3. Deep link `ils://fleet` continues to navigate to the Host Profiles screen; `ils://host-profiles` also works
  4. Evidence capture pipeline (`evidence/` directory) is operational -- running the capture script produces numbered screenshot artifacts on iPhone simulator
**Plans**: 49-01 (ILSShared + backend rename, dual routes), 49-02 (iOS path strings, deep link, pbxproj, evidence pipeline)

### Phase 50: Backend API -- Config Endpoint & Audit
**Goal**: A new config merge endpoint exists that returns the effective configuration with per-key scope annotations, and all existing endpoints return proper HTTP error codes
**Depends on**: Phase 49
**Requirements**: API-01, API-02
**Success Criteria** (what must be TRUE):
  1. `GET /api/v1/config/effective` returns JSON with merged config values and a `winningScope` annotation (user/project/local/managed) for each key
  2. All API endpoints return appropriate HTTP status codes for errors (400 for bad input, 404 for missing resources, 500 for server errors) -- not 200-with-error-body
  3. cURL against every backend endpoint confirms JSON structure matches expected field names and nesting
**Plans**: 50-01 (ConfigScope managed case, EffectiveConfig DTO, merge logic, /config/effective route), 50-02 (try? error audit on mutation paths in MCPController and PluginsController)

### Phase 51: Settings & Config Inheritance
**Goal**: Users see exactly which settings are inherited from the connected host vs locally overridden, with contextual help on every control
**Depends on**: Phase 50 (needs /config/effective endpoint)
**Requirements**: CFG-01, CFG-02, CFG-03
**Success Criteria** (what must be TRUE):
  1. Each setting row in the Settings screen displays an "Inherited" badge (when value comes from host CLI) or "Custom" badge (when user has overridden it)
  2. System prompt and model picker show the connected host's CLI defaults as the inherited value -- not hardcoded fallbacks
  3. Tapping an info tooltip on any tool control, permission, or settings section reveals explanatory text of at least 20 words describing what the setting does
  4. Toggling a setting from "Inherited" to "Custom" persists the override and the badge updates immediately
**Plans**: TBD

### Phase 52: Hooks & Status Management
**Goal**: Users can view, create, edit, and delete hooks for all Claude Code event types, and toggle skill/plugin active status
**Depends on**: Phase 51 (uses saveWithPatch config write pattern from settings work)
**Requirements**: SKILL-05, SKILL-06, SKILL-07
**Success Criteria** (what must be TRUE):
  1. Hooks management screen lists hooks grouped by all 16 Claude Code event types (PreToolUse, PostToolUse, Notification, Stop, SubagentStart, SubagentStop, etc.) -- not just the original 5
  2. User can create a new hook by selecting an event type, choosing a handler type (command, prompt, agent, or http), and filling in the handler configuration
  3. User can edit an existing hook's matcher pattern, handler type, and handler configuration, and delete hooks -- changes persist across app restarts
  4. Skills and plugins in the browser display an active/inactive status indicator, and tapping the toggle changes the state with visual feedback
**Plans**: TBD

### Phase 53: GitHub Browse & Install
**Goal**: Users can discover and install skills and plugins directly from GitHub without leaving the app
**Depends on**: Phase 49 (stable codebase after rename)
**Requirements**: SKILL-01, SKILL-02, SKILL-03, SKILL-04
**Success Criteria** (what must be TRUE):
  1. Browser view includes a "Discover" tab where users can search GitHub for skills by keyword, with results showing name, description, and star count
  2. Tapping a search result shows a preview with README content, file listing, and an Install button
  3. Installing a skill from GitHub shows a progress indicator, handles network errors gracefully with retry option, and the skill appears in the local skills list after install
  4. The same browse/search/preview/install flow works identically for plugins (symmetric UX)
  5. Search results are debounced and cached to avoid GitHub API rate limit errors
**Plans**: TBD

### Phase 54: Navigation, Profiles & Polish
**Goal**: Home screen is immediately useful with quick actions and consistent data, and profile switching gives clear feedback about which host config is active
**Depends on**: Phase 49 (Host Profile rename complete)
**Requirements**: NAV-01, NAV-02, PROF-01, PROF-02, FOUND-02
**Success Criteria** (what must be TRUE):
  1. Home screen displays quick action shortcuts (e.g., New Session, Browse Skills, Configure MCP) above the recent sessions list
  2. Recent sessions on the Home screen show the exact same data (count, order, content) as the dedicated Sessions screen -- no discrepancy
  3. Switching host profiles updates the settings context and a visual indicator (banner or badge) confirms which host's configuration is currently active
  4. System monitor displays real-time CPU, memory, disk, and network metrics from the connected host -- values update while the screen is visible
  5. Skills file scanning confirmed to exclude `node_modules` directories -- installing a JS-based skill does not surface thousands of dependency files
**Plans**: TBD

### Phase 55: Visual Audit -- iPhone, iPad & Mac
**Goal**: Every screen on every platform has numbered screenshot evidence confirming correct layout and content
**Depends on**: Phase 50, Phase 51, Phase 52, Phase 53, Phase 54 (all implementation complete)
**Requirements**: GATE-01, GATE-02, GATE-03
**Success Criteria** (what must be TRUE):
  1. 15+ numbered screenshot artifacts exist for iPhone covering every major screen (Home, Sessions, Chat, Browser/Skills/Plugins/MCP, Settings, Host Profiles, System Monitor, Hooks, Themes)
  2. 15+ numbered screenshot artifacts exist for iPad showing correct NavigationSplitView layout with sidebar and detail panes
  3. 10+ numbered screenshot artifacts exist for Mac showing proper macOS chrome, menu bar, and keyboard shortcut indicators
  4. All screenshots show real data (not empty states) and correct theming
**Plans**: TBD

### Phase 56: Functional Audit & Bug Hunt
**Goal**: Every feature area works end-to-end across platforms, and edge cases are systematically tested and documented
**Depends on**: Phase 55 (visual audit complete, all screens verified)
**Requirements**: GATE-04, GATE-05
**Success Criteria** (what must be TRUE):
  1. Functional audit confirms real data flows on all platforms -- sessions load, chat opens, browser displays skills/plugins/MCP, settings persist, profile switching works, hooks CRUD operates
  2. Config inheritance badges reflect actual host values (verified by comparing app display to `claude config show` CLI output)
  3. 20+ edge case scenarios are tested and documented with evidence: offline behavior, empty states, rapid navigation, accessibility (VoiceOver), memory pressure, large data sets, malformed API responses
  4. Zero CRITICAL bugs remain -- any found during bug hunt are fixed before gate closes
**Plans**: TBD

## Progress

**Execution Order:**
Phases 49-50 are sequential (rename first, then API). Phase 51 depends on 50. Phase 52 depends on 51. Phase 53 depends on 49 (can run in parallel with 51-52 after rename). Phase 54 depends on 49. Phase 55 requires all implementation phases (50-54) complete. Phase 56 requires Phase 55.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 49. Foundation -- Fleet-to-HostProfile Rename | v5.0 | Complete    | 2026-02-28 | - |
| 50. Backend API -- Config Endpoint & Audit | v5.0 | 0/2 | Planned | - |
| 51. Settings & Config Inheritance | v5.0 | 0/TBD | Not started | - |
| 52. Hooks & Status Management | v5.0 | 0/TBD | Not started | - |
| 53. GitHub Browse & Install | v5.0 | 0/TBD | Not started | - |
| 54. Navigation, Profiles & Polish | v5.0 | 0/TBD | Not started | - |
| 55. Visual Audit -- iPhone, iPad & Mac | v5.0 | 0/TBD | Not started | - |
| 56. Functional Audit & Bug Hunt | v5.0 | 0/TBD | Not started | - |
