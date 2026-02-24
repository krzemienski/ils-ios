# ILS iOS/macOS

## What This Is

A native Swift iOS/macOS client for Claude Code (ILS). The app is functionally complete (v1.0), performance-optimized (v2.0), and has passed comprehensive audit remediation (v3.0). This milestone addresses remaining code quality issues found during a full re-audit on 2026-02-24.

## Core Value

Ship-ready code quality — every audit finding resolved, tests reliable and meaningful, Swift 6 concurrency on a clear migration path. Native SwiftUI is our competitive advantage; this milestone ensures the codebase is maintainable and safe for ongoing development.

## Current Milestone: v1.5 All Audit Fixes

**Goal:** Fix the remaining ~60 issues from the 2026-02-24 full codebase re-audit (70 total, 10 already fixed in commit c57690f) — covering testing infrastructure overhaul, concurrency hardening, energy/memory cleanup, and SwiftUI performance improvements.

**Target features:**
- Testing infrastructure overhaul (replace sleep() with condition-based waiting, meaningful unit tests, Swift Testing migration)
- Concurrency hardening (remaining HIGH/MEDIUM: Task captures, Sendable compliance, continuation safety)
- Energy/memory cleanup (animation lifecycle, polling tuning, observer cleanup, NSTask lifecycle)
- SwiftUI performance (computed property caching, filter memoization, lazy container adoption)
- Swift 6 preparation (address the two compile-error blockers, move toward strict-concurrency=targeted)

**Previous Milestones:**
- v1.0 (Phases 1-10): Cross-Platform Audit — SHIPPED 2026-02-21
- v2.0 (Phases 11-17): Performance Optimization Suite — COMPLETE 2026-02-24
- v3.0 (Phases 18-24): Comprehensive Audit Remediation — COMPLETE 2026-02-23

## Requirements

### Validated

- v1.0: REQ-01 through REQ-15 — All PASS (sidebar nav, settings, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP, backend API, visual consistency, sessions)
- v2.0: LAUNCH-01/02, NET-01/02/03, MEM-01/02/03, BATT-01/02, RENDER-01/02/03, BATT-03, COMPAT-01/02, TEST-01/02/03/04 — Performance optimization complete
- v3.0: 165 audit issues remediated across Phases 18-24 (concurrency, energy, architecture, performance, navigation, Codable, build, accessibility, database, networking, security, memory, layout, modernization)
- v1.5-partial: 10 issues fixed in commit c57690f (CRIT-C1, CRIT-E1, CRIT-SP1, H-SP1, H-E1, H-E2, H-E5, H-C3, H-C4, H-M1)

### Active (v1.5 All Audit Fixes)

*See `.planning/REQUIREMENTS.md` for full scoped requirements with REQ-IDs.*

### Out of Scope

- New feature development — code health only
- App Store submission (separate milestone)
- Android/web platform support
- Full Swift 6 strict mode (`-strict-concurrency=complete`) — address blockers, target `targeted` level
- Features from deferred v2.0 performance metrics (100MB memory, "Low" battery rating)

## Context

- **Codebase**: 149+ Swift files (iOS), 14 (macOS), 52 (backend), 26 (shared)
- **Previous work**: v1.0 (216 issues), v2.0 (performance baselines), v3.0 (165 audit issues) — all complete
- **2026-02-24 re-audit**: 70 new issues found by 16 parallel specialist agents; 10 already fixed
- **Testing gap**: Biggest category (19 issues) — tests use sleep(), placeholders, no Swift Testing
- **Swift 6 blockers**: 2 compile-error issues blocking `-strict-concurrency=complete`
- **Backend**: Vapor 4, SQLite, port 9999 — no backend issues in this audit

## Constraints

- **Platform**: iOS 17+, macOS 14+, Swift 5.10+, SwiftUI
- **Simulator**: UDID 50523130-57AA-48B0-ABD0-4D59CE455F14 (iPhone 16 Pro Max)
- **No mocks**: Functional validation only — real system, real measurements
- **Backward compat**: All v1.0 audit REQs must remain PASS
- **Build system**: Auto-build hook fires on every .swift edit
- **Phase numbering**: Continues from 25 (v3.0 ended at Phase 24)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| All 5 perf dimensions in scope (v2.0) | Comprehensive optimization | ✓ Good |
| Research before planning (v2.0) | Analyzed bottlenecks first | ✓ Good |
| Regression tests included (v2.0) | XCTest metrics in Phase 17 | ✓ Good |
| Skip research for v1.5 | Audit reports serve as requirements — no new features | — Pending |
| v1.5 naming (user-specified) | Decoupled from internal phase numbering (Phase 25+) | — Pending |

---
*Last updated: 2026-02-24 after v1.5 milestone start (All Audit Fixes)*
