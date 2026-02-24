# Architecture Research

**Domain:** iOS/macOS native client for Claude Code — v3.1 feature integration
**Researched:** 2026-02-24
**Confidence:** HIGH (based on direct codebase inspection, not inference)

---

## Existing Architecture Map

Confirmed by reading source files directly:

```
ILSAppApp.swift
  ├── AppState (@Observable @MainActor)
  │     ├── APIClient (actor) — HTTP, auto-prefixes /api/v1, NSCache
  │     ├── ConnectionManager (@Observable @MainActor)
  │     └── NavigationIntent (drives SidebarRootView routing)
  │
  ├── ThemeManager (@Observable)
  │
  └── SidebarRootView (root SwiftUI view)
        ├── ActiveScreen enum (home/chat/system/settings/browser/
        │                      teams/hostProfiles/themes/hooks)
        ├── SessionsViewModel (@State)
        ├── HomeView
        ├── ChatView
        ├── BrowserView → SkillsViewModel, PluginsViewModel, MCPViewModel
        ├── SettingsView → SettingsViewModel (@State)
        ├── HostProfilesView → HostProfilesViewModel (@State)
        └── [system/teams/themes/hooks screens]

Vapor Backend (:9999, /api/v1 prefix):
  ConfigController   → FileSystemService → ~/.claude/settings.json
  FleetController    → FleetHostModel (Fluent/SQLite)
  SkillsController   → FileSystemService + GitHubService
  PluginsController  → FileSystemService + git clone subprocess
  [10 other controllers]

ILSShared (Swift package, used by both iOS app and backend):
  ClaudeConfig       — full config model, already has all fields needed
  ConfigInfo         — scope + path + content + isValid
  ConfigProfiles     — user/project/local triple (ALREADY EXISTS in ResponseDTOs.swift)
  ConfigOverride     — per-key winning scope (ALREADY EXISTS in ResponseDTOs.swift)
  FleetHost          — host model with health status
  Skill, Plugin, MCPServer, etc.
```

---

## New vs Modified Components

### New Components (must be created from scratch)

| Component | Type | File Path |
|-----------|------|-----------|
| `SettingsDefaultsSection` | SwiftUI View | `ILSApp/ILSApp/Views/Settings/SettingsDefaultsSection.swift` |
| `ConfigOverrideRow` | SwiftUI View | `ILSApp/ILSApp/Views/Settings/ConfigOverrideRow.swift` |
| `GitHubBrowseView` | SwiftUI View | `ILSApp/ILSApp/Views/Browser/GitHubBrowseView.swift` |
| `GitHubResultRow` | SwiftUI View | `ILSApp/ILSApp/Views/Browser/GitHubResultRow.swift` |
| `InstallProgressView` | SwiftUI View (sheet) | `ILSApp/ILSApp/Views/Browser/InstallProgressView.swift` |
| `EffectiveConfigResponse` | Shared DTO | `Sources/ILSShared/DTOs/ResponseDTOs.swift` (additive) |
| `GET /config/defaults` handler | Backend | `Sources/ILSBackend/Controllers/ConfigController.swift` (additive) |
| `GET /fleet/:id/config` handler | Backend | `Sources/ILSBackend/Controllers/FleetController.swift` (additive) |

### Modified Components (targeted additions to existing files)

| Component | File | What Changes |
|-----------|------|--------------|
| `SettingsViewModel` | `ViewModels/SettingsViewModel.swift` | Add `loadEffectiveDefaults()`, `effectiveConfig` property |
| `HostProfilesViewModel` | `ViewModels/HostProfilesViewModel.swift` | Add `fetchConfigForHost(id:)`, `configSnapshot` |
| `SkillsViewModel` | `ViewModels/SkillsViewModel.swift` | Add `searchGitHub(query:)`, `installFromGitHub(repo:)`, `installedNames` |
| `PluginsViewModel` | `ViewModels/PluginsViewModel.swift` | Add `install(name:marketplace:)`, `uninstall(name:)` calls (endpoints exist) |
| `SidebarRootView` | `Views/Root/SidebarRootView.swift` | Fix hamburger accessibility from all screens |
| `SidebarView` | `Views/Sidebar/SidebarView.swift` | Add active host name indicator |
| `SettingsView` | `Views/Settings/SettingsView.swift` | Add `SettingsDefaultsSection` into scroll view |
| `HostProfilesView` | `Views/Fleet/HostProfilesView.swift` | Add "Sync Config" action, active profile indicator |
| `HostProfileDetailView` | `Views/Fleet/HostProfileDetailView.swift` | Show config snapshot section |
| `SkillsView` | `Views/Browser/` (skills tab) | Status badges (installed/not-installed), GitHub browse button |
| `PluginsView` | `Views/Browser/` (plugins tab) | Install/enable/disable action buttons, status badges |
| `ConfigController` | `Sources/ILSBackend/Controllers/ConfigController.swift` | Add `defaults()` handler route |
| `FleetController` | `Sources/ILSBackend/Controllers/FleetController.swift` | Add `remoteConfig()` handler route |

---

## Data Flows

### Feature 1: Host CLI Config Sync

Shows the user their host's effective Claude Code defaults, with per-key scope attribution.

```
SettingsView.task
    → SettingsViewModel.loadEffectiveDefaults()
    → APIClient.get("/config/defaults")                    ← NEW endpoint
    → ConfigController.defaults()                          ← NEW handler
        FileSystemService.readConfig("local")
        FileSystemService.readConfig("project")
        FileSystemService.readConfig("user")
        mergeConfigs() → [ConfigOverride]
    → EffectiveConfigResponse                              ← NEW DTO
    → SettingsViewModel.effectiveConfig: EffectiveConfigResponse

SettingsView body
    → SettingsDefaultsSection(overrides: effectiveConfig.overrides)
        → ConfigOverrideRow for each key
            shows: key name + winning value + scope badge
            ("model: claude-opus-4-6 · from user config")
```

**What's new at each layer:**

Backend: one new route `config.get("defaults", use: defaults)`. Handler reads all three scopes via existing `FileSystemService.readConfig()`, merges with `local > project > user` precedence, builds `[ConfigOverride]` array. Uses `ConfigProfiles` and `ConfigOverride` that already exist in `ILSShared/DTOs/ResponseDTOs.swift`.

ILSShared: new `EffectiveConfigResponse` struct wrapping `ConfigProfiles` + `[ConfigOverride]`. Additive to `ResponseDTOs.swift`.

iOS: `SettingsViewModel` gets `effectiveConfig: EffectiveConfigResponse?` property and `loadEffectiveDefaults()` async method called from `loadAll()`. New `SettingsDefaultsSection` view inserted into `SettingsView` body. New `ConfigOverrideRow` component shows per-key scope badges.

### Feature 2: GitHub Skill Browse + Install

```
BrowserView (Skills segment)
    → "Browse GitHub" button → GitHubBrowseView (sheet or push)
        SkillsViewModel.searchGitHub(query: String) async
        → APIClient.get("/skills/search?q={query}")        ← endpoint EXISTS
        → SkillsController.search()                        ← EXISTS, uses GitHubService
        → [GitHubSearchResult]
        GitHubBrowseView renders GitHubResultRow cards
        User taps "Install" → InstallProgressView sheet
            SkillsViewModel.installFromGitHub(repo: String) async
            → APIClient.post("/skills/install", body: SkillInstallRequest)  ← EXISTS
            → SkillsController.install()                   ← EXISTS
            → fileSystem.invalidateSkillsCache()           ← EXISTS
        On success:
            SkillsViewModel.loadSkills()                   ← refresh list
            Skill list shows "Installed" badge on newly installed entry
```

**What's new at each layer:**

Backend: nothing. `GET /skills/search` and `POST /skills/install` are fully implemented in `SkillsController.swift`.

ILSShared: nothing. `GitHubSearchResult` and `SkillInstallRequest` already exist in `SearchResult.swift`.

iOS: new `GitHubBrowseView`, `GitHubResultRow`, `InstallProgressView` views. New `searchGitHub()` and `installFromGitHub()` methods on `SkillsViewModel`. `SkillsViewModel` needs a computed `installedSkillNames: Set<String>` from the existing `skills` array so `SkillsView` rows can show badges.

### Feature 3: GitHub Plugin Browse + Install

```
BrowserView (Plugins segment)
    PluginsViewModel.loadMarketplace() async
    → APIClient.get("/plugins/marketplace")                ← EXISTS
    → [PluginMarketplace] (official + custom)
    Plugins list shows install/enable/disable buttons per row

"Install" tapped → InstallProgressView (same component as skills)
    PluginsViewModel.install(name: String, marketplace: String) async
    → APIClient.post("/plugins/install", body: InstallPluginRequest)  ← EXISTS
    → git clone in backend (~5–30s) → returns Plugin
    Plugin row updates to show "Installed" + "Enabled" badges

"Enable"/"Disable" tapped
    PluginsViewModel.enable(name: String) / disable(name: String) async
    → APIClient.post("/plugins/{name}/enable")             ← EXISTS
    → APIClient.post("/plugins/{name}/disable")            ← EXISTS
    → Plugin.isEnabled updated in-place in ViewModel

"Uninstall" tapped (context menu)
    PluginsViewModel.uninstall(name: String) async
    → APIClient.delete("/plugins/{name}")                  ← EXISTS
    → Plugin removed from ViewModel.plugins array
```

**What's new at each layer:**

Backend: nothing. All endpoints exist in `PluginsController.swift`.

ILSShared: nothing.

iOS: `PluginsViewModel` gets `install()`, `uninstall()`, `enable()`, `disable()` async methods wrapping existing API calls (these methods are missing from the ViewModel — the endpoints are there but the VM doesn't call them). `PluginsView` rows get status badges and action buttons. `InstallProgressView` is reused from skills feature.

### Feature 4: Host Profiles Redesign

```
HostProfilesView (existing)
    Already shows: host list, health badges, active capsule badge, context menu
    New: "Sync Config" action in context menu
        HostProfilesViewModel.fetchConfigForHost(id: UUID) async
        → APIClient.get("/fleet/{id}/config")              ← NEW endpoint
        → FleetController.remoteConfig()                   ← NEW handler
            Looks up FleetHostModel by ID
            HTTP GET to http://{host}:{backendPort}/api/v1/config?scope=user
            (same pattern as existing health() handler)
        → configSnapshot: ConfigInfo stored on HostProfilesViewModel

HostProfileDetailView (existing)
    New section: "Configuration" showing configSnapshot values
    If not yet fetched: "Fetch Config" button

SidebarView header/footer
    Active host name shown when activeHostId != nil
    → HostProfilesViewModel.activeHost: FleetHost? (computed property)
    → SidebarView reads from shared or newly loaded HostProfilesViewModel
```

**What's new at each layer:**

Backend: one new route `fleet.get(":id", "config", use: remoteConfig)`. Handler follows the same pattern as `FleetController.health()` — loads the host model, makes HTTP GET to the remote host's backend, returns proxied response. Falls back to error if unreachable.

ILSShared: nothing. `ConfigInfo` already exists and is the return type.

iOS: `HostProfilesViewModel` gets `configSnapshot: [UUID: ConfigInfo]` dictionary and `fetchConfigForHost(id:)` method. `HostProfileDetailView` expanded with a config preview section. `HostProfilesView` context menu gets "Fetch Config" action. `SidebarView` reads `activeHostId` from `HostProfilesViewModel` to show active host name in header.

**Note on SidebarView access to HostProfilesViewModel:** `HostProfilesViewModel` is currently `@State` inside `HostProfilesView`. For the sidebar to read the active host name, two options: (a) lift `activeHostId` into `AppState` when activation is called, or (b) give `SidebarView` its own lightweight `HostProfilesViewModel` reference. Option (a) is simpler — `AppState.activeHostName: String?` set by `HostProfilesViewModel.activate()`.

### Feature 5: Navigation / UX Overhaul

```
Current problem:
    Hamburger button is in each child view's toolbar independently.
    Some screens don't have it at all.

Fix in SidebarRootView.mainContent():
    The NavigationStack is the container. The hamburger goes on the
    NavigationStack's own toolbar, not inside child view bodies.
    This ensures it appears consistently on EVERY screen.

Current code (simplified):
    NavigationStack {
        Group { switch activeScreen { ... } }
        .toolbar {
            if showHamburger {
                ToolbarItem(.topBarLeading) { hamburgerButton }
            }
        }
    }

The .toolbar modifier is already at the NavigationStack level in
SidebarRootView.mainContent() — the fix is ensuring child views
do NOT also add conflicting .topBarLeading items that override it.
Audit each child view's .toolbar for conflicts.

Session back button:
    ChatView uses NavigationLink push — verify .navigationBarBackButtonHidden(false)
    is not set. No code change expected — just a verification.

Home screen layout:
    HomeView.swift changes only — layout/spacing within existing view.
```

**What's new:** Primarily audit and remove conflicting toolbar items from child views. The navigation architecture (`SidebarRootView`, `ActiveScreen` enum) is not changed.

---

## Component Boundaries

### Strict Rules to Maintain

| Rule | Rationale |
|------|-----------|
| iOS never reads `~/.claude/settings.json` directly | Sandbox + backend is the config broker |
| GitHub API calls go through backend `/skills/search` | `GitHubService` in backend handles rate limits |
| All new ViewModels follow `@Observable @MainActor class` pattern | Existing codebase convention |
| No new `ActiveScreen` cases for GitHub browse | GitHub browse is a sub-flow within Browser, not a peer screen |
| `EffectiveConfigResponse` goes in `ILSShared` | Both backend (produces it) and iOS (consumes it) need the type |
| `APIClient` adds `/api/v1` prefix automatically | Never double-prefix paths |

### Component Communication

| From | To | Via |
|------|----|-----|
| `SettingsView` | `ConfigController.defaults()` | `APIClient.get("/config/defaults")` |
| `SkillsViewModel` | `SkillsController.search()` | `APIClient.get("/skills/search?q=")` |
| `SkillsViewModel` | `SkillsController.install()` | `APIClient.post("/skills/install")` |
| `PluginsViewModel` | `PluginsController.install()` | `APIClient.post("/plugins/install")` |
| `PluginsViewModel` | `PluginsController.enable/disable()` | `APIClient.post("/plugins/{name}/enable|disable")` |
| `HostProfilesViewModel` | `FleetController.remoteConfig()` | `APIClient.get("/fleet/{id}/config")` |
| `HostProfilesViewModel` | `AppState.activeHostName` | Direct property set on activation |
| `SidebarView` | `AppState.activeHostName` | `@Environment(AppState.self)` |

---

## Suggested Build Order

Dependencies between the four features:

```
Navigation/UX Overhaul        ← no dependencies, unblocks comfortable dev of other screens
GitHub Browse + Install        ← no backend changes needed
Host CLI Config Sync           ← needs EffectiveConfigResponse DTO + GET /config/defaults
Host Profiles Redesign         ← needs GET /fleet/:id/config; benefits from config sync patterns
```

### Step 1: Navigation / UX Overhaul (fastest, no backend)

**Why first:** Every other feature requires navigating to its screen during development. Fixing the hamburger accessibility and home screen layout removes friction for all subsequent work. Zero backend risk.

**Files touched:** `SidebarRootView.swift`, `HomeView.swift`, child view toolbar audits.

### Step 2: GitHub Browse + Install — Skills first, then Plugins

**Why second:** Backend endpoints are complete. Pure iOS UI work — fastest path to demonstrable new functionality. Skills install is simpler (file write) vs plugins (git clone with longer latency), so tackle skills first to validate the `InstallProgressView` component before reusing it for plugins.

**Files touched:** New `GitHubBrowseView`, `GitHubResultRow`, `InstallProgressView`. Modified `SkillsViewModel`, `PluginsViewModel`, `SkillsView`, `PluginsView`.

### Step 3: Host CLI Config Sync

**Why third:** Requires the one meaningful ILSShared DTO addition (`EffectiveConfigResponse`) and one new backend handler (`GET /config/defaults`). The DTO change rebuilds both backend and iOS — do it in one commit. The backend handler is straightforward (3x `FileSystemService.readConfig()` calls + merge logic). iOS side is new `SettingsDefaultsSection` + `ConfigOverrideRow`.

**Sequence within this step:**
1. Add `EffectiveConfigResponse` to `ILSShared/DTOs/ResponseDTOs.swift`
2. Add `defaults()` handler + route to `ConfigController.swift`
3. Add `loadEffectiveDefaults()` to `SettingsViewModel`
4. Add `SettingsDefaultsSection` + `ConfigOverrideRow` views
5. Wire into `SettingsView`

### Step 4: Host Profiles Redesign

**Why last:** Requires `GET /fleet/:id/config` (second new backend endpoint) and the active host indicator in the sidebar (which touches `AppState`). Benefits from having config display patterns established in step 3. The `HostProfileDetailView` config section reuses `ConfigOverrideRow` from step 3.

**Sequence within this step:**
1. Add `activeHostName: String?` to `AppState`
2. Set it in `HostProfilesViewModel.activate()`
3. Add `remoteConfig()` handler + route to `FleetController.swift`
4. Add `fetchConfigForHost()` + `configSnapshot` to `HostProfilesViewModel`
5. Update `HostProfileDetailView` with config section
6. Update `HostProfilesView` context menu with "Fetch Config" action
7. Update `SidebarView` to show active host name

---

## Scaling Considerations

This is a local-first iOS app connecting to a personal backend. Scaling is not a concern. Relevant practical limits:

| Concern | Approach |
|---------|----------|
| GitHub API rate limits on skill search | Backend `GitHubService` already proxies all calls; add response caching in `GitHubService` if rate limits hit during development |
| `POST /plugins/install` latency (git clone) | Can take 5–30s. iOS must show a spinner + allow cancellation. `InstallProgressView` sheet handles this. Do not set a short URLSession timeout on the iOS side for this call |
| `/config/defaults` reads filesystem 3x | Acceptable for a settings screen load — not a hot path. If latency is noticeable, combine into a single `readAllConfigs()` in `FileSystemService` |
| Config cache in `APIClient` | `/config` path has 60s TTL. After `PUT /config`, call `APIClient.get("/config/defaults", bypassCache: true)` to get fresh effective defaults |

---

## Anti-Patterns

### Anti-Pattern 1: New ActiveScreen cases for sub-flows

**What people do:** Add `.githubSkills` or `.githubPlugins` to the `ActiveScreen` enum to navigate to GitHub browse.

**Why it's wrong:** GitHub browse is a sub-flow within the existing Browser screen, not a peer navigation destination. Adding top-level cases grows the sidebar nav model unnecessarily and breaks the existing URL scheme deep-link handling.

**Do this instead:** Show `GitHubBrowseView` as a `.sheet` from `SkillsView`/`PluginsView`, or as a `NavigationLink` push within the Browser `NavigationStack`.

### Anti-Pattern 2: URLSession GitHub calls directly from iOS ViewModels

**What people do:** Add `URLSession` calls to `api.github.com` directly in `SkillsViewModel`.

**Why it's wrong:** Duplicates the existing `GitHubService` on the backend, splits rate-limit quota, adds GitHub token management to the iOS layer.

**Do this instead:** Call existing `GET /skills/search?q=`. The backend handles GitHub entirely.

### Anti-Pattern 3: Singleton ViewModel for shared GitHub state

**What people do:** Create a `GitHubViewModel` singleton shared between Skills and Plugins browse.

**Why it's wrong:** Established pattern is per-screen `@State` ViewModels. Singletons carry stale state across view lifecycles.

**Do this instead:** `SkillsViewModel` owns its own `githubResults: [GitHubSearchResult]` and `isGitHubLoading: Bool`. Same for `PluginsViewModel`. Separate state, same backing API.

### Anti-Pattern 4: Reading config via direct file path from iOS

**What people do:** Use `FileManager` to read `~/.claude/settings.json` from the iOS app by guessing a path via SSH or hardcoded path assumption.

**Why it's wrong:** iOS sandbox prevents this. The Vapor backend is the config broker — it runs on macOS with full filesystem access.

**Do this instead:** All config access via `APIClient.get("/config")` and `APIClient.put("/config")`.

### Anti-Pattern 5: Blocking the NIO event loop in new backend handlers

**What people do:** Add synchronous network calls (e.g., `URLSession.shared.data(from:)`) inside new Vapor handlers without async/await.

**Why it's wrong:** Blocks NIO event loop threads, starving other requests.

**Do this instead:** Follow the existing pattern in `FleetController.health()` — use `async/await` with `URLSession` (which is async-compatible in Swift 5.10+) or run blocking work in a detached `Task`.

---

## Sources

All findings based on direct file inspection:

- `Sources/ILSBackend/Controllers/ConfigController.swift` — existing config routes and `FileSystemService` usage
- `Sources/ILSBackend/Controllers/FleetController.swift` — health check HTTP proxy pattern (the model for remote config fetch)
- `Sources/ILSBackend/Controllers/SkillsController.swift` — GitHub search and install endpoints (confirmed complete)
- `Sources/ILSBackend/Controllers/PluginsController.swift` — install/enable/disable/uninstall endpoints (confirmed complete)
- `Sources/ILSShared/Models/ClaudeConfig.swift` — full field inventory
- `Sources/ILSShared/DTOs/ResponseDTOs.swift` — `ConfigProfiles` and `ConfigOverride` already present (lines 227–272)
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — `ActiveScreen` enum, hamburger pattern, screen routing
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift` — section composition pattern
- `ILSApp/ILSApp/Views/Fleet/HostProfilesView.swift` — existing host profile UI
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` — existing config load/save pattern
- `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` — fleet CRUD + health polling
- `ILSApp/ILSApp/Services/APIClient.swift` — caching, path prefixing, per-endpoint TTLs
- `.planning/PROJECT.md` — v3.1 scope and constraints

Confidence: HIGH — all integration points verified against actual source, not inferred.

---
*Architecture research for: ILS iOS/macOS v3.1 feature integration*
*Researched: 2026-02-24*
