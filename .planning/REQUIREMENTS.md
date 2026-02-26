# Requirements: ILS iOS/macOS v4.0

**Defined:** 2026-02-25
**Core Value:** Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience

## v4.0 Requirements

Requirements for v4.0 milestone (Comprehensive Spec Compliance Audit & Remediation). Each maps to roadmap phases starting at Phase 43. Source: `.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md` (673 lines).

**FIX_PROTOCOL:** Every fix follows: axiom skill → `/axiom:ask` → implement → rebuild → screenshot/cURL → document.

### iOS UI Gaps

- [ ] **UI-01**: HomeView has Quick Actions row with navigation shortcuts (Discover Skills, Browse Plugins, Configure MCP, Edit Settings)
- [ ] **UI-02**: Quick Settings toggles below config editor (Model picker, Extended Thinking toggle, Co-authored-by toggle)
- [ ] **UI-03**: GitHub skill search UI wired in BrowserView with "Discovered from GitHub" section and Install buttons
- [ ] **UI-04**: Session management overflow menu wired for all operations (rename, export, fork, delete) in ChatView
- [ ] **UI-05**: GitHub rate limit user-facing "try again in X seconds" message in BrowserView skill/plugin search
- [ ] **UI-06**: Animation timing values verified against spec values (0.25s spring, 0.2s easeOut) and corrected where needed

### iOS Platform Gaps

- [ ] **PLAT-01**: Dynamic Island compact/expanded views verified and functional with Live Activity
- [ ] **PLAT-02**: Live Activity SSE integration for active chat sessions
- [ ] **PLAT-03**: Remaining DispatchQueue.main.asyncAfter calls replaced with Task-based equivalents
- [ ] **PLAT-04**: URLSession cellular constraints fully applied in APIClient
- [ ] **PLAT-05**: .equatable() applied to complex views (ChatView, BrowserView) for render performance
- [ ] **PLAT-06**: drawingGroup() applied for shadow-heavy views to offload GPU compositing
- [ ] **PLAT-07**: TipKit tips complete for Theme, MCP, Teams (extending existing Server Setup, Create Session, Command Palette tips)
- [ ] **PLAT-08**: Tip display rules with sequential unlock and after-N-opens triggers

### Data & Backend Gaps

- [ ] **DATA-01**: ConfigScope enum in ILSShared replacing string-based scope handling for MCP servers
- [ ] **DATA-02**: DashboardStats standalone DTO in ILSShared for type-safe stats responses
- [ ] **DATA-03**: Message caching depth verified in CacheService — messages cached alongside sessions
- [ ] **DATA-04**: "Last updated X ago" indicator visible in offline-capable views (Home, Sessions, Browser)
- [ ] **DATA-05**: Message draft queue depth verified in SyncCoordinator — queued messages survive app restart
- [ ] **DATA-06**: Input validation in model initializers across ILSShared models

### Security & Compliance

- [ ] **SEC-01**: Per-route authorization (admin vs user distinction) beyond global API key middleware
- [ ] **SEC-02**: Request size limits explicitly configured in Vapor middleware
- [ ] **SEC-03**: GDPR single "delete all my data" endpoint aggregating all user data deletion
- [ ] **SEC-04**: Free trial StoreKit configuration verified and functional
- [ ] **SEC-05**: Receipt validation flow verified with StoreKit 2 server-side

### Ecosystem Gaps

- [ ] **ECO-01**: Plugin versioning with auto-update availability check
- [ ] **ECO-02**: Plugin dependency management (detect conflicts, warn on missing deps)
- [ ] **ECO-03**: MeshGradient theme support verification in theme system
- [ ] **ECO-04**: String Catalog (.xcstrings) migration from .lproj format

### Verification & Audit

- [ ] **AUDIT-01**: Visual audit — iPhone and iPad screens with numbered screenshot evidence (20+ artifacts)
- [ ] **AUDIT-02**: Functional audit — real data verification on iPhone and iPad with evidence
- [ ] **AUDIT-03**: Backend audit — cURL every endpoint, verify JSON structure matches spec contract
- [ ] **AUDIT-04**: Integration validation — correlated backend+frontend evidence showing data flows
- [ ] **AUDIT-05**: Proactive bug hunt — edge cases, offline behavior, accessibility, memory profiling

## Future Requirements

### macOS Feature Parity (v4.1)

- **MAC-01**: Drag-and-drop support for sessions, files into chat
- **MAC-02**: Handoff (NSUserActivity) for cross-device session continuation
- **MAC-03**: Menu bar completeness (File, Edit, View, Session menus)
- **MAC-04**: Inspector panel for session/entity details
- **MAC-05**: AppleScript/Automator support
- **MAC-06**: Share Extension
- **MAC-07**: Stage Manager window optimization
- **MAC-08**: Additional keyboard shortcuts beyond existing 16

### Extended Validation (v4.2+)

- **EXT-01**: RTL layout (Arabic) support
- **EXT-02**: Dark mode screenshot captures for all screens
- **EXT-03**: iPad mini compact size class testing
- **EXT-04**: Chat streaming E2E validation (requires Claude CLI)
- **EXT-05**: Premium vs free tier state validation on both devices
- **EXT-06**: Public API documentation for all ILSShared models

## Out of Scope (v4.0)

| Feature | Reason |
|---------|--------|
| macOS feature parity | Deferred to v4.1 — user decision during milestone init |
| RTL/Arabic layout | Low user demand; English + 3 languages sufficient for launch |
| Public API documentation | Polish item with low user impact |
| Certificate pinning | Deferred — local-first usage model makes this unnecessary |
| Testing infrastructure | Per project rules: no mocks, stubs, test doubles, or unit tests |
| New features beyond spec | v4.0 is compliance, not innovation |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UI-01 | Pending | Pending |
| UI-02 | Pending | Pending |
| UI-03 | Pending | Pending |
| UI-04 | Pending | Pending |
| UI-05 | Pending | Pending |
| UI-06 | Pending | Pending |
| PLAT-01 | Pending | Pending |
| PLAT-02 | Pending | Pending |
| PLAT-03 | Pending | Pending |
| PLAT-04 | Pending | Pending |
| PLAT-05 | Pending | Pending |
| PLAT-06 | Pending | Pending |
| PLAT-07 | Pending | Pending |
| PLAT-08 | Pending | Pending |
| DATA-01 | Pending | Pending |
| DATA-02 | Pending | Pending |
| DATA-03 | Pending | Pending |
| DATA-04 | Pending | Pending |
| DATA-05 | Pending | Pending |
| DATA-06 | Pending | Pending |
| SEC-01 | Pending | Pending |
| SEC-02 | Pending | Pending |
| SEC-03 | Pending | Pending |
| SEC-04 | Pending | Pending |
| SEC-05 | Pending | Pending |
| ECO-01 | Pending | Pending |
| ECO-02 | Pending | Pending |
| ECO-03 | Pending | Pending |
| ECO-04 | Pending | Pending |
| AUDIT-01 | Pending | Pending |
| AUDIT-02 | Pending | Pending |
| AUDIT-03 | Pending | Pending |
| AUDIT-04 | Pending | Pending |
| AUDIT-05 | Pending | Pending |

**Coverage:**
- v4.0 requirements: 34 total
- Mapped to phases: 0 (pending roadmap creation)
- Unmapped: 34

---
*Requirements defined: 2026-02-25*
*Last updated: 2026-02-25 after milestone v4.0 initialization*
