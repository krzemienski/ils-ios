---
phase: 25-concurrency-high-swift6-blockers
plan: 02
subsystem: concurrency
tags: [swift-concurrency, weak-self, nonisolated-unsafe, swift6, websocket, actor]

# Dependency graph
requires:
  - phase: 25-concurrency-high-swift6-blockers
    provides: "Plan 01 fixes TeamsExecutorService non-Sendable Process and SystemMetricsService continuation safety"
provides:
  - "WebSocket Task capture uses [weak self] preventing retain cycles"
  - "ClaudeExecutorService.useAgentSDK marked nonisolated(unsafe) for Swift 6 strict concurrency"
affects: [31-swift6-preparation, 32-final-validation]

# Tech tracking
tech-stack:
  added: []
  patterns: ["[weak self] on inner Task closures within actor callback chains", "nonisolated(unsafe) for set-once-read-many static configuration flags"]

key-files:
  created: []
  modified:
    - Sources/ILSBackend/Services/WebSocketService.swift
    - Sources/ILSBackend/Services/ClaudeExecutorService.swift

key-decisions:
  - "Used [weak self] on inner Task closures (not just outer closure) to prevent retain cycles when WebSocket outlives service"
  - "Used nonisolated(unsafe) for useAgentSDK static var -- set-once-read-many pattern is safe, eliminates Swift 6 compile-error blocker"

patterns-established:
  - "Inner Task weak self: When an actor method registers a callback (e.g., ws.onText) that spawns a Task, both the outer closure AND the inner Task should capture [weak self]"
  - "nonisolated(unsafe) for config flags: Mutable static vars on actors that are set once at startup and read many times should use nonisolated(unsafe) with documenting comment"

requirements-completed: [CONC-02, CONC-10, SWIFT6-01]

# Metrics
duration: 2min
completed: 2026-02-24
---

# Phase 25 Plan 02: WebSocket Task Capture + ClaudeExecutorService Static Var Summary

**WebSocket onText/onClose Task closures use [weak self] preventing retain cycles; ClaudeExecutorService.useAgentSDK marked nonisolated(unsafe) resolving Swift 6 compile-error blocker**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-24T17:22:48Z
- **Completed:** 2026-02-24T17:25:19Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- WebSocketService inner Task closures now use `[weak self]` on both `ws.onText` and `ws.onClose` handlers, preventing retain cycles if WebSocket outlives the service actor
- ClaudeExecutorService `useAgentSDK` static var marked `nonisolated(unsafe)` with documenting comment, resolving the Swift 6 strict concurrency compile-error blocker
- All three build targets (Backend, iOS, macOS) pass with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix WebSocket Task capture + mutable static var** - `acedf3d` (fix)
2. **Task 2: Build verification -- iOS and macOS targets** - verification only, no code changes

## Files Created/Modified
- `Sources/ILSBackend/Services/WebSocketService.swift` - Added `[weak self]` to inner Task closures in `handleConnection` for both `ws.onText` and `ws.onClose`
- `Sources/ILSBackend/Services/ClaudeExecutorService.swift` - Marked `useAgentSDK` as `nonisolated(unsafe) static var` with safety documentation

## Decisions Made
- Used `[weak self]` on inner Task closures (not just the outer closure) to prevent retain cycles when WebSocket outlives the service. The outer closure already had `[weak self]`, but after `guard let self` the inner Task re-captured `self` strongly. Adding `[weak self]` to the Task itself ensures no strong reference is held.
- Used `nonisolated(unsafe)` for `useAgentSDK` rather than making it a `let` constant or `@TaskLocal`. The value can change at runtime (user toggles SDK vs CLI mode), but in practice it is set once during app configuration and read many times. No concurrent writes occur, making `nonisolated(unsafe)` the correct Swift pattern.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- macOS build initially failed with "database is locked" because iOS and macOS builds were run in parallel sharing the same DerivedData. Retried macOS build sequentially after iOS completed -- succeeded immediately.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 25 complete (both plans) -- all 4 HIGH concurrency defects and 2 Swift 6 blockers resolved
- Ready for Phase 26 (Concurrency MEDIUM + LOW) which addresses remaining 15 concurrency patterns
- Phase 31 (Swift 6 Preparation) can now proceed since both compile-error blockers (CONC-10/SWIFT6-01 from this plan, SWIFT6-02 from plan 01) are resolved

## Self-Check: PASSED

- FOUND: WebSocketService.swift
- FOUND: ClaudeExecutorService.swift
- FOUND: 25-02-SUMMARY.md
- FOUND: commit acedf3d
- VERIFIED: 2 `[weak self]` on inner Tasks in WebSocketService
- VERIFIED: 1 `nonisolated(unsafe)` in ClaudeExecutorService

---
*Phase: 25-concurrency-high-swift6-blockers*
*Completed: 2026-02-24*
