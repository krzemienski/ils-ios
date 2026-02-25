# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-25)

**Core value:** Every screen works correctly, reflects host config, and provides a polished native experience
**Current focus:** Phase 38 — Cross-Platform Validation

## Current Position

Phase: 38 — Cross-Platform Validation (IN PROGRESS)
Plan: 1 of 2 complete
Status: Executing Phase 38
Last activity: 2026-02-25 — Plan 01 (cross-platform build validation) verified — all 3 targets build with zero errors

### Planning Summary (Phases 36-38)
- Phase 36: 3 plans / 2 waves / 8 reqs (BRW-01..08) — GitHub browse & install for skills + plugins
- Phase 37: 2 plans / 1 wave / 3 reqs (SYS-01..03) — System monitor host fix + theme verification
- Phase 38: 2 plans / 2 waves / 3 reqs (XP-01..03) — Cross-platform build + parity validation

## Previous Milestones

- v1.0 (Phases 1-10): Cross-Platform Audit — SHIPPED 2026-02-21 | 15/15 REQs PASS | 0 crashes
- v2.0 (Phases 11-17): Performance Optimization Suite — COMPLETE 2026-02-24 | 838ms cold-start, regression tests
- v3.0 (Phases 18-24): Comprehensive Audit Remediation — COMPLETE 2026-02-23 | 165/165 issues resolved
- v1.5 (Phases 25-32): All Audit Fixes — SHIPPED 2026-02-24 | 50 REQs | 70/70 findings resolved/documented

## Accumulated Context

### Decisions

- [v3.1]: Shift from code health to product quality — UX gaps now blocking real usage
- [v3.1]: Fleet → Host Profiles redesign — multi-host concept clearer than fleet metaphor
- [v3.1]: Host CLI config sync required — app must reflect connected host defaults
- [v3.1]: Phase numbering continues from 33 (v1.5 ended at Phase 32)
- [v3.1]: Scope includes new features (GitHub browse/install, host sync) unlike previous code-health milestones
- [33-01]: Sub-token spacing (1pt, 2pt) retained for tight label pairs -- below spacingXS threshold by design
- [33-01]: HomeView section ordering verified correct as-is -- no reordering needed
- [33-02]: Used lightweight previousScreen @State instead of NavigationPath to avoid breaking @SceneStorage chat restoration
- [33-02]: Back button replaces hamburger via topBarLeading placement; sidebar remains accessible via edge swipe
- [33-02]: activeHostName defaults to nil; wired by Phase 34 HostProfilesViewModel.activate()
- [33-03]: Used BrowserSegment type (not String) for browserSegmentIntent since enum is top-level and target-accessible
- [33-03]: ils://projects grouped with ils://browser (no .projects case in BrowserSegment); mcp/skills/plugins get individual segment intents
- [33-03]: Non-chat deep links clear previousScreen to prevent stale back destinations
- [34-03]: UI-facing terminology uses "host profile"; backend API paths and model types keep "fleet"
- [34-01]: HostProfilesViewModel uses optional pattern in View -- initialized in .task to ensure AppState is available from @Environment
- [34-01]: hostProfileRow receives unwrapped viewModel as parameter rather than optional chaining throughout
- [34-01]: Health polling uses silent catch (best-effort) while user-facing operations surface errors via loadError
- [34-03]: Fixed HostProfilesView optional viewModel pattern to match updated init(appState:) signature
- [34-02]: SidebarRootView onChange also reloads custom themes via themeManager to keep theme picker in sync with new host
- [34-02]: SettingsView onChange updates local serverURL @State so connection section reflects new host URL immediately
- [34-02]: ConfigEditorView onChange resets both configText and originalConfigText to prevent false unsaved-changes warnings
- [34-02]: ChatView only reconfigures clients without reloading -- preserves visible conversation
- [35-01]: Closure-based delta pattern for saveWithPatch instead of KeyPath -- supports compound mutations (model + theme)
- [35-01]: PUT full config back (not stripped) because server writes payload verbatim; stripping would also drop CLI fields
- [35-02]: API Key always shows Host Default badge -- cannot be set from iOS app
- [35-02]: Agent Teams always shows Custom badge -- device-local @AppStorage setting
- [35-02]: System Prompt section is read-only informational -- systemPrompt is NOT a settings.json field
- [35-02]: Advanced fields (statusLine, env) show fallback rows when nil so badges are always visible
- [36-01]: getDefaultBranch falls back to "main" on any error (best-effort, no crash)
- [36-01]: Skills enable/disable uses .skills-config.json in ~/.claude/skills/ (isolated from main settings)
- [36-01]: searchPlugins reuses GitHubSearchResult DTO (skillPath field holds plugin.json path)
- [36-02]: isInstalled checks both skill.name and skill.path against repo name for robust matching
- [36-02]: Rate limit errors routed to gitHubError (inline banner) while other errors go to generic error property
- [36-02]: Context menu Enable/Disable placed before Remove for safer default action ordering
- [36-03]: Used InstallPluginRequest (not SkillInstallRequest) for plugin GitHub install -- matches actual backend endpoint contract
- [36-03]: Plugin GitHub results use context menu Remove (not inline delete) matching skills pattern
- [36-03]: Enable/disable on installed rows served via existing context menus from Plan 02 -- no additional UI needed
- [37-01]: Kept init default parameter as localhost:9999 for previews; only runtime baseURL is mutable via updateBaseURL()
- [37-01]: updateBaseURL is a no-op when URL unchanged (guard) -- safe to call on every onAppear
- [37-01]: Removed redundant loadProcesses from onAppear since connect() already calls startProcessAutoRefresh which does initial load
- [37-02]: No code changes needed -- all theme verification checks passed without gaps
- [37-02]: Legacy ILSTheme.swift platform-adaptive colors confirmed out of scope (not a built-in AppTheme)
- [38-01]: No code changes needed -- all three targets already build cleanly after Phases 33-37
- [38-01]: HapticManager cross-platform pattern confirmed correct -- #if os(iOS) with macOS no-op stubs
- [38-01]: .refreshable in SettingsView confirmed safe -- available on macOS 13+ and app targets macOS 14+

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-02-25
Stopped at: Completed 38-01-PLAN.md (cross-platform build validation) -- 1/2 plans done in Phase 38
Resume file: None
