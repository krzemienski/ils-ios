# Unified Context Document — ILS iOS/macOS Cross-Platform Audit

**Gate:** VG-04 | **Status:** PASS | **Date:** 2026-02-21
**Synthesized from:** codebase-inventory.json (Task 1.1), tech-research-summary.md (Task 1.2), ux-platform-audit.md (Task 1.3), api-audit-report.md (pre-existing)

---

## 1. Fix Registry

Every issue assigned an ID, severity, affected files, affected screens, and owning phase.

| Fix ID | Severity | Title | Affected Files | Affected Screens | REQs | Owning Phase |
|--------|----------|-------|----------------|------------------|------|--------------|
| FIX-001 | CRITICAL | Model defaults to Sonnet instead of host CLI value | SettingsViewModel.swift, NewSessionView.swift | Settings, New Session | REQ-03 | Phase 3 |
| FIX-002 | CRITICAL | No hooks management screen | New: HooksManagementView.swift, HooksViewModel.swift | Settings (new screen) | REQ-06 | Phase 4 |
| FIX-003 | CRITICAL | Fleet API returns 500 Internal Server Error | FleetController.swift | Fleet | REQ-08, REQ-13 | Phase 6 |
| FIX-004 | HIGH | Themes API returns 0 items | ThemesController.swift, ThemeManager.swift | Themes | REQ-11 | Phase 4 |
| FIX-005 | HIGH | "Fleet" terminology must be renamed to "Hosts/Profiles" | FleetManagementView.swift, FleetHostDetailView.swift, FleetViewModel.swift, SidebarView.swift, SidebarRootView.swift (ActiveScreen enum), FleetController.swift, FleetDTOs.swift, CreateFleetHosts migration | Fleet, Sidebar | REQ-08 | Phase 5 |
| FIX-006 | HIGH | MCP env vars shown in plain text (security) | MCPServerDetailView.swift | Browser > MCP Detail | -- | Phase 4 |
| FIX-007 | HIGH | SidebarSessionRow touch target ~24pt (should be >= 44pt) | SidebarSessionRow.swift | Sidebar | -- | Phase 2 |
| FIX-008 | HIGH | Missing tooltips on 3 settings items | SettingsConfigSection.swift | Settings | REQ-10 | Phase 3 |
| FIX-009 | HIGH | GitHub browse/install not fully integrated | BrowserView.swift, SkillsViewModel.swift, PluginsViewModel.swift | Browser | REQ-05 | Phase 4 |
| FIX-010 | HIGH | Config endpoint missing model/systemPrompt fields | ConfigFileService.swift, ConfigController.swift | Settings | REQ-02, REQ-03 | Phase 3 |
| FIX-011 | MEDIUM | Animations ignore accessibilityReduceMotion | LaunchScreenView.swift, SystemMonitorView.swift, StreamingIndicatorView.swift | Launch, System Monitor, Chat | -- | Phase 7 |
| FIX-012 | MEDIUM | Custom segmented control not accessible (VoiceOver) | BrowserView.swift | Browser | -- | Phase 4 |
| FIX-013 | MEDIUM | Themes screen is orphaned route (no sidebar nav) | SidebarView.swift | Sidebar, Themes | REQ-11 | Phase 4 |
| FIX-014 | MEDIUM | Reset-to-inherited not implemented for settings | SettingsConfigSection.swift, SettingsViewModel.swift | Settings | REQ-02 | Phase 3 |
| FIX-015 | MEDIUM | Plugin install tracked by name (collision risk) | PluginsViewModel.swift | Browser > Plugins | -- | Phase 4 |
| FIX-016 | MEDIUM | Network section display incomplete in System Monitor | SystemMonitorView.swift | System Monitor | REQ-07 | Phase 5 |
| FIX-017 | MEDIUM | Fleet should graduate from DEBUG to production | SidebarView.swift | Sidebar | REQ-08 | Phase 5 |
| FIX-018 | MEDIUM | Tunnel status missing APIResponse wrapper | TunnelController.swift | Settings > Remote Access | REQ-13 | Phase 6 |
| FIX-019 | MEDIUM | System metrics has no JSON snapshot mode (SSE only) | SystemController.swift | System Monitor | REQ-07 | Phase 6 |
| FIX-020 | LOW | TeamsViewModel uses Timer instead of Task-based polling | TeamsViewModel.swift | Agent Teams | -- | Phase 7 |
| FIX-021 | LOW | MCPServer.id is mutable (var vs let) | MCPServer.swift | -- | -- | Phase 7 |
| FIX-022 | LOW | ThemeMarketplaceView + ThemePreviewView appear dead | ThemeMarketplaceView.swift, ThemePreviewView.swift | -- | -- | Phase 7 |
| FIX-023 | LOW | Code block performance on long outputs | CodeBlockView.swift | Chat | -- | Phase 7 |

**Total: 23 fixes | 3 CRITICAL | 7 HIGH | 10 MEDIUM | 3 LOW**

---

## 2. Requirements Traceability

Every REQ-01 through REQ-15 mapped to fix registry entries and owning phases.

| REQ-ID | Requirement | Fix IDs | Status | Owning Phase | Notes |
|--------|-------------|---------|--------|--------------|-------|
| REQ-01 | Sidebar on all platforms | -- | PASS | Phase 2 | Already works: hamburger iPhone, persistent iPad, NavigationSplitView Mac |
| REQ-02 | Config inherits from host CLI | FIX-010, FIX-014 | PARTIAL | Phase 3 | InheritanceBadge exists but config API doesn't expose full merged config; reset-to-inherited missing |
| REQ-03 | Model defaults correctly | FIX-001, FIX-010 | FAIL | Phase 3 | Defaults to Sonnet, not host CLI value. Config API missing model field |
| REQ-04 | Accurate skills data | -- | PASS | Phase 4 (verify) | No node_modules contamination. 3500 skills from correct paths |
| REQ-05 | Plugins with GitHub browse/install | FIX-009 | PARTIAL | Phase 4 | Backend GitHubService exists; frontend integration incomplete |
| REQ-06 | Hooks management screen | FIX-002 | FAIL | Phase 4 | No HooksManagementView exists. New feature required |
| REQ-07 | Real-time system monitor | FIX-016, FIX-019 | PARTIAL | Phase 5 | WebSocket works but network display and snapshot mode need attention |
| REQ-08 | Fleet -> Profiles rename | FIX-003, FIX-005, FIX-017 | FAIL | Phase 5 | API 500, terminology unchanged, DEBUG-only |
| REQ-09 | Quick actions above sessions | -- | PASS | -- | Already correct in HomeView.swift code ordering |
| REQ-10 | All settings have explanations | FIX-008 | PARTIAL | Phase 3 | 5/8 settings have tooltips, 3 missing |
| REQ-11 | Default themes restored | FIX-004, FIX-013 | FAIL | Phase 4 | API returns 0 themes; orphaned sidebar route |
| REQ-12 | MCP servers registered | -- | PASS | Phase 6 (verify) | 16 servers, all healthy |
| REQ-13 | API endpoints correct | FIX-003, FIX-018, FIX-019 | PARTIAL | Phase 6 | Fleet 500, tunnel missing wrapper, metrics SSE-only |
| REQ-14 | Zero visual regressions | -- | PENDING | Phase 8 | Requires full platform validation after fixes |
| REQ-15 | Sessions data consistency | -- | PASS (code) | Phase 2 (verify) | Same SessionsViewModel used, different views. Needs functional verification |

**Summary: 4 PASS | 4 PARTIAL | 4 FAIL | 3 PENDING/VERIFY**

---

## 3. Dependency Graph

Fixes that depend on other fixes. No circular dependencies.

```
FIX-001 (model defaults) ──depends-on──> FIX-010 (config API fix)
    Reason: Model default can only show host CLI value if config API exposes it

FIX-014 (reset-to-inherited) ──depends-on──> FIX-010 (config API fix)
    Reason: Reset action needs to know the host default value from API

FIX-002 (hooks management) ──depends-on──> (none, new feature)
    Note: HooksConfig model already exists in ClaudeConfig.swift

FIX-005 (fleet rename) ──depends-on──> FIX-003 (fleet API 500)
    Reason: Fix the API first, then rename terminology

FIX-017 (fleet graduate DEBUG) ──depends-on──> FIX-005 (fleet rename)
    Reason: Rename before making visible in production

FIX-013 (themes sidebar nav) ──depends-on──> FIX-004 (themes API 0 items)
    Reason: No point adding sidebar entry if themes list is empty
```

**Phase execution order respects these dependencies:**
- Phase 2: Navigation fixes (independent)
- Phase 3: Settings + Config (FIX-010 first, then FIX-001, FIX-014, FIX-008)
- Phase 4: Skills/Plugins/Hooks/Themes (FIX-002, FIX-004, FIX-006, FIX-009, FIX-012, FIX-013, FIX-015)
- Phase 5: System Monitor + Profiles (FIX-003 first, then FIX-005, FIX-016, FIX-017)
- Phase 6: Backend API audit (FIX-018, FIX-019, verification of all API fixes)
- Phase 7: Convergence polish (FIX-011, FIX-020, FIX-021, FIX-022, FIX-023)

---

## 4. Risk Assessment

| Risk | Impact | Probability | Mitigation | Affected Phases |
|------|--------|-------------|------------|-----------------|
| Config API refactor breaks existing settings UI | HIGH | MEDIUM | Test SettingsView after every ConfigFileService change; keep backward compat | Phase 3 |
| Fleet rename causes cascade of broken references | MEDIUM | HIGH | Use global grep + systematic rename; run full build after each file | Phase 5 |
| Hooks management is a new feature with no existing code | MEDIUM | LOW | HooksConfig model already exists; follow existing SettingsView patterns | Phase 4 |
| ThemesController change affects custom theme CRUD | MEDIUM | LOW | Return built-in themes as read-only alongside DB themes | Phase 4 |
| NavigationSplitView changes break iPad/iPhone layout | HIGH | LOW | Research confirms current approach is correct; minimal changes needed | Phase 2 |
| accessibilityReduceMotion fixes trigger animation regressions | LOW | MEDIUM | Test with Accessibility Inspector before/after | Phase 7 |

---

## 5. Phase Readiness Checklists

### Phase 2: Navigation + Layout

| Input Required | Source | Available? |
|----------------|--------|------------|
| Navigation hierarchy map | codebase-inventory.json | YES |
| ActiveScreen enum cases | codebase-inventory.json | YES (8 cases mapped) |
| SidebarRootView architecture | tech-research-summary.md Topic 1 | YES |
| SidebarSessionRow touch target issue | ux-platform-audit.md UX-H04 | YES |
| Sessions data consistency analysis | ux-platform-audit.md + codebase-inventory.json | YES |
| Evidence screenshots | evidence/phase-00-discovery/, evidence/phase-02-streams/ | YES |

**Phase 2 readiness: FULLY SATISFIED**

### Phase 3: Settings & Config

| Input Required | Source | Available? |
|----------------|--------|------------|
| Config flow architecture | codebase-inventory.json (config_flow section) | YES |
| CLI config hierarchy (5 levels) | tech-research-summary.md Topic 6 | YES |
| InheritanceBadge current state | codebase-inventory.json + ux-platform-audit.md | YES |
| Settings tooltip inventory | ux-platform-audit.md UX-H05 | YES |
| Model default issue details | ux-platform-audit.md UX-C01 | YES |
| Form/Settings patterns | tech-research-summary.md Topic 3 | YES |
| API audit findings | api-audit-report.md (#8 config) | YES |

**Phase 3 readiness: FULLY SATISFIED**

### Phase 4: Skills, Plugins, Hooks & Themes

| Input Required | Source | Available? |
|----------------|--------|------------|
| Skills data source analysis | codebase-inventory.json (data_sources.skills) | YES |
| MCP security issue | ux-platform-audit.md UX-H03, codebase-inventory.json ISSUE-001 | YES |
| HooksConfig model | codebase-inventory.json (config_flow) | YES |
| Themes architecture | tech-research-summary.md Topic 5 | YES |
| GitHub integration status | ux-platform-audit.md UX-H06 | YES |
| Browser view architecture | codebase-inventory.json (view_inventory.browser) | YES |

**Phase 4 readiness: FULLY SATISFIED**

### Phase 5: System Monitor + Profiles

| Input Required | Source | Available? |
|----------------|--------|------------|
| System metrics data flow | codebase-inventory.json (data_sources.system_metrics) | YES |
| Fleet architecture | codebase-inventory.json (data_sources.fleet) | YES |
| Fleet rename scope | ux-platform-audit.md UX-H02 + fix registry FIX-005 | YES |
| SSH monitoring patterns | tech-research-summary.md Topic 5 | YES |
| Fleet API error details | api-audit-report.md (#14 fleet 500) | YES |

**Phase 5 readiness: FULLY SATISFIED**

### Phase 6: Backend API Audit

| Input Required | Source | Available? |
|----------------|--------|------------|
| Full API endpoint list | codebase-inventory.json (backend_controllers) | YES |
| Existing audit results | api-audit-report.md (15 endpoints tested) | YES |
| Known issues (themes 0, fleet 500, tunnel wrapper, config model) | Fix registry FIX-003, FIX-004, FIX-018, FIX-019 | YES |
| Expected response structures | codebase-inventory.json (shared_dtos) | YES |

**Phase 6 readiness: FULLY SATISFIED**

---

## 6. Architecture Decisions (Confirmed by Research)

| Decision | Rationale | Source |
|----------|-----------|--------|
| Keep custom overlay sidebar on iPhone | NavigationSplitView collapses to full-screen list on compact, not a floating panel | Tech Research Topic 1 |
| Keep NavigationSplitView on iPad | Correct per Apple HIG, already implemented | Tech Research Topic 1 |
| Extend InheritanceBadge to all settings | Foundation already exists in SettingsConfigSection.swift | Tech Research Topic 2 |
| Fix ThemesController to return built-in themes | Simpler than DB seeding; keeps single source of truth in Swift | Tech Research Topic 5 |
| Read config from correct hierarchy paths | Current reads ~/.claude.json (legacy); should read ~/.claude/settings.json | Tech Research Topic 6 |
| No changes to font token system | theme.font* tokens use relative text styles, Dynamic Type works automatically | Tech Research Topic 7 |
| Use Citadel for SSH (already in project) | Best Swift async/await SSH library, already a dependency | Tech Research Topic 5 |

---

## 7. Cross-Cutting Concerns

Issues that span multiple phases and must be coordinated:

### A. Config API Fix (Phases 3 + 6)
The config endpoint refactor (FIX-010) is owned by Phase 3 but also affects Phase 6 API audit. Phase 3 fixes the read path and model exposure. Phase 6 verifies the fix and tests all edge cases.

### B. Fleet Rename (Phases 5 + 2)
Fleet rename (FIX-005) touches the sidebar navigation (Phase 2 territory), but is owned by Phase 5 because the API fix (FIX-003) must come first. Phase 2 should NOT rename Fleet -- leave it for Phase 5.

### C. Themes Pipeline (Phases 4 + 6)
Themes API fix (FIX-004) in Phase 4 adds built-in themes to the API response. Phase 6 then verifies the endpoint returns >= 13 themes.

### D. Settings Completeness (Phases 3 + 4)
Phase 3 fixes the settings UI (inheritance, tooltips, model default). Phase 4 adds hooks management which appears as a new section in settings. These must not conflict.

### E. Accessibility (Phase 7)
Multiple reduce-motion fixes (FIX-011) span LaunchScreenView, SystemMonitorView, and StreamingIndicatorView. All deferred to Phase 7 convergence to avoid blocking core fixes.

---

## 8. Metrics Summary

| Metric | Value |
|--------|-------|
| Total Swift files inventoried | 258 |
| Total screens audited (iOS + macOS) | 54 |
| Total criteria evaluated | 236 (87+87+62) |
| Requirements mapped | 15/15 (100%) |
| Fix registry entries | 23 |
| Critical fixes | 3 |
| Phases with readiness confirmed | 5/5 (Phases 2-6) |
| Cross-cutting concerns identified | 5 |
| Dead code candidates | 3 files |
| Security issues | 1 (MCP env vars plaintext) |
