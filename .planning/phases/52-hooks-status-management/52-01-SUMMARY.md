---
phase: 52-hooks-status-management
plan: 01
subsystem: ui
tags: [swiftui, hooks, codable, crud, claude-code]

requires:
  - phase: 51-settings-config-write
    provides: saveWithPatch config write pattern
provides:
  - Dictionary-based HooksConfig preserving all 17 event types
  - Expanded HookDefinition with all 4 handler types
  - HooksViewModel with CRUD methods and 17-event-type metadata
  - HookEditorSheet form for create/edit
affects: [52-02, hooks-management-view, browser-view]

tech-stack:
  added: []
  patterns: [dictionary-based-codable, singleValueContainer, read-modify-write-crud]

key-files:
  created:
    - ILSApp/ILSApp/Views/Hooks/HookEditorSheet.swift
  modified:
    - Sources/ILSShared/Models/ClaudeConfig.swift
    - ILSApp/ILSApp/ViewModels/HooksViewModel.swift
    - ILSApp/ILSApp/ViewModels/SettingsViewModel.swift
    - ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift
    - ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift

key-decisions:
  - "Dictionary-based HooksConfig with singleValueContainer Codable prevents silent data loss when round-tripping through encode/decode"
  - "Backward-compatible computed accessors maintain compilation of existing consumers (SettingsViewModel, SettingsConfigSection)"
  - "saveHook/deleteHook create temporary SettingsViewModel instances to use saveWithPatch - avoids coupling to shared instance"
  - "CodingKeys maps isAsync to JSON key 'async' since async is a Swift reserved keyword"

patterns-established:
  - "Dictionary-based Codable: Use singleValueContainer for JSON structures with dynamic keys"
  - "Event type metadata: Static array with lookup dictionary for O(1) access in UI"

requirements-completed: [SKILL-05, SKILL-06]

duration: 12min
completed: 2026-02-27
---

# Plan 52-01: Hooks Data Model, ViewModel CRUD & Editor Sheet Summary

**Dictionary-based HooksConfig preserving all 17 event types, expanded HookDefinition with 4 handler types, CRUD methods via saveWithPatch, and Form-based HookEditorSheet**

## Performance

- **Duration:** 12 min
- **Tasks:** 3
- **Files created:** 1
- **Files modified:** 5

## Accomplishments
- HooksConfig uses [String: [HookGroup]] dictionary with singleValueContainer Codable so all 17 event types survive encode/decode round-trips
- HookDefinition expanded with fields for command/isAsync, url/headers/allowedEnvVars, prompt/model, and common timeout/statusMessage/once
- HooksViewModel has static allEventTypes array with metadata for all 17 Claude Code event types
- saveHook and deleteHook methods use SettingsViewModel.saveWithPatch for read-modify-write CRUD
- HookEditorSheet provides Form-based create/edit with event type picker, matcher field, handler type segmented control, and handler-specific fields

## Task Commits

1. **Task 1: Expand HooksConfig and HookDefinition models** - `4d76ab2` (feat)
2. **Task 2: Expand HooksViewModel with 17 event types and CRUD** - `3dcfa73` (feat)
3. **Task 3: Create HookEditorSheet** - `f77e77a` (feat)

## Files Created/Modified
- `Sources/ILSShared/Models/ClaudeConfig.swift` - Dictionary-based HooksConfig, expanded HookDefinition with all handler type fields
- `ILSApp/ILSApp/ViewModels/HooksViewModel.swift` - 17 event types metadata, CRUD methods, dictionary-based flattening
- `ILSApp/ILSApp/Views/Hooks/HookEditorSheet.swift` - Form-based create/edit modal with handler-type-specific fields
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` - hookEventBreakdown updated to use dictionary iteration
- `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` - countHooks updated to use dictionary reduce
- `ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift` - eventSections and countTotalHooks updated for dictionary-based HooksConfig

## Decisions Made
- Dictionary-based HooksConfig with singleValueContainer prevents data loss when Claude Code returns hooks for event types beyond the original 5
- Backward-compatible computed accessors (preToolUse, postToolUse, etc.) maintain compilation of all existing consumers
- HookEditorSheet disables event type picker when editing to prevent confusing move-between-types UX

## Deviations from Plan

### Auto-fixed Issues

**1. Updated SettingsViewModel.hookEventBreakdown for dictionary-based HooksConfig**
- **Found during:** Task 1 (model changes)
- **Issue:** hookEventBreakdown hardcoded 5 event types, would not compile with new HooksConfig
- **Fix:** Changed to iterate hooks.events dictionary
- **Files modified:** ILSApp/ILSApp/ViewModels/SettingsViewModel.swift
- **Verification:** iOS build succeeds
- **Committed in:** 4d76ab2

**2. Updated SettingsConfigSection.countHooks for dictionary-based HooksConfig**
- **Found during:** Task 1 (model changes)
- **Issue:** countHooks accessed explicit properties that no longer exist as stored properties
- **Fix:** Changed to hooks.events.values.reduce
- **Files modified:** ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift
- **Verification:** iOS build succeeds
- **Committed in:** 4d76ab2

**3. Updated HooksManagementView for dictionary-based HooksConfig**
- **Found during:** Task 1 (model changes)
- **Issue:** eventSections and countTotalHooks accessed explicit properties
- **Fix:** Changed to iterate hooks.events dictionary
- **Files modified:** ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift
- **Verification:** iOS build succeeds
- **Committed in:** 4d76ab2

---

**Total deviations:** 3 auto-fixed (all compile fixes from model change)
**Impact on plan:** All fixes necessary for compilation. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 52-02 can proceed: HooksViewModel CRUD methods and HookEditorSheet are ready for HooksManagementView integration
- BrowserView toggle buttons are independent of Plan 01 output

---
*Phase: 52-hooks-status-management*
*Completed: 2026-02-27*
