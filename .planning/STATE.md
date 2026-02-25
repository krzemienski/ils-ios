# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Every screen works correctly, reflects host config, and provides a polished native experience
**Current focus:** v3.1 Comprehensive Audit, Bug Fix & UX Overhaul

## Current Position

Phase: 35 — Settings & Config Sync -- COMPLETE
Plan: 2/2 complete — All summaries documented
Status: All 2 plans executed and documented. Phase 35 complete.
Last activity: 2026-02-25 — Completed 35-02 (annotation badges, tooltips, system prompt section)

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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-02-25
Stopped at: Completed 35-02-PLAN.md — full annotation badge + tooltip coverage on all settings fields
Resume file: None
