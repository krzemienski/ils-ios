# Architecture Patterns

**Domain:** Cross-platform feature completion for native Swift iOS/macOS Claude Code client
**Researched:** 2026-02-27
**Confidence:** HIGH (codebase fully analyzed, all integration points mapped, patterns verified against existing code)

## Current Architecture Summary

The ILS app follows a well-established architecture after 8 milestones of hardening:

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                       │
│                                                                 │
│  iOS: SidebarRootView (ActiveScreen enum routing)               │
│       NavigationStack + sheet-based sidebar (iPhone)             │
│       NavigationSplitView (iPad)                                │
│                                                                 │
│  macOS: MacContentView (NavigationSplitView 3-column)           │
│         SidebarSection enum mirrors ActiveScreen                │
│                                                                 │
│  Shared Views: HomeView, ChatView, BrowserView, SettingsView,   │
│                SystemMonitorView, HooksManagementView,          │
│                HostProfilesView, ThemePickerView,                │
│                AgentTeamsListView                                │
├─────────────────────────────────────────────────────────────────┤
│                        VIEWMODEL LAYER                          │
│                                                                 │
│  @Observable @MainActor classes                                 │
│  configure(client:) pattern for deferred APIClient injection    │
│  18 ViewModels: Dashboard, Sessions, Chat, Config, Hooks,       │
│                 Settings, Skills, Plugins, MCP, Projects,       │
│                 HostProfiles, Themes, Teams, System, SSH,        │
│                 NewSession, QuickConnect, Setup                  │
├─────────────────────────────────────────────────────────────────┤
│                        SERVICE LAYER                            │
│                                                                 │
│  APIClient (actor): REST with cache, retry, auth, coalescing    │
│  SSEClient: Server-sent events for chat streaming               │
│  CacheService: NSCache with per-endpoint TTL                    │
│  ConnectionManager: URL, health polling, reconnect              │
│  MetricsWebSocketClient: Real-time system metrics               │
│  SyncCoordinator: Offline queue + replay                        │
│  FeatureGate + SubscriptionManager: Premium features            │
├─────────────────────────────────────────────────────────────────┤
│                        SHARED LAYER (ILSShared)                 │
│                                                                 │
│  Models: Session, Project, Skill, Plugin, MCPServer,            │
│          FleetHost (aliased as HostProfile), ClaudeConfig,      │
│          Message, CustomTheme, StreamMessage                    │
│  DTOs: FleetDTOs, SystemDTOs, TeamDTOs, TunnelDTOs,            │
│        ResponseDTOs, Requests, DashboardStats,                  │
│        ConfigOverride, UpdateConfigRequest                      │
│  Enums: ConfigScope (user/project/local)                        │
├─────────────────────────────────────────────────────────────────┤
│                        BACKEND (Vapor 4)                        │
│                                                                 │
│  15 Controllers: Sessions, Projects, Chat, Skills, MCP,         │
│                  Plugins, Config, Stats, Themes, System,         │
│                  Teams, Tunnel, Fleet, Health, DataErasure       │
│  Services: FileSystemService, SkillsFileService,                │
│            ClaudeExecutorService                                │
│  Database: SQLite via Fluent ORM, 8 migrations                  │
│  Middleware: CORS, APIKey, RateLimit, RequestLogging,           │
│             ILSError, Admin, BodySize                           │
└─────────────────────────────────────────────────────────────────┘
```

## v5.0 Feature Integration Map

### Stream 1: Navigation & Layout

**What changes:** Refinements to existing navigation, not structural changes.

| Component | Type | Change Description |
|-----------|------|-------------------|
| `SidebarRootView.swift` | MODIFY | Add quick actions row in homeScreen builder, ensure data consistency for recent sessions |
| `HomeView.swift` | MODIFY | Home sidebar content improvements, quick actions, recent sessions widget consistency |
| `SidebarView.swift` | MODIFY | Session detail navigation improvements from sidebar |
| `MacContentView.swift` | MODIFY (mirror) | Mirror all iOS sidebar/home changes |
| `SessionsViewModel.swift` | MODIFY | Ensure filtered/recent session data consistency |

**Integration Points:**
- ActiveScreen enum: No changes needed (all screens already routed)
- NavigationIntent: No changes needed (deep links already cover all routes)
- browserSegment forwarding: Already working

**Dependencies:** None. This stream can start immediately.

### Stream 2: Settings & Config Inheritance

**What changes:** The most architecturally significant stream. Introduces config cascade visualization and inherited-vs-custom distinction in the settings UI.

| Component | Type | Change Description |
|-----------|------|-------------------|
| `ConfigController.swift` (backend) | MODIFY | Add `GET /config/cascade` endpoint that returns all 3 scopes merged with per-key provenance |
| `FileSystemService.swift` (backend) | MODIFY | Add `readAllScopes()` method returning user + project + local configs |
| `ConfigOverride` (ILSShared) | EXISTS | Already has `winningScope`, `userValue`, `projectValue`, `localValue` fields |
| `ConfigInfo` (ILSShared) | EXISTS | Already has `scope` and `path` fields |
| `SettingsViewModel.swift` | MODIFY | Add `loadCascade()` to fetch merged config, add `overrides: [ConfigOverride]` property |
| `SettingsView.swift` | MODIFY | Add inheritance badges ("Host Default", "Project", "Custom") next to each setting |
| `ConfigEditorViewModel.swift` | MODIFY | Support scope-aware editing (user vs project vs local) |
| `MacSettingsView.swift` | MODIFY (mirror) | Mirror iOS settings changes |

**Data Flow:**
```
CLI writes ~/.claude/settings.json (user scope)
CLI writes .claude/settings.json (project scope)
CLI writes .claude/settings.local.json (local scope)
    │
    ▼
Backend FileSystemService reads all 3 files
    │
    ▼
GET /config/cascade returns:
  {
    mergedConfig: ClaudeConfig,        // final merged result
    overrides: [ConfigOverride],       // per-key provenance
    scopes: {
      user: ConfigInfo,
      project: ConfigInfo?,
      local: ConfigInfo?
    }
  }
    │
    ▼
SettingsViewModel stores merged + overrides
    │
    ▼
SettingsView renders each setting with:
  - Current value (from merged config)
  - Source badge (user/project/local/default)
  - Tooltip explaining inheritance
```

**Key Architectural Decision:** The existing `ConfigOverride` DTO in ILSShared already models per-key cascade provenance. The backend needs a new endpoint but the shared model layer is ready. The `saveWithPatch` pattern in SettingsViewModel already implements read-then-patch to preserve CLI-only fields -- this pattern extends naturally to scope-aware saves.

**New DTO needed:**
```swift
public struct ConfigCascadeResponse: Codable, Sendable {
    public let merged: ClaudeConfig
    public let overrides: [ConfigOverride]
    public let userConfig: ConfigInfo
    public let projectConfig: ConfigInfo?
    public let localConfig: ConfigInfo?
}
```

**Dependencies:** None for backend work. Settings UI depends on the cascade endpoint.

### Stream 3: Skills/Plugins/Hooks/Theming

**What changes:** Multiple sub-features that touch BrowserView, SkillsFileService, and HooksManagementView.

#### 3a: MCP Data Fixes

| Component | Type | Change Description |
|-----------|------|-------------------|
| `MCPViewModel.swift` | MODIFY | Verify MCP server data displays correctly (scope, tools, status) |
| `MCPController.swift` (backend) | VERIFY | Ensure scope field uses ConfigScope enum |

**Dependencies:** DATA-01 (ConfigScope) already completed in v4.0.

#### 3b: node_modules Filtering

| Component | Type | Change Description |
|-----------|------|-------------------|
| `SkillsFileService.swift` (backend) | ALREADY DONE | `excludedDirectories` already contains "node_modules" at line 143 |

**Status:** This is pre-satisfied. The `excludedDirectories` set already filters `node_modules`, `.git`, `__pycache__`, `.venv`, `venv`, `.build`, `build`, `dist`, `.cache`, `.npm`, `.yarn`, `vendor`, `Pods`, `.swiftpm`, `examples`, `tests`, `test`. Verify only.

#### 3c: GitHub Browse & Install

| Component | Type | Change Description |
|-----------|------|-------------------|
| `SkillsController.swift` (backend) | MODIFY | Add `GET /skills/github/search?q=` endpoint proxying GitHub API |
| `PluginsController.swift` (backend) | MODIFY | Add `GET /plugins/github/search?q=` endpoint proxying GitHub API |
| `SkillsController.swift` (backend) | MODIFY | Add `POST /skills/github/install` endpoint to clone/install from GitHub |
| `PluginsController.swift` (backend) | MODIFY | Add `POST /plugins/github/install` endpoint |
| `SkillsViewModel.swift` | MODIFY | Add `searchGitHub(query:)`, `installFromGitHub(url:)` methods |
| `PluginsViewModel.swift` | MODIFY | Add `searchGitHub(query:)`, `installFromGitHub(url:)` methods |
| `BrowserView.swift` | MODIFY | Add "Discover from GitHub" section in skills and plugins tabs |
| `GitHubSearchResult` (ILSShared) | NEW | DTO for GitHub search results (name, description, stars, url) |
| `GitHubInstallRequest` (ILSShared) | NEW | Request body for install-from-github |
| `GitHubRateLimitHandler` (backend) | NEW | Middleware/utility for rate limit tracking + retry-after headers |

**Data Flow:**
```
User types search query in BrowserView Skills/Plugins tab
    │
    ▼
SkillsViewModel.searchGitHub(query:) or PluginsViewModel
    │
    ▼
GET /api/v1/skills/github/search?q=query
    │
    ▼
Backend proxies to GitHub API (api.github.com/search/repositories)
Rate limit tracking via X-RateLimit-* headers
    │
    ▼
Returns [GitHubSearchResult] to iOS
    │
    ▼
BrowserView shows "Discovered from GitHub" section
Each result has Install button
    │
    ▼
POST /api/v1/skills/github/install { url: "...", name: "..." }
    │
    ▼
Backend clones repo, validates structure, copies to skills directory
    │
    ▼
Invalidates skills cache, returns updated skill list
```

**Key decision:** GitHub search is proxied through the backend (not called directly from iOS) because:
1. The backend is already authenticated and can manage rate limits server-side
2. GitHub API requires a token for higher rate limits; the backend can store this securely
3. Installation requires filesystem access which only the backend has

**Dependencies:** None. Independent of other streams.

#### 3d: Hooks Management Enhancement

| Component | Type | Change Description |
|-----------|------|-------------------|
| `HooksManagementView.swift` | MODIFY | Currently read-only display. Add enable/disable toggle per hook, add/remove hooks |
| `HooksViewModel.swift` | MODIFY | Add CRUD operations: `addHook()`, `removeHook()`, `toggleHook()` |
| `SettingsViewModel.swift` | REUSE | `saveWithPatch()` already preserves hooks -- used by HooksViewModel for writes |

**Key insight:** HooksManagementView currently reads hooks via `SettingsViewModel` loading `/config?scope=user`. It already displays all hook groups correctly. Enhancement is to make it editable, using the same `saveWithPatch` pattern that SettingsView uses for config writes. The hooks data structure (`HooksConfig` -> `[HookGroup]` -> `[HookDefinition]`) is already fully modeled in ILSShared.

**Dependencies:** None.

#### 3e: Themes Audit

| Component | Type | Change Description |
|-----------|------|-------------------|
| `ThemePickerView.swift` | VERIFY | Verify all 13 built-in themes render correctly |
| `ThemesViewModel.swift` | VERIFY | Verify custom theme CRUD works end-to-end |
| `ThemesListView.swift` (macOS) | VERIFY | Verify macOS theme picker matches iOS |

**Dependencies:** ECO-03 (MeshGradient) already completed in v4.0.

### Stream 4: System Monitor + Profiles

**What changes:** Rename "Fleet" to "Host Profiles" everywhere (code-level, not just UI), verify system monitor metrics.

| Component | Type | Change Description |
|-----------|------|-------------------|
| `FleetHost.swift` (ILSShared) | RENAME | Rename struct to `HostProfile`, remove typealias |
| `FleetDTOs.swift` (ILSShared) | RENAME | Rename to `HostProfileDTOs.swift`, rename types |
| `FleetController.swift` (backend) | RENAME | Rename to `HostProfileController.swift` |
| `FleetHostModel` (backend) | RENAME | Rename to `HostProfileModel` |
| `CreateFleetHosts` migration | KEEP | Migration name stays (Fluent tracks by name) |
| `HostProfilesViewModel.swift` | MODIFY | Remove Fleet references, use HostProfile directly |
| `HostProfilesView.swift` | VERIFY | Already uses "Host Profiles" in UI |
| `HostProfileDetailView.swift` | VERIFY | Already uses HostProfile typealias |
| `AppState.swift` | VERIFY | `activeHostName` already named correctly |
| `SidebarRootView.swift` | VERIFY | `.hostProfiles` case already exists |
| `configure.swift` (routes) | MODIFY | Route registration after controller rename |
| `SystemMetricsViewModel.swift` | VERIFY | Verify real-time metrics data flow |
| `MetricsWebSocketClient.swift` | VERIFY | Verify WebSocket connection and data parsing |

**Grep audit results from codebase:**
- `FleetHost` struct: ILSShared/Models/FleetHost.swift (with `HostProfile` typealias)
- `FleetDTOs`: ILSShared/DTOs/FleetDTOs.swift (with typealiases for `HostProfileListResponse`, etc.)
- `FleetController`: Sources/ILSBackend/Controllers/FleetController.swift
- `FleetHostModel`: Backend database model
- iOS files using "Fleet": 8 files total (SettingsView, SidebarRootView, HostProfiles*, AppState, plus localization)

**Rename Strategy:** The existing typealias pattern (`public typealias HostProfile = FleetHost`) was intentionally created as a migration path. v5.0 completes the migration:
1. Rename the underlying types (FleetHost -> HostProfile, FleetListResponse -> HostProfileListResponse)
2. Add reverse typealiases temporarily (`public typealias FleetHost = HostProfile`)
3. Update all call sites
4. Remove reverse typealiases in a follow-up

**Key constraint:** The database migration `CreateFleetHosts` must keep its name (Fluent tracks migrations by name). The table name in SQLite stays `fleet_hosts` -- only the Swift types change.

**Dependencies:** None.

### Stream 5: Backend API Audit

**What changes:** Verification and hardening of all 15 controllers.

| Component | Type | Change Description |
|-----------|------|-------------------|
| All 15 controllers | VERIFY | Endpoint structure matches spec, error codes are consistent |
| `configure.swift` | VERIFY | Route registration order, middleware chain |
| `ILSErrorMiddleware.swift` | VERIFY | Structured error response format |
| Response DTOs | VERIFY | JSON field names match camelCase convention |

**Dependencies:** Depends on Stream 4 (Fleet rename) completing first, so API audit covers the final endpoint names.

### macOS Feature Parity (MAC-01 through MAC-08)

**What changes:** Platform-specific macOS capabilities that don't exist on iOS.

| Component | Type | Change Description |
|-----------|------|-------------------|
| `MacContentView.swift` | MODIFY | Add drag-and-drop support (MAC-01), inspector panel (MAC-04) |
| `ILSCommands.swift` | MODIFY | Complete menu bar (File, Edit, View, Session menus) (MAC-03) |
| `MacChatView.swift` | MODIFY | Add drag-and-drop for files into chat (MAC-01) |
| `ILSMacApp.swift` | MODIFY | Add Handoff support via NSUserActivity (MAC-02) |
| `AppDelegate.swift` | MODIFY | Register NSUserActivity types for Handoff (MAC-02) |
| `SessionWindowView.swift` | MODIFY | Stage Manager window optimization (MAC-07) |
| `WindowManager.swift` | MODIFY | Window sizing for Stage Manager (MAC-07) |
| NEW: `ShareExtension/` target | NEW | macOS Share Extension for sharing text/URLs to ILS (MAC-06) |
| NEW: `AutomatorActions/` | NEW | AppleScript/Automator support (MAC-05) |

**macOS-specific patterns:**
- Drag-and-drop uses `.onDrop(of:)` modifier with `UTType` conformance
- Handoff requires `NSUserActivity` with `activityType` registered in Info.plist
- Share Extension is a separate Xcode target with its own `ShareViewController`
- AppleScript support requires an `.sdef` (scripting definition) file

**Dependencies:** Streams 1-4 should complete first so macOS parity mirrors the final iOS state.

### Platform Validation & Audit

| Component | Type | Change Description |
|-----------|------|-------------------|
| No new code | VALIDATION | Screenshot capture across iPhone, iPad, Mac |
| Evidence artifacts | NEW | 50+ screenshots across 3 platforms |

**Dependencies:** All implementation streams must complete before validation.

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| SidebarRootView / MacContentView | Top-level routing, sidebar, navigation | AppState, all screen views |
| AppState | Global state coordination, deep links | ConnectionManager, NavigationIntent |
| APIClient (actor) | HTTP REST, caching, auth, retry | Backend controllers via HTTP |
| SSEClient | Chat streaming via server-sent events | ChatController (backend) |
| ViewModels | Screen-specific state + business logic | APIClient, AppState |
| ILSShared | Type-safe models + DTOs | iOS app, macOS app, backend |
| Backend Controllers | Route handlers, DB queries | FileSystemService, Fluent ORM |
| FileSystemService | Config file I/O, skill scanning | Filesystem (~/.claude/) |
| SkillsFileService | Skill discovery + GitHub proxy | Filesystem + GitHub API |

## Data Flow Changes for v5.0

### Config Inheritance Flow (NEW)

```
~/.claude/settings.json ──────► FileSystemService.readConfig(.user)
.claude/settings.json ─────────► FileSystemService.readConfig(.project)
.claude/settings.local.json ───► FileSystemService.readConfig(.local)
                                       │
                                       ▼
                               ConfigController.cascade()
                               Merges: local > project > user
                               Tracks: per-key winning scope
                                       │
                                       ▼
                               ConfigCascadeResponse {
                                 merged: ClaudeConfig
                                 overrides: [ConfigOverride]
                                 userConfig, projectConfig, localConfig
                               }
                                       │
                                       ▼
                               SettingsViewModel.loadCascade()
                                       │
                                       ▼
                               SettingsView renders:
                                 [Model: claude-sonnet-4] [Host Default]
                                 [Thinking: ON]           [Project]
                                 [Co-author: OFF]         [Custom]
```

### GitHub Search + Install Flow (NEW)

```
BrowserView ──► SkillsViewModel.searchGitHub("query")
                        │
                        ▼
                GET /skills/github/search?q=query
                        │
                        ▼
                Backend → GitHub API (api.github.com)
                Rate limit tracking (X-RateLimit-Remaining)
                        │
                        ▼
                [GitHubSearchResult] → BrowserView "Discovered from GitHub"
                        │
                        ▼ (user taps Install)
                POST /skills/github/install { url, name }
                        │
                        ▼
                Backend: git clone → validate → install
                Invalidate /skills cache
                        │
                        ▼
                SkillsViewModel.loadSkills() → refreshed list
```

### Hooks CRUD Flow (ENHANCED)

```
Current (read-only):
  HooksManagementView → SettingsViewModel.loadConfig() → display hooks

v5.0 (read-write):
  HooksManagementView → HooksViewModel (dedicated)
    │
    ├── loadHooks() → GET /config?scope=user → flattenHooks()
    │
    ├── addHook(eventType, matcher, command)
    │   └── SettingsViewModel.saveWithPatch { config.hooks.preToolUse.append(...) }
    │
    ├── removeHook(id)
    │   └── SettingsViewModel.saveWithPatch { config.hooks.preToolUse.remove(at:) }
    │
    └── toggleHook(id, enabled)
        └── Not natively supported by HookDefinition schema
        └── Workaround: remove hook to "disable", re-add to "enable"
        └── OR: Add optional `enabled: Bool?` field to HookDefinition
```

**Key insight about hook toggling:** Claude Code's hook schema does not have an `enabled` field. Options:
1. **Add `enabled: Bool?` to HookDefinition** (cleanest, backward-compatible since optional)
2. **Comment-out pattern** (move hook to a `_disabled` key) -- fragile
3. **Remove/re-add** -- data loss risk

Recommendation: Option 1. Add `enabled` field to HookDefinition in ILSShared. The field is optional so existing configs without it default to `true` (enabled). The backend preserves it through the `saveWithPatch` read-then-write pattern.

## Patterns to Follow

### Pattern 1: ViewModel configure(client:) + .task {}

Every ViewModel follows the same lifecycle:

```swift
@Observable @MainActor
class FooViewModel {
    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
    }

    func loadData() async { /* use client */ }
}

// In View:
.task {
    viewModel.configure(client: appState.apiClient)
    await viewModel.loadData()
}
.onChange(of: appState.serverURL) { _, _ in
    viewModel.configure(client: appState.apiClient)
    Task { await viewModel.loadData() }
}
```

New ViewModels (if any) MUST follow this pattern. Do not inject APIClient via init -- the `configure(client:)` pattern handles server URL changes.

### Pattern 2: saveWithPatch for Config Writes

```swift
func saveWithPatch(applying delta: (inout ClaudeConfig) -> Void) async -> String? {
    // 1. Load fresh config from server
    // 2. Apply delta closure (mutates ONLY target field)
    // 3. PUT full config back (preserves CLI-only fields)
}
```

All config mutations MUST use this pattern. Direct PUT with partial config destroys CLI-only fields (hooks, env, permissions, etc.).

### Pattern 3: iOS/macOS View Sharing

Most views are shared between iOS and macOS via `#if os(iOS)` / `#if os(macOS)` guards. The macOS target includes all files from `ILSApp/ILSApp/` except for iOS-only files (Widgets, LiveActivity, Intents). When modifying shared views:

1. Build iOS first (auto-build hook handles this)
2. Build macOS immediately after: `xcodebuild -scheme ILSMacApp -destination 'platform=macOS' -quiet`
3. Platform-specific code goes in `#if os()` blocks, not separate files

### Pattern 4: Backend Response Wrapping

All backend endpoints return `APIResponse<T>`:

```swift
APIResponse(success: true, data: someData)
```

New endpoints MUST follow this pattern. The iOS APIClient's `get<T>` method expects to decode `APIResponse<T>`.

### Pattern 5: ILSShared DTOs with Preconditions

```swift
public struct NewDTO: Codable, Sendable {
    public let field: String

    public init(field: String) {
        precondition(!field.isEmpty, "field must not be empty")
        self.field = field
    }
}
```

All new ILSShared types MUST be `Codable, Sendable` and include precondition validation in initializers.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Direct Config PUT Without Read

**What:** Sending a partial ClaudeConfig via PUT /config
**Why bad:** Destroys CLI-only fields (hooks, env, permissions, statusLine, enabledPlugins)
**Instead:** Always use `saveWithPatch` which reads fresh config, applies delta, PUTs full config

### Anti-Pattern 2: Separate View Files for iOS vs macOS

**What:** Creating `FooView.swift` and `MacFooView.swift` for the same screen
**Why bad:** Doubles maintenance burden, features drift out of sync
**Instead:** Use `#if os(iOS)` guards within a single file. Exception: MacContentView is necessarily different (3-column NavigationSplitView vs iOS's sheet sidebar)

### Anti-Pattern 3: Fleet Terminology in New Code

**What:** Using `Fleet`, `FleetHost`, `FleetListResponse` in new code
**Why bad:** v5.0 is completing the rename to HostProfile
**Instead:** Use `HostProfile`, `HostProfileListResponse`, etc. Old typealiases exist for backward compat only

### Anti-Pattern 4: Double-Prefixing API Paths

**What:** `client.get("/api/v1/sessions")`
**Why bad:** APIClient already adds `/api/v1` prefix
**Instead:** `client.get("/sessions")`

### Anti-Pattern 5: Bypassing FeatureGate

**What:** `if isPremium { showFeature() }` directly in views
**Why bad:** Duplicates gate logic, misses paywall trigger
**Instead:** Use `FeatureGateView(feature: .chatExport) { ExportButton() }` or `FeatureGate.shared.isAvailable(.feature)` in ViewModels

### Anti-Pattern 6: Guessing Simulator Coordinates

**What:** Hardcoding tap coordinates from visual estimation
**Why bad:** Coordinates vary by device, OS version, dynamic type size
**Instead:** Use `idb_describe operation:all` to get accessibility tree with exact centerX/centerY

## New Components Inventory

### New Files (estimated)

| File | Target | Purpose |
|------|--------|---------|
| `Sources/ILSShared/DTOs/GitHubDTOs.swift` | ILSShared | GitHubSearchResult, GitHubInstallRequest, GitHubInstallResponse |
| `Sources/ILSShared/DTOs/ConfigCascadeDTOs.swift` | ILSShared | ConfigCascadeResponse |
| `Sources/ILSBackend/Services/GitHubService.swift` | Backend | GitHub API proxy with rate limit tracking |
| `ILSApp/ILSMacApp/Extensions/ShareExtension/` | macOS | Share Extension target (MAC-06) |
| `ILSApp/ILSMacApp/Scripting/ILS.sdef` | macOS | AppleScript definition (MAC-05) |

### Modified Files (by stream)

**Stream 1 (Nav/Layout):** ~5 files
- HomeView.swift, SidebarView.swift, SidebarRootView.swift, MacContentView.swift, SessionsViewModel.swift

**Stream 2 (Settings/Config):** ~8 files
- ConfigController.swift, FileSystemService.swift, SettingsViewModel.swift, SettingsView.swift, ConfigEditorViewModel.swift, MacSettingsView.swift, + 2 new DTOs

**Stream 3 (Skills/Plugins/Hooks):** ~10 files
- SkillsController.swift, PluginsController.swift, SkillsViewModel.swift, PluginsViewModel.swift, BrowserView.swift, HooksManagementView.swift, HooksViewModel.swift, + 2 new backend service + DTOs

**Stream 4 (Rename/Monitor):** ~12 files (rename touches many)
- FleetHost.swift, FleetDTOs.swift, FleetController.swift, FleetHostModel.swift, HostProfilesViewModel.swift, HostProfilesView.swift, HostProfileDetailView.swift, SettingsView.swift, configure.swift, routes.swift, Localizable.xcstrings

**Stream 5 (API Audit):** ~0-3 files (verification, fixes as found)

**macOS Parity:** ~10 files
- MacContentView.swift, MacChatView.swift, ILSCommands.swift, ILSMacApp.swift, AppDelegate.swift, SessionWindowView.swift, WindowManager.swift, + new Share Extension target, + new sdef

**Validation:** 0 new code files (evidence artifacts only)

## Suggested Build Order

```
Phase 1: Stream 4 (Fleet → HostProfile rename)
  └── Must happen first: touches shared types used everywhere
  └── All other streams build on the renamed types

Phase 2: Stream 2 (Config inheritance) + Stream 3b (node_modules verify)
  └── Config cascade endpoint + Settings UI
  └── node_modules is pre-satisfied, just verify

Phase 3: Stream 1 (Nav/Layout) + Stream 3a (MCP verify) + Stream 3d (Hooks CRUD)
  └── Independent features, can run in parallel
  └── Hooks CRUD builds on config write patterns from Phase 2

Phase 4: Stream 3c (GitHub browse/install)
  └── New backend endpoints + iOS UI
  └── Most complex new feature, benefits from stable foundation

Phase 5: Stream 5 (Backend API audit)
  └── Runs after all endpoint changes are complete

Phase 6: macOS Feature Parity (MAC-01 through MAC-08)
  └── Mirrors final iOS state
  └── Share Extension and AppleScript are independent substreams

Phase 7: Platform Validation (30-gate audit)
  └── All code complete, evidence capture only

Phase 8: Bug Hunt + Final Gate
  └── Edge cases, offline, accessibility, memory profiling
```

**Phase ordering rationale:**
1. Rename first because it touches shared types -- doing it later risks merge conflicts with every other stream
2. Config inheritance second because it establishes the cascade pattern that hooks management builds on
3. GitHub browse/install is the most complex new feature and benefits from a stable codebase
4. macOS parity last (before validation) because it mirrors iOS and should capture the final state
5. API audit after all endpoint changes to avoid auditing endpoints that will change

## Scalability Considerations

| Concern | Current State | v5.0 Impact |
|---------|--------------|-------------|
| File count | 149 iOS + 14 macOS + 52 backend + 26 shared = 241 | +5-10 new files, ~40 modified |
| ViewModel count | 18 | No new VMs needed (existing ones extended) |
| Backend controllers | 15 | 15 (Fleet renamed, no new controllers) |
| API endpoints | ~50 | +4 new (config/cascade, skills/github/search, skills/github/install, plugins equivalents) |
| Database migrations | 8 | 8 (no schema changes needed) |
| Build time impact | ~30s iOS, ~20s macOS | Minimal -- no new targets except Share Extension |

## Sources

- Codebase analysis: all 241 Swift files examined
- Existing patterns: verified against SidebarRootView, APIClient, SettingsViewModel, ConfigController
- ConfigOverride DTO: Sources/ILSShared/DTOs/ResponseDTOs.swift (already models cascade)
- Fleet rename state: 8 iOS files, 3 shared files, 2 backend files still use Fleet types
- node_modules filter: Sources/ILSBackend/Services/SkillsFileService.swift line 143 (pre-satisfied)
- v4.0 audit: 123 evidence artifacts, all 34 requirements PASS
- Confidence: HIGH -- all integration points verified against actual source code
