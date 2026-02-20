# Roadmap: ILS Comprehensive Audit & Remediation

## Overview

A 10-phase audit of the ILS iOS/macOS monorepo that validates every spec-defined feature with screenshot evidence from real data. Phases 0-2 establish the baseline (builds, screenshots, gap fix), Phases 3-5 run the audit core in parallel (mandates, visual, functional), Phases 6-7 verify backend and integration, Phase 8 stress-tests edge cases, and Phase 9 produces the final report. The output is 105+ evidence artifacts proving App Store readiness.

## Phases

**Parallel Execution Groups:**
- **Group A (parallel):** Phase 0 + Phase 1 + Phase 2
- **Group B (parallel):** Phase 3 + Phase 4 + Phase 5
- **Group C (sequential):** Phase 6 -> Phase 7 -> Phase 8 -> Phase 9

- [x] **Phase 0: Build Verification** - All 3 targets build green, correct backend binary confirmed
- [ ] **Phase 1: Screen Inventory** - Before-state screenshots for all 28 screens (19 iPhone + 4 iPad + 5 macOS)
- [ ] **Phase 2: Implementation Gap** - AddMCPServerView verified end-to-end
- [ ] **Phase 3: Mandate Verification** - 9 audit mandates validated with evidence
- [ ] **Phase 4: Visual Audit** - All screens pass visual inspection across 3 platforms
- [ ] **Phase 5: Functional Audit** - All interactive features verified with real data
- [ ] **Phase 6: Backend Audit** - 14 API endpoints verified, security checks passed
- [ ] **Phase 7: Integration Validation** - App data matches backend responses, zero mocks
- [ ] **Phase 8: Edge Cases & Quality** - Empty states, Dynamic Type, VoiceOver, offline recovery
- [ ] **Phase 9: Report & Documentation** - Final audit report with 105+ evidence artifacts

## Phase Details

### Phase 0: Build Verification
**Goal**: Confirm all 3 build targets compile cleanly and backend serves correct responses
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05
**Skills**: `axiom:axiom-ios-build`, `axiom:build-fixer` agent
**Success Criteria** (what must be TRUE):
  1. iOS app builds with zero errors on dedicated simulator (UDID: 50523130)
  2. macOS app builds with zero errors (platform=macOS)
  3. Backend builds with zero errors (swift build)
  4. `lsof -i :9999` shows binary path in `ils-ios/`, not `ils/ILSBackend/`
  5. `curl localhost:9999/api/v1/sessions` returns APIResponse with camelCase keys
**Plans**: 1 plan

Plans:
- [x] 00-01: Parallel build verification (iOS + macOS + Backend) with backend binary validation

### Phase 1: Screen Inventory
**Goal**: Capture before-state screenshots for all screens across iPhone, iPad, and macOS
**Depends on**: Phase 0 (iOS build must succeed, app must be installed)
**Requirements**: SCRN-01, SCRN-02, SCRN-03, SCRN-04, SCRN-05
**Skills**: `ios-simulator-control`, `xclaude-plugin:simulator-workflows`, `ios-ui-automation`, `xclaude-plugin:ui-automation-workflows`
**Success Criteria** (what must be TRUE):
  1. 19 iPhone screenshots captured and visually verified via Read tool
  2. 4 iPad screenshots captured showing adaptive layout
  3. 5 macOS screenshots captured
  4. Evidence directory at `/tmp/ils-audit-evidence/` organized by platform
**Plans**: 2 plans

Plans:
- [x] 01-01: iPhone screenshot capture (19 screens via idb_describe + simulator_screenshot)
- [ ] 01-02: iPad + macOS screenshot capture (4 iPad + 5 macOS)

### Phase 2: Implementation Gap
**Goal**: Verify AddMCPServerView renders, accepts input, submits to backend, and new server appears in list
**Depends on**: Phase 0 (backend must be running)
**Requirements**: IMPL-01, IMPL-02, IMPL-03, IMPL-04, IMPL-05
**Skills**: `axiom:axiom-ios-ui`, `axiom:axiom-hig`, validation gate skills
**Success Criteria** (what must be TRUE):
  1. AddMCPServerView UI renders correctly in Browser > MCP tab
  2. Form accepts server name, command, args, and scope
  3. Submit calls POST /api/v1/mcp and succeeds
  4. New server appears in MCP list after creation
  5. All form elements have 44pt minimum tap targets
**Plans**: 1 plan

Plans:
- [ ] 02-01: AddMCPServerView end-to-end verification with HIG compliance check

### Phase 3: Mandate Verification
**Goal**: Validate all 9 spec-mandated features with screenshot + curl evidence
**Depends on**: Phase 0 (backend running), Phase 2 (MCP creation verified)
**Requirements**: MNDT-01, MNDT-02, MNDT-03, MNDT-04, MNDT-05, MNDT-06, MNDT-07, MNDT-08, MNDT-09
**Skills**: `axiom:axiom-ios-ui`, `axiom:axiom-hig`, `functional-validation`, `ios-validation-gate`
**Success Criteria** (what must be TRUE):
  1. GitHub Skill Search returns results, install button works
  2. MCP Server Creation verified (Phase 2 output)
  3. ConfigEditor scope selector works, JSON validation indicator present
  4. SkillDetailView markdown renders, edit/delete/toggle functional
  5. Settings shows "Host Default" badges on model, color scheme, thinking, coauthor
  6. All UI references show "Hosts" not "Fleet"
  7. System Monitor shows real CPU/Memory/Disk/Network via WebSocket
  8. Hooks screen shows config path, Edit Config, Copy Path, all 5 event types
  9. Plugin GitHub Search returns results, install/enable toggles work
**Plans**: 2 plans

Plans:
- [ ] 03-01: Mandates 1-5 (Skills, MCP, Config, SkillDetail, Settings badges)
- [ ] 03-02: Mandates 6-9 (Hosts rename, System Monitor, Hooks, Plugin search)

### Phase 4: Visual Audit
**Goal**: Every screen passes visual inspection — correct colors, spacing, tap targets, theme tokens
**Depends on**: Phase 1 (before-state screenshots available for comparison)
**Requirements**: VAUD-01, VAUD-02, VAUD-03, VAUD-04, VAUD-05, VAUD-06, VAUD-07, VAUD-08
**Skills**: `axiom:axiom-ios-accessibility`, `axiom:axiom-swiftui-layout`, `axiom:swiftui-layout-auditor` agent, `axiom:accessibility-auditor` agent
**Success Criteria** (what must be TRUE):
  1. 19 iPhone screens pass visual inspection (no truncation, correct colors)
  2. Entity color system consistent (Sessions=blue, Projects=green, Skills=purple, MCP=orange, Plugins=pink)
  3. All interactive elements have 44pt minimum tap targets
  4. No hardcoded font sizes below 11pt — theme tokens used throughout
  5. 4 iPad screens render with adaptive layout
  6. 5 macOS screens render correctly in NavigationSplitView
  7. All animations gated on `accessibilityReduceMotion`
  8. Dark mode: no white flashes, all theme colors applied
**Plans**: 2 plans

Plans:
- [ ] 04-01: iPhone visual audit (19 screens) + entity colors + tap targets + theme tokens
- [ ] 04-02: iPad + macOS visual audit + reduce motion + dark mode verification

### Phase 5: Functional Audit
**Goal**: All interactive features work end-to-end with real data from the backend
**Depends on**: Phase 0 (backend running), Phase 1 (navigation established)
**Requirements**: FAUD-01, FAUD-02, FAUD-03, FAUD-04, FAUD-05, FAUD-06, FAUD-07, FAUD-08, FAUD-09
**Skills**: `axiom:axiom-swiftui-nav`, `axiom:swiftui-nav-auditor` agent, validation gate skills
**Success Criteria** (what must be TRUE):
  1. Dashboard loads with real session/project/skill/MCP/plugin counts
  2. Session list scrolls, search works, session tap opens ChatView
  3. ChatView shows real message content with markdown rendering
  4. Sidebar navigation works for all screens (swipe gesture verified)
  5. Deep links work for all 12 routes (ils://home through ils://mcp)
  6. Browser tabs (MCP/Skills/Plugins) load real data with counts
  7. Settings shows real config values, toggles functional
  8. System Monitor shows live metrics with "Live" indicator
  9. All sheets/modals open and dismiss correctly
**Plans**: 2 plans

Plans:
- [ ] 05-01: Core flows (Dashboard, Sessions, Chat, Sidebar, Deep links)
- [ ] 05-02: Browser, Settings, System Monitor, Sheets/Modals

### Phase 6: Backend Audit
**Goal**: All 14 API endpoints return correct JSON with proper structure and security
**Depends on**: Phase 0 (backend running and verified)
**Requirements**: BKND-01, BKND-02, BKND-03, BKND-04, BKND-05, BKND-06
**Skills**: `axiom:axiom-ios-networking`, `axiom:axiom-codable`, `axiom:security-privacy-scanner` agent, `axiom:codable-auditor` agent
**Success Criteria** (what must be TRUE):
  1. All 14 API endpoints return HTTP 200 with correct JSON structure
  2. APIResponse wrapper present on all list endpoints (items array + total count)
  3. CamelCase keys in all responses (verifies correct binary)
  4. MCP env vars masked in GET /api/v1/mcp responses (***masked***)
  5. Chat streaming endpoint returns SSE events
  6. Stats endpoint returns accurate counts matching database
**Plans**: 1 plan

Plans:
- [ ] 06-01: Curl all 14 endpoints, verify structure + security + camelCase

### Phase 7: Integration Validation
**Goal**: App screenshots correlate with backend data — zero mock data anywhere
**Depends on**: Phase 5 (app screenshots), Phase 6 (backend curl responses)
**Requirements**: INTG-01, INTG-02, INTG-03, INTG-04
**Skills**: `spec-compliance`, validation gate skills
**Success Criteria** (what must be TRUE):
  1. App session counts match GET /api/v1/sessions total count
  2. Creating a session in app appears in backend response
  3. Config changes in app reflected in GET /api/v1/config
  4. All evidence from real backend with real SQLite database
**Plans**: 1 plan

Plans:
- [ ] 07-01: Cross-reference app screenshots with backend curl responses

### Phase 8: Edge Cases & Quality
**Goal**: App handles gracefully under stress — disconnection, large data, accessibility extremes
**Depends on**: Phase 5 (functional baseline established)
**Requirements**: EDGE-01, EDGE-02, EDGE-03, EDGE-04, EDGE-05, EDGE-06
**Skills**: `axiom:axiom-ios-performance`, `axiom:axiom-ios-concurrency`, `axiom:axiom-energy`, `axiom:memory-auditor` agent, `axiom:concurrency-auditor` agent, `axiom:energy-auditor` agent
**Success Criteria** (what must be TRUE):
  1. Disconnect backend: all screens show graceful empty states (no crashes)
  2. Dynamic Type at XXL: key screens readable, no text overlapping
  3. VoiceOver labels present on all interactive elements
  4. Kill backend mid-request: app handles gracefully
  5. Force-quit and relaunch preserves selected theme and session
  6. 22K sessions scroll without performance degradation
**Plans**: 2 plans

Plans:
- [ ] 08-01: Empty states + offline recovery + state persistence
- [ ] 08-02: Dynamic Type XXL + VoiceOver + large data sets

### Phase 9: Report & Documentation
**Goal**: Comprehensive audit report with all evidence cataloged and App Store readiness assessed
**Depends on**: All previous phases complete
**Requirements**: REPT-01, REPT-02, REPT-03, REPT-04, REPT-05
**Skills**: `appstore-check`, `axiom:axiom-app-store-submission`, `axiom:axiom-shipping`, `axiom:axiom-privacy-ux`, `axiom:security-privacy-scanner` agent
**Success Criteria** (what must be TRUE):
  1. Comprehensive audit report with 12 sections generated
  2. 105+ evidence artifacts cataloged (78+ screenshots, 22 JSON, 5 other)
  3. All PASS/FAIL verdicts supported by evidence file references
  4. Remaining backlog items documented with severity and recommendations
  5. App Store readiness assessment completed
**Plans**: 1 plan

Plans:
- [ ] 09-01: Generate final audit report + App Store readiness check

## Progress

**Execution Order:**
Group A (parallel): 0 + 1 + 2 -> Gate -> Group B (parallel): 3 + 4 + 5 -> Gate -> Group C (sequential): 6 -> 7 -> 8 -> 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Build Verification | 1/1 | Complete | 2026-02-20 |
| 1. Screen Inventory | 1/2 | In Progress | - |
| 2. Implementation Gap | 0/1 | Not started | - |
| 3. Mandate Verification | 0/2 | Not started | - |
| 4. Visual Audit | 0/2 | Not started | - |
| 5. Functional Audit | 0/2 | Not started | - |
| 6. Backend Audit | 0/1 | Not started | - |
| 7. Integration Validation | 0/1 | Not started | - |
| 8. Edge Cases & Quality | 0/2 | Not started | - |
| 9. Report & Documentation | 0/1 | Not started | - |

**Total Plans:** 15 across 10 phases

---
*Roadmap created: 2026-02-19*
*Based on: .planning/research/SUMMARY.md, .planning/REQUIREMENTS.md*
