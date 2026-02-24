---
phase: 14-sse-background-lifecycle
plan: 01
subsystem: services
tags: [low-power-mode, battery, polling, websocket, sse, background-lifecycle]

# Dependency graph
requires:
  - phase: 22-low-medium-remaining
    provides: SSE background disconnect via NotificationCenter (ENRG-05)
provides:
  - LowPowerModeMonitor singleton for centralized power state tracking
  - LPM-adaptive polling intervals in PollingManager, MetricsWebSocketClient, SSEClient
  - MetricsWebSocketClient background suspend/foreground resume in SystemMonitorView
affects: [16-cross-platform-verification, 17-regression-test-infrastructure]

# Tech tracking
tech-stack:
  added: []
  patterns: [LowPowerModeMonitor singleton modeled on NetworkMonitor, LPM-adaptive intervals read once at loop start]

key-files:
  created:
    - ILSApp/ILSApp/Services/LowPowerModeMonitor.swift
  modified:
    - ILSApp/ILSApp/Services/PollingManager.swift
    - ILSApp/ILSApp/Services/MetricsWebSocketClient.swift
    - ILSApp/ILSApp/Services/SSEClient.swift
    - ILSApp/ILSApp/Views/System/SystemMonitorView.swift

key-decisions:
  - "LowPowerModeMonitor uses @Observable singleton pattern matching NetworkMonitor for consistency"
  - "LPM interval check done once at loop start, not inside every Task.sleep iteration, to avoid overhead"
  - "SSE watchdog timeout checked once at creation, not re-evaluated mid-stream, per research recommendation"
  - "PollingManager restarts active polling loops on LPM toggle via NotificationCenter observer"
  - "No disconnect on .inactive in SystemMonitorView to avoid transient notification center events"

patterns-established:
  - "LPM-adaptive pattern: read LowPowerModeMonitor.shared.isLowPowerModeEnabled once at loop/watchdog creation"
  - "Background lifecycle in views: .background -> disconnect, .active -> connect, skip .inactive"

requirements-completed: [BATT-01, BATT-02]

# Metrics
duration: 20min
completed: 2026-02-23
---

# Phase 14 Plan 01: SSE/Background Lifecycle Summary

**LowPowerModeMonitor singleton with LPM-adaptive intervals in PollingManager, MetricsWebSocketClient, and SSEClient, plus WebSocket background suspend/resume in SystemMonitorView**

## Performance

- **Duration:** 20 min
- **Started:** 2026-02-23T21:28:38Z
- **Completed:** 2026-02-23T21:49:02Z
- **Tasks:** 2
- **Files modified:** 6 (1 created, 4 modified, 1 project file)

## Accomplishments
- LowPowerModeMonitor singleton tracks Low Power Mode state reactively via ProcessInfo notification
- PollingManager doubles health poll (60s->120s) and retry start (5s->10s) in LPM, restarts active loops on LPM toggle
- MetricsWebSocketClient doubles heartbeat (15s->30s) and fallback poll (30s->60s) in LPM
- SSEClient watchdog timeout doubles (45s->90s) in LPM
- SystemMonitorView disconnects WebSocket on background and reconnects on foreground (BATT-02 gap closed)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create LowPowerModeMonitor and wire LPM-adaptive intervals** - `1f848c9` (feat)
2. **Task 2: Add WebSocket background suspend/resume in SystemMonitorView** - `77b0207` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/Services/LowPowerModeMonitor.swift` - Centralized Low Power Mode state singleton
- `ILSApp/ILSApp/Services/PollingManager.swift` - LPM-adaptive health and retry polling intervals with LPM toggle restart
- `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` - LPM-adaptive heartbeat and fallback polling intervals
- `ILSApp/ILSApp/Services/SSEClient.swift` - LPM-adaptive watchdog timeout (45s->90s)
- `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` - Background disconnect and foreground reconnect for WebSocket
- `ILSApp/ILSApp.xcodeproj/project.pbxproj` - Added LowPowerModeMonitor.swift to both iOS and macOS targets

## Decisions Made
- LowPowerModeMonitor uses @Observable singleton pattern matching NetworkMonitor for consistency
- LPM interval check done once at loop start (not inside every Task.sleep iteration) to avoid overhead
- SSE watchdog timeout checked once at creation, not re-evaluated mid-stream, per research recommendation
- PollingManager restarts active polling loops on LPM toggle via NotificationCenter observer
- No disconnect on .inactive in SystemMonitorView to avoid transient notification center events (Pitfall 1 from research)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed @Observable deinit isolation for LowPowerModeMonitor**
- **Found during:** Task 1 (LowPowerModeMonitor creation)
- **Issue:** `deinit` is nonisolated and cannot access `@MainActor @Observable` property `observer`. Using plain `nonisolated` conflicts with `@Observable` macro expansion.
- **Fix:** Used `@ObservationIgnored nonisolated(unsafe)` on the observer property to opt out of both observation tracking and strict isolation (safe because singleton deinit only runs at process exit)
- **Files modified:** ILSApp/ILSApp/Services/LowPowerModeMonitor.swift
- **Verification:** iOS and macOS builds pass with zero errors and zero warnings from this file
- **Committed in:** 1f848c9

**2. [Rule 1 - Bug] Removed unnecessary await on MainActor-isolated access in SSEClient**
- **Found during:** Task 1 (SSE watchdog timeout wiring)
- **Issue:** `performStream` is already `@MainActor` isolated, so accessing `LowPowerModeMonitor.shared.isLowPowerModeEnabled` does not need `await`. Compiler warning: "no 'async' operations occur within 'await' expression"
- **Fix:** Removed `await` keyword from the LPM check
- **Files modified:** ILSApp/ILSApp/Services/SSEClient.swift
- **Verification:** iOS build passes with zero warnings
- **Committed in:** 1f848c9

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for clean compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- BATT-01 and BATT-02 requirements satisfied
- Ready for Phase 15 (View Rendering) and Phase 16 (Cross-Platform Verification)
- Battery "Low" rating requires real-device 24h usage to validate (noted in STATE.md blockers)

---
*Phase: 14-sse-background-lifecycle*
*Completed: 2026-02-23*
