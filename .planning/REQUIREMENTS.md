# Requirements: ILS Comprehensive Audit & Remediation

**Defined:** 2026-02-19
**Core Value:** Every spec-defined feature has screenshot evidence proving it works end-to-end with real data — no mocks, no stubs, no assumptions.

## v1 Requirements

Requirements for the audit. Each maps to roadmap phases.

### Build Verification (Phase 0)

- [x] **BUILD-01**: iOS app builds with zero errors on dedicated simulator (UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14)
- [x] **BUILD-02**: macOS app builds with zero errors (platform=macOS)
- [x] **BUILD-03**: Backend builds with zero errors (swift build)
- [x] **BUILD-04**: Backend serves correct API responses from `ils-ios/` binary (verified via `lsof -i :9999`)
- [x] **BUILD-05**: All 3 builds run in parallel with `run_in_background: true`

### Screen Inventory (Phase 1)

- [x] **SCRN-01**: Before-state screenshots captured for all 19 iPhone screens
- [x] **SCRN-02**: Before-state screenshots captured for 4 iPad screens (adaptive layout verified)
- [x] **SCRN-03**: Before-state screenshots captured for 5 macOS screens
- [x] **SCRN-04**: Each screenshot is read with Read tool and visually verified before cataloging
- [x] **SCRN-05**: Evidence directory created at `/tmp/ils-audit-evidence/` with organized subdirectories

### Implementation Gap (Phase 2)

- [x] **IMPL-01**: AddMCPServerView UI renders correctly in Browser > MCP tab
- [x] **IMPL-02**: AddMCPServerView form accepts server name, command, args, and scope
- [x] **IMPL-03**: AddMCPServerView submits via MCPViewModel.addServer() to POST /api/v1/mcp
- [x] **IMPL-04**: New MCP server appears in list after creation (end-to-end verified)
- [x] **IMPL-05**: AddMCPServerView follows HIG compliance (44pt targets, Dynamic Type, theme tokens)

### Mandate Verification (Phase 3)

- [x] **MNDT-01**: GitHub Skill Search/Install — search returns results, install button works
- [x] **MNDT-02**: MCP Server Creation — verified via AddMCPServerView (Phase 2 output)
- [x] **MNDT-03**: ConfigEditor — scope selector works, JSON validation indicator present
- [x] **MNDT-04**: SkillDetailView — Markdown renders, edit/delete/toggle functional
- [x] **MNDT-05**: Settings inheritance badges — "Host Default" badges on model, color scheme, thinking, coauthor
- [x] **MNDT-06**: Fleet-to-Hosts rename — all UI references show "Hosts" not "Fleet"
- [x] **MNDT-07**: System Monitor pipeline — real CPU/Memory/Disk/Network metrics via WebSocket
- [x] **MNDT-08**: Hooks Management — config path, Edit Config, Copy Path, all 5 event types
- [x] **MNDT-09**: Plugin GitHub Search — search returns results, install/enable toggles work

### Visual Audit (Phase 4)

- [x] **VAUD-01**: All 19 iPhone screens pass visual inspection (no truncation, correct colors, proper spacing)
- [x] **VAUD-02**: Entity color system consistent — Sessions=blue, Projects=green, Skills=purple, MCP=orange, Plugins=pink
- [x] **VAUD-03**: All interactive elements have 44pt minimum tap targets
- [x] **VAUD-04**: Theme tokens used throughout (no hardcoded font sizes below 11pt)
- [x] **VAUD-05**: 4 iPad screens render with adaptive layout (no phone-sized content)
- [x] **VAUD-06**: 5 macOS screens render correctly in NavigationSplitView
- [x] **VAUD-07**: Reduce motion: all animations gated on `accessibilityReduceMotion` (C1-C3, H12)
- [x] **VAUD-08**: Dark mode: no white flashes, all theme colors properly applied

### Functional Audit (Phase 5)

- [x] **FAUD-01**: Dashboard loads with real session/project/skill/MCP/plugin counts
- [x] **FAUD-02**: Session list scrolls, search works, session tap opens ChatView
- [x] **FAUD-03**: ChatView shows real message content with markdown rendering
- [x] **FAUD-04**: Sidebar navigation works for all screens (swipe gesture verified)
- [x] **FAUD-05**: Deep links work for all 12 routes (ils://home through ils://mcp)
- [x] **FAUD-06**: Browser tabs (MCP/Skills/Plugins) load real data with counts
- [x] **FAUD-07**: Settings shows real configuration values, toggles functional
- [x] **FAUD-08**: System Monitor shows live metrics with "Live" indicator
- [x] **FAUD-09**: All sheets/modals open and dismiss correctly

### Backend Audit (Phase 6)

- [x] **BKND-01**: All 14 API endpoints return HTTP 200 with correct JSON structure
- [x] **BKND-02**: APIResponse wrapper present on all list endpoints (items array + total count)
- [x] **BKND-03**: CamelCase keys in all responses (not snake_case — verifies correct binary)
- [x] **BKND-04**: MCP env vars masked in GET /api/v1/mcp responses (security-critical)
- [x] **BKND-05**: Chat streaming endpoint (POST /chat/stream) returns SSE events
- [x] **BKND-06**: Stats endpoint returns accurate counts matching database

### Integration Validation (Phase 7)

- [x] **INTG-01**: App screenshots correlate with backend curl responses (same session counts, names)
- [x] **INTG-02**: Creating a session in app appears in GET /api/v1/sessions response
- [x] **INTG-03**: Config changes in app reflected in GET /api/v1/config response
- [x] **INTG-04**: Zero mock data — all evidence from real backend with real SQLite database

### Edge Cases & Quality (Phase 8)

- [x] **EDGE-01**: Empty states: disconnect backend, all screens show graceful messages (no crashes)
- [x] **EDGE-02**: Dynamic Type at XXL: key screens readable, no text overlapping
- [x] **EDGE-03**: VoiceOver labels present on all interactive elements
- [x] **EDGE-04**: Offline recovery: kill backend mid-request, app handles gracefully
- [x] **EDGE-05**: State persistence: force-quit and relaunch preserves selected theme and session
- [x] **EDGE-06**: Large data sets: 22K sessions scroll without performance degradation

### Report & Documentation (Phase 9)

- [x] **REPT-01**: Comprehensive audit report with 12 sections generated
- [x] **REPT-02**: 234 evidence artifacts cataloged (170 screenshots, 43 JSON, 17 logs, 4 reports)
- [x] **REPT-03**: All PASS/FAIL verdicts supported by evidence file references
- [x] **REPT-04**: Remaining backlog items documented with severity and recommendations
- [x] **REPT-05**: App Store readiness assessment — CONDITIONAL verdict with checklist

### Skill Discipline (Cross-Cutting)

- [ ] **SKIL-01**: `Skill("ils-ios-project")` invoked at session start
- [ ] **SKIL-02**: Phase-specific skills invoked before each phase (per Skill Execution Matrix)
- [ ] **SKIL-03**: Validation gate skills invoked before marking any task PASS
- [ ] **SKIL-04**: Agent fix-then-validate mandate followed (capture → verify → fix → re-verify)
- [ ] **SKIL-05**: All screenshots read with Read tool before PASS claim

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Backlog Remediation (from Axiom auditors)

- **BKLG-01**: C4 — UIScreen.main.bounds iPad Split View fix → containerRelativeFrame
- **BKLG-02**: C5 — MarkdownParser caching in @State + .task(id:)
- **BKLG-03**: C6 — ThemeMarketplaceView filteredThemes memoization
- **BKLG-04**: C7 — Remove forced .colorScheme(.dark) throughout app
- **BKLG-05**: C8 — Consider NavigationSplitView on iPhone (sidebar gesture conflict)
- **BKLG-06**: M5 — SSEClient ObservableObject → @Observable migration
- **BKLG-07**: H1 — BrowserView custom segmented control accessibility
- **BKLG-08**: H2 — SidebarSessionRow 24pt → 44pt touch target fix

### Performance Optimization

- **PERF-01**: Non-lazy VStack → LazyVStack conversion (M2, M6)
- **PERF-02**: String copy elimination in ChatViewModel streaming hot path (C7 from Feb 19 audit)
- **PERF-03**: removeFirst O(n) → circular buffer in MetricsWebSocketClient (H10)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Unit tests / mocks / stubs | Global mandate: functional validation only |
| iPad dedicated layout redesign | Adaptive iPhone layout sufficient (D5) |
| macOS feature parity push | Spec only defines iOS views (D6) |
| Extended Thinking/Co-authored-by editing | Keep read-only with Host Default badge (D1/D2) |
| MCP env var editor in creation UI | Security concern — use CLI/Config Editor (D3) |
| Architecture redesign | Targeted fixes only — separate initiative |
| New dependencies | Unless strictly required for AddMCPServerView |
| SSH streaming pipeline rebuild | Separate project |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 to BUILD-05 | Phase 0 | Complete |
| SCRN-01 to SCRN-05 | Phase 1 | Complete |
| IMPL-01 to IMPL-05 | Phase 2 | Complete |
| MNDT-01 to MNDT-09 | Phase 3 | Complete |
| VAUD-01 to VAUD-08 | Phase 4 | Complete |
| FAUD-01 to FAUD-09 | Phase 5 | Complete |
| BKND-01 to BKND-06 | Phase 6 | Complete |
| INTG-01 to INTG-04 | Phase 7 | Complete |
| EDGE-01 to EDGE-06 | Phase 8 | Complete |
| REPT-01 to REPT-05 | Phase 9 | Complete |
| SKIL-01 to SKIL-05 | All Phases | Pending |

**Coverage:**
- v1 requirements: 62 total
- Mapped to phases: 62
- Unmapped: 0

---
*Requirements defined: 2026-02-19*
*Last updated: 2026-02-19 after research synthesis*
