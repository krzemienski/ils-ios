# Requirements: ILS iOS/macOS v3.5

**Defined:** 2026-02-25
**Core Value:** Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience

## v3.5 Requirements

Requirements for v3.5 milestone (Comprehensive Functional Validation -- iOS & iPad). Each maps to roadmap phases starting at Phase 40. Source: `.planning/research/` (5 research files from 2026-02-25).

### Environment & Infrastructure

- [ ] **ENV-01**: iPhone simulator (50523130) booted with app installed from newest DerivedData binary
- [ ] **ENV-02**: iPad simulator (C074375B) booted with same binary as iPhone
- [ ] **ENV-03**: Backend verified running from `ils-ios/` path on port 9999 with health check
- [ ] **ENV-04**: Evidence directories created (`/tmp/v3.5-evidence/{iphone,ipad}/`)
- [ ] **ENV-05**: Status bar overridden to 9:41 on both simulators for clean screenshots
- [ ] **ENV-06**: PASS criteria document created listing all screens and their verification points

### iPhone Validation

- [x] **IPH-01**: Home screen -- stats cards, quick actions, recent sessions, sparklines render correctly
- [x] **IPH-02**: Sessions list -- sessions load, row tap opens chat, session count matches
- [x] **IPH-03**: Chat view -- messages display, back button returns to sessions, toolbar actions visible
- [x] **IPH-04**: Browser MCP tab -- MCP servers list with health status indicators
- [x] **IPH-05**: Browser Skills tab -- skills list with install/enable states, GitHub browse
- [x] **IPH-06**: Browser Plugins tab -- plugins list with enable/disable, GitHub browse
- [ ] **IPH-07**: System Monitor -- live metrics (CPU, memory, disk, network), process list, WebSocket connected
- [ ] **IPH-08**: Settings -- all sections render, inheritance badges visible, tooltips functional
- [ ] **IPH-09**: Host Profiles -- profile list, active indicator, health badges
- [ ] **IPH-10**: Themes -- theme list with preview, theme editor form
- [ ] **IPH-11**: Sidebar navigation -- accessible from all screens, active item highlighted
- [ ] **IPH-12**: Connection states -- connected banner, disconnected banner, reconnection behavior
- [x] **IPH-13**: Any issue found during validation is fixed immediately, rebuilt, and re-validated

### Deep Link Testing

- [ ] **DL-01**: `ils://home` navigates to Home screen on both devices
- [ ] **DL-02**: `ils://sessions` navigates to Sessions list on both devices
- [ ] **DL-03**: `ils://sessions/{uuid}` opens specific chat session on both devices
- [ ] **DL-04**: `ils://browser`, `ils://mcp`, `ils://skills`, `ils://plugins` navigate to correct Browser tabs
- [ ] **DL-05**: `ils://settings`, `ils://system`, `ils://fleet`, `ils://themes` navigate correctly
- [ ] **DL-06**: Console logs captured during deep link testing -- zero crashes, zero unhandled errors

### iPad Validation

- [ ] **IPAD-01**: NavigationSplitView persistent sidebar renders with correct items
- [ ] **IPAD-02**: All 12+ screens render correctly in iPad split-view layout
- [ ] **IPAD-03**: Sidebar selection highlights sync with active screen
- [ ] **IPAD-04**: Home screen adapts to wider iPad layout (no stretched/compressed elements)
- [ ] **IPAD-05**: Chat view uses full width appropriately in detail column
- [ ] **IPAD-06**: Browser tabs render correctly in wider detail view
- [ ] **IPAD-07**: Any iPad-specific layout issue found is fixed immediately and re-validated

### Evidence Gate (embedded in each phase)

Evidence gate requirements are distributed across phases rather than concentrated in a single final gate. Each phase runs its own dual-agent verification before proceeding to the next.

- [ ] **GATE-01**: All iPhone screenshots organized with numbered naming in evidence directory (Phase 41)
- [ ] **GATE-02**: All iPad screenshots organized with numbered naming in evidence directory (Phase 42)
- [ ] **GATE-03**: Agent A independently reviews screenshots and produces verdicts (Phase 41 for iPhone, Phase 42 for iPad)
- [ ] **GATE-04**: Agent B independently reviews screenshots and produces verdicts (Phase 41 for iPhone, Phase 42 for iPad)
- [ ] **GATE-05**: PASS requires 2/2 agent agreement -- applied as gate principle in every phase (Phase 40 for setup, Phase 41 for iPhone, Phase 42 for iPad)

## Future Requirements

### Extended Validation (v3.6+)

- **EXT-01**: Dark mode screenshot captures for all screens on both devices
- **EXT-02**: iPad portrait vs landscape dual-orientation validation
- **EXT-03**: iPad mini compact size class edge case testing
- **EXT-04**: Chat streaming E2E validation (requires Claude CLI availability)
- **EXT-05**: Premium vs free tier state validation on both devices
- **EXT-06**: macOS full functional validation pass

## Out of Scope (v3.5)

| Feature | Reason |
|---------|--------|
| macOS validation | Separate milestone -- different window management paradigm |
| Dark mode captures | Scope contained to light mode for v3.5; dark mode deferred to v3.6+ |
| Chat message sending | Requires Claude CLI in environment; chat rendering still validated |
| iPad mini testing | Edge case -- v3.5 covers iPad Pro 13" as canonical iPad |
| Rotation/orientation | Portrait only for v3.5; landscape deferred |
| Performance profiling | Already covered in v2.0 milestone |
| New feature development | v3.5 is validation only -- no new features |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENV-01 | 40 | Pending |
| ENV-02 | 40 | Pending |
| ENV-03 | 40 | Pending |
| ENV-04 | 40 | Pending |
| ENV-05 | 40 | Pending |
| ENV-06 | 40 | Pending |
| IPH-01 | 41 | Complete |
| IPH-02 | 41 | Complete |
| IPH-03 | 41 | Complete |
| IPH-04 | 41 | Complete |
| IPH-05 | 41 | Complete |
| IPH-06 | 41 | Complete |
| IPH-07 | 41 | Pending |
| IPH-08 | 41 | Pending |
| IPH-09 | 41 | Pending |
| IPH-10 | 41 | Pending |
| IPH-11 | 41 | Pending |
| IPH-12 | 41 | Pending |
| IPH-13 | 41 | Complete |
| DL-01 | 41 | Pending |
| DL-02 | 41 | Pending |
| DL-03 | 41 | Pending |
| DL-04 | 41 | Pending |
| DL-05 | 41 | Pending |
| DL-06 | 41 | Pending |
| IPAD-01 | 42 | Pending |
| IPAD-02 | 42 | Pending |
| IPAD-03 | 42 | Pending |
| IPAD-04 | 42 | Pending |
| IPAD-05 | 42 | Pending |
| IPAD-06 | 42 | Pending |
| IPAD-07 | 42 | Pending |
| GATE-01 | 41 | Pending |
| GATE-02 | 42 | Pending |
| GATE-03 | 41 | Pending |
| GATE-04 | 42 | Pending |
| GATE-05 | 40 | Pending |

**Coverage:**
- v3.5 requirements: 37 total
- Mapped to phases: 37
- Unmapped: 0

---
*Requirements defined: 2026-02-25*
*Last updated: 2026-02-25 after roadmap revision (embedded evidence gates)*
