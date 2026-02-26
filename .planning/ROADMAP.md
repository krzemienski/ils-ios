# Roadmap -- ILS iOS/macOS

## Milestones

- ✅ **v1.0 Cross-Platform Audit** - Phases 1-10 (shipped 2026-02-21)
- ✅ **v2.0 Performance Optimization Suite** - Phases 11-17 (shipped 2026-02-24)
- ✅ **v3.0 Comprehensive Audit Remediation** - Phases 18-24 (shipped 2026-02-23)
- ✅ **v1.5 All Audit Fixes** - Phases 25-32 (shipped 2026-02-24)
- ✅ **v3.1 Comprehensive Audit, Bug Fix & UX Overhaul** - Phases 33-39 (shipped 2026-02-25)
- ✅ **v3.5 Comprehensive Functional Validation** - Phases 40-42 (iPhone complete, iPad deferred)
- 🚧 **v4.0 Comprehensive Spec Compliance Audit & Remediation** - Phases 43-48 (in progress)

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

### v4.0 Comprehensive Spec Compliance Audit & Remediation

**Milestone Goal:** Close every gap between the 3 original ILS build specs and the current app. Zero CRITICAL/HIGH gaps remaining. 20+ evidence artifacts. All gate checks PASS.

**FIX_PROTOCOL:** Every fix goes through axiom skill -> axiom:ask -> implement -> rebuild -> evidence.

- [x] **Phase 43: iOS UI Gap Remediation** - Close all 6 UI gaps: Quick Actions, Quick Settings, GitHub search, session overflow, rate limit UX, animation timing ✓ 2026-02-25
- [ ] **Phase 44: Platform & Performance Compliance** - Live Activity, concurrency modernization, render optimization, TipKit tips
- [ ] **Phase 45: Data & Backend Hardening** - Type-safe DTOs, caching verification, offline indicators, input validation
- [ ] **Phase 46: Security & Compliance** - Per-route auth, request limits, GDPR deletion, StoreKit verification
- [ ] **Phase 47: Ecosystem Polish** - Plugin versioning, dependency management, MeshGradient themes, String Catalog migration
- [ ] **Phase 48: Comprehensive Audit & Verification** - Visual/functional/backend/integration audits on iPhone+iPad, proactive bug hunt

## Phase Details

### Phase 43: iOS UI Gap Remediation
**Goal**: Every iOS screen matches its original spec -- missing UI elements are built, wired, and visually correct
**Depends on**: Nothing (first v4.0 phase)
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06
**Success Criteria** (what must be TRUE):
  1. HomeView displays a Quick Actions row with working navigation shortcuts to Discover Skills, Browse Plugins, Configure MCP, and Edit Settings
  2. Settings screen shows Quick Settings toggles (Model picker, Extended Thinking, Co-authored-by) below the config editor that persist changes
  3. BrowserView skill search includes a "Discovered from GitHub" section with Install buttons that trigger real installs
  4. ChatView session overflow menu offers Rename, Export, Fork, and Delete operations that complete successfully
  5. GitHub rate limit errors display a user-facing "try again in X seconds" countdown instead of a generic error
**Plans:** 2 plans

Plans:
- [ ] 43-01-PLAN.md -- Implement Quick Actions labels + Edit Settings card, rate limit countdown timer, animation timing fix (UI-01, UI-05, UI-06)
- [ ] 43-02-PLAN.md -- Functional validation of all 6 UI requirements with screenshot evidence (UI-01 through UI-06)

### Phase 44: Platform & Performance Compliance
**Goal**: Platform-specific capabilities (Live Activity, TipKit, render optimization) work correctly and match spec expectations
**Depends on**: Phase 43
**Requirements**: PLAT-01, PLAT-02, PLAT-03, PLAT-04, PLAT-05, PLAT-06, PLAT-07, PLAT-08
**Success Criteria** (what must be TRUE):
  1. Dynamic Island shows compact and expanded Live Activity views during active chat sessions with real streaming data
  2. No DispatchQueue.main.asyncAfter calls remain -- all replaced with Task-based structured concurrency
  3. ChatView and BrowserView use .equatable() and shadow-heavy views use drawingGroup() for measurably smoother scrolling
  4. TipKit tips appear for Theme, MCP, and Teams features with sequential unlock rules and after-N-opens triggers
  5. URLSession cellular constraints are applied in APIClient, observable in Settings as a data usage preference
**Plans**: TBD

Plans:
- [ ] 44-01: TBD
- [ ] 44-02: TBD

### Phase 45: Data & Backend Hardening
**Goal**: Backend DTOs are type-safe, caching behaves correctly, and offline state is clearly communicated to users
**Depends on**: Phase 43
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06
**Success Criteria** (what must be TRUE):
  1. MCP server scope uses a ConfigScope enum in ILSShared instead of raw strings -- compiler catches invalid scopes
  2. DashboardStats is a standalone DTO in ILSShared with typed fields, verified by cURL against /api/v1/stats
  3. Home, Sessions, and Browser views display "Last updated X ago" indicators when showing cached data
  4. Chat message drafts survive app restart -- type a message, kill the app, relaunch, draft is restored
  5. ILSShared model initializers reject invalid input (empty strings, negative counts, malformed UUIDs) with clear errors
**Plans**: TBD

Plans:
- [ ] 45-01: TBD
- [ ] 45-02: TBD

### Phase 46: Security & Compliance
**Goal**: The app enforces per-route authorization, request limits, GDPR data deletion, and verified StoreKit flows
**Depends on**: Phase 45
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05
**Success Criteria** (what must be TRUE):
  1. Backend distinguishes admin vs user roles on sensitive routes -- non-admin requests to admin-only endpoints return 403
  2. Oversized requests (beyond configured limit) are rejected by Vapor middleware with a clear error response
  3. A single "Delete All My Data" endpoint exists and aggregates deletion across sessions, messages, config, and cache
  4. StoreKit free trial configuration loads correctly in sandbox -- trial period is displayed on the paywall
  5. Receipt validation completes via StoreKit 2 server-side flow -- premium status updates immediately after purchase
**Plans**: TBD

Plans:
- [ ] 46-01: TBD
- [ ] 46-02: TBD

### Phase 47: Ecosystem Polish
**Goal**: Plugins show version info with update availability, dependencies are validated, themes support MeshGradient, and strings use String Catalog format
**Depends on**: Phase 44
**Requirements**: ECO-01, ECO-02, ECO-03, ECO-04
**Success Criteria** (what must be TRUE):
  1. Plugin detail view shows current version and indicates when an update is available with an Update button
  2. Installing a plugin with missing dependencies shows a warning listing unmet dependencies before proceeding
  3. Theme editor supports MeshGradient backgrounds -- creating or editing a theme with MeshGradient renders correctly
  4. All localizable strings use .xcstrings String Catalog format -- no .lproj/Localizable.strings files remain
**Plans**: TBD

Plans:
- [ ] 47-01: TBD
- [ ] 47-02: TBD

### Phase 48: Comprehensive Audit & Verification
**Goal**: Every screen on iPhone and iPad is visually verified, every backend endpoint returns spec-compliant JSON, and no edge-case bugs remain
**Depends on**: Phase 43, Phase 44, Phase 45, Phase 46, Phase 47 (all remediation complete)
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04, AUDIT-05
**Success Criteria** (what must be TRUE):
  1. 20+ numbered screenshot artifacts exist covering every screen on both iPhone and iPad with correct layout and content
  2. Functional audit confirms real data flows on both devices -- sessions load, chat works, browser displays real skills/plugins/MCP
  3. cURL evidence for every backend endpoint shows JSON structure matching the spec contract (field names, types, nesting)
  4. Correlated backend+frontend evidence pairs demonstrate data flows end-to-end (e.g., POST session -> session appears in list)
  5. Proactive bug hunt documents edge cases tested (offline, empty states, accessibility, memory) with evidence for each
**Plans**: TBD

Plans:
- [ ] 48-01: TBD
- [ ] 48-02: TBD
- [ ] 48-03: TBD

## Progress

**Execution Order:**
Phases 43, 44, 45 can partially overlap (independent). Phase 46 depends on 45. Phase 47 depends on 44. Phase 48 requires all prior phases complete.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 43. iOS UI Gap Remediation | v4.0 | 2/2 | Complete ✓ | 2026-02-25 |
| 44. Platform & Performance Compliance | v4.0 | 0/? | Not started | - |
| 45. Data & Backend Hardening | v4.0 | 0/? | Not started | - |
| 46. Security & Compliance | v4.0 | 0/? | Not started | - |
| 47. Ecosystem Polish | v4.0 | 0/? | Not started | - |
| 48. Comprehensive Audit & Verification | v4.0 | 0/? | Not started | - |
