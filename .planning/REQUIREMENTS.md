# Requirements: ILS iOS/macOS v5.0

**Defined:** 2026-02-27
**Core Value:** Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience

## v5.0 Requirements

Requirements for v5.0 milestone (Cross-Platform Feature Completion & 30-Gate Audit). Each maps to roadmap phases starting at Phase 49. Source: `.planning/research/SUMMARY.md` + MILESTONE-CONTEXT.md scope decisions.

### Foundation

- [ ] **FOUND-01**: "Fleet" terminology replaced with "Host Profiles" across all Swift files, API routes (with backward-compatible aliasing), deep links, and UI labels
- [ ] **FOUND-02**: Skills file scanning verified to exclude node_modules directories
- [ ] **FOUND-03**: Validation evidence pipeline captures screenshots and gate tracking artifacts to evidence/ directory

### Config & Settings

- [x] **CFG-01**: Config cascade visualization shows "inherited from host" vs "custom override" badges on each setting
- [x] **CFG-02**: System prompt and model defaults inherited from connected host CLI configuration, not hardcoded
- [x] **CFG-03**: Info tooltips (>=20 words) on tool controls, permissions, and settings sections

### Skills, Plugins & Hooks

- [ ] **SKILL-01**: User can browse GitHub for skills with search, category filtering, and preview
- [ ] **SKILL-02**: User can install skills from GitHub with progress indication and error handling
- [ ] **SKILL-03**: User can browse GitHub for plugins with search, category filtering, and preview
- [ ] **SKILL-04**: User can install plugins from GitHub with progress indication and error handling
- [x] **SKILL-05**: Hooks management screen supports all 16 Claude Code event types (expanded from 5)
- [x] **SKILL-06**: User can create, edit, and delete hooks with 4 handler types (command, prompt, agent, http)
- [x] **SKILL-07**: Skills and plugins display active/inactive status indicators with toggle capability

### Profiles

- [ ] **PROF-01**: Profile switching updates settings context with visual feedback showing which host's config is active
- [ ] **PROF-02**: System monitor shows real-time CPU, memory, disk, and network metrics from connected host

### Navigation

- [ ] **NAV-01**: Home screen displays quick action shortcuts above recent sessions
- [ ] **NAV-02**: Home recent sessions list matches dedicated Sessions screen data exactly

### Backend API

- [x] **API-01**: All API endpoints return expected JSON structures with proper HTTP error codes (not 200-with-error)
- [x] **API-02**: GET /config/effective endpoint returns merged config with winning-scope annotations per key

### Validation -- 30-Gate Audit

- [ ] **GATE-01**: Visual audit -- iPhone screens with numbered screenshot evidence (>=15 artifacts)
- [ ] **GATE-02**: Visual audit -- iPad screens with numbered screenshot evidence (>=15 artifacts)
- [ ] **GATE-03**: Visual audit -- Mac screens with numbered screenshot evidence (>=10 artifacts)
- [ ] **GATE-04**: Functional audit -- end-to-end verification of all feature areas across platforms
- [ ] **GATE-05**: Bug hunt -- >=20 edge case scenarios tested (offline, empty states, accessibility, memory)

## Validated (Previous Milestones)

- v1.0: REQ-01 through REQ-15 -- All PASS (sidebar nav, settings, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP, backend API, visual consistency, sessions)
- v2.0: LAUNCH-01/02, NET-01/02/03, MEM-01/02/03, BATT-01/02/03, RENDER-01/02/03, COMPAT-01/02, TEST-01/02/03/04 -- Performance optimization complete
- v3.0: 165 audit issues remediated across Phases 18-24
- v1.5: 70/70 audit findings resolved
- v3.1: NAV-01..05, HP-01..05, CFG-01..07, BRW-01..08, SYS-01..03, XP-01..03 -- 31/31 PASS
- v3.5: IPH-01..13, DL-01..06, GATE-01/03/04/05 -- iPhone 23/23 PASS
- v4.0: UI-01..06, PLAT-01..08, DATA-01..06, SEC-01..05, ECO-01..04, AUDIT-01..05 -- 34/34 PASS, 123 evidence artifacts

## Future Requirements

### macOS Feature Parity (v6.0)

- **MAC-01**: Drag-and-drop support for sessions, files into chat
- **MAC-02**: Handoff (NSUserActivity) for cross-device session continuation
- **MAC-03**: Menu bar completeness (File, Edit, View, Session menus)
- **MAC-04**: Keyboard shortcuts beyond existing set
- **MAC-05**: AppleScript/Automator support
- **MAC-06**: Share Extension
- **MAC-07**: Stage Manager window optimization

### Extended Validation (v6.0+)

- **EXT-01**: RTL layout (Arabic) support
- **EXT-02**: Dark mode screenshot captures for all screens
- **EXT-03**: iPad mini compact size class testing
- **EXT-04**: Chat streaming E2E validation (requires Claude CLI)
- **EXT-05**: Premium vs free tier state validation on both devices

## Out of Scope (v5.0)

| Feature | Reason |
|---------|--------|
| macOS feature parity (keyboard shortcuts, drag-drop, Handoff) | User deferred to v6.0 during milestone init |
| App Store submission | Separate milestone |
| Android/web platform support | Out of product scope |
| Certificate pinning | Local-first usage model makes this unnecessary |
| Testing infrastructure | Per project rules: no mocks, stubs, test doubles, or unit tests |
| RTL/Arabic layout | Low user demand |
| Full Swift 6 strict mode | Already at `targeted` level |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 49 | Pending |
| FOUND-02 | Phase 54 | Pending |
| FOUND-03 | Phase 49 | Pending |
| CFG-01 | Phase 51 | Complete |
| CFG-02 | Phase 51 | Complete |
| CFG-03 | Phase 51 | Complete |
| SKILL-01 | Phase 53 | Pending |
| SKILL-02 | Phase 53 | Pending |
| SKILL-03 | Phase 53 | Pending |
| SKILL-04 | Phase 53 | Pending |
| SKILL-05 | Phase 52 | Complete |
| SKILL-06 | Phase 52 | Complete |
| SKILL-07 | Phase 52 | Complete |
| PROF-01 | Phase 54 | Pending |
| PROF-02 | Phase 54 | Pending |
| NAV-01 | Phase 54 | Pending |
| NAV-02 | Phase 54 | Pending |
| API-01 | Phase 50 | Complete |
| API-02 | Phase 50 | Complete |
| GATE-01 | Phase 55 | Pending |
| GATE-02 | Phase 55 | Pending |
| GATE-03 | Phase 55 | Pending |
| GATE-04 | Phase 56 | Pending |
| GATE-05 | Phase 56 | Pending |

**Coverage:**
- v5.0 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after roadmap creation -- traceability complete*
