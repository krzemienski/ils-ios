---
phase: 20-architecture-performance-high
plan: 02
subsystem: architecture
tags: [swiftui, mvvm, separation-of-concerns, binding, view-body-optimization]

requires:
  - phase: 18-critical-fixes
    provides: "Foundation services and ViewModel patterns"
provides:
  - "SwiftUI-free PollingManager service layer"
  - "Synchronous Binding setters delegating to ViewModel fire-and-forget methods"
  - "Pre-computed hook event breakdown in ViewModel"
  - "Cached sorted entries in FileBrowserView via @State"
affects: [settings, file-browser, polling, cross-platform]

tech-stack:
  added: []
  patterns:
    - "PollingManager.AppPhase enum to decouple service from SwiftUI.ScenePhase"
    - "Fire-and-forget ViewModel methods (updateModel, updateToggle) for synchronous Binding setters"
    - "@State cache + onChange(of:) for computed-property-in-body elimination"

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Services/PollingManager.swift
    - ILSApp/ILSApp/ViewModels/SettingsViewModel.swift
    - ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift
    - ILSApp/ILSApp/Views/Settings/SettingsView.swift
    - ILSApp/ILSApp/Views/System/FileBrowserView.swift
    - ILSApp/ILSMacApp/ILSMacApp.swift
    - Sources/ILSShared/DTOs/SystemDTOs.swift

key-decisions:
  - "Used PollingManager.AppPhase enum instead of importing SwiftUI for ScenePhase"
  - "Fire-and-forget ViewModel methods create internal Task rather than Binding setters containing Task{await}"
  - "hookEventBreakdown as computed property on ViewModel (derived from cached config) rather than @State cache"
  - "FileEntryResponse gained Equatable for onChange(of:) support"

patterns-established:
  - "Service classes must not import SwiftUI -- use Foundation + custom enums for UI types"
  - "Binding setters must be synchronous -- delegate async work to ViewModel methods"
  - "Computed properties in view body that sort/filter should become @State cached + onChange"

requirements-completed: [ARCH-08, ARCH-09, ARCH-10, ARCH-11, ARCH-12]

duration: 7min
completed: 2026-02-22
---

# Phase 20 Plan 02: Architecture Violations in Settings/FileBrowser/PollingManager Summary

**Removed SwiftUI from PollingManager, eliminated async Binding setters, and cached view-body computed properties in Settings and FileBrowser views**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-22T23:31:06Z
- **Completed:** 2026-02-22T23:38:30Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- PollingManager is now SwiftUI-free with custom AppPhase enum, improving testability
- All three SettingsConfigSection Binding setters are synchronous (zero Task{} blocks)
- SettingsView.testConnection delegates entirely to ViewModel.saveAndTestConnection
- hookEventBreakdown data computed once in ViewModel, not rebuilt on every view body evaluation
- FileBrowserView sorted entries cached via @State instead of computed property on every render
- Both iOS and macOS builds green

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove SwiftUI from PollingManager and fix Binding setters** - `cc6afe1` (refactor)
2. **Task 2: Extract SettingsView.testConnection, hookEventBreakdown, and FileBrowserView.sortedEntries** - `942bcfa` (refactor)

## Files Created/Modified
- `ILSApp/ILSApp/Services/PollingManager.swift` - Replaced import SwiftUI with Foundation, added AppPhase enum
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` - Added updateModel, updateToggle, saveAndTestConnection, hookEventBreakdown
- `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` - Synchronous Binding setters, hookBreakdownView reads from ViewModel
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift` - testConnection delegates to ViewModel
- `ILSApp/ILSApp/Views/System/FileBrowserView.swift` - @State cachedSortedEntries with static sortEntries helper
- `ILSApp/ILSMacApp/ILSMacApp.swift` - ScenePhase to AppPhase mapping (cross-platform fix)
- `Sources/ILSShared/DTOs/SystemDTOs.swift` - FileEntryResponse Equatable conformance

## Decisions Made
- Used `PollingManager.AppPhase` enum to completely decouple from SwiftUI -- callers map ScenePhase at call site
- Fire-and-forget pattern: synchronous ViewModel methods internally create Task for async work
- hookEventBreakdown as computed property on ViewModel rather than @State cache -- it derives from already-cached config, so no extra caching needed
- Added Equatable to FileEntryResponse to enable onChange(of: entries) for cache invalidation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] macOS ILSMacApp.swift ScenePhase mapping**
- **Found during:** Task 2 (cross-platform build verification)
- **Issue:** macOS app directly passed ScenePhase to PollingManager.handleScenePhase, which now expects AppPhase
- **Fix:** Added same ScenePhase-to-AppPhase switch mapping as iOS ILSAppApp.swift
- **Files modified:** ILSApp/ILSMacApp/ILSMacApp.swift
- **Verification:** macOS build passes
- **Committed in:** 942bcfa (Task 2 commit)

**2. [Rule 1 - Bug] SettingsViewModel hookEventBreakdown optional chaining**
- **Found during:** Task 2 (iOS build verification)
- **Issue:** `config?.content?.hooks` used optional chaining on non-optional `content` property, causing compiler error
- **Fix:** Changed to `config?.content.hooks` (content is non-optional ClaudeConfig)
- **Files modified:** ILSApp/ILSApp/ViewModels/SettingsViewModel.swift
- **Verification:** iOS build passes
- **Committed in:** 942bcfa (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Architecture violations ARCH-08 through ARCH-12 resolved
- Settings, FileBrowser, and PollingManager follow clean MVVM patterns
- Ready for remaining Phase 20 plans (20-03, 20-04)

---
*Phase: 20-architecture-performance-high*
*Completed: 2026-02-22*
