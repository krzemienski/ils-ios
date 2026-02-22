---
phase: 19-concurrency-memory-high
plan: 01
subsystem: concurrency
tags: [swift-concurrency, mainactor, task, timer, nonisolated-unsafe, observation]

# Dependency graph
requires:
  - phase: 18-critical-fixes
    provides: "OSAllocatedUnfairLock patterns, @MainActor enum isolation, .task(id:) caching"
provides:
  - "Zero nonisolated(unsafe) declarations in ViewModel layer"
  - "Task-based polling pattern replacing Timer.scheduledTimer"
  - "Correct @MainActor isolation for Task properties in ViewModels"
affects: [19-concurrency-memory-high, 20-arch-perf-medium]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@ObservationIgnored private var task: Task<Void, Never>? for MainActor ViewModels"
    - "while !Task.isCancelled + Task.sleep polling loop replacing Timer.scheduledTimer"

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/ViewModels/SkillsViewModel.swift
    - ILSApp/ILSApp/ViewModels/MCPViewModel.swift
    - ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift
    - ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift

key-decisions:
  - "Task.cancel() is safe from nonisolated deinit -- no workaround needed"
  - "Added @ObservationIgnored to SystemMetricsViewModel.processRefreshTask (was missing)"
  - "Task.sleep(for:) used instead of nanoseconds variant for readability in HostProfilesViewModel"

patterns-established:
  - "ViewModel Task storage: @ObservationIgnored private var xTask: Task<Void, Never>? (no nonisolated(unsafe))"
  - "Polling pattern: Task { [weak self] in while !Task.isCancelled { try? await Task.sleep(for:); guard let self ... } }"

requirements-completed: [CONC-03, CONC-04, CONC-05, MEM-01]

# Metrics
duration: 2min
completed: 2026-02-22
---

# Phase 19 Plan 01: ViewModel Concurrency Cleanup Summary

**Removed all nonisolated(unsafe) from ViewModel Task properties and migrated HostProfilesViewModel from Timer.scheduledTimer to Task-based polling**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-22T23:14:16Z
- **Completed:** 2026-02-22T23:16:21Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Eliminated all `nonisolated(unsafe)` declarations from SkillsViewModel, MCPViewModel, and SystemMetricsViewModel
- Added missing `@ObservationIgnored` to SystemMetricsViewModel.processRefreshTask
- Migrated HostProfilesViewModel from `Timer.scheduledTimer` to structured `Task`-based polling loop
- Zero `nonisolated(unsafe)` and zero `Timer.scheduledTimer` remain in the ViewModel layer

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove nonisolated(unsafe) from three ViewModels** - `746ab4c` (fix)
2. **Task 2: Migrate HostProfilesViewModel Timer to Task polling** - `ce8a2a9` (fix)

## Files Created/Modified
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` - Removed nonisolated(unsafe) from searchTask property
- `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` - Removed nonisolated(unsafe) from healthTimer property
- `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` - Replaced nonisolated(unsafe) with @ObservationIgnored on processRefreshTask
- `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` - Replaced Timer.scheduledTimer with Task-based while loop polling

## Decisions Made
- Task.cancel() is documented as safe to call from any isolation context, so deinit patterns work without workarounds
- Added @ObservationIgnored to SystemMetricsViewModel.processRefreshTask since Task properties should not trigger observation (was missing from original code)
- Used Task.sleep(for: .seconds(interval)) in HostProfilesViewModel for readability over nanoseconds variant

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added @ObservationIgnored to SystemMetricsViewModel.processRefreshTask**
- **Found during:** Task 1 (nonisolated(unsafe) removal)
- **Issue:** processRefreshTask was missing @ObservationIgnored, meaning Task property changes could trigger spurious observation updates
- **Fix:** Added @ObservationIgnored alongside the nonisolated(unsafe) removal
- **Files modified:** ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift
- **Verification:** Build passes, grep confirms correct annotation
- **Committed in:** 746ab4c (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for correctness -- Task property changes should not trigger UI observation. No scope creep.

## Issues Encountered
None -- all changes compiled on first attempt, both iOS and macOS builds pass.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ViewModel layer is now free of nonisolated(unsafe) and Timer.scheduledTimer
- Ready for 19-02 (additional concurrency/memory fixes)
- All four ViewModels maintain existing functionality (search debounce, health polling, process refresh, host health polling)

---
*Phase: 19-concurrency-memory-high*
*Completed: 2026-02-22*
