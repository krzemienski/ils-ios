---
phase: 37-system-monitor-themes
plan: 01
subsystem: ui
tags: [swiftui, websocket, system-monitor, host-profiles]

# Dependency graph
requires:
  - phase: 34-host-profiles
    provides: Host profile activation with appState.serverURL reactivity
provides:
  - Host-aware SystemMetricsViewModel with mutable baseURL and updateBaseURL() method
  - SystemMonitorView onChange reactivity for live host switching
affects: [37-02, system-monitor, fleet]

# Tech tracking
tech-stack:
  added: []
  patterns: [updateBaseURL pattern for host-aware ViewModels]

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift
    - ILSApp/ILSApp/Views/System/SystemMonitorView.swift

key-decisions:
  - "Kept init default parameter as localhost:9999 for previews; only runtime baseURL is mutable"
  - "updateBaseURL is a no-op when URL unchanged (guard) -- safe to call on every onAppear"
  - "Removed redundant loadProcesses from onAppear since connect() already calls startProcessAutoRefresh which does initial load"

patterns-established:
  - "updateBaseURL pattern: disconnect, swap client, clear stale data, guard against same-URL no-op"

requirements-completed: [SYS-01]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 37 Plan 01: System Monitor Host Fix Summary

**System Monitor WebSocket and REST endpoints now follow active host profile via mutable baseURL with onChange reactivity**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T03:37:15Z
- **Completed:** 2026-02-25T03:38:42Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- SystemMetricsViewModel.baseURL changed from immutable to mutable with updateBaseURL() method
- WebSocket client (MetricsWebSocketClient) is replaced when host URL changes, clearing stale process data
- SystemMonitorView reacts to host switches via onChange(of: appState.serverURL)
- Both iOS and macOS builds pass with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Make SystemMetricsViewModel host-aware** - `28ca0be` (feat)
2. **Task 2: Wire SystemMonitorView to react to host switches** - `12a6fe1` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` - Mutable baseURL, updateBaseURL() method that disconnects/reconnects with new host
- `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` - Simplified onAppear using updateBaseURL, added onChange(of: appState.serverURL) for live switching

## Decisions Made
- Kept init default parameter as localhost:9999 for previews; only runtime baseURL is mutable via updateBaseURL()
- updateBaseURL guards against same-URL calls -- safe to invoke on every onAppear without redundant reconnects
- Removed redundant Task { await viewModel.loadProcesses() } from onAppear since connect() already triggers startProcessAutoRefresh() which does initial load

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- System Monitor now correctly targets the active host for all connections
- Ready for Plan 02 (theme verification/fix)
- No blockers

---
*Phase: 37-system-monitor-themes*
*Completed: 2026-02-25*

## Self-Check: PASSED
- [x] SystemMetricsViewModel.swift exists
- [x] SystemMonitorView.swift exists
- [x] 37-01-SUMMARY.md exists
- [x] Commit 28ca0be exists (Task 1)
- [x] Commit 12a6fe1 exists (Task 2)
