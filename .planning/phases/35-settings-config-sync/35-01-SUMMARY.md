---
phase: 35-settings-config-sync
plan: 01
subsystem: ui
tags: [swiftui, settings, config, read-then-patch, safety]

# Dependency graph
requires:
  - phase: 34-host-profiles-fix-redesign
    provides: "SettingsView onChange(appState.serverURL) for host switch reload"
provides:
  - "saveWithPatch(applying:) safe config write method in SettingsViewModel"
  - "Config auto-refresh on reconnect in SettingsView"
affects: [35-02, settings, config-sync]

# Tech tracking
tech-stack:
  added: []
  patterns: ["read-then-patch config write: load fresh, apply delta closure, PUT full config back"]

key-files:
  created: []
  modified:
    - "ILSApp/ILSApp/ViewModels/SettingsViewModel.swift"
    - "ILSApp/ILSApp/Views/Settings/SettingsView.swift"

key-decisions:
  - "Used closure-based delta pattern instead of KeyPath-based approach for flexibility with compound mutations (model + theme)"
  - "PUT full config back (not stripped) because server writes payload verbatim -- stripping would also drop CLI fields"

patterns-established:
  - "read-then-patch: all config writes must GET fresh config, apply delta closure, PUT full config back"
  - "Delta closures must only touch allowlisted fields: model, theme, autoUpdatesChannel, alwaysThinkingEnabled, includeCoAuthoredBy"

requirements-completed: [CFG-01, CFG-03, CFG-05, CFG-07]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 35 Plan 01: Settings Config Sync Summary

**Safe read-then-patch config writes preserving CLI-only fields, plus reconnect auto-refresh for SettingsView**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T02:27:25Z
- **Completed:** 2026-02-25T02:29:17Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments
- Replaced dangerous full-struct PUT with `saveWithPatch(applying:)` that loads fresh config from server before applying delta
- CLI-only fields (hooks, env, permissions, statusLine, enabledPlugins, extraKnownMarketplaces) are never touched by any delta closure
- SettingsView auto-refreshes config on reconnect, matching HomeView and BrowserView patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace config save methods with read-then-patch pattern** - `4279e9d` (feat)
2. **Task 2: Add config auto-refresh on reconnect** - `81b3268` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` - Added saveWithPatch(applying:), rewrote saveConfig and saveConfigToggle to delegate to it
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift` - Added onChange(of: appState.isConnected) with guard for connected=true

## Decisions Made
- Used closure-based delta `(inout ClaudeConfig) -> Void` instead of KeyPath-based approach. KeyPath would be cleaner for single-field updates but `saveConfig` needs to update both `model` and `theme` in one call, which requires a closure.
- PUT the FULL config back (including CLI-only fields loaded from server) rather than stripping to allowlisted fields. The server writes the payload verbatim to disk, so stripping would also delete CLI-only fields. The read-then-patch approach is correct because the fresh GET includes all fields, and the delta only mutates the intended ones.
- `saveConfigToggle` uses `break` for unknown keys instead of returning an error string, since the caller (Binding setter) cannot display errors and the key is always valid from the UI.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Safe config write foundation in place for Plan 02 (annotation badges and tooltips)
- Both iOS and macOS builds pass with zero errors
- No blockers

## Self-Check: PASSED

- [x] SettingsViewModel.swift exists
- [x] SettingsView.swift exists
- [x] 35-01-SUMMARY.md exists
- [x] Commit 4279e9d found
- [x] Commit 81b3268 found

---
*Phase: 35-settings-config-sync*
*Completed: 2026-02-25*
