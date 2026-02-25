---
phase: 36-browse-skills-plugins
plan: 02
subsystem: ui
tags: [swiftui, skills, plugins, browser, per-item-tracking, context-menu]

# Dependency graph
requires:
  - phase: 36-browse-skills-plugins
    provides: "GitHubService search, SkillsController enable/disable, PluginsController github-search"
provides:
  - "Per-item install spinners on GitHub skill search results"
  - "Installed badge + checkmark on already-installed GitHub results"
  - "Context menu Remove/Enable/Disable on skill and plugin browse rows"
  - "Rate limit error banner in GitHub browse section"
affects: [36-browse-skills-plugins]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-item Set<String> tracking pattern for async operations (installingSkills)"
    - "isInstalled() cross-reference between GitHub results and local skills by repo name"

key-files:
  created: []
  modified:
    - "ILSApp/ILSApp/ViewModels/SkillsViewModel.swift"
    - "ILSApp/ILSApp/Views/Browser/BrowserView.swift"

key-decisions:
  - "isInstalled checks both skill.name and skill.path against repo name for robust matching"
  - "Rate limit errors routed to gitHubError (inline banner) while other errors go to generic error property"
  - "Context menu Enable/Disable placed before Remove for safer default action ordering"

patterns-established:
  - "Per-item async operation tracking: Set<String> + defer removal pattern for UI spinners"
  - "Installed state badge: capsule badge + checkmark icon replacing install button"

requirements-completed: [BRW-01, BRW-02, BRW-03, BRW-08]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 36 Plan 02: Skills UI Summary

**Per-item install spinners, installed badges, context menu uninstall, and rate limit error banner for skills and plugins browse**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T03:21:59Z
- **Completed:** 2026-02-25T03:24:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- SkillsViewModel tracks per-item install state via Set<String>, checks installed state by repo name, and surfaces rate limit errors separately
- BrowserView shows per-item spinners (not global), "Installed" capsule badge, and checkmark icon on already-installed GitHub results
- Context menus with Enable/Disable and Remove actions on both skill and plugin browse rows
- Inline warning banner for GitHub API rate limit errors with actionable messaging

## Task Commits

Each task was committed atomically:

1. **Task 1: SkillsViewModel per-item tracking + installed state + error surfacing** - `580778f` (feat)
2. **Task 2: BrowserView per-item spinners, badges, context menus, error banner** - `0cd89cb` (feat)

## Files Created/Modified
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` - Added installingSkills Set, isInstalled() method, gitHubError property, updated installFromGitHub and searchGitHub
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift` - Per-item spinners replacing global isLoading, Installed badge + checkmark, context menus on skill/plugin rows, rate limit error banner

## Decisions Made
- isInstalled() checks both `skill.name == repoName` and `skill.path.contains(repoName)` for robust matching across different naming conventions
- Rate limit errors (containing "rate limit", "429", or "limit reached") route to `gitHubError` for inline display; other errors go to the generic `error` property
- Context menu places Enable/Disable before Remove (destructive) for safer default ordering

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Skills browse UI complete with per-item UX improvements
- Plugin browse context menus ready; plugin GitHub search UI deferred to Plan 03
- All BRW-01 through BRW-03 and BRW-08 requirements satisfied
- No blockers for Plan 03 (Plugins UI)

## Self-Check: PASSED

- [x] SkillsViewModel.swift exists with installingSkills, isInstalled(), gitHubError
- [x] BrowserView.swift exists with per-item spinners, badges, context menus, error banner
- [x] 36-02-SUMMARY.md exists
- [x] Commit 580778f (Task 1) verified
- [x] Commit 0cd89cb (Task 2) verified
- [x] iOS build succeeds with zero errors

---
*Phase: 36-browse-skills-plugins*
*Completed: 2026-02-25*
