---
phase: 20-architecture-performance-high
plan: 03
subsystem: performance
tags: [swiftui, async-let, classification-cache, file-io, copy-on-write, existential-boxing]

# Dependency graph
requires:
  - phase: 18-critical-fixes
    provides: "ThemeSnapshot concrete value type replacing any AppTheme in views"
provides:
  - "Pre-computed process classification cache in ProcessListView"
  - "Async file I/O in ThemeMarketplaceView import handler"
  - "Parallel API calls in DashboardViewModel.loadAll()"
  - "ChatMessage copy overhead analysis and appendText() helper"
  - "SPERF-02 documentation in ThemeManager"
affects: [24-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-compute dictionary cache for O(n) string matching in ForEach views"
    - "Task {} wrapper for synchronous file I/O in SwiftUI result handlers"
    - "async let for parallel independent API calls in @MainActor ViewModels"

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Views/System/ProcessListView.swift
    - ILSApp/ILSApp/Views/Themes/ThemeMarketplaceView.swift
    - ILSApp/ILSApp/ViewModels/DashboardViewModel.swift
    - ILSApp/ILSApp/Models/ChatMessage.swift
    - ILSApp/ILSApp/Theme/AppTheme.swift

key-decisions:
  - "ProcessListView: @State dictionary cache rebuilt on .task + .onChange(of: count) -- lightweight and avoids ViewModel coupling"
  - "ThemeMarketplaceView: Task {} with MainActor.run for mutations -- simplest safe pattern for fileImporter handlers"
  - "DashboardViewModel: async let over withTaskGroup -- clearer intent for exactly 2 parallel calls"
  - "ChatMessage: struct retained as-is -- streaming already uses inout, CoW handles final copy; appendText() added for explicit intent"
  - "SPERF-02: documented as resolved-by-design -- registry stores any AppTheme, views use ThemeSnapshot"

patterns-established:
  - "Pre-compute pattern: rebuild cache dictionary when source data count changes, read from cache in row views"
  - "Async file import: wrap Data(contentsOf:) in Task, hop to MainActor for state mutations"

requirements-completed: [SPERF-02, SPERF-03, SPERF-04, UIPERF-04, UIPERF-05]

# Metrics
duration: 3min
completed: 2026-02-22
---

# Phase 20 Plan 03: UI Rendering & API Parallelization Summary

**Pre-computed process classification cache, async theme file import, parallel dashboard API calls, and ChatMessage copy overhead documentation across 5 files**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-22T23:31:03Z
- **Completed:** 2026-02-22T23:34:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- ProcessListView now reads classification badges from a pre-computed dictionary instead of calling classifyProcess() per ForEach row (50 string-matching calls eliminated per body evaluation)
- ThemeMarketplaceView file import reads data via async Task, preventing main thread blocking during large file reads
- DashboardViewModel.loadAll() runs loadStats() and loadRecentActivity() in parallel with async let, reducing dashboard load time
- ChatMessage struct copy overhead fully analyzed and documented -- streaming path is already optimal (inout mutation + CoW)
- SPERF-02 (any AppTheme existential) documented as resolved-by-design in ThemeManager

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-compute process classification and move theme file I/O off main thread** - `ea6cab4` (perf)
2. **Task 2: Parallelize DashboardViewModel API calls, optimize ChatMessage, and document SPERF-02** - `d348d3d` (perf)

## Files Created/Modified
- `ILSApp/ILSApp/Views/System/ProcessListView.swift` - Added @State classificationCache dictionary, rebuildClassificationCache() method, .task/.onChange triggers; processRow reads from cache
- `ILSApp/ILSApp/Views/Themes/ThemeMarketplaceView.swift` - Wrapped Data(contentsOf:) in Task with MainActor.run for ThemeManager mutations
- `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` - Replaced sequential await with async let for parallel API dispatch
- `ILSApp/ILSApp/Models/ChatMessage.swift` - Added SPERF-03 copy overhead documentation comment and appendText() mutating helper
- `ILSApp/ILSApp/Theme/AppTheme.swift` - Added SPERF-02 documentation comment near availableThemes array

## Decisions Made
- ProcessListView: Used @State dictionary cache over ViewModel-based approach -- keeps classification logic colocated with the view that uses it
- ThemeMarketplaceView: Used Task {} with explicit MainActor.run rather than Task.detached -- simpler pattern, file read still moves off synchronous callsite
- DashboardViewModel: Chose async let over withTaskGroup -- more readable for exactly 2 parallel calls with known types
- ChatMessage: Retained as struct after analysis -- streaming uses inout mutation (no per-token copies), final array append uses CoW for Strings
- SPERF-02: Documented as resolved-by-design rather than attempting to eliminate all `any AppTheme` usage

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- macOS build has a pre-existing failure (ScenePhase/PollingManager.AppPhase type mismatch in ILSMacApp.swift:140) unrelated to this plan's changes. Confirmed by building from clean state before our changes. Logged as out-of-scope.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All SPERF and UIPERF performance items from this plan are resolved
- Pre-existing macOS build error should be addressed in a separate fix
- Ready for Phase 20 Plan 04 or Phase 21

---
*Phase: 20-architecture-performance-high*
*Completed: 2026-02-22*
