# ILS iOS/macOS

## What This Is

A native Swift iOS/macOS client for Claude Code (ILS). The app is code-quality solid after 4 milestones of hardening (v1.0 audit, v2.0 performance, v3.0 remediation, v1.5 audit fixes). This milestone shifts focus from code health to product quality — fixing broken screens, restoring missing features, syncing host CLI defaults, and overhauling navigation and UX across all platforms.

## Core Value

Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience for managing Claude Code sessions, skills, plugins, and system monitoring.

## Current Milestone: v3.1 Comprehensive Audit, Bug Fix & UX Overhaul

**Goal:** Systematically audit every screen, fix broken functionality, restore missing features (GitHub skill/plugin browsing, host config sync, hooks management), redesign Fleet into Host Profiles, and ensure consistent UX across iOS, iPadOS, and macOS.

**Target features:**
- Navigation fixes (side menu accessibility from all screens, session back button, home screen layout)
- Settings & defaults sync (inherit model, system prompt, tools, permissions from host CLI config)
- Browse, Skills & Plugins overhaul (status badges, GitHub browse/install flow, plugin management)
- System Monitor restoration (SSH connection, real-time data)
- Fleet → Host Profiles redesign (multi-host switching, active profile indicator)
- Theme loading fixes and cross-platform validation

**Previous Milestones:**
- v1.0 (Phases 1-10): Cross-Platform Audit — SHIPPED 2026-02-21
- v2.0 (Phases 11-17): Performance Optimization Suite — COMPLETE 2026-02-24
- v3.0 (Phases 18-24): Comprehensive Audit Remediation — COMPLETE 2026-02-23
- v1.5 (Phases 25-32): All Audit Fixes — SHIPPED 2026-02-24

## Requirements

### Validated

- v1.0: REQ-01 through REQ-15 — All PASS (sidebar nav, settings, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP, backend API, visual consistency, sessions)
- v2.0: LAUNCH-01/02, NET-01/02/03, MEM-01/02/03, BATT-01/02, RENDER-01/02/03, BATT-03, COMPAT-01/02, TEST-01/02/03/04 — Performance optimization complete
- v3.0: 165 audit issues remediated across Phases 18-24 (concurrency, energy, architecture, performance, navigation, Codable, build, accessibility, database, networking, security, memory, layout, modernization)
- v1.5-partial: 10 issues fixed in commit c57690f (CRIT-C1, CRIT-E1, CRIT-SP1, H-SP1, H-E1, H-E2, H-E5, H-C3, H-C4, H-M1)

### Active (v3.1 Comprehensive Audit, Bug Fix & UX Overhaul)

*See `.planning/REQUIREMENTS.md` for full scoped requirements with REQ-IDs.*

- Navigation & Home Screen (side menu from all screens, session back button, home layout)
- Settings & Defaults Sync (host CLI config inheritance, override indicators, explanatory text)
- ~~Browse, Skills & Plugins~~ — VALIDATED Phase 36 (BRW-01..08: GitHub browse/install, per-item progress, badges, branch detection, rate limits, context menus)
- System Monitor (SSH connection fix, real-time data)
- Host Profiles (Fleet redesign, multi-host switching)
- Themes (default loading, cross-platform consistency)
- Cross-Platform Validation (iOS, iPadOS, macOS)

### Out of Scope

- App Store submission (separate milestone)
- Android/web platform support
- Full Swift 6 strict mode (`-strict-concurrency=complete`) — already at `targeted` level
- Features from deferred v2.0 performance metrics (100MB memory, "Low" battery rating)
- Backend rewrite — incremental backend changes only as needed for new features

## Context

- **Codebase**: 149+ Swift files (iOS), 14 (macOS), 52 (backend), 26 (shared)
- **Previous work**: v1.0 (audit), v2.0 (performance), v3.0 (remediation), v1.5 (audit fixes) — all shipped
- **Code quality**: All builds green, 31 tests pass, Swift 6 targeted, 70/70 audit findings resolved
- **Product gaps**: Multiple screens have broken or missing functionality despite code-quality hardening
- **Host sync**: App does not currently inherit defaults from connected Claude Code CLI configuration
- **Skills/Plugins**: GitHub browse/install with per-item progress, badges, branch detection, rate limit messaging (Phase 36)
- **Fleet**: Current implementation needs redesign to Host Profiles concept
- **Backend**: Vapor 4, SQLite, port 9999 — may need endpoint additions for new features

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
| Skip research for v1.5 | Audit reports serve as requirements — no new features | ✓ Good |
| v1.5 naming (user-specified) | Decoupled from internal phase numbering (Phase 25+) | ✓ Good |
| Shift to product quality (v3.1) | Code health complete; UX gaps now blocking real usage | — Pending |
| Fleet → Host Profiles (v3.1) | Multi-host concept clearer than fleet metaphor | — Pending |
| Host CLI config sync (v3.1) | App must reflect connected host's defaults to be useful | — Pending |
| Symmetric GitHub browse (Phase 36) | Skills and plugins get identical browse/install/manage UX | ✓ Good |
| Context menu for inline actions (Phase 36) | LazyVStack can't use swipeActions; context menu is standard iOS pattern | ✓ Good |

---
*Last updated: 2026-02-25 after Phase 36 (Browse, Skills & Plugins)*
