---
phase: 53-github-browse-install
plan: 01
subsystem: api
tags: [github-api, vapor, swiftui, dto, preview, rest]

requires:
  - phase: 52-browser-view-crud
    provides: BrowserView with skills/plugins tabs, SkillsViewModel, PluginsViewModel

provides:
  - GitHubRepoPreview and GitHubFileEntry shared DTOs
  - GET /skills/preview and GET /plugins/preview backend endpoints
  - SkillsViewModel.fetchPreview() and PluginsViewModel.fetchPreview() methods
  - Error-capturing installFromGitHub with lastInstallError for retry UI

affects: [53-02-github-preview-ui, browser-view, discover-tab]

tech-stack:
  added: []
  patterns:
    - "GitHub README API with base64 decoding and 5000 char truncation"
    - "Concurrent async let for parallel GitHub API fetches"
    - "lastInstallError property pattern for retry UI support"

key-files:
  created: []
  modified:
    - Sources/ILSShared/DTOs/SearchResult.swift
    - Sources/ILSBackend/Services/GitHubService.swift
    - Sources/ILSBackend/Controllers/SkillsController.swift
    - Sources/ILSBackend/Controllers/PluginsController.swift
    - Sources/ILSBackend/Extensions/VaporContent+Extensions.swift
    - ILSApp/ILSApp/ViewModels/SkillsViewModel.swift
    - ILSApp/ILSApp/ViewModels/PluginsViewModel.swift

key-decisions:
  - "Added Vapor Content conformance for GitHubRepoPreview and GitHubFileEntry in VaporContent+Extensions.swift"
  - "Preview endpoints return nil description and 0 stars since full metadata comes from the search result, not re-fetched"

patterns-established:
  - "Preview endpoint pattern: GET /{entity}/preview?repo=owner/repo returns GitHubRepoPreview"
  - "lastInstallError pattern: dedicated error property preserved across loadSkills/loadPlugins refreshes"

requirements-completed: [SKILL-01, SKILL-02, SKILL-03, SKILL-04]

duration: 4min
completed: 2026-02-28
---

# Phase 53 Plan 01: Backend Data Layer for GitHub Preview Summary

**GitHub repo preview endpoints with README fetching, file tree listing, and error-capturing install methods for retry UI**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-28T05:01:54Z
- **Completed:** 2026-02-28T05:05:45Z
- **Tasks:** 4
- **Files modified:** 7

## Accomplishments
- GitHubRepoPreview and GitHubFileEntry DTOs in ILSShared, shared between backend and iOS
- GitHubService.fetchReadme() with GitHub README API auto-detection, base64 decoding, and 5000 char truncation
- GitHubService.fetchRepoContents() mapping GitHub Contents API to GitHubFileEntry DTOs
- GET /skills/preview and GET /plugins/preview routes with concurrent async let fetching
- SkillsViewModel and PluginsViewModel fetchPreview() methods for iOS
- lastInstallError property on both VMs enabling retry UI after failed installs

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GitHubRepoPreview and GitHubFileEntry DTOs** - `798585a` (feat)
2. **Task 2: Add fetchReadme and fetchRepoContents to GitHubService** - `d755d5f` (feat)
3. **Task 3: Add preview routes to controllers** - `9dc4c5c` (feat)
4. **Task 4: Add fetchPreview and error-capturing install to VMs** - `74b03d4` (feat)

## Files Created/Modified
- `Sources/ILSShared/DTOs/SearchResult.swift` - Added GitHubRepoPreview and GitHubFileEntry DTOs
- `Sources/ILSBackend/Services/GitHubService.swift` - Added fetchReadme and fetchRepoContents methods
- `Sources/ILSBackend/Controllers/SkillsController.swift` - Added GET /skills/preview route
- `Sources/ILSBackend/Controllers/PluginsController.swift` - Added GET /plugins/preview route
- `Sources/ILSBackend/Extensions/VaporContent+Extensions.swift` - Added Content conformance for new DTOs
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` - Added fetchPreview, lastInstallError
- `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` - Added fetchPreview, lastInstallError

## Decisions Made
- Added Vapor Content conformance in VaporContent+Extensions.swift (Rule 3 - Blocking: required for APIResponse to work with new DTOs)
- Preview endpoints return nil description and 0 stars since metadata comes from search results, not re-fetched

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Content conformance for new DTOs**
- **Found during:** Task 3 (preview routes)
- **Issue:** GitHubRepoPreview and GitHubFileEntry needed Vapor Content conformance for APIResponse
- **Fix:** Added `extension GitHubRepoPreview: Content {}` and `extension GitHubFileEntry: Content {}` in VaporContent+Extensions.swift
- **Files modified:** Sources/ILSBackend/Extensions/VaporContent+Extensions.swift
- **Verification:** swift build succeeds
- **Committed in:** 9dc4c5c (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential for compilation. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Data layer complete: DTOs, backend endpoints, ViewModel methods all ready
- Plan 53-02 (UI layer) can now build GitHubPreviewView and Discover tab consuming these APIs

---
*Phase: 53-github-browse-install*
*Completed: 2026-02-28*
