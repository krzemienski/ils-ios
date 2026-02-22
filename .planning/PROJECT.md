# ILS iOS/macOS — Performance Optimization Suite

## What This Is

A native Swift iOS/macOS client for Claude Code (ILS). After completing a comprehensive cross-platform audit (v1.0 — 10 phases, 15/15 REQs PASS, 0 crashes), the app is functionally correct across all Apple platforms. This milestone focuses on making it *fast* — optimizing launch time, memory usage, network efficiency, rendering performance, and battery impact.

## Core Value

The app must feel instant and lightweight — launch in under 1 second, use under 100MB memory, maintain 60fps scrolling, and achieve "Low" battery rating. Native SwiftUI is our competitive advantage over Electron-based alternatives; this milestone ensures we capitalize on it.

## Current Milestone: v2.0 Performance Optimization Suite

**Goal:** Optimize all five performance dimensions to production-quality baselines with regression test infrastructure.

**Target features:**
- Launch time optimization (< 1 second cold start)
- Memory usage optimization (< 100MB typical sessions)
- Network request batching and deduplication
- 60fps rendering for large lists and chat histories
- Battery impact optimization ("Low" rating)
- Performance regression test infrastructure

## Requirements

### Validated (from v1.0 Cross-Platform Audit)

- REQ-01 through REQ-15: All PASS — sidebar navigation, settings inheritance, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP servers, backend API, zero visual regressions, session consistency

### Active

- [ ] PERF-01: App launches in under 1 second (cold start)
- [ ] PERF-02: Memory usage stays under 100MB for typical sessions
- [ ] PERF-03: Network requests are batched and deduplicated
- [ ] PERF-04: Large lists (500+ sessions) scroll at 60fps
- [ ] PERF-05: Chat with 200+ messages renders without jank
- [ ] PERF-06: Battery impact rated "Low" by iOS Energy Organizer
- [ ] PERF-07: Performance regression tests prevent future degradation

### Out of Scope

- New feature development beyond performance
- App Store submission (separate milestone)
- Android/web platform support
- Server-side performance optimization (backend Vapor is already fast)
- UI redesign or architectural changes

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
*Last updated: 2026-02-22 after v2.0 milestone start*
