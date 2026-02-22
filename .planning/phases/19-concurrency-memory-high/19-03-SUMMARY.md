---
phase: 19-concurrency-memory-high
plan: 03
subsystem: concurrency
tags: [swift-concurrency, sendable, task-detached, sse, isolation]

# Dependency graph
requires:
  - phase: 18-critical-fixes
    provides: "AppLogger OSAllocatedUnfairLock thread safety (18-01)"
provides:
  - "Isolation-correct SSEClient heartbeat watchdog capturing only Sendable values"
affects: [24-validation]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Task.detached closures should capture only Sendable values, never @MainActor self"]

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Services/SSEClient.swift

key-decisions:
  - "Removed [weak self] entirely rather than replacing with alternative — watchdog needs no reference to SSEClient"

patterns-established:
  - "Task.detached watchdog pattern: capture only Sendable actors, let Task.isCancelled handle lifecycle"

requirements-completed: [CONC-09]

# Metrics
duration: 1min
completed: 2026-02-22
---

# Phase 19 Plan 03: SSEClient Heartbeat Watchdog Isolation Summary

**Removed @MainActor self capture from Task.detached heartbeat watchdog, capturing only Sendable LastActivityTracker actor**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-22T23:14:28Z
- **Completed:** 2026-02-22T23:15:27Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Eliminated @MainActor isolation violation in Task.detached watchdog closure
- Removed unnecessary `[weak self]` capture and `guard self != nil` check
- Watchdog now captures only Sendable values: `LastActivityTracker` actor and `AppLogger.shared`
- Both iOS and macOS builds pass with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove self capture from SSEClient heartbeat watchdog** - `f4658df` (fix)

## Files Created/Modified
- `ILSApp/ILSApp/Services/SSEClient.swift` - Removed `[weak self]` capture list and `guard self != nil` from heartbeat watchdog Task.detached closure

## Decisions Made
- Removed `[weak self]` entirely rather than replacing with a different capture strategy. The watchdog only checks `lastActivity.secondsSinceLastActivity()` and logs via `AppLogger.shared` -- neither requires a reference to SSEClient. The `defer { heartbeatWatchdog.cancel() }` on the parent scope ensures the watchdog is cancelled when the stream ends, making the `guard self != nil` lifecycle check redundant with `Task.isCancelled`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SSEClient heartbeat watchdog is now isolation-correct
- All Task.detached closures in SSEClient capture only Sendable values
- Ready for remaining Phase 19 plans or Phase 20

## Self-Check: PASSED

- FOUND: SSEClient.swift
- FOUND: f4658df (Task 1 commit)
- FOUND: 19-03-SUMMARY.md

---
*Phase: 19-concurrency-memory-high*
*Completed: 2026-02-22*
