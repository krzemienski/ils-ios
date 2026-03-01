# Domain Pitfalls: v5.0 Cross-Platform Feature Completion & 30-Gate Audit

**Domain:** Adding config inheritance, GitHub browse/install, hooks management, macOS parity, and 30-gate validation to an existing native Swift iOS/macOS Claude Code client with Vapor backend
**Project:** ILS iOS/macOS -- v5.0
**Researched:** 2026-02-27
**Confidence:** HIGH -- derived from direct code inspection of 240+ Swift files, 8 prior milestones of project history, verified simulator behavior, and official documentation

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or cascade failures across multiple features.

---

### Pitfall 1: "Fleet" to "Host Profiles" Rename -- API Route Change Breaks iOS Client Mid-Migration

**What goes wrong:**
The rename from "Fleet" to "Host Profiles" touches 16+ Swift files across 3 targets (iOS, macOS, backend). The backend `FleetController` serves routes at `/api/v1/fleet/*` (`GET /fleet`, `POST /fleet/register`, `POST /fleet/:id/activate`, `DELETE /fleet/:id`, `GET /fleet/:id/health`). If the backend routes are renamed to `/api/v1/host-profiles/*` without preserving the old routes, any iOS build still referencing `/fleet` endpoints gets 404 errors. Worse: the iOS app and backend are built separately -- a developer may update the backend and forget to update the iOS `HostProfilesViewModel`, or vice versa.

The existing codebase has **three layers of "Fleet" references** that must change in lockstep:
1. **Backend routes** -- `FleetController` registers at `routes.grouped("fleet")` (FleetController.swift:16)
2. **Backend models** -- `FleetHostModel`, `CreateFleetHosts` migration, `FleetDTOs.swift`, `FleetHost.swift`
3. **iOS/macOS ViewModels** -- `HostProfilesViewModel` calls API paths containing `/fleet`
4. **Deep links** -- `handleURL()` accepts both `"fleet"` and `"profiles"` (AppState.swift:123)
5. **Database table** -- `fleet_hosts` table name in SQLite via Fluent migration

Additionally, `FleetHost.swift` already has `public typealias HostProfile = FleetHost` (line 4), indicating a partial rename was started but never completed. The `ActiveScreen` enum uses `.hostProfiles` (SidebarRootView.swift:18) but the backend still serves `/fleet`. This half-migrated state is the most dangerous -- it looks finished but is not.

**Consequences:**
- 404 errors on host profile operations if routes change without client update
- Database migration failure if table rename is attempted incorrectly
- Deep links `ils://fleet` stop working if removed instead of aliased
- The existing `typealias HostProfile = FleetHost` creates false confidence that the rename is done

**Prevention:**
1. **Do NOT rename the database table** -- `fleet_hosts` stays as-is. Fluent model property `schema` can map to the old table name. Renaming SQLite tables requires a migration that creates a new table, copies data, and drops the old one -- high risk for zero user-facing benefit.
2. **Keep old routes alive with redirect aliases:**
   ```swift
   // Old routes forward to new controller
   let legacyFleet = routes.grouped("fleet")
   legacyFleet.get { req -> Response in
       return req.redirect(to: "/api/v1/host-profiles", redirectType: .permanent)
   }
   ```
3. **Rename in this order:** (a) Add new routes alongside old, (b) Update iOS/macOS clients to use new routes, (c) Verify both old and new routes work, (d) Deprecate old routes in a future milestone.
4. **Deep link `ils://fleet` must remain supported forever** -- add `"host-profiles"` as an additional case, do not remove `"fleet"`.
5. **Rename Swift types last** -- `FleetHost` -> `HostProfile` can be done as a final cleanup after all API routes are stable, using the existing typealias for backward compat.

**Detection:**
- `HostProfilesView` shows empty state or error when it should show hosts
- `curl http://localhost:9999/api/v1/fleet` returns 404 after backend update
- Deep link `ils://fleet` navigates to Home instead of Host Profiles

**Phase to address:** The very first implementation phase for Stream 4 (System Monitor + Profiles). Get the route aliasing right before any UI rename work.

---

### Pitfall 2: GitHub Code Search API Rate Limiting -- 10 req/min Unauthenticated, 1000 Result Cap

**What goes wrong:**
The existing `GitHubService.swift` uses the GitHub Code Search API (`/search/code`) to find SKILL.md and plugin.json files. This API has harsh rate limits that differ dramatically from the REST API's general 5000 req/hr for authenticated users:

- **Code Search specific limit: 10 requests per minute** (separate from the 5000/hr general limit)
- **Unauthenticated: 10 requests per minute with only 60/hr general limit**
- **Results capped at 1000 per query** -- `total_count` may report higher but pagination stops at 1000
- **Secondary rate limits:** No more than 100 concurrent requests, 900 points/minute across all endpoints

The current code checks `X-RateLimit-Remaining` headers but only logs a warning when remaining < 10 (GitHubService.swift:72-76). It does not surface the `X-RateLimit-Reset` timestamp to the iOS client, does not implement exponential backoff, and does not differentiate between the general rate limit and the code-search-specific rate limit. The rate limit countdown UI from Phase 43 (UI-05) exists but may not receive the reset timestamp from the current error response.

**Consequences:**
- Users who browse/search GitHub skills get 403/429 after ~10 searches in a minute
- The error message says "Set GITHUB_TOKEN on host" but does not show when limits reset
- Rapid pagination (user scrolls through results) burns through the 10 req/min budget instantly
- The 1000-result cap means popular queries return incomplete results with no indication they are truncated
- Without backoff, the iOS client may retry immediately, wasting remaining budget

**Prevention:**
1. **Parse and forward `X-RateLimit-Reset` to the client** -- the existing `Abort(.tooManyRequests)` should include the reset timestamp in the error payload so the iOS countdown timer (UI-05) can display "try again in X seconds"
2. **Implement client-side request throttling** -- debounce search input to max 1 request per 6 seconds (10/min budget)
3. **Cache aggressively** -- the current cache in `IndexingService` is good, but ensure cache hits bypass the API entirely. Consider pre-warming cache for common queries.
4. **Surface the 1000-result cap** -- when `total_count > 1000`, show "Showing 1000 of X results. Refine your search."
5. **Differentiate error types** -- GitHub returns 403 for rate limiting AND for repository access restrictions. Parse the response body to distinguish them.
6. **Add `GITHUB_TOKEN` to backend config** -- not just env var. Make it configurable through the Settings UI so users do not need SSH access to set it.
7. **Handle GitHub Code Search deprecation risk** -- GitHub has changed the Code Search API before (March 2023 changelog). Pin to the current API version via `Accept: application/vnd.github.v3+json` header (already done in current code).

**Detection:**
- Users see "GitHub search limit reached" after ~10 searches
- Countdown timer shows "try again in 0 seconds" (reset timestamp not forwarded)
- Search results always show exactly 20 items even for broad queries (pagination not working)
- Same search query hits the API every time (cache miss)

**Phase to address:** Stream 3 (Skills/Plugins/Hooks/Theming) -- GitHub browse/install feature. Must design the throttling and caching strategy before building the browse UI.

---

### Pitfall 3: Config Inheritance Visualization -- Displaying "Inherited vs Custom" Without a Merge Endpoint

**What goes wrong:**
Claude Code has 3 config scopes: `user` (~/.claude/settings.json), `project` (.claude/settings.json in project root), and `local` (.claude/settings.local.json). The effective config is a merge of all three with local > project > user precedence. The iOS app needs to show which values are inherited from a parent scope and which are overridden locally.

The current backend `ConfigController` exposes individual scope configs via `GET /api/v1/config?scope=user` (returns `ConfigInfo` with scope, path, content, isValid). But there is **no merged/effective config endpoint** that shows the final resolved values with per-field provenance (which scope each value came from). The `ConfigOverride` DTO in `ResponseDTOs.swift` has a `winningScope: ConfigScope` field, suggesting this was partially designed but may not be fully implemented.

Building the inheritance visualization without a proper merge endpoint means either:
(a) The iOS app fetches all 3 scopes and does client-side merging (duplicating backend logic, prone to drift)
(b) A new backend endpoint is needed that returns the merged config with provenance annotations

**Consequences:**
- If client-side merging is implemented, the merge algorithm may differ from Claude Code's actual merge, showing incorrect "inherited" badges
- Circular reference risk: a project config could reference another config file, creating infinite loops in the merge chain
- If the backend endpoint is incomplete, the Settings screen shows misleading inheritance indicators
- Users modify "inherited" values thinking they are changing the parent scope but actually create local overrides

**Prevention:**
1. **Build a backend merge endpoint** -- `GET /api/v1/config/effective` that returns the merged config with per-field `source: ConfigScope` annotations. This is the single source of truth.
2. **Never duplicate merge logic on the client** -- the iOS app should only display what the backend computes.
3. **Handle missing scope files gracefully** -- not every project has all 3 config files. The merge endpoint should return the effective config even when 1 or 2 scopes are missing.
4. **Read-only inheritance display first** -- show "Inherited from User" or "Overridden in Local" badges, but do NOT allow editing inherited values through the Settings UI initially. Editing introduces the question of "which scope should I write to?" which is a separate feature.
5. **Validate the merge against Claude CLI output** -- run `claude config show` on the host and compare with the backend's merged result to ensure consistency.

**Detection:**
- Settings screen shows "Inherited" for a value that is actually overridden
- Editing a config value in Settings creates a local override instead of modifying the expected scope
- Three scopes fetched independently show values that do not match the effective behavior

**Phase to address:** Stream 2 (Settings & Config Inheritance) -- backend merge endpoint must exist before any UI visualization work begins.

---

### Pitfall 4: macOS Feature Parity -- NavigationSplitView State Desync After Programmatic Navigation

**What goes wrong:**
The macOS app uses `NavigationSplitView` with 3 columns (sidebar, content, detail) in `MacContentView.swift`. The sidebar selection is managed by `@State private var selectedSection: SidebarSection?` which syncs with `activeScreen` via `onChange(of: selectedSection)`. When navigation is triggered programmatically (deep links, menu bar commands, keyboard shortcuts), `activeScreen` is set directly in `handleNavigationIntent()` (lines 607-629), which then syncs `selectedSection`.

The pitfall: `NavigationSplitView` has its own internal selection tracking. When `selectedSection` is set programmatically, the visual highlight in the sidebar List may not update, or may flicker, or may show the wrong selection for one render cycle. This is a documented SwiftUI limitation where programmatic selection changes do not always propagate to the visual state of `List(selection:)` in `NavigationSplitView`.

Additionally, `MacContentView` uses `NotificationCenter` for menu bar command communication (ILSCommands.swift posts `ilsNavigateTo`, `ilsRenameSession`, etc.). These notifications are fire-and-forget -- there is no confirmation that the view received and processed the navigation intent. If the view is not yet in the hierarchy (e.g., window is minimized), the notification is lost.

**Consequences:**
- User presses Cmd+1 (Home), detail shows Home but sidebar highlights System Monitor
- Deep link `ils://settings` shows Settings in detail but sidebar shows Home selected
- Menu bar "Navigate > Browse" does nothing when the window is minimized
- Keyboard shortcuts conflict: `Cmd+Shift+F` for Fork Session conflicts with system Find
- New features (Host Profiles, Hooks) added to iOS sidebar but missing from macOS `SidebarSection` enum

**Prevention:**
1. **When adding new screens to iOS, always update macOS `SidebarSection` enum** -- `MacContentView.swift:9-46` has a separate `SidebarSection` enum from iOS's `ActiveScreen`. Both must be updated in lockstep. Currently they have identical cases (home, system, browser, teams, hostProfiles, themes, hooks, settings) but this parity is fragile.
2. **Test every programmatic navigation path on macOS** -- deep links, keyboard shortcuts, and menu bar commands must all result in both correct detail content AND correct sidebar highlight.
3. **Add keyboard shortcuts for new screens** -- the current `ILSCommands.swift` only has Navigate shortcuts for Home (Cmd+1), Sessions (Cmd+2), Browse (Cmd+3), System (Cmd+4), and Settings (Cmd+,). New screens (Host Profiles, Hooks, Themes) need keyboard shortcuts.
4. **Guard against notification loss** -- consider making `handleNavigationIntent()` idempotent and checking for pending navigation on window activation (`.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))`).
5. **Verify keyboard shortcut conflicts** before adding new ones. macOS reserves many Cmd+ combinations at the system level.

**Detection:**
- Sidebar highlight does not match detail content after keyboard navigation
- New screen appears in iOS sidebar but not in macOS sidebar
- Menu bar command does nothing when window is in background
- Keyboard shortcut triggers wrong action or system beep

**Phase to address:** macOS Feature Parity phase -- test every navigation code path on macOS after adding new screens.

---

### Pitfall 5: Cross-Platform Code Sharing -- #if os() Guards Create Silent Feature Gaps

**What goes wrong:**
The codebase has 47 files with `#if os(iOS)` / `#if os(macOS)` guards. When a new feature is added inside an `#if os(iOS)` block, it silently does not exist on macOS. The compiler does not warn about this -- the macOS build succeeds, and the feature simply is not there. This is not a build error; it is a feature gap that can only be discovered by running the macOS app and checking every screen.

Current examples of platform divergence risk:
- `HooksManagementView.swift` uses `#if os(iOS)` for `UIPasteboard` and `#if os(macOS)` for `NSPasteboard` (lines 251-256) -- this is correct, but new clipboard operations must replicate this pattern
- `PlatformCompat.swift` provides macOS shims for `UIKeyboardType`, `UITextAutocapitalizationType`, `ToolbarItemPlacement.navigationBarTrailing` -- but new iOS-only modifiers added without shims will cause macOS build failures
- `ILSAppApp.swift` (iOS entry point) has `PerformanceMonitor.shared.start()` inside `#if os(iOS)` -- macOS does not get performance monitoring
- Live Activity (`ILSLiveActivity.swift`) is iOS-only by nature -- no macOS equivalent needed

The v5.0 scope adds features to 5 parallel streams. Each stream may add iOS-specific code that must also work on macOS. Without a systematic check, features will be iOS-only by default.

**Consequences:**
- macOS app silently lacks features that exist on iOS
- macOS build succeeds but app behavior differs from iOS in ways not caught until the 30-gate audit
- New `#if os(iOS)` blocks added without corresponding macOS implementation
- PlatformCompat.swift needs new shims but developer does not realize it until macOS build fails

**Prevention:**
1. **After every feature implementation, run BOTH builds:**
   ```bash
   xcodebuild -scheme ILSApp -destination 'id=50523130' -quiet  # iOS
   xcodebuild -scheme ILSMacApp -destination 'platform=macOS' -quiet  # macOS
   ```
   The auto-build hook only builds the target whose file was edited. If you edit a shared file from the iOS target directory, the macOS build is not checked.
2. **Create a "parity checklist" per feature** -- for each new View/ViewModel/Service, explicitly document: "Does this need macOS-specific handling? Does PlatformCompat need a new shim?"
3. **Avoid adding new `#if os(iOS)` blocks** -- prefer the PlatformCompat shim pattern where a no-op extension provides API compatibility on macOS.
4. **macOS SidebarSection must match iOS ActiveScreen** -- when a new case is added to `ActiveScreen` (SidebarRootView.swift), the same case must be added to `SidebarSection` (MacContentView.swift) and its `.screen` computed property.
5. **Test deep links on macOS** -- the macOS app handles `onOpenURL` in `ILSMacApp.swift`, which must support all the same routes as iOS.

**Detection:**
- Feature works on iPhone simulator but is not visible on macOS app
- macOS build succeeds but a View shows empty or default content where iOS shows the new feature
- `SidebarSection.allCases` on macOS has fewer items than `ActiveScreen` cases on iOS

**Phase to address:** Every implementation stream -- make "verify macOS build + feature presence" a gate for every plan completion.

---

## Moderate Pitfalls

---

### Pitfall 6: Hooks Management -- Editing Hooks Config Without Understanding Scope Precedence

**What goes wrong:**
The `HooksManagementView` currently is read-only -- it displays hooks from `viewModel.config?.content.hooks` where the config is loaded via `SettingsViewModel.loadConfig()`. The v5.0 scope adds hooks management (create, edit, delete hooks).

The danger: hooks can exist in any of the 3 config scopes (user, project, local). If the management UI writes to the wrong scope, the user's edit may:
- Be overridden by a higher-precedence scope (user sets a hook, project config overrides it)
- Persist globally when they intended a project-specific hook (writing to user scope instead of project)
- Conflict with existing hooks in another scope (same event type, different commands)

The `HooksConfig` CodingKeys use PascalCase (`"PreToolUse"`, `"PostToolUse"`) matching Claude Code's JSON format (ClaudeConfig.swift:132-138). If the write path uses Swift's default camelCase encoding, the JSON will have `"preToolUse"` keys that Claude Code ignores silently.

**Consequences:**
- User creates a hook, saves, but Claude Code does not execute it (wrong JSON key casing)
- Hook appears in the app but not in `claude config show` output (scope mismatch)
- Deleting a hook from one scope reveals the same hook from a parent scope -- user thinks delete failed
- Concurrent modification: user edits hooks in ILS app while Claude CLI modifies the same file

**Prevention:**
1. **Always show which scope a hook comes from** before allowing edits. Use `ConfigScope` badges.
2. **Write to the same scope the hook was read from** -- do not silently create local overrides.
3. **Verify JSON encoding uses PascalCase keys** -- the `CodingKeys` in `HooksConfig` define the correct mapping. Ensure the `JSONEncoder` used for writing respects these keys.
4. **File-level atomic writes** -- if the backend writes config files, use `Data.write(to:url:options:.atomic)` to prevent corruption from concurrent writes.
5. **After any hook write, re-read the config and diff** -- confirm the write actually persisted by fetching the config again.
6. **Warn about scope conflicts** -- if a hook exists in both user and project scope, show a warning icon.

**Detection:**
- Hook created in app does not appear in `cat ~/.claude/settings.json`
- Hook keys in JSON file are camelCase instead of PascalCase
- Deleting a hook makes it reappear (from parent scope)

**Phase to address:** Stream 3 (Skills/Plugins/Hooks/Theming) -- hooks management. Design the write path carefully before implementing.

---

### Pitfall 7: GitHub Browse/Install -- Installing Skills/Plugins Without Validating Content

**What goes wrong:**
The GitHub browse feature lets users search for and install skills/plugins directly from GitHub. The current `GitHubService` fetches raw file content via `raw.githubusercontent.com` (GitHubService.swift:253-281). When "Install" is tapped, the content is fetched and presumably written to the local filesystem.

Security risk: the fetched SKILL.md or plugin.json could contain:
- Malformed JSON that crashes the plugin loader
- Path traversal in filenames (`../../etc/passwd`)
- Excessively large files (no size limit on raw content fetch)
- Shell injection in hook commands embedded in plugin configs
- Plugins that declare dependencies on system tools not present on the host

The current code also uses `getDefaultBranch()` to determine which branch to fetch from, defaulting to "main" on error. If a repo's default branch is something else (e.g., "master", "develop"), the first fetch fails silently, falls back to "main", and fetches a 404 (which is handled but could confuse users).

**Consequences:**
- Installing a malicious skill could execute arbitrary commands on the host
- Large file download blocks the UI (no progress indicator or cancellation)
- Plugin with unmet dependencies fails silently after install
- User installs from a fork with outdated/malicious code thinking it is the official version

**Prevention:**
1. **Validate all fetched content before writing to disk:**
   - JSON files: parse and validate schema before saving
   - SKILL.md files: check size limit (reject > 1MB), sanitize content
   - Reject any file paths containing `..` or absolute paths
2. **Add a size limit to raw content fetch** -- `response.body.readableBytes` should be checked before decoding
3. **Show a preview before install** -- display the file content (or a summary) and require user confirmation
4. **Verify repository authenticity** -- show the repository full name, star count, and last update date prominently. Warn if stars < 10 or last update > 1 year ago.
5. **Plugin dependency checking** -- the v4.0 ECO-02 requirement added dependency detection. Ensure this runs BEFORE install, not after.
6. **Sandbox installed plugins** -- skills and plugins should run in the context of Claude Code, not directly on the host system.

**Detection:**
- Install succeeds but skill/plugin does not appear in the installed list
- Install of a very large repo hangs the app
- Plugin with missing dependencies shows no warning

**Phase to address:** Stream 3 -- implement install with validation before building the browse UI.

---

### Pitfall 8: 30-Gate Validation -- Screenshot Evidence Collection Is Fragile and Non-Deterministic

**What goes wrong:**
The 30-gate audit framework (from `evidence/AUDIT-STATE.md`) requires screenshot evidence for every screen on 3+ platforms. From v3.5 and v4.0 experience, screenshot capture has multiple failure modes:

- `screencapture -l` fails for iPad (known issue from v3.5 -- must use `simctl io screenshot` after `Window > Fit Screen`)
- Screenshots captured before SwiftUI renders show loading states or blank content
- `idb_tap` cannot hit SwiftUI toolbar buttons (must use edge swipe for sidebar)
- Deep link UUIDs must be lowercase
- Stale DerivedData binary silently invalidates all evidence
- iPad NavigationSplitView takes 300-500ms to settle column animations
- macOS Catalyst screenshots require a different capture approach than iOS simulators

With 50+ screens across 3-4 platforms, that is 150-200 screenshots. If the capture infrastructure is fragile, a single issue (wrong binary, wrong backend, timing) invalidates an entire platform's evidence set, requiring full re-capture.

**Consequences:**
- Re-capture costs 30-60 minutes per platform per occurrence
- Flaky evidence undermines confidence in the audit
- Gate review rejects evidence with loading spinners or wrong screens
- macOS screenshots require platform-specific tooling not used in prior milestones

**Prevention:**
1. **Automate the capture pipeline** -- build a script that: verifies backend binary path, boots simulator, builds + installs fresh, navigates to each screen via deep link, waits 3+ seconds, captures, names with structured convention
2. **Capture alongside accessibility tree dump** -- `idb_describe` output serves as machine-verifiable evidence that content loaded
3. **Validate before archiving** -- a post-capture script checks: file size > 10KB (not blank), filename matches convention, timestamp within session window
4. **macOS capture strategy** -- use `screencapture -w` (window capture) with the macOS app window, not simulator
5. **Build the capture infrastructure in Phase 0** before any feature implementation, so evidence collection is reliable from the start
6. **Checkpoint evidence per stream** -- do not wait until the final audit phase to capture all evidence. Capture per-stream evidence as features are completed.

**Detection:**
- Evidence directory has fewer screenshots than expected
- Multiple screenshots show the same screen (copy-paste error in deep link)
- Screenshot file is < 5KB (blank or error screen)
- Timestamps span days instead of a single session (mixed evidence from multiple runs)

**Phase to address:** Phase 0 (validation infrastructure) -- before any feature work begins.

---

### Pitfall 9: macOS Keyboard Shortcut Conflicts -- New Shortcuts Collide With System or Existing Bindings

**What goes wrong:**
`ILSCommands.swift` defines keyboard shortcuts for the macOS app: Cmd+N (New Session), Cmd+1-4 (Navigate), Cmd+, (Settings), Cmd+Shift+R/F/E (Rename/Fork/Export), Cmd+Delete (Delete Session), Cmd+Option+E (Toggle Tool Calls). The v5.0 scope adds new screens (Host Profiles, Hooks, Themes) that need keyboard shortcuts.

The pitfall: macOS reserves many keyboard combinations at the system and app framework level:
- `Cmd+H` -- system Hide (cannot override reliably)
- `Cmd+M` -- system Minimize
- `Cmd+Q` -- system Quit
- `Cmd+W` -- system Close Window
- `Cmd+Shift+?` -- system Help menu
- `Cmd+,` -- already used for Settings
- `Cmd+5` through `Cmd+9` -- safe to use but may conflict with other apps
- `Cmd+Shift+F` (currently Fork Session) -- conflicts with system "Show All Tabs" in some contexts

If new shortcuts collide, the system intercepts the keypress and the app never receives it. The user presses the shortcut, nothing happens in the app, and there is no error or feedback.

**Consequences:**
- Keyboard shortcut silently does nothing (system intercept)
- Two menu items share the same shortcut -- SwiftUI picks one arbitrarily
- Documentation/UI shows a shortcut that does not work
- Accessibility users who rely on keyboard navigation cannot reach new screens

**Prevention:**
1. **Audit existing shortcuts before adding new ones.** Current allocation:
   - Cmd+N: New Session
   - Cmd+1-4: Navigation (Home, Sessions, Browse, System)
   - Cmd+,: Settings
   - Cmd+Shift+R/F/E: Session actions
   - Cmd+Option+E: Toggle tool calls
   - Cmd+Delete: Delete session
2. **Available safe slots:** Cmd+5 (Host Profiles), Cmd+6 (Hooks), Cmd+7 (Themes), Cmd+8 (Teams)
3. **Test every new shortcut on macOS** -- verify the action fires, not the system handler
4. **Use the Navigate menu for navigation shortcuts** -- keep them grouped for discoverability
5. **Add the `keyboardShortcut` to the `ILSCommands` struct** -- never add keyboard shortcuts directly to Views on macOS

**Detection:**
- Pressing shortcut does nothing or triggers system behavior (window hides, minimizes)
- Menu bar shows shortcut indicator but keypress has no effect
- Two menu items show the same shortcut combination

**Phase to address:** macOS Feature Parity phase -- allocate and test all shortcuts in one pass.

---

### Pitfall 10: Hooks File System Watching -- DispatchSource Cannot Monitor Remote Host Config Files

**What goes wrong:**
The hooks management feature needs to reflect the current state of hooks from the host's config files. If hooks are modified outside the app (via Claude CLI, text editor, or another session), the app should update. The natural approach is file system monitoring using `DispatchSource` (for specific files) or `FSEvents` (for directory hierarchies).

The fundamental problem: ILS connects to a **remote** backend. The config files (`~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`) live on the **host machine**, not on the iOS/macOS client. `DispatchSource` and `FSEvents` can only monitor the local filesystem. There is no mechanism to push config changes from the host to the app in real-time.

Even for the local macOS case (backend running on the same machine), `FSEvents` requires careful setup:
- The `FSEventStream` info pointer creates a dangling pointer if the client deallocates without calling `stop()`
- `DispatchSource.FileSystemEvent` monitors a specific file descriptor -- if the file is replaced (deleted + recreated), the descriptor becomes invalid
- iOS in background mode does not receive file system notifications; they queue until foreground

**Consequences:**
- User modifies hooks via CLI, app shows stale data until manual refresh
- Implementing local file watching for macOS only creates platform-inconsistent behavior
- File watcher leak if not cleaned up properly on view disappear
- File replaced (not modified) silently breaks the watcher

**Prevention:**
1. **Do NOT implement client-side file watching** -- it only works locally and creates complexity
2. **Use pull-based refresh** -- the current `HooksManagementView` already has `.refreshable { await viewModel.loadConfig() }`. This is the correct pattern.
3. **Add a "Config last loaded X ago" indicator** (similar to DATA-04's cache freshness from v4.0) so users know when data might be stale
4. **Consider WebSocket push from backend** -- the backend already uses WebSocket for system metrics. A config change notification channel could be added if real-time hooks updates become important.
5. **For macOS local development only**, consider an opt-in file watcher behind a feature flag -- but do not make it the primary mechanism.

**Detection:**
- Hooks view shows old hooks after CLI modification (expected with pull-based)
- File watcher crash on macOS when config file is replaced
- Memory leak from un-cleaned DispatchSource

**Phase to address:** Stream 3 (Hooks management) -- decide on refresh strategy upfront. Pull-based first, push-based as a future enhancement.

---

### Pitfall 11: GitHub Search Result Install -- Fetching from Wrong Branch or Fork

**What goes wrong:**
The existing `GitHubService.getDefaultBranch()` (line 186-216) fetches the repo's default branch, falling back to "main" on any error. When a user finds a skill/plugin via code search, the search result contains `item.repository.fullName` (e.g., `user/repo`). The install flow then calls `fetchRawContent(owner:repo:path:)` which uses the default branch.

Problems:
1. **Fork confusion** -- Code Search returns results from forks. A search for "claude skill" might return `malicious-user/popular-repo` (a fork) alongside `original-author/popular-repo`. The UI shows both identically if only the skill name is displayed.
2. **Branch mismatch** -- The search API indexes from the default branch, but `getDefaultBranch()` makes a separate API call that could return a different result if the repo's default branch was changed between indexing and the install request.
3. **Rate limit on default branch lookup** -- Each install requires an extra API call to get the default branch. With 10 req/min code search limit, adding a branch lookup per install further reduces the budget.
4. **Path encoding** -- `skillPath` from search results may contain spaces or special characters. The current `fetchRawContent` constructs the URL with string interpolation (line 255) -- if the path contains `%20` or `#`, the URL breaks.

**Consequences:**
- User installs a skill from a fork thinking it is the official version
- Install fetches from wrong branch, getting old or incompatible version
- Rate limit hit during install flow (search + branch lookup + content fetch = 3 requests per install)
- Install fails silently for paths with special characters

**Prevention:**
1. **Show full repository path** (`owner/repo`) prominently in search results, not just the skill name
2. **Highlight forks** -- check if `repository.fork` is true in the search response and display a "Fork" badge
3. **Cache the default branch** per repository -- do not look it up for every file fetch
4. **URL-encode the file path** -- use `path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)`
5. **Batch install requests** -- when installing a skill that has multiple files, fetch all in parallel to minimize API calls
6. **Prefer the `git_url` from the search result** rather than constructing a raw.githubusercontent URL

**Detection:**
- Search shows duplicate results from forks
- Install fails with 404 for repos with non-"main" default branch
- Install works for simple paths but fails for paths with spaces

**Phase to address:** Stream 3 -- GitHub browse/install implementation.

---

## Minor Pitfalls

---

### Pitfall 12: macOS Window Management -- New Screens Not Accessible via Window > New Window

**What goes wrong:**
`WindowManager.swift` manages opening sessions in new windows via `openSessionWindow()`. If new screens (Host Profiles, Hooks, Themes) are added without extending the window management system, users cannot open them in separate windows -- a core macOS expectation. Currently only chat sessions can be opened in new windows.

**Prevention:**
- Extend `WindowManager` to support arbitrary `ActiveScreen` types, not just `ChatSession`
- Add "Open in New Window" to the context menu for new list items (host profiles, etc.)
- Test that each new window receives its own `NavigationStack` and does not interfere with the main window's state

**Phase to address:** macOS Feature Parity phase.

---

### Pitfall 13: Backend Database Migration for New Features -- Fluent Migration Ordering

**What goes wrong:**
Adding new backend features (hooks storage, GitHub cache, host profile metadata) may require new database tables or columns. Fluent migrations must be added in order -- a migration that references a table from another migration must come after it. If migrations are added out of order (e.g., by two parallel development streams), the database fails to initialize.

Additionally, existing data must survive migration. The current database has 22K+ external sessions, 373 projects, and fleet hosts. A migration that drops and recreates a table loses this data.

**Prevention:**
- Always add new migrations at the END of the migration list in `configure.swift`
- Never use `.delete()` on existing tables in a migration
- Test migrations against a database with existing data, not just a fresh database
- Use `ALTER TABLE ADD COLUMN` style migrations for existing tables
- If parallel streams both need migrations, assign explicit ordering (e.g., stream 1 = migration 100-109, stream 2 = 110-119)

**Phase to address:** All implementation streams that add backend models.

---

### Pitfall 14: Config Editor Write Safety -- Malformed JSON Bricks Claude Code

**What goes wrong:**
The Settings > Config Editor allows editing the raw JSON config file. If a user (or the hooks management feature) writes malformed JSON to `~/.claude/settings.json`, Claude Code cannot start -- it fails to parse its own config on launch. This effectively bricks the user's Claude Code installation until they manually fix the JSON.

The current `ConfigEditorView` may or may not validate JSON before saving. Even with validation, edge cases exist: valid JSON but invalid schema (wrong field types), valid schema but semantically invalid (conflicting hook matchers).

**Prevention:**
1. **Always validate JSON syntax before writing** -- `try JSONSerialization.jsonObject(with:)` as a minimum gate
2. **Schema validation** -- decode the JSON into `ClaudeConfig` and check for errors before writing
3. **Backup before write** -- copy the current file to `settings.json.backup` before overwriting
4. **Atomic write** -- use `.atomic` write option so a crash mid-write does not produce a truncated file
5. **"Revert to last known good" button** -- if validation fails after write, offer to restore the backup

**Phase to address:** Stream 2 (Settings & Config) and Stream 3 (Hooks management).

---

### Pitfall 15: 30-Gate Evidence for macOS -- Different Screenshot Tooling Than iOS

**What goes wrong:**
iOS screenshots use `xcrun simctl io $UDID screenshot`. macOS screenshots of the native app require different tooling:
- `screencapture -w` (interactive window capture) -- requires human click
- `screencapture -l $WINDOWID` -- requires knowing the window ID
- `screencapture -R x,y,w,h` -- requires knowing exact coordinates

The automation scripts built for iOS simulators do not work for macOS app screenshots. If this is not addressed in the validation infrastructure phase, the macOS evidence collection becomes a manual process, significantly slowing the 30-gate audit.

**Prevention:**
1. **Get the macOS app window ID programmatically:**
   ```bash
   osascript -e 'tell application "System Events" to tell process "ILSMacApp" to get id of window 1'
   ```
2. **Use `screencapture -l $WINDOWID`** for automated macOS screenshots
3. **Build the macOS capture into the same script that handles iOS capture** -- one script, platform parameter
4. **For Catalyst apps**, the iOS simulator approach may still work -- verify which target architecture is used

**Phase to address:** Phase 0 (validation infrastructure).

---

### Pitfall 16: AppState.handleURL Becomes a Giant Switch -- Deep Link Handler Does Not Scale

**What goes wrong:**
`AppState.handleURL()` (AppState.swift:89-134) is a flat `switch url.host` with 12 cases. Adding new deep link routes (e.g., `ils://host-profiles`, `ils://host-profiles/{id}`, `ils://hooks/{eventType}`) makes this switch statement grow linearly. With sub-routes (detail views), the parsing logic becomes complex and error-prone.

**Prevention:**
1. **Do not add `ils://host-profiles` as a new case** -- the existing `ils://fleet` and `ils://profiles` already route to `.hostProfiles`. Simply add `"host-profiles"` as another accepted hostname.
2. **Consider a route registration pattern** for sub-routes rather than nested switch statements
3. **Always maintain backward compatibility** -- old deep link hosts must continue working
4. **Test every deep link on both iOS and macOS** -- the macOS app also receives `onOpenURL`

**Phase to address:** Any stream that adds new deep link routes.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Stream 1: Navigation & Layout | P5 (cross-platform gaps), P4 (macOS NavigationSplitView desync) | Build iOS + macOS after every feature, test deep links on both |
| Stream 2: Settings & Config Inheritance | P3 (merge endpoint missing), P14 (write safety), P6 (scope confusion) | Build merge endpoint first, validate JSON before write, show scope badges |
| Stream 3: Skills/Plugins/Hooks/Theming | P2 (GitHub rate limit), P7 (unvalidated installs), P11 (fork confusion), P6 (hook scope), P10 (file watching) | Throttle searches, validate content, show repo metadata, pull-based refresh |
| Stream 4: System Monitor + Profiles | P1 (Fleet rename), P13 (DB migration) | Route aliasing, additive migrations only |
| Stream 5: Backend API Audit | P13 (migration ordering), P1 (route backward compat) | Strict migration ordering, old routes preserved |
| macOS Feature Parity | P4 (NavSplitView), P5 (platform guards), P9 (keyboard conflicts), P12 (window management), P15 (screenshot tooling) | Update both sidebar enums, audit shortcuts, test every screen on macOS |
| Platform Validation (30-gate) | P8 (evidence fragility), P15 (macOS screenshots) | Automate capture pipeline, validate evidence before archiving |

---

## "Looks Done But Is Not" Checklist

- [ ] **Fleet rename has route aliases:** Old `/api/v1/fleet/*` routes still work after rename
- [ ] **Deep link `ils://fleet` still works:** Not removed, only supplemented with `ils://host-profiles`
- [ ] **macOS SidebarSection matches iOS ActiveScreen:** Same cases, same ordering
- [ ] **GitHub search is throttled:** No more than 10 requests per minute client-side
- [ ] **GitHub rate limit reset time forwarded to iOS:** Countdown timer shows real seconds
- [ ] **Config merge endpoint exists:** Backend computes effective config with per-field provenance
- [ ] **Hooks write uses PascalCase keys:** `"PreToolUse"` not `"preToolUse"` in saved JSON
- [ ] **Config editor validates before save:** Malformed JSON blocked, backup created
- [ ] **macOS keyboard shortcuts tested:** Each shortcut verified to fire the correct action
- [ ] **Cross-platform build verified:** Both `ILSApp` and `ILSMacApp` schemes build green after every feature
- [ ] **Database migrations are additive:** No `DROP TABLE`, no column renames on populated tables
- [ ] **Evidence capture automated:** Script handles iOS + macOS with structured naming
- [ ] **PlatformCompat updated:** New iOS-only modifiers have macOS shims
- [ ] **Database table NOT renamed:** `fleet_hosts` table name preserved, model `schema` maps to it

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Fleet route rename breaks client (P1) | MEDIUM -- add redirect routes | Add old routes as aliases, deploy backend, rebuild client |
| GitHub rate limit hit (P2) | LOW -- wait 60 seconds | Show countdown, implement backoff, increase cache TTL |
| Config inheritance wrong (P3) | HIGH -- redesign backend endpoint | Build proper merge endpoint, update all config UIs |
| macOS NavSplitView desync (P4) | LOW -- fix selection binding | Ensure programmatic navigation updates both `selectedSection` and `activeScreen` |
| Cross-platform feature gap (P5) | MEDIUM -- add missing macOS code | Build macOS, identify gaps, add platform code, rebuild |
| Hook scope confusion (P6) | MEDIUM -- add scope UI | Show scope badges, validate write target, re-read after write |
| Unsafe GitHub install (P7) | HIGH -- security review | Add content validation, size limits, preview before install |
| Evidence pipeline failure (P8) | HIGH -- recapture all | Fix infrastructure, recapture entire platform set |
| Keyboard shortcut conflict (P9) | LOW -- reassign shortcut | Test on macOS, pick non-conflicting combination |
| File watcher complexity (P10) | LOW -- use pull-based | Remove watcher, add manual refresh + freshness indicator |
| Wrong branch install (P11) | LOW -- fix URL construction | Cache default branch, URL-encode paths, show fork badges |

---

## Sources

- Direct code inspection: `Sources/ILSBackend/Services/GitHubService.swift` -- Code Search API calls at lines 43-111, rate limit header parsing at lines 72-76, raw content fetch at lines 253-281, default branch lookup at lines 186-216
- Direct code inspection: `Sources/ILSBackend/Controllers/FleetController.swift` -- route registration at `routes.grouped("fleet")` line 16, all endpoints at `/fleet/*`
- Direct code inspection: `Sources/ILSShared/Models/FleetHost.swift` -- `typealias HostProfile = FleetHost` at line 4
- Direct code inspection: `Sources/ILSShared/Models/ClaudeConfig.swift` -- `HooksConfig` CodingKeys with PascalCase at lines 132-138, `ConfigInfo` with `ConfigScope` at lines 182-208
- Direct code inspection: `ILSApp/ILSApp/AppState.swift` -- `handleURL()` deep link router at lines 89-134, `"fleet"` and `"profiles"` both map to `.hostProfiles` at line 123
- Direct code inspection: `ILSApp/ILSMacApp/Views/MacContentView.swift` -- `SidebarSection` enum at lines 9-46, `NavigationSplitView` at line 85, `handleNavigationIntent()` at lines 607-629
- Direct code inspection: `ILSApp/ILSMacApp/Commands/ILSCommands.swift` -- keyboard shortcuts Cmd+N, Cmd+1-4, Cmd+,, Cmd+Shift+R/F/E, Cmd+Option+E, Cmd+Delete
- Direct code inspection: `ILSApp/ILSApp/Utils/PlatformCompat.swift` -- macOS shims for UIKeyboardType, ToolbarItemPlacement, autocapitalization
- Direct code inspection: `ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift` -- read-only display, `#if os(iOS)` clipboard handling at lines 251-256
- [GitHub REST API Rate Limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) -- 60/hr unauthenticated, 5000/hr authenticated, secondary limits
- [Updated rate limits for unauthenticated requests (May 2025)](https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/) -- recent changes to unauthenticated limits
- [Changes to the Code Search API (March 2023)](https://github.blog/changelog/2023-03-10-changes-to-the-code-search-api/) -- code search API versioning history
- [GitHub Search API 1000 result limit](https://github.com/PyGithub/PyGithub/issues/824) -- `total_count` maxed at 1000, pagination stops
- [NavigationSplitView Apple Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview) -- column behavior, compact collapse
- [NavigationLink breaks NavigationSplitView hierarchy](https://www.hackingwithswift.com/forums/swiftui/navigationlink-on-detail-navigationsplitview-breaks-navigation-stack-hierarchy/23770) -- known SwiftUI issue
- [NavigationStack inside NavigationSplitView tab switching](https://www.hackingwithswift.com/forums/swiftui/navigationstack-inside-navigationsplitview-changing-top-level-tab-does-not-change-view/22960) -- programmatic navigation pitfall
- [DispatchSource file monitoring in Swift](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift) -- DispatchSource limitations and pitfalls
- [FSEvents dangling pointer issue](https://developer.apple.com/forums/thread/115387) -- stream info pointer lifecycle
- [Vapor routing documentation](https://docs.vapor.codes/basics/routing/) -- redirects for backward compatibility
- Project MEMORY.md: Backend binary mismatch, deep link UUID case sensitivity, idb_tap toolbar limitation, DerivedData path confusion, screencapture iPad limitation

---
*Pitfalls research for: ILS iOS/macOS -- v5.0 Cross-Platform Feature Completion & 30-Gate Audit*
*Researched: 2026-02-27*
