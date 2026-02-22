---
phase: 19-concurrency-memory-high
plan: 02
subsystem: concurrency
tags: [swift-concurrency, MainActor, GCD-migration, NSWindowDelegate, Task-debounce, macOS]

# Dependency graph
requires:
  - phase: 18-critical-fixes
    provides: "Foundation services with correct actor isolation patterns"
provides:
  - "GCD-free macOS managers with proper MainActor isolation"
  - "WindowFrameDelegate with window close lifecycle cleanup"
  - "NotificationManager without @preconcurrency suppression"
affects: [19-concurrency-memory-high, 24-validation]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Task { @MainActor in } for nonisolated-to-MainActor crossing", "Task-based debounce replacing DispatchWorkItem + asyncAfter", "windowWillClose delegate for lifecycle cleanup"]

key-files:
  created: []
  modified:
    - ILSApp/ILSMacApp/Managers/NotificationManager.swift
    - ILSApp/ILSMacApp/Views/SessionWindowView.swift
    - ILSApp/ILSMacApp/Managers/WindowManager.swift

key-decisions:
  - "Used nonisolated + Task { @MainActor in } for NotificationManager delegate methods instead of removing @MainActor from the class"
  - "WindowFrameDelegate windowWillClose as NSWindowDelegate method (not NotificationCenter observer) since delegate is already set on window"
  - "Belt-and-suspenders deinit cancellation on WindowFrameDelegate debounce Task"

patterns-established:
  - "nonisolated delegate with @MainActor hop: Use nonisolated on SDK delegate methods, hop to MainActor via Task only when accessing @MainActor state"
  - "Task-based debounce: Cancel previous Task, create new Task with Task.sleep, check isCancelled after sleep"

requirements-completed: [CONC-06, CONC-07, CONC-08, MEM-02]

# Metrics
duration: 2min
completed: 2026-02-22
---

# Phase 19 Plan 02: macOS GCD-to-MainActor Migration Summary

**Eliminated all GCD-to-@MainActor crossings in macOS managers with Task-based debounce and window close lifecycle cleanup**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-22T23:14:22Z
- **Completed:** 2026-02-22T23:16:37Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Removed @preconcurrency suppression from NotificationManager delegate conformance, using nonisolated + Task { @MainActor in } for correct isolation
- Replaced DispatchQueue.main.async in WindowAccessor with Task { @MainActor in } for proper actor hop
- Migrated WindowFrameDelegate from DispatchWorkItem + DispatchQueue.main.asyncAfter to Task-based debounce
- Added windowWillClose delegate method to cancel pending debounce Tasks when OS closes windows directly, preventing delegate accumulation

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix NotificationManager delegate isolation and WindowAccessor GCD crossing** - `b5d72cd` (fix)
2. **Task 2: Migrate WindowFrameDelegate from GCD to Task and add window close cleanup** - `4e461c1` (fix)

## Files Created/Modified
- `ILSApp/ILSMacApp/Managers/NotificationManager.swift` - Removed @preconcurrency, added nonisolated delegate methods with @MainActor hop
- `ILSApp/ILSMacApp/Views/SessionWindowView.swift` - WindowAccessor uses Task { @MainActor in } instead of DispatchQueue.main.async
- `ILSApp/ILSMacApp/Managers/WindowManager.swift` - WindowFrameDelegate uses Task-based debounce with windowWillClose cleanup

## Decisions Made
- Used nonisolated + Task { @MainActor in } for NotificationManager delegate methods because UNUserNotificationCenterDelegate is not @MainActor in the SDK -- the willPresent method doesn't need MainActor (just calls completionHandler), while didReceive wraps NSApplication/NotificationCenter access in a MainActor Task
- Implemented windowWillClose as NSWindowDelegate method rather than a separate NotificationCenter observer since WindowFrameDelegate is already set as the window's delegate
- Added deinit cancellation on debounceTask as belt-and-suspenders cleanup

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- macOS managers now use correct Swift Concurrency patterns with zero GCD crossings
- WindowFrameDelegate properly cleans up on window close, preventing accumulation
- Ready for remaining Phase 19 plans (19-03)

## Self-Check: PASSED

All files found. All commits verified (b5d72cd, 4e461c1).

---
*Phase: 19-concurrency-memory-high*
*Completed: 2026-02-22*
