# ILS Comprehensive Audit & Remediation

## What This Is

A full spec-compliance audit and remediation of the ILS iOS/macOS app. The audit verifies every spec-defined screen, backend endpoint, and user interaction with real data and screenshot evidence — then fixes the gaps. The single confirmed implementation gap is AddMCPServerView; everything else is verify-with-evidence.

## Core Value

Every spec-defined feature has screenshot evidence proving it works end-to-end with real data — no mocks, no stubs, no assumptions.

## Requirements

### Validated

<!-- Shipped and confirmed valuable via code reading before plan creation. -->

- ✓ Fleet -> Hosts rename — commit `eb93856`
- ✓ MCP env masking (security) — `MCPController.swift` lines 21-43
- ✓ HooksManagementView with all 5 event types — line 261
- ✓ GitHub 401 error handling (Skills + Plugins) — graceful "GitHub token not configured" message
- ✓ GitHub search + install UI (Skills) — `BrowserView.swift` lines 312-782
- ✓ GitHub search + install UI (Plugins) — `PluginsViewModel.swift` lines 250-290
- ✓ MCPViewModel.addServer() backend call — line 107
- ✓ ConfigEditorView scope + JSON validation — accepts scope, `isValidJSON()` indicator
- ✓ SkillDetailView (Markdown, edit/delete/toggle) — complete
- ✓ Settings "Host Default" badges — model, color scheme, thinking, coauthor
- ✓ System Monitor (6 files) — real metrics via WebSocket
- ✓ Hooks Management — config path, edit/copy controls
- ✓ Quick Actions on HomeView — 2x2 LazyVGrid, 4 items

### Active

<!-- Current scope. Building toward these. -->

- [ ] AddMCPServerView UI (the ONE implementation gap)
- [ ] Phase 0: All 3 build targets compile with zero errors
- [ ] Phase 1: Screenshot evidence of every spec-required screen (before-state)
- [ ] Phase 2: AddMCPServerView implemented end-to-end
- [ ] Phase 3: All 9 mandate sub-tasks verified with screenshots
- [ ] Phase 4: Visual audit across iPhone (19 screens), iPad (4 screens), macOS (5 screens)
- [ ] Phase 5: Functional audit — all interactions work with real data
- [ ] Phase 6: All spec-required endpoints return valid JSON, MCP env vars masked
- [ ] Phase 7: Correlated evidence (app + backend), zero mock data
- [ ] Phase 8: Empty states, edge cases, accessibility, offline recovery verified
- [ ] Phase 9: Comprehensive audit report (12 sections, 105+ artifacts)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- iPad dedicated layout redesign — verified no broken layouts, but no new iPad-specific work (D5)
- macOS feature parity beyond current 11 views — spec only defines iOS views (D6)
- Making Extended Thinking / Co-authored-by editable — keep read-only with Host Default badge (D1/D2)
- SSH streaming pipeline rebuild — architectural initiative, separate project
- MCP env var editor in creation UI — security concern, configurable via CLI/Config Editor (D3)
- Architecture redesign — targeted fixes only
- New dependencies unless strictly required
- Changes to working features that pass verification

## Context

This audit is driven by `docs/ils.md` (~4,300 lines, 5 phases with gate checks). The ILS app is a brownfield Swift monorepo with 3 build targets (iOS, macOS, Backend), 65+ iOS views, 11 macOS views, and 14 backend controllers.

Pre-audit codebase verification confirmed 13 of 14 spec items are already implemented. The sole implementation gap is AddMCPServerView — the UI for creating new MCP servers from the Browser > MCP tab.

Evidence directory: `/tmp/ils-audit-evidence/`
Dedicated simulator: iPhone 16 Pro Max (UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`)
Backend port: 9999

## Constraints

- **No mocks**: All evidence from real device/simulator with real backend data
- **No architecture changes**: Targeted fixes only
- **Cross-platform parity**: Every iOS fix must be checked in macOS
- **Evidence-based**: PASS requires screenshot/curl evidence, not just code reading
- **Spec source**: `docs/ils.md` is the authoritative specification

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| D1: Extended Thinking read-only | CLI-level setting; mobile reflects, doesn't control | — Pending verification |
| D2: Co-authored-by read-only | Same as D1 | — Pending verification |
| D3: Omit env vars from MCP creation UI | Security-sensitive; use CLI/Config Editor | — Pending verification |
| D4: Keep "New Session" quick action | Settings always accessible from sidebar; New Session is primary action | — Pending verification |
| D5: iPad dedicated pass OUT OF SCOPE | Adaptive iPhone layout is sufficient | — Pending verification |
| D6: macOS feature parity OUT OF SCOPE | Spec only defines iOS views | — Pending verification |

---
*Last updated: 2026-02-19 after initialization*
