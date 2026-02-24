# Stack Research

**Domain:** iOS/macOS SwiftUI client — v3.1 new feature additions only
**Researched:** 2026-02-24
**Confidence:** HIGH (all findings grounded in current codebase + existing resolved packages)

---

## Scope: What This File Covers

This document covers ONLY the stack additions/changes required for v3.1 new features:

1. Host CLI config sync (reading `~/.claude/settings.json` from connected host)
2. GitHub skill/plugin browse + install
3. Host Profiles redesign (Fleet rename + multi-host switching UX)
4. Navigation/UX changes (side menu from all screens, session back button)

**Everything in this file describes net-new needs.** The existing stack (SwiftUI, Vapor 4, Fluent/SQLite, Citadel, Yams, Splash, MarkdownUI, SSEClient, APIClient actor) is already validated and requires no version changes or new packages for these features.

---

## What Already Exists — Do NOT Re-Add

| Capability | Already In Stack | Location |
|------------|-----------------|----------|
| SSH command execution | Citadel (iOS + macOS Xcode targets, `XCRemoteSwiftPackageReference`) | `ILSApp/ILSApp/Services/CitadelSSHService.swift` |
| Config file read/write | `ConfigFileService` + `ConfigController` | `Sources/ILSBackend/` — reads all three scopes (user/project/local) |
| `ClaudeConfig` model | `ILSShared/Models/ClaudeConfig.swift` | Covers model, permissions, hooks, env, plugins, theme, status line |
| GitHub Code Search | `GitHubService.swift` | Already searches `filename:SKILL.md`, fetches raw content, caches, handles rate limits |
| Fleet/Host model | `ILSShared/Models/FleetHost.swift` | `HostProfile` typealias already present; id, name, host, port, backendPort, isActive, healthStatus |
| Fleet CRUD backend | `FleetController.swift` | GET list, POST register, POST activate (atomic transaction), DELETE, GET health |
| Markdown rendering | `swift-markdown-ui` / `MarkdownUI` | Linked in Xcode project for both iOS and macOS targets |
| YAML parsing | Yams 5.4.0 (resolved) | Backend only, for skill file parsing |
| NavigationStack + sheet sidebar | SwiftUI native | `SidebarRootView.swift` — iPhone uses `.sheet` sidebar + `NavigationStack`; iPad uses `NavigationSplitView` |

---

## Recommended Stack Additions

**No new SPM packages or Xcode package references are required.** All four feature areas are implementable with what's already linked. Adding packages for this scope would increase build complexity and binary size without providing any capability the existing stack lacks.

### Capabilities to Enable From Existing Stack

| Existing Asset | Use For v3.1 | Integration Point |
|---------------|-------------|-------------------|
| `CitadelSSHService.executeCommand` | Read remote host's `~/.claude/settings.json` over SSH | `SettingsViewModel` calls new backend endpoint that proxies SSH read for active fleet host |
| `ConfigController GET /config?scope=user` | Local host config sync | Already works — backend reads from host filesystem. Expose merged defaults via new `/config/defaults` endpoint |
| `ConfigFileService` | Backend-side config merge (user + project scopes) | Add a `mergedDefaults()` method that overlays project scope on top of user scope |
| `GitHubService.searchSkills` | Extend to plugin search | Add `searchPlugins(query:)` method using `filename:PLUGIN.md` search query — identical pattern, different filename |
| `GitHubService.fetchRawContent` | Preview skill/plugin content before install | Already fetches raw GitHub file content; wire to a preview sheet in `BrowserView` |
| `FleetHost` / `HostProfile` typealias | Host Profiles redesign | Model is correct as-is; rename is cosmetic (view names, UI labels, route comments) |
| `FleetController POST /:id/activate` | Multi-host switching | Already deactivates all hosts then activates selected one in a DB transaction |
| `SidebarRootView` toolbar pattern | Side menu from all screens | Add `.toolbar` modifier with sidebar button to every top-level screen; `SidebarRootView` already owns the sidebar sheet state |
| `navigationPath` `@State<NavigationPath>` | Session back button | Already declared in `SidebarRootView`; push `ChatSession` onto path from any screen using existing `navigationDestination` |

---

## Feature-by-Feature Stack Analysis

### Feature 1: Host CLI Config Sync

**What's needed:** Surface the connected host's `~/.claude/settings.json` defaults in the iOS Settings screen, with visual indicators showing which values come from the host vs. are overridden locally.

**How the existing stack handles it:**

The `ConfigController` (`GET /api/v1/config?scope=user`) already reads `~/.claude/settings.json` from the machine running the Vapor backend. Since the backend runs on the host (not the iOS device), calling this endpoint from the iOS `APIClient` already returns the host's config. The `ClaudeConfig` Codable model in `ILSShared` already covers every relevant field (model, permissions, hooks, env, plugins, theme).

**What needs to be built (code, not new tech):**

1. `GET /api/v1/config/defaults` backend endpoint — returns a merged `ClaudeConfig` where project-scope settings overlay user-scope settings. This is a new route and a `mergedDefaults()` method on `ConfigFileService`, not a new library.

2. `HostConfigViewModel` in the iOS app — calls `/config/defaults`, stores the result, and compares against locally-stored user overrides. Pure `@Observable` Swift code.

3. UI overlay indicators in `SettingsView` — small "From host" badges on fields whose values come from the host config. Pure SwiftUI.

**For remote hosts (non-local fleet hosts):** Use `CitadelSSHService.executeCommand("cat ~/.claude/settings.json")` to read the file over SSH, then decode the JSON string as `ClaudeConfig`. This requires no new library — `CitadelSSHService` already supports arbitrary command execution and the `ClaudeConfig` Codable model handles deserialization.

**Confidence:** HIGH. The complete data path exists; the work is wiring, not technology.

---

### Feature 2: GitHub Skill/Plugin Browse + Install

**What's needed:** Browse GitHub for skills and plugins, preview content, install to the host's Claude Code directories.

**How the existing stack handles it:**

`GitHubService` already implements:
- GitHub Code Search API (`GET https://api.github.com/search/code?q=...+filename:SKILL.md`) via Vapor's `Client`
- Raw file fetch (`raw.githubusercontent.com`)
- Rate limit header monitoring (logs warning at <10 remaining requests)
- `GITHUB_TOKEN` env var support for 30 req/min (vs 10 unauthenticated)
- Result caching via `IndexingService` (keyed by query+page+perPage)

**What needs to be built (code, not new tech):**

1. `searchPlugins(query:page:perPage:)` on `GitHubService` — identical to `searchSkills` but with `filename:PLUGIN.md`. 10 lines of code.

2. Install endpoint: `POST /api/v1/github/install` — accepts `{type: "skill"|"plugin", owner, repo, path}`, fetches raw content via `fetchRawContent`, then writes the file to the appropriate host directory using `FileManager` (for local host) or `CitadelSSHService.executeCommand("mkdir -p ~/.claude/skills && cat > ...")` for remote hosts.

3. iOS `BrowserViewModel` extension — calls search and install endpoints, manages install state per item. Pure `@Observable` Swift.

4. UI: status badges (Installed, Available, Update available) in `BrowserView`. Pure SwiftUI.

**Rate limiting:** The existing `IndexingService` cache handles the 10/30 req/min constraint for search. Raw content fetches are not rate-limited by the Code Search quota — they go to `raw.githubusercontent.com` which is served by CDN.

**What NOT to add:** Do not add `octokit.swift` or any GitHub SDK. The existing bespoke `GitHubService` covers all needed endpoints with proper caching and rate limit handling. A full SDK adds 30+ source files for 3 API endpoints.

**Confidence:** HIGH. Search and content fetch already work; install is filesystem + optional SSH write.

---

### Feature 3: Host Profiles Redesign

**What's needed:** Rename "Fleet" to "Host Profiles" throughout the UI, add visible active-profile indicator, make host switching prominent.

**How the existing stack handles it:**

- `FleetHost.swift` already has `public typealias HostProfile = FleetHost` — the rename hook is in place.
- `isActive` field + `POST /fleet/:id/activate` already implement exclusive activation via atomic DB transaction.
- `FleetController.index` already sorts active host first in the response.
- `FleetListResponse` already includes `activeHostId`.

**What needs to be built (code, not new tech):**

1. New `GET /api/v1/fleet/active` convenience endpoint — returns just the active host without fetching the full list. Used by the home screen and sidebar to show the active profile indicator without over-fetching. 10 lines of controller code.

2. iOS `HostProfileSwitcherView` — a `.sheet` or toolbar popover listing profiles with a checkmark/indicator on the active one, and a tap-to-switch action. Uses existing `FleetViewModel` data and the existing activate endpoint.

3. Rename all UI labels from "Fleet" to "Host Profiles" — view names, navigation titles, sidebar item label. No model changes.

4. Active profile indicator in the sidebar — a small badge or subtitle showing the active host name. Pure SwiftUI addition to `SidebarView`.

**What NOT to add:** Do not create a new `HostProfile` Fluent model. The `FleetHostModel` is the right data store; adding a second model would require migrations and dual-write logic. The `HostProfile` typealias is the correct abstraction boundary.

**Confidence:** HIGH. No architectural gap — the work is UI and one convenience endpoint.

---

### Feature 4: Navigation/UX Overhaul

**What's needed:** Side menu accessible from all screens (not just home), reliable session back button, home screen layout improvements.

**How the existing stack handles it:**

`SidebarRootView` already implements the correct architecture:
- iPhone: `NavigationStack` with a `.sheet` sidebar triggered by a toolbar button. The sidebar sheet state (`isSidebarOpen`) is owned by `SidebarRootView`.
- iPad: `NavigationSplitView` with a persistent sidebar column and `NavigationSplitViewVisibility` state.
- `navigationPath: NavigationPath` `@State` is declared in `SidebarRootView` and passed down for push navigation.

**What needs to be built (code, not new tech):**

1. Sidebar toolbar button on every top-level screen — currently only some screens have it. Add a consistent `.toolbar { ToolbarItem(placement: .navigationBarLeading) { SidebarToggleButton() } }` to every screen's root view. Pure SwiftUI.

2. Session back button — push `ChatSession` onto `navigationPath` from the sessions list row tap (instead of using `.sheet` presentation). This changes chat presentation from modal to push-navigation, enabling the system back button. The `navigationDestination(for: ChatSession.self)` handler is the right pattern (SwiftUI iOS 16+, already available in iOS 17 target).

3. Home screen layout — purely compositional SwiftUI layout changes; no navigation architecture changes needed.

**Key constraint:** `SidebarRootView`'s `isSidebarOpen` sheet state must remain the single source of truth. Do not duplicate sidebar state in individual screen ViewModels — pass the binding down or use `@Environment`.

**What NOT to add:** Do not add a tab bar. The sidebar-first pattern is correct for 8+ top-level screens; a tab bar caps at 5 items and would require an information architecture redesign. Do not add a third-party navigation library (Coordinator pattern libraries, Router frameworks) — SwiftUI native `NavigationStack` + `navigationDestination` covers all needed push navigation.

**Confidence:** HIGH. The architecture already supports all required changes; the work is consistent application of the existing patterns.

---

## Installation

No new packages to install. No `swift package update` or Xcode package reference additions needed.

All v3.1 feature work is:
- New Swift source files (ViewModels, Services, View components)
- New backend controller methods/routes
- Model extensions in `ILSShared` (if any DTO additions are needed)

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Extend `GitHubService` with plugin search | Add `octokit.swift` (v0.15+) | 30+ source files for 3 API endpoints; existing service already handles rate limits and caching |
| `CitadelSSHService.executeCommand` for remote config reads | Separate HTTP endpoint on remote host | Requires remote backend to be running; SSH works regardless of remote backend state |
| `HostProfile` typealias (cosmetic rename only) | New `HostProfile` Fluent model replacing `FleetHostModel` | Would require DB migration, new backend routes, model mapping layer — all for a rename |
| `NavigationStack` push for chat sessions | Modal `.sheet` for all session navigation | Sheets block the back-navigation mental model; push navigation gives the system back button for free |
| Backend computes merged config (`/config/defaults`) | iOS client fetches all scopes and merges client-side | Server-side merge is testable, keeps business logic in one place, reduces iOS API calls from 3 to 1 |
| Single `SidebarToggleButton` component in toolbar | Per-screen sidebar open logic | Consistency requires one component definition, applied uniformly |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `octokit.swift` | Large dependency for 3 endpoints; `GitHubService` already does the work | Extend `GitHubService` with `searchPlugins` method |
| GitHub GraphQL API | More complex than REST for file search; requires separate parsing setup | GitHub REST Code Search v3 (already in use, stable) |
| SwiftData for Host Profiles | Codebase is on Fluent/SQLite; mixing ORMs creates dual migration paths | Continue with `FleetHostModel` (Fluent) |
| `AsyncHTTPClient` in iOS app | NIO-based, adds complexity; URLSession is correct for iOS networking | `APIClient` actor (already handles all backend calls via URLSession) |
| Third-party navigation/coordinator frameworks | `NavigationStack` + `navigationDestination` covers all needed patterns | SwiftUI native navigation (already in `SidebarRootView`) |
| Separate "profiles" REST resource on backend | Model already exists as `/fleet`; duplication creates sync bugs | Add `GET /fleet/active` convenience endpoint on existing route group |

---

## Version Compatibility

No version changes required. All existing packages are compatible with the v3.1 additions.

| Component | Resolved Version | v3.1 Impact |
|-----------|-----------------|-------------|
| Vapor | 4.121.1 | Adding controller methods only — no API changes |
| Fluent | 4.13.0 | No new migrations for Host Profiles rename |
| Yams | 5.4.0 | Available in backend if YAML skill/plugin parsing is needed |
| Citadel | Xcode-managed (no SPM pin) | No new Citadel APIs needed; `executeCommand` is already used |
| MarkdownUI | Xcode-managed | Skill/plugin preview content uses existing Markdown rendering |
| swift-markdown-ui | Xcode-managed | Same as above |

---

## Sources

- Codebase: `Sources/ILSBackend/Services/GitHubService.swift` — GitHub Code Search + raw fetch, rate limit handling, caching: HIGH confidence (direct inspection)
- Codebase: `Sources/ILSBackend/Services/ConfigFileService.swift` — three-scope config read/write: HIGH confidence
- Codebase: `Sources/ILSBackend/Controllers/ConfigController.swift` — existing GET/PUT/validate routes: HIGH confidence
- Codebase: `Sources/ILSBackend/Controllers/FleetController.swift` — CRUD + activate with atomic DB transaction: HIGH confidence
- Codebase: `Sources/ILSShared/Models/FleetHost.swift` — `HostProfile` typealias confirmed present: HIGH confidence
- Codebase: `Sources/ILSShared/Models/ClaudeConfig.swift` — full config model with all relevant fields: HIGH confidence
- Codebase: `ILSApp/ILSApp/Services/CitadelSSHService.swift` — `executeCommand` for SSH command execution: HIGH confidence
- Codebase: `ILSApp/ILSApp.xcodeproj/project.pbxproj` — Citadel, MarkdownUI linked to both iOS and macOS targets: HIGH confidence
- Codebase: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — NavigationStack + NavigationSplitView architecture: HIGH confidence
- Codebase: `Package.resolved` — full resolved dependency graph, no version gaps: HIGH confidence
- GitHub REST API (training knowledge): Code Search `GET /search/code`, `filename:` qualifier, rate limits (10 unauth / 30 with token per minute): MEDIUM confidence (stable API since 2013, unlikely to have changed)

---

*Stack research for: ILS iOS/macOS v3.1 — Host CLI config sync, GitHub browse/install, Host Profiles redesign, Navigation/UX overhaul*
*Researched: 2026-02-24*
