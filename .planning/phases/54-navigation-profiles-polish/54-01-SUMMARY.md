---
phase: 54-navigation-profiles-polish
plan: 01
subsystem: ui
tags: [swiftui, home-screen, navigation, quick-actions]

requires:
  - phase: 49-foundation
    provides: Host profile rename complete, ActiveScreen enum
provides:
  - "New Session" and "System Monitor" quick action cards on Home screen
  - "View All (N)" button in Recent Sessions header for data consistency
  - Verified PROF-02 (system monitor metrics) and FOUND-02 (node_modules exclusion) already implemented
affects: [home-screen, navigation, sessions]

tech-stack:
  added: []
  patterns: [quick-action-grid-6-card-layout]

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Views/Home/HomeView.swift

key-decisions:
  - "6-card grid (3x2) avoids orphaned card in 2-column layout"
  - "New Session is first card as most common user action"
  - "View All navigates to .browser since no dedicated .sessions ActiveScreen case"
  - "PROF-02 and FOUND-02 verified as already implemented — no code changes needed"

patterns-established:
  - "Quick action cards: primary action first, monitoring last"

requirements-completed: [NAV-01, NAV-02, PROF-02, FOUND-02]

duration: 8min
completed: 2026-02-28
---

# Plan 54-01: Home Screen Navigation & Data Consistency Summary

**6-card quick actions grid with New Session + System Monitor, and View All sessions link for data consistency**

## Performance

- **Duration:** 8 min
- **Tasks:** 3 (2 code + 1 evidence-only)
- **Files modified:** 1

## Accomplishments
- Added "New Session" as first quick action card triggering showNewSessionSheet
- Added "System Monitor" as sixth card navigating to .system screen
- Added "View All (N)" button in Recent Sessions header with total count from sessionsVM.totalCount
- Verified PROF-02: SystemMonitorView renders real-time CPU, memory, disk, network via WebSocket
- Verified FOUND-02: SkillsFileService.excludedDirectories contains "node_modules" with check in scanSkillsRecursively

## Task Commits

1. **Task 1: Add New Session and System Monitor quick action cards** - `b715ee5` (feat)
2. **Task 2: Add View All link to Recent Sessions header** - `b715ee5` (feat, same commit)
3. **Task 3: Verify PROF-02 and FOUND-02** - evidence-only, no code changes

## Files Created/Modified
- `ILSApp/ILSApp/Views/Home/HomeView.swift` - Added 2 quick action cards (New Session, System Monitor) and View All button in Recent Sessions header

## Decisions Made
- Used `.browser` as navigation target for View All since `ActiveScreen` has no `.sessions` case
- New Session card uses `theme.entitySession` color for visual consistency with session entities
- System Monitor card uses `theme.entityMCP` color matching the monitoring/infrastructure category

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Home screen now provides quick access to all key features
- Data consistency between Home and Sessions achieved via shared ViewModel + View All link

---
*Phase: 54-navigation-profiles-polish*
*Completed: 2026-02-28*
