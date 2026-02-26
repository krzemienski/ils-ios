# ILS iOS/macOS

## What This Is

A native Swift iOS/macOS client for Claude Code (ILS). The app is code-quality solid after 4 milestones of hardening (v1.0 audit, v2.0 performance, v3.0 remediation, v1.5 audit fixes). This milestone shifts focus from code health to product quality — fixing broken screens, restoring missing features, syncing host CLI defaults, and overhauling navigation and UX across all platforms.

## Core Value

Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience for managing Claude Code sessions, skills, plugins, and system monitoring.

## Current Milestone: v4.0 Comprehensive Spec Compliance Audit & Remediation

**Goal:** Systematically close every gap between the 3 original ILS build specifications and the current application state, with evidence-backed verification at every step. Zero CRITICAL or HIGH gaps remaining. 20+ evidence artifacts collected. All gate checks PASS.

**Target features:**
- MEDIUM gap remediation (7 items): Quick Settings toggles, HomeView Quick Actions, GitHub skill search wiring, SSH auth form, raw JSON config editor, custom marketplace, settings UX
- LOW gap remediation (16 items): cosmetic/polish differences from spec
- Visual audit across all platforms (iPhone, iPad, Mac) with screenshot evidence
- Functional audit with real data verification on all platforms
- Backend audit: cURL every endpoint, verify JSON matches spec
- Integration validation: correlated backend+frontend evidence
- Proactive bug hunt: edge cases, offline, accessibility, memory
- FIX_PROTOCOL: every fix through axiom skill → axiom:ask → implement → evidence

**Previous Milestones:**
- v1.0 (Phases 1-10): Cross-Platform Audit — SHIPPED 2026-02-21
- v2.0 (Phases 11-17): Performance Optimization Suite — COMPLETE 2026-02-24
- v3.0 (Phases 18-24): Comprehensive Audit Remediation — COMPLETE 2026-02-23
- v1.5 (Phases 25-32): All Audit Fixes — SHIPPED 2026-02-24
- v3.1 (Phases 33-39): Comprehensive Audit, Bug Fix & UX Overhaul — SHIPPED 2026-02-25
- v3.5 (Phases 40-42): Comprehensive Functional Validation — iPhone COMPLETE, iPad deferred to v4.0

## Requirements

### Validated

- v1.0: REQ-01 through REQ-15 — All PASS (sidebar nav, settings, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP, backend API, visual consistency, sessions)
- v2.0: LAUNCH-01/02, NET-01/02/03, MEM-01/02/03, BATT-01/02, RENDER-01/02/03, BATT-03, COMPAT-01/02, TEST-01/02/03/04 — Performance optimization complete
- v3.0: 165 audit issues remediated across Phases 18-24 (concurrency, energy, architecture, performance, navigation, Codable, build, accessibility, database, networking, security, memory, layout, modernization)
- v1.5-partial: 10 issues fixed in commit c57690f (CRIT-C1, CRIT-E1, CRIT-SP1, H-SP1, H-E1, H-E2, H-E5, H-C3, H-C4, H-M1)
- v3.1: NAV-01..05, HP-01..05, CFG-01..07, BRW-01..08, SYS-01..03, XP-01..03 — 31/31 requirements PASS (shipped 2026-02-25)
- v3.5-partial: IPH-01..13, DL-01..06, GATE-01/03/04/05 — iPhone validation 23/23 PASS (iPad deferred)

### Active (v4.0 Comprehensive Spec Compliance Audit & Remediation)

*See `.planning/REQUIREMENTS.md` for full scoped requirements with REQ-IDs.*

- MEDIUM Gap Remediation (7 items): Quick Settings toggles, HomeView Quick Actions, GitHub skill search, SSH auth form, raw JSON config editor, custom marketplace, settings UX
- LOW Gap Remediation (16 items): cosmetic/polish differences from original specs
- Visual Audit: all platforms (iPhone, iPad, Mac) with screenshot evidence
- Functional Audit: real data verification on all platforms
- Backend Audit: cURL every endpoint, verify JSON structure matches spec
- Integration Validation: correlated backend+frontend evidence
- Proactive Bug Hunt: edge cases, offline, accessibility, memory

### Out of Scope

- App Store submission (separate milestone)
- Android/web platform support
- Full Swift 6 strict mode (`-strict-concurrency=complete`) — already at `targeted` level
- Features from deferred v2.0 performance metrics (100MB memory, "Low" battery rating)
- Backend rewrite — incremental backend changes only as needed for gap closure
- New features beyond what the 3 original specs define — this is compliance, not innovation

## Context

- **Codebase**: 149+ Swift files (iOS), 14 (macOS), 52 (backend), 26 (shared)
- **Previous work**: v1.0 (audit), v2.0 (performance), v3.0 (remediation), v1.5 (audit fixes) — all shipped
- **Code quality**: All builds green, 31 tests pass, Swift 6 targeted, 70/70 audit findings resolved
- **Gap analysis**: Quick Task 6 produced 673-line GAP-ANALYSIS.md — ~78% strict / ~87% effective compliance across 3 specs
- **Remaining gaps**: 0 CRITICAL, 0 HIGH, 7 MEDIUM, 16 LOW — all polish/completion items
- **Three spec documents**: `specs/ils-complete-rebuild/requirements.md`, `specs/rebuild-ground-up/requirements.md`, `.claude/plan/MASTER_ROADMAP.md`
- **Backend**: Vapor 4, SQLite, port 9999 — may need endpoint additions for gap closure
- **Coding guidelines**: Minimum complexity, no over-engineering, no mocks/tests

## Constraints

- **Platform**: iOS 17+, macOS 14+, Swift 5.10+, SwiftUI
- **Simulator**: UDID 50523130-57AA-48B0-ABD0-4D59CE455F14 (iPhone 16 Pro Max)
- **No mocks**: Functional validation only — real system, real measurements
- **Backward compat**: All v1.0 audit REQs must remain PASS
- **Build system**: Auto-build hook fires on every .swift edit
- **Phase numbering**: Continues from 43 (v3.5 ended at Phase 42)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| All 5 perf dimensions in scope (v2.0) | Comprehensive optimization | ✓ Good |
| Research before planning (v2.0) | Analyzed bottlenecks first | ✓ Good |
| Regression tests included (v2.0) | XCTest metrics in Phase 17 | ✓ Good |
| Skip research for v1.5 | Audit reports serve as requirements — no new features | ✓ Good |
| v1.5 naming (user-specified) | Decoupled from internal phase numbering (Phase 25+) | ✓ Good |
| Shift to product quality (v3.1) | Code health complete; UX gaps now blocking real usage | ✓ Good |
| Fleet → Host Profiles (v3.1) | Multi-host concept clearer than fleet metaphor | ✓ Good |
| Host CLI config sync (v3.1) | App must reflect connected host's defaults to be useful | ✓ Good |
| Symmetric GitHub browse (Phase 36) | Skills and plugins get identical browse/install/manage UX | ✓ Good |
| Context menu for inline actions (Phase 36) | LazyVStack can't use swipeActions; context menu is standard iOS pattern | ✓ Good |
| No code fixes needed for cross-platform (Phase 38) | All v3.1 phases already had correct #if os(iOS) guards | ✓ Good |
| macOS parity via MacContentView mirroring (Phase 38) | 3 gaps closed by mirroring iOS SidebarRootView patterns | ✓ Good |
| Start v4.0 with v3.5 iPad pending | iPad validation folded into v4.0 visual audit phase | — Pending |
| Skip research for v4.0 | Gap Analysis (Quick Task 6) already provides comprehensive spec mapping | ✓ Good |
| FIX_PROTOCOL mandatory | Every fix through axiom skill → axiom:ask → implement → evidence | — Pending |

---
*Last updated: 2026-02-25 after v4.0 milestone initialization*
