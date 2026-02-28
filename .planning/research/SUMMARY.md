# Project Research Summary

**Project:** ILS iOS/macOS v5.0 -- Cross-Platform Feature Completion & 30-Gate Audit
**Domain:** Native Swift iOS/macOS client for Claude Code (feature completion milestone)
**Researched:** 2026-02-27
**Confidence:** HIGH

## Executive Summary

ILS v5.0 is a feature-completion milestone for a mature native Swift app (240+ files, 8 prior milestones) that serves as a mobile/desktop client for Claude Code. The app already has substantial infrastructure -- 18 ViewModels, 15 backend controllers, 13 themes, premium gating, and streaming chat. This milestone adds five feature domains: config inheritance visualization (showing CLI settings cascade), GitHub-based skill/plugin discovery and install, hooks management CRUD (currently read-only), macOS platform parity (Handoff, keyboard shortcuts, drag-and-drop, menu bar), and a "Fleet" to "Host Profiles" terminology rename. No new SPM dependencies are needed -- every feature is buildable with Foundation, SwiftUI, and existing Apple frameworks.

The recommended approach is to sequence work around shared-model changes first, then build features on the stabilized foundation. The Fleet-to-HostProfile rename must happen before anything else because it touches shared types used across all three targets (iOS, macOS, backend). Config inheritance comes next because it establishes the cascade pattern that hooks management builds on. GitHub browse/install is the most complex new feature and should land on a stable codebase. macOS parity mirrors the final iOS state and comes last before validation. The 30-gate audit captures evidence across all platforms as the final phase.

The key risks are: (1) the Fleet rename breaking API routes if old endpoints are not preserved as aliases, (2) GitHub API rate limiting at 10 requests/minute for code search silently degrading the browse experience, (3) config inheritance visualization built without a backend merge endpoint leading to incorrect "inherited" badges, and (4) cross-platform `#if os()` guards silently creating feature gaps on macOS that are only discovered during the audit phase. All four risks have concrete prevention strategies documented in the research. The overall complexity budget is approximately 2 weeks for table stakes, 4 weeks with key differentiators.

## Key Findings

### Recommended Stack

Zero new SPM packages are needed for v5.0. Every feature is implementable with Foundation (URLSession, JSONEncoder, NSUserActivity, FileManager), SwiftUI (.keyboardShortcut, .draggable/.dropDestination, .userActivity, DisclosureGroup, Form), UniformTypeIdentifiers (for drag-and-drop), and AppKit (NSMenu, NSWindow -- already imported). The GitHub API integration uses direct URLSession rather than OctoKit.swift because the library lacks the specific endpoints needed (contents/tree, topic-based search). The project stays on Swift Concurrency (async/await, Task, actor) throughout -- no Combine.

**Core technologies (all existing):**
- **Swift 5.10+ / SwiftUI**: Presentation layer with @Observable @MainActor ViewModels -- no change
- **Vapor 4 / Fluent / SQLite**: Backend with 15 controllers, 8 migrations -- add 1 new endpoint (config/cascade)
- **URLSession (via APIClient actor)**: HTTP with cache, retry, auth, coalescing -- extend for GitHub API proxy
- **xcrun simctl + idb**: Validation tooling for 30-gate evidence capture -- verified on machine

**New files to create (~8):** GitHubAPIClient, GitHubModels, GitHubBrowseViewModel, GitHubBrowseView, SkillInstaller, HookEditorView, ConfigInheritanceViewModel, ConfigInheritanceView. Plus 2 new DTOs in ILSShared (GitHubDTOs, ConfigCascadeDTOs) and 1 new backend service (GitHubService).

### Expected Features

**Must have (table stakes -- ship without these = incomplete):**
- Config inheritance visualization with scope badges (user/project/local/managed) and "Inherited"/"Overridden" indicators
- Hooks display for all 16 event types (currently only 5 of 16 shown) with hook type badges (command/prompt/agent/http)
- macOS keyboard shortcuts (Cmd+N, Cmd+F, Cmd+,, Cmd+1-8) and proper menu bar items via SwiftUI Commands
- Profile switching cascades settings reload (existing `onChange(of: appState.serverURL)` handlers need gap-filling)
- Plugin/skill browser enhancements with version info, update indicators, skill frontmatter display

**Should have (differentiators -- target for v5.0 but deferrable):**
- Hooks CRUD editor -- structured form for creating/editing hooks (high value, high complexity)
- GitHub marketplace browsing -- visual catalog of available plugins from registered marketplaces
- macOS full menu bar with File, Edit, View, Session, Window menus and all shortcuts visible

**Defer (v6.0+):**
- Config diff view (side-by-side scope comparison)
- Handoff / Continuity (cross-device session viewing via NSUserActivity)
- Config history with rollback (leveraging Claude Code's auto-backup files)
- Marketplace install from mobile (requires backend CLI invocation)
- Multi-window panels for config/system monitor/hooks (macOS)
- Hook execution logs/history

### Architecture Approach

The app follows a well-established layered architecture: Presentation (SwiftUI views with platform-specific routing), ViewModel (@Observable @MainActor classes with `configure(client:)` deferred injection), Service (APIClient actor, SSEClient, CacheService), Shared (ILSShared package with Codable/Sendable models and DTOs), and Backend (Vapor 4 controllers with Fluent ORM). v5.0 does not change the architecture -- it extends it with new endpoints, new views following existing patterns, and a type rename. The most architecturally significant addition is the config cascade endpoint that returns merged config with per-key provenance.

**Major components and their v5.0 changes:**
1. **ILSShared models** -- Add `managed` case to ConfigScope, expand HooksConfig from 5 to 16 event types, add ConfigCascadeResponse and GitHubDTOs
2. **Backend ConfigController** -- Add `GET /config/cascade` endpoint returning merged config with per-field provenance
3. **Backend SkillsController/PluginsController** -- Add GitHub search proxy and install endpoints
4. **iOS/macOS Views** -- Config inheritance badges in Settings, expanded hooks display, GitHub browse tab in Browser
5. **macOS ILSCommands** -- Complete keyboard shortcuts and menu bar items

**Critical patterns to follow:**
- `configure(client:)` for ViewModel initialization (not init injection)
- `saveWithPatch` for config writes (read-then-mutate-then-PUT to preserve CLI-only fields)
- `#if os()` guards in shared views (not separate Mac files)
- `APIResponse<T>` wrapping for all backend responses
- `Codable, Sendable` with precondition validation for all ILSShared types

### Critical Pitfalls

1. **Fleet-to-HostProfile rename breaks API routes (P1)** -- The rename touches 16+ files across 3 targets. Old `/api/v1/fleet/*` routes must be preserved as aliases. Database table `fleet_hosts` must NOT be renamed. Deep link `ils://fleet` must continue working. Prevention: add new routes alongside old, update clients, deprecate old routes later.

2. **GitHub Code Search rate limiting at 10 req/min (P2)** -- Separate from the general 5000/hr limit. Results capped at 1000. Current code logs warnings but does not surface reset timestamps to iOS or implement client-side throttling. Prevention: debounce search to 1 req/6s, cache aggressively, forward `X-RateLimit-Reset` to client, show "Showing 1000 of X results" cap indicator.

3. **Config inheritance without merge endpoint (P3)** -- No backend endpoint returns the merged effective config with per-field provenance. Building the UI without this means client-side merging that may differ from Claude Code's actual merge. Prevention: build `GET /config/cascade` endpoint first, never duplicate merge logic on client.

4. **macOS NavigationSplitView state desync (P4)** -- Programmatic navigation (deep links, keyboard shortcuts, menu commands) can leave sidebar highlight out of sync with detail content. NotificationCenter-based commands are fire-and-forget and lost if window is minimized. Prevention: test every programmatic navigation path on macOS, guard against notification loss.

5. **Cross-platform #if os() guards create silent feature gaps (P5)** -- 47 files have platform guards. New features added inside `#if os(iOS)` blocks silently do not exist on macOS. The auto-build hook only builds the edited target. Prevention: run BOTH iOS and macOS builds after every feature, update macOS SidebarSection enum in lockstep with iOS ActiveScreen.

## Implications for Roadmap

Based on combined research, the following 8-phase structure is recommended. This ordering is driven by dependency analysis (shared types first), risk mitigation (rename before features), and progressive complexity (verify existing patterns before adding new ones).

### Phase 1: Foundation -- Fleet-to-HostProfile Rename + Validation Infrastructure
**Rationale:** The rename touches shared types used everywhere. Doing it later risks merge conflicts with every other stream. Validation infrastructure must exist before feature work so evidence collection is reliable from the start.
**Delivers:** Clean type naming across all targets, route aliases for backward compat, automated screenshot capture pipeline for iOS + macOS.
**Addresses:** Host Profile activation cascade (table stakes), 30-gate validation framework.
**Avoids:** P1 (Fleet rename route breakage), P8 (fragile evidence collection), P15 (macOS screenshot tooling).
**Estimated effort:** 2-3 days.

### Phase 2: Settings & Config Inheritance
**Rationale:** Establishes the cascade pattern that hooks management builds on. The `ConfigOverride` DTO already exists in ILSShared; this phase builds the backend merge endpoint and the Settings UI badges.
**Delivers:** `GET /config/cascade` backend endpoint, config inheritance visualization in Settings with scope badges, scope-aware config editing.
**Addresses:** Config inheritance visualization (table stakes), config scope picker (table stakes).
**Avoids:** P3 (merge endpoint missing), P14 (config write safety -- validate JSON before save, backup before write).
**Estimated effort:** 3-4 days.

### Phase 3: Hooks Management Enhancement
**Rationale:** Depends on config write patterns established in Phase 2 (saveWithPatch). Extends the existing read-only HooksManagementView to display all 16 event types and optionally support CRUD.
**Delivers:** Full hooks display (16 event types, 4 hook types), scope badges per hook, optional CRUD editor form.
**Addresses:** Hooks display for all event types (table stakes), hooks CRUD editor (differentiator, deferrable).
**Avoids:** P6 (hook scope confusion -- show which scope each hook comes from), P10 (file watching -- use pull-based refresh, not DispatchSource).
**Estimated effort:** 2-5 days (2 for display, +3 for CRUD).

### Phase 4: GitHub Browse & Install
**Rationale:** Most complex new feature. Benefits from stable codebase after rename and config work. New backend endpoints (GitHub search proxy, install) are independent of other streams.
**Delivers:** GitHub search in Browser view, skill/plugin preview, one-tap install with content validation.
**Addresses:** Plugin/skill browser enhancements (table stakes), marketplace discovery (differentiator).
**Avoids:** P2 (rate limiting -- debounce search, cache results, surface reset timestamps), P7 (unvalidated installs -- validate content, size limits, preview before install), P11 (fork confusion -- show full repo path, highlight forks).
**Estimated effort:** 4-6 days.

### Phase 5: Navigation & Layout Polish + Browser Enhancements
**Rationale:** Independent of the model/backend work in Phases 1-4. Quick wins for polish: home screen improvements, skill frontmatter display, plugin metadata, MCP data verification.
**Delivers:** Enhanced home screen, skill frontmatter in browser, plugin version/update indicators, verified MCP data display.
**Addresses:** Plugin/skill browser metadata (table stakes), node_modules filtering verification.
**Avoids:** P5 (cross-platform gaps -- build both targets after every change).
**Estimated effort:** 2-3 days.

### Phase 6: macOS Feature Parity
**Rationale:** Mirrors the final iOS state. Must happen after all iOS features are complete so macOS captures the full feature set. Keyboard shortcuts, menu bar, drag-and-drop, and missing macOS views are all independent substreams.
**Delivers:** Complete keyboard shortcuts (Cmd+1-8), full menu bar (File/Edit/View/Session/Window), drag-and-drop, macOS views for any screens missing from the macOS target.
**Addresses:** macOS keyboard shortcuts (table stakes), macOS menu bar (table stakes).
**Avoids:** P4 (NavigationSplitView desync -- test every programmatic navigation path), P9 (keyboard shortcut conflicts -- audit before adding, use safe slots Cmd+5-8), P12 (window management -- extend WindowManager for new screens).
**Estimated effort:** 3-5 days.

### Phase 7: Backend API Audit
**Rationale:** Runs after all endpoint changes are complete. Covers the final API surface including renamed routes and new endpoints.
**Delivers:** Verified endpoint structure, consistent error codes, JSON field name validation, route registration audit.
**Addresses:** API consistency, backward compatibility verification.
**Avoids:** P1 (verify old routes still work), P13 (migration ordering).
**Estimated effort:** 1-2 days.

### Phase 8: 30-Gate Platform Validation + Bug Hunt
**Rationale:** All code complete. This phase captures evidence across iPhone and Mac. Includes edge case testing, offline behavior, accessibility, and memory profiling.
**Delivers:** 50+ evidence screenshots, per-gate VERDICT.md files, final audit report.
**Addresses:** 30-gate validation framework, cross-platform verification.
**Avoids:** P8 (evidence fragility -- use automated capture pipeline built in Phase 1).
**Estimated effort:** 2-3 days.

### Phase Ordering Rationale

- **Rename first (Phase 1)** because it touches shared types -- doing it later causes merge conflicts with every other phase
- **Config before hooks (Phase 2 before 3)** because hooks CRUD uses the same `saveWithPatch` config write pattern
- **GitHub browse is the most complex new feature (Phase 4)** and benefits from a stable foundation
- **macOS parity last before validation (Phase 6)** because it mirrors iOS and should capture the final feature state
- **API audit after all endpoint changes (Phase 7)** to avoid auditing endpoints that will change
- **Validation last (Phase 8)** because all code must be complete before evidence capture

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (GitHub Browse & Install):** Complex integration with external API rate limits, content validation, fork detection. Needs `/gsd:research-phase` to verify GitHub API behavior for specific query patterns and install flows.
- **Phase 6 (macOS Feature Parity):** Share Extension and AppleScript/Automator support (MAC-05, MAC-06) are new target types not previously built in this project. Needs research on Xcode target configuration and `.sdef` scripting definition files.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Rename + Validation Infra):** Well-documented patterns -- route aliasing in Vapor, type renaming with typealiases, `xcrun simctl` automation.
- **Phase 2 (Config Inheritance):** The `ConfigOverride` DTO already models the cascade. Backend endpoint is straightforward Vapor routing. UI is standard SwiftUI Form with badges.
- **Phase 3 (Hooks Enhancement):** Extends existing `HooksManagementView` using established `saveWithPatch` pattern. Model updates are additive.
- **Phase 5 (Nav/Layout Polish):** Standard SwiftUI view composition. No new patterns.
- **Phase 7 (API Audit):** Verification-only, no new code.
- **Phase 8 (Validation):** Established pattern from v3.5 and v4.0 milestones.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Grounded in codebase analysis of all 241 Swift files. Zero new dependencies needed. All Apple APIs verified against deployment targets (iOS 17+, macOS 14+). |
| Features | HIGH | Official Claude Code docs (hooks reference, settings reference, plugin marketplaces, skills) plus direct codebase analysis of existing models and DTOs. ConfigOverride DTO confirms backend was designed for cascade. |
| Architecture | HIGH | Every integration point mapped against existing source code. Patterns (configure(client:), saveWithPatch, APIResponse wrapping) verified in 18+ ViewModels. |
| Pitfalls | HIGH | Derived from 240+ file code inspection, 8 milestones of project history, verified simulator behavior, and official GitHub API rate limit documentation. Real-world failure modes from prior milestones (v3.5, v4.0) inform evidence capture pitfalls. |

**Overall confidence:** HIGH

### Gaps to Address

- **Config merge algorithm parity:** The backend merge endpoint must match Claude Code's actual scope precedence (managed > local > project > user). Validate against `claude config show` CLI output during Phase 2 implementation.
- **HookDefinition `enabled` field:** Claude Code's hook schema does not natively support an `enabled` boolean. Adding it to ILSShared is backward-compatible (optional field defaults to true), but the field is app-level convention, not CLI-recognized. Decide during Phase 3 planning whether to implement toggle-as-remove or add the field.
- **GitHub Code Search API stability:** GitHub has changed this API before (March 2023). The v5.0 implementation should pin to `Accept: application/vnd.github.v3+json` and be prepared for API changes.
- **macOS Share Extension and AppleScript:** These are new Xcode target types not previously built in this project. Build feasibility and scope should be validated early in Phase 6 planning -- they may be better deferred to v6.0 if they require significant Xcode project restructuring.
- **Complexity budget for differentiators:** Table stakes alone is ~2 weeks. Hooks CRUD + marketplace browsing add another ~2 weeks. The roadmapper should flag differentiators as stretch goals with explicit cut criteria.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- All 241 Swift files across iOS (149), macOS (14), backend (52), shared (26) examined
- `Sources/ILSShared/DTOs/ResponseDTOs.swift` -- ConfigOverride with winningScope, userValue, projectValue, localValue
- `Sources/ILSShared/Models/ClaudeConfig.swift` -- HooksConfig with 5/16 event types, PascalCase CodingKeys
- `Sources/ILSBackend/Controllers/ConfigController.swift` -- GET/PUT/validate routes, scope parameter support
- `Sources/ILSBackend/Controllers/FleetController.swift` -- routes at `/fleet/*`, route registration
- `ILSApp/ILSMacApp/Commands/ILSCommands.swift` -- existing keyboard shortcuts Cmd+N, Cmd+1-4, Cmd+,
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- 16 event types, matcher patterns, hook handler types
- [Claude Code Settings Reference](https://code.claude.com/docs/en/settings) -- scope precedence, merge behavior
- [GitHub REST API Rate Limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- [Apple NSUserActivity Documentation](https://developer.apple.com/documentation/foundation/nsuseractivity)
- [Apple SwiftUI Keyboard Shortcuts](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:))

### Secondary (MEDIUM confidence)
- [OctoKit.swift](https://github.com/nerdishbynature/octokit.swift) -- evaluated v0.11+, missing contents/tree/topic-search endpoints
- [SwiftUI Handoff tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-continue-an-nsuseractivity-in-swiftui)
- [NavigationSplitView programmatic navigation issues](https://www.hackingwithswift.com/forums/swiftui/navigationlink-on-detail-navigationsplitview-breaks-navigation-stack-hierarchy/23770)
- [DispatchSource file monitoring limitations](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift)

### Tertiary (LOW confidence)
- macOS Share Extension and AppleScript/Automator feasibility -- not yet prototyped, scope TBD during Phase 6 planning

---
*Research completed: 2026-02-27*
*Ready for roadmap: yes*
