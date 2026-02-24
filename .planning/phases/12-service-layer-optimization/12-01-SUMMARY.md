---
phase: 12-service-layer-optimization
plan: 01
subsystem: networking
tags: [nscache, request-coalescing, memory-pressure, actor-isolation, swift-concurrency]

# Dependency graph
requires:
  - phase: 22-high-energy-build-a11y
    provides: NET-01 TOFU documentation, existing cache TTL logic
  - phase: 19-concurrency-memory
    provides: MEM-01 Timer-to-Task migration, actor-based services
provides:
  - In-flight GET request coalescing via actor-isolated Task dictionary
  - Memory-bounded NSCache with totalCostLimit (10MB) and per-entry cost estimation
  - Mutation-triggered in-flight cancellation preventing stale cache repopulation
  - iOS memory pressure observer for proactive GRDB cache eviction
affects: [13-viewmodel-optimization, 14-sse-client-optimization, 15-view-layer-optimization]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Actor-isolated in-flight Task dictionary for request coalescing"
    - "MemoryLayout.stride-based cost estimation for NSCache totalCostLimit"
    - "NotificationCenter memory pressure observer with #if os(iOS) guard"

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Services/APIClient.swift
    - ILSApp/ILSApp/ILSAppApp.swift

key-decisions:
  - "Used Task<Any, Error> for in-flight dictionary to support heterogeneous generic types across concurrent callers"
  - "MemoryLayout.stride for cost estimation — absolute accuracy unnecessary since NSCache treats cost as eviction priority signal"
  - "Observer registration in .task modifier rather than new stored property — App struct lifecycle matches process lifetime"
  - "100MB memory target deferred — 273MB RSS baseline includes system frameworks, requires Instruments profiling"

patterns-established:
  - "In-flight coalescing: check inFlightGETs[path] before network call, store Task, defer cleanup"
  - "Cost-bounded caching: cache.setObject with estimatedCost for memory-aware eviction"

requirements-completed: [NET-01, NET-03, MEM-01]

# Metrics
duration: 3min
completed: 2026-02-23
---

# Phase 12 Plan 01: Service Layer Optimization Summary

**In-flight GET request coalescing via actor-isolated Task dictionary, 10MB NSCache totalCostLimit with stride-based cost estimation, and iOS memory pressure observer for proactive GRDB cache eviction**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-23T14:53:02Z
- **Completed:** 2026-02-23T14:56:12Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Concurrent GET requests to the same API path now share a single network call via actor-isolated inFlightGETs dictionary
- NSCache has both countLimit (100) and totalCostLimit (10MB) with per-entry cost estimation using MemoryLayout.stride
- POST/PUT/DELETE mutations cancel in-flight GETs for affected paths and parent list paths, preventing stale cache repopulation
- iOS memory pressure observer proactively clears GRDB persistent cache with diagnostic logging

## Task Commits

Each task was committed atomically:

1. **Task 1: Add in-flight request coalescing and totalCostLimit to APIClient** - `56d80b2` (feat)
2. **Task 2: Add memory pressure observer for proactive cache eviction** - `06d9715` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/Services/APIClient.swift` - Added inFlightGETs dictionary, totalCostLimit, estimatedCost helper, coalescing in get(), cancellation in invalidateCacheForMutation()
- `ILSApp/ILSApp/ILSAppApp.swift` - Added UIApplication.didReceiveMemoryWarningNotification observer with #if os(iOS) guard

## Decisions Made
- Used `Task<Any, Error>` for in-flight dictionary value type to support heterogeneous Decodable types across concurrent callers — `as?` downcast handles type safety
- MemoryLayout.stride for cost estimation rather than serialized size — NSCache treats cost as a relative eviction signal, not absolute bytes
- Memory pressure observer registered in `.task` modifier rather than creating a new MemoryPressureMonitor class — single observer registration does not warrant a new file
- 100MB memory target deferred to a profiling phase — 273MB RSS baseline at cold start includes UIKit/SwiftUI system frameworks, making the target meaningless without Instruments attribution

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused `session` capture in Task closure**
- **Found during:** Task 1 (APIClient coalescing)
- **Issue:** Capture list included `session` but `performWithRetry` accesses it via `self`
- **Fix:** Removed `session` from capture list, kept `baseURL` and `decoder`
- **Files modified:** ILSApp/ILSApp/Services/APIClient.swift
- **Verification:** Build warning eliminated, iOS + macOS BUILD SUCCEEDED
- **Committed in:** 56d80b2 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor compiler warning fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- APIClient request coalescing and memory-bounded caching are complete
- Ready for Phase 13 (ViewModel optimization) which can leverage the improved caching layer
- 100MB memory target requires separate Instruments profiling phase

## Self-Check: PASSED

- [x] APIClient.swift: FOUND
- [x] ILSAppApp.swift: FOUND
- [x] 12-01-SUMMARY.md: FOUND
- [x] Commit 56d80b2: FOUND (Task 1)
- [x] Commit 06d9715: FOUND (Task 2)

---
*Phase: 12-service-layer-optimization*
*Completed: 2026-02-23*
