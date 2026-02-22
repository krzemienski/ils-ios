# ILS iOS/macOS — Performance Optimization Suite

## What This Is

A native Swift iOS/macOS client for Claude Code (ILS). After completing a comprehensive cross-platform audit (v1.0 — 10 phases, 15/15 REQs PASS, 0 crashes), the app is functionally correct across all Apple platforms. This milestone focuses on making it *fast* — optimizing launch time, memory usage, network efficiency, rendering performance, and battery impact.

## Core Value

The app must feel instant and lightweight — launch in under 1 second, use under 100MB memory, maintain 60fps scrolling, and achieve "Low" battery rating. Native SwiftUI is our competitive advantage over Electron-based alternatives; this milestone ensures we capitalize on it.

## Current Milestone: v3.0 Comprehensive Audit Remediation

**Goal:** Fix all 165 issues (13 CRITICAL, 49 HIGH, 73 MEDIUM, 30 LOW) found across 15 Axiom audits to achieve production-quality code health across concurrency safety, energy efficiency, architecture, performance, navigation, error handling, accessibility, and security.

**Target features:**
- Concurrency safety (Swift 6 readiness — data race elimination, actor adoption)
- Energy efficiency (polling optimization, animation lifecycle, background suspension)
- SwiftUI architecture (business logic extraction from views, ViewModel routing)
- Swift + SwiftUI performance (cached syntax highlighting, Set-based lookups, lazy evaluation)
- Navigation correctness (dead path cleanup, macOS parity)
- Error handling (try? → do/catch, Codable best practices)
- Accessibility compliance (Dynamic Type, reduce motion, WCAG)
- Database safety (PRAGMA foreign_keys, migration correctness)
- Build optimization (dSYM, ONLY_ACTIVE_ARCH)
- Networking safety (SSH host validation, reconnection handling)
- Memory lifecycle (Timer → Task migration, cleanup on window close)

**Previous Milestone: v2.0 Performance Optimization Suite**
- Phase 11 complete (launch baseline)
- Phases 12-17 remain (will resume after v3.0 or be absorbed where overlapping)

## Requirements

### Validated (from v1.0 Cross-Platform Audit)

- REQ-01 through REQ-15: All PASS — sidebar navigation, settings inheritance, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP servers, backend API, zero visual regressions, session consistency

### Active (v3.0 Audit Remediation)

- [ ] CONC-01: All data races eliminated (AppLogger actor, SyntaxHighlighter @MainActor)
- [ ] CONC-02: nonisolated(unsafe) Task patterns fixed across all ViewModels
- [ ] CONC-03: GCD→Task migration for @MainActor boundary crossings
- [ ] ENRG-01: Polling optimized (MCP lightweight health, Teams exponential backoff)
- [ ] ENRG-02: Animation lifecycle managed (Low Power Mode, background suspend)
- [ ] ENRG-03: Live Activity timer reduced to 1.0s interval
- [ ] ARCH-01: MacChatView API calls routed through ViewModel
- [ ] ARCH-02: NewSessionView business logic extracted to ViewModel
- [ ] ARCH-03: Logic-in-view extracted across 6+ views
- [ ] ARCH-04: Binding setter async patterns fixed
- [ ] PERF-S1: SyntaxHighlighter cached with .task(id:), keywords → Set
- [ ] PERF-S2: CodeBlockView computed properties cached
- [ ] PERF-S3: ThemePickerView Set-based availability check
- [ ] PERF-S4: classifyProcess pre-computed in ViewModel
- [ ] NAV-01: Dead NavigationPath removed, nested NavigationStack fixed
- [ ] NAV-02: macOS navigation completeness (hooks, detail column)
- [ ] CODBL-01: try? → do/catch conversions across APIClient, CacheService, AuthService
- [ ] CODBL-02: Codable best practices (dateDecodingStrategy, CodingKeys)
- [ ] DB-01: PRAGMA foreign_keys set via pool configuration callback
- [ ] DB-02: DROP TABLE removed from revert() functions
- [ ] A11Y-01: Fixed font sizes replaced with Dynamic Type in 3 views
- [ ] A11Y-02: Reduce motion checks added to animations
- [ ] BUILD-01: dSYM format and ONLY_ACTIVE_ARCH optimized for debug
- [ ] NET-01: SSH host key validation implemented properly
- [ ] NET-02: WebSocket/polling reconnection with timeouts
- [ ] MEM-01: HostProfilesViewModel Timer → Task migration
- [ ] MEM-02: WindowFrameDelegate cleanup on OS window close
- [ ] LAYOUT-01: Size class identity loss fixed
- [ ] SEC-01: Localhost hardcoding reviewed
- [ ] MOD-01: Minor API deprecation cleanups

### Deferred (v2.0 Performance — resume after v3.0)

- [ ] PERF-01: App launches in under 1 second (cold start) — Phase 11 DONE
- [ ] PERF-02: Memory usage stays under 100MB for typical sessions
- [ ] PERF-03: Network requests are batched and deduplicated
- [ ] PERF-04: Large lists (500+ sessions) scroll at 60fps
- [ ] PERF-05: Chat with 200+ messages renders without jank
- [ ] PERF-06: Battery impact rated "Low" by iOS Energy Organizer
- [ ] PERF-07: Performance regression tests prevent future degradation

### Out of Scope

- New feature development
- App Store submission (separate milestone)
- Android/web platform support
- Full Swift 6 migration (address data races, but don't enable strict mode yet)
- v2.0 phases 12-17 (deferred, some overlap will be absorbed)

## Context

- **Codebase**: 149+ Swift files (iOS), 14 (macOS), 52 (backend), 26 (shared)
- **Previous work**: v1.0 audit complete — 216 issues remediated, 30 bugs found/7 fixed, zero crashes
- **Known perf issues**: Artificial launch delay existed (2.2s), fixed font sizes, no lazy loading for large message lists, no request batching, animations run in Low Power Mode
- **Competitive edge**: Native SwiftUI vs Cursor/Cline/Windsurf (Electron). Performance is the differentiator.
- **Backend**: Vapor 4, SQLite, port 9999 — already fast for read operations

## Constraints

- **Platform**: iOS 17+, macOS 14+, Swift 5.10+, SwiftUI
- **Simulator**: UDID 50523130-57AA-48B0-ABD0-4D59CE455F14 (iPhone 16 Pro Max)
- **No mocks**: Functional validation only — real system, real measurements
- **Backward compat**: All v1.0 audit REQs must remain PASS after optimization
- **Build system**: Auto-build hook fires on every .swift edit

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| All 5 perf dimensions in scope | User wants comprehensive optimization, not incremental | — Pending |
| Research before planning | Analyze current bottlenecks before designing solutions | — Pending |
| Regression tests included | Prevent future perf degradation with XCTest metrics | — Pending |

---
*Last updated: 2026-02-22 after v3.0 milestone start (Comprehensive Audit Remediation)*
