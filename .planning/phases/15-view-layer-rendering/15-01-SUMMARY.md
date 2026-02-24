---
phase: 15-view-layer-rendering
plan: 01
subsystem: ui
tags: [syntax-highlighting, concurrency, OSAllocatedUnfairLock, Task.detached, Splash]

# Dependency graph
requires:
  - phase: 18-critical-fixes
    provides: "OSAllocatedUnfairLock pattern established for AppLogger"
provides:
  - "Nonisolated SyntaxHighlighter with thread-safe cache"
  - "Background syntax highlighting in CodeBlockView via Task.detached"
affects: [15-view-layer-rendering, 16-cross-platform-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [OSAllocatedUnfairLock for shared cache, Task.detached for off-main-thread computation]

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Utils/SyntaxHighlighter.swift
    - ILSApp/ILSApp/Views/Chat/CodeBlockView.swift

key-decisions:
  - "OSAllocatedUnfairLock over actor to avoid await at synchronous call sites"
  - "Task.detached(priority: .userInitiated) for highlighting -- high priority since user is waiting for colored text"
  - "Lock protects only cache lookup (microseconds); highlighting runs outside lock"

patterns-established:
  - "OSAllocatedUnfairLock + Task.detached: lock-protected cache with off-main-thread computation"

requirements-completed: [RENDER-03]

# Metrics
duration: 7min
completed: 2026-02-23
---

# Phase 15 Plan 01: Async Syntax Highlighting Summary

**Nonisolated SyntaxHighlighter with OSAllocatedUnfairLock cache and Task.detached background highlighting in CodeBlockView**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-23T23:01:30Z
- **Completed:** 2026-02-23T23:08:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Removed @MainActor isolation from SyntaxHighlighter, enabling background thread execution
- Added OSAllocatedUnfairLock to protect highlighter cache for thread-safe concurrent access
- CodeBlockView now runs syntax highlighting via Task.detached(priority: .userInitiated) in both .task(id:) and .onChange(of:) paths
- Both iOS and macOS builds pass with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Make SyntaxHighlighter nonisolated with OSAllocatedUnfairLock cache** - `1f417f9` (feat)
2. **Task 2: Move CodeBlockView highlighting to background Task.detached** - `491e0a8` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/Utils/SyntaxHighlighter.swift` - Removed @MainActor, added OSAllocatedUnfairLock for cache, highlight() runs outside lock
- `ILSApp/ILSApp/Views/Chat/CodeBlockView.swift` - .task(id:) and .onChange(of:) use Task.detached for background highlighting

## Decisions Made
- Used OSAllocatedUnfairLock instead of making SyntaxHighlighter an actor -- actor would require `await` at all call sites including synchronous onChange handlers
- Task.detached(priority: .userInitiated) chosen over .background -- user is actively waiting for highlighted text to appear
- Lock scope minimized to cache lookup only; actual highlighting (the expensive part) runs without holding the lock

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SyntaxHighlighter is now safe to call from any thread
- CodeBlockView shows plain text briefly then colored text (existing UX preserved)
- Ready for Phase 15 Plan 02 (next view layer optimization)

## Self-Check: PASSED

- FOUND: SyntaxHighlighter.swift
- FOUND: CodeBlockView.swift
- FOUND: 15-01-SUMMARY.md
- FOUND: commit 1f417f9
- FOUND: commit 491e0a8

---
*Phase: 15-view-layer-rendering*
*Completed: 2026-02-23*
