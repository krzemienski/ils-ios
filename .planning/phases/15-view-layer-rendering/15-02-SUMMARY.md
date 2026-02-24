---
phase: 15-view-layer-rendering
plan: 02
subsystem: ui
tags: [swiftui, list, view-recycling, forEachIdentity, message-windowing, performance]

# Dependency graph
requires:
  - phase: 13-viewmodel-model-optimization
    provides: "Chat message windowing backend (TranscriptResult, loadOlderMessages)"
provides:
  - "List-based sidebar with UICollectionView-backed view recycling"
  - "Stable ForEach identity in ChatMessageList (no enumerated array copy)"
  - "displayMessages computed property capping rendered messages at 50"
affects: [16-cross-platform-verification, 17-regression-test-infrastructure]

# Tech tracking
tech-stack:
  added: []
  patterns: ["List+.listStyle(.plain) for view recycling in large lists", "ForEach(items) with Identifiable instead of ForEach(Array(items.enumerated()))"]

key-files:
  created: []
  modified:
    - ILSApp/ILSApp/Views/Root/SidebarView.swift
    - ILSApp/ILSApp/Views/Chat/ChatMessageList.swift
    - ILSApp/ILSApp/ViewModels/ChatViewModel.swift
    - ILSApp/ILSApp/Views/Chat/ChatView.swift
    - ILSApp/ILSMacApp/Views/MacChatView.swift

key-decisions:
  - "List with .plain style replaces ScrollView+LazyVStack for constant-memory session rendering"
  - "ForEach(messages) with Identifiable protocol replaces Array(messages.enumerated()) to eliminate per-body array copies"
  - "displayMessages reuses existing messageWindowSize (50) from Phase 13-02 windowing infrastructure"

patterns-established:
  - "List+.listStyle(.plain)+.scrollContentBackground(.hidden) for themed recycling lists"
  - "ForEach(collection) over ForEach(Array(collection.enumerated())) for stable identity"

requirements-completed: [RENDER-01, RENDER-02]

# Metrics
duration: 9min
completed: 2026-02-23
---

# Phase 15 Plan 02: List View Recycling and Chat Identity Summary

**List-based sidebar with UICollectionView view recycling; stable ForEach identity and 50-message display window for chat**

## Performance

- **Duration:** 9 min
- **Started:** 2026-02-23T23:01:02Z
- **Completed:** 2026-02-23T23:10:18Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Migrated SidebarView session list from ScrollView+LazyVStack to List for constant-memory view recycling with 500+ sessions
- Eliminated ForEach identity destruction in ChatMessageList by removing Array(messages.enumerated()) copy
- Added displayMessages computed property to ChatViewModel capping rendered messages at 50 most recent
- Updated both iOS ChatView and macOS MacChatView to use windowed display messages

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate SidebarView session list from LazyVStack to List** - `83a08fe` (feat)
2. **Task 2: Fix ChatMessageList identity and add message windowing** - `d693731` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/Views/Root/SidebarView.swift` - Replaced ScrollView+LazyVStack with List for UICollectionView-backed view recycling
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` - Replaced ForEach(Array(messages.enumerated())) with ForEach(messages) for stable identity
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` - Added displayMessages, hasOlderDisplayMessages, previousMessage(before:) for display windowing
- `ILSApp/ILSApp/Views/Chat/ChatView.swift` - Changed messages parameter to viewModel.displayMessages
- `ILSApp/ILSMacApp/Views/MacChatView.swift` - Changed messages parameter to viewModel.displayMessages

## Decisions Made
- Used List with `.plain` style and `.scrollContentBackground(.hidden)` to match existing sidebar theme while gaining view recycling
- Reused existing `messageWindowSize = 50` from Phase 13-02 windowing infrastructure for the display window
- Used inline closure for previousMessage lookup in ForEach (O(n) per message, but n=50 max so 2500 comparisons is negligible)
- Applied `.listRowBackground(Color.clear)` and `.listRowSeparator(.hidden)` to preserve visual consistency with the original design

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- View layer rendering optimizations complete for this plan
- Ready for Phase 15 Plan 03 (remaining view optimizations) or Phase 16 (cross-platform verification)
- Both iOS and macOS builds pass cleanly

---
*Phase: 15-view-layer-rendering*
*Completed: 2026-02-23*
