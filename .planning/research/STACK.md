# Technology Stack

**Project:** ILS iOS/macOS v5.0 -- Cross-Platform Feature Completion & 30-Gate Audit
**Researched:** 2026-02-27
**Overall confidence:** HIGH (grounded in codebase analysis + Apple framework docs + verified library research)

---

## Scope: What This File Covers

Stack additions and changes needed ONLY for v5.0 new features:

1. **Config inheritance visualization** -- showing CLI -> backend -> mobile settings chain
2. **GitHub API integration** -- browsing/installing skills and plugins from GitHub repos
3. **Hooks management UI** -- CRUD for Claude Code hooks (currently read-only)
4. **macOS feature parity** -- Handoff, drag-and-drop, additional keyboard shortcuts, menu bar items
5. **"Fleet" -> "Host Profiles" rename** -- API endpoint and model name migration
6. **node_modules filtering** -- already exists in backend, needs UI-level awareness
7. **30-gate validation framework** -- screenshot-based evidence collection

---

## What Already Exists -- Do NOT Re-Add

| Capability | Current State | Location |
|------------|---------------|----------|
| SwiftUI + @Observable | iOS 17+/macOS 14+ | All ViewModels |
| Vapor 4 backend + Fluent/SQLite | Port 9999, /api/v1 prefix | Sources/ILSBackend/ |
| APIClient (actor, caching, retry) | GET/POST/PUT/DELETE with dedup | Services/APIClient.swift |
| SSEClient for streaming | ChatView real-time | Services/SSEClient.swift |
| ConfigScope enum (user/project/local) | Already in ILSShared | Models/MCPServer.swift |
| ClaudeConfig + HooksConfig models | Full Codable structs | Models/ClaudeConfig.swift |
| ConfigController (GET/PUT/validate) | Backend routes /config | Controllers/ConfigController.swift |
| HooksManagementView (read-only) | Displays hooks from config | Views/Hooks/HooksManagementView.swift |
| HooksViewModel (read-only) | Flattens hook groups for display | ViewModels/HooksViewModel.swift |
| ConfigEditorViewModel | Raw JSON editor for configs | ViewModels/ConfigEditorViewModel.swift |
| HostProfilesViewModel | Fleet CRUD with health polling | ViewModels/HostProfilesViewModel.swift |
| FleetHost model (+ HostProfile alias) | Full Codable struct | Models/FleetHost.swift |
| macOS WindowManager | Multi-window, frame persistence | Managers/WindowManager.swift |
| macOS ILSCommands | Keyboard shortcuts via .keyboardShortcut | Commands/ILSCommands.swift |
| macOS AppDelegate | Menu bar (File/Edit/View/Window) | AppDelegate.swift |
| node_modules filtering | excludedDirectories set | Services/SkillsFileService.swift |
| MarkdownUI, HighlightSwift, Citadel, GRDB | Already in project.yml | SPM dependencies |
| Yams, Splash | Already in Package.swift | SPM dependencies |
| StoreKit 2 / FeatureGate | Premium subscriptions | Services/FeatureGate.swift |
| xcrun simctl + idb | Screenshot/deep link/tap automation | Verified on machine |

---

## Recommended Stack Additions

### Feature 1: Config Inheritance Visualization

**New libraries needed: NONE**

Use existing `ConfigController` GET endpoint with scope parameter. The backend already supports `?scope=user`, `?scope=project`, and `?scope=local`. The mobile app already has `ConfigEditorViewModel` and `SettingsViewModel` that load config by scope.

| Component | What to Build | Technology | Why |
|-----------|---------------|------------|-----|
| ConfigInheritanceViewModel | Load all 3 scopes, compute effective values | Swift @Observable | Extends existing pattern; no new deps |
| ConfigInheritanceView | Tree/table showing key -> value -> winning scope | SwiftUI List + DisclosureGroup | Native SwiftUI; matches existing UI patterns |
| ConfigDiffHelper | Compare configs across scopes, flag overrides | Foundation (Codable reflection) | Pure Swift struct comparison |

**API integration point:** Call `GET /config?scope=user`, `GET /config?scope=project`, `GET /config?scope=local` in parallel using existing `APIClient.get()`. The `ConfigInfo` response already includes `scope`, `path`, `content`, and `isValid` -- everything needed for inheritance display.

**Backend change needed:** Add `GET /config/effective` endpoint that returns the merged config with winning-scope annotations per key. This avoids client-side merge logic. The `ConfigValidationResult` DTO in `ResponseDTOs.swift` already has a `winningScope: ConfigScope` field, confirming the backend was designed for this.

**Confidence:** HIGH -- all models and endpoints already exist; this is UI composition work.

---

### Feature 2: GitHub API Integration (Browse/Install Skills & Plugins)

**New libraries needed: NONE -- use URLSession directly**

| Decision | Choice | Why |
|----------|--------|-----|
| HTTP client | URLSession (existing APIClient pattern) | Project already uses URLSession exclusively; adding Alamofire or OctoKit.swift would introduce a second HTTP stack for marginal benefit |
| GitHub API version | REST API v3 | Stable, well-documented, sufficient for repo browsing |
| Authentication | Optional GitHub PAT via Settings | Unauthenticated: 60 req/hr. Authenticated: 5,000 req/hr. Search API: 10/min unauth, 30/min auth |

**Why NOT OctoKit.swift:** OctoKit.swift (nerdishbynature/octokit.swift, v0.11+) covers Users, Repos, Stars, Issues -- but NOT the endpoints we need most (repository contents tree, file download, search with topic filters). We need exactly 4 GitHub API endpoints, all trivially callable via URLSession:

| Endpoint | Purpose | Rate Limit (unauth) |
|----------|---------|---------------------|
| `GET /search/repositories?q=topic:claude-code-skill` | Browse available skill repos | 10/min |
| `GET /repos/{owner}/{repo}/contents/{path}` | List files in a skill/plugin repo | 60/hr |
| `GET /repos/{owner}/{repo}/readme` | Show repo README for preview | 60/hr |
| Raw content URL (`raw.githubusercontent.com`) | Download skill .md files | No API limit |

**Implementation approach:**

| Component | What to Build | Location |
|-----------|---------------|----------|
| GitHubAPIClient | Actor wrapping URLSession for GitHub REST v3 | New: Services/GitHubAPIClient.swift |
| GitHubRepository model | Codable struct for search results | New: in ILSShared or local Models/ |
| GitHubBrowseViewModel | Search, list, preview GitHub repos | New: ViewModels/GitHubBrowseViewModel.swift |
| GitHubBrowseView | Search bar + repo list + detail sheet | New: Views/Browser/GitHubBrowseView.swift |
| SkillInstaller service | Download .md files, write to skills directory | New: Services/SkillInstaller.swift |

**Caching strategy:** Cache search results and repo contents in NSCache (same pattern as APIClient) with 5-minute TTL for search results, 30-minute TTL for repo contents.

**Rate limit handling:** Track `X-RateLimit-Remaining` header from GitHub responses. Show warning badge in UI when < 10 remaining. Disable search when exhausted. Display reset time from `X-RateLimit-Reset`.

**Token storage:** Store optional GitHub PAT in Keychain using existing `KeychainService` (already used for API key in APIClient). Surface in Settings under a "GitHub" section.

**Confidence:** HIGH -- URLSession is proven in this codebase; GitHub REST API v3 is stable and well-documented.

---

### Feature 3: Hooks Management UI (CRUD)

**New libraries needed: NONE**

The current `HooksManagementView` is read-only (displays hooks from config). CRUD requires:

| Component | What to Build | Technology |
|-----------|---------------|------------|
| HookEditorView | Form for creating/editing a hook | SwiftUI Form + TextField + Picker |
| HookEditorViewModel | Validate + serialize hook changes | @Observable, existing ClaudeConfig models |
| Updated HooksManagementView | Add swipe-to-delete, add button, edit tap | SwiftUI .swipeActions + NavigationLink |

**Backend integration:** Hooks are stored in `~/.claude/settings.json` (user scope) or `.claude/settings.json` (project scope). The existing `PUT /config` endpoint already writes full config. The CRUD flow is:

1. `GET /config?scope=user` -- load current config
2. Modify the `hooks` property of the `ClaudeConfig` struct in memory
3. `POST /config/validate` -- validate before saving
4. `PUT /config` -- write back the full config with updated hooks

No new backend endpoints needed. The `ClaudeConfig`, `HooksConfig`, `HookGroup`, and `HookDefinition` structs in ILSShared are already fully `Codable` with `var` properties (mutable).

**Form fields for HookEditorView:**

| Field | Type | Validation |
|-------|------|------------|
| Event Type | Picker (5 options) | Required |
| Matcher (regex) | TextField | Optional; validate regex syntax |
| Hook Type | Picker ("command") | Required; currently only "command" |
| Command | TextField (multiline) | Required; non-empty |

**Confidence:** HIGH -- all models exist and are mutable; backend already supports full config write-back.

---

### Feature 4: macOS Feature Parity

**New libraries needed: NONE for core parity. One OPTIONAL addition.**

All macOS parity features use built-in Apple frameworks:

#### 4a. Handoff (NSUserActivity)

| Technology | API | Min OS | Status |
|------------|-----|--------|--------|
| NSUserActivity | Foundation | macOS 10.10+ / iOS 8+ | Built-in |
| `.userActivity()` modifier | SwiftUI | iOS 14+ / macOS 11+ | Built-in |
| `.onContinueUserActivity()` modifier | SwiftUI | iOS 14+ / macOS 11+ | Built-in |

**Implementation:** Register `NSUserActivity` with type `com.ils.app.viewing-session` when user views a session. Include `sessionId` in `userInfo`. On the other device, `.onContinueUserActivity` picks it up and navigates to the same session via deep link routing (already exists in `AppState.handleURL`).

**Requirements:**
- Same Team ID signing (already: `HC36V7B67Z` on both targets)
- Add `NSUserActivityTypes` to both Info.plist files
- iCloud entitlement (already present in entitlements files)

#### 4b. Keyboard Shortcuts (additional)

| Technology | API | Status |
|------------|-----|--------|
| `.keyboardShortcut()` modifier | SwiftUI | Already used in ILSCommands.swift |
| `Commands` protocol | SwiftUI | Already used in ILSCommands.swift |

**What exists:** Navigate (Cmd+1-6), New Session (Cmd+N), Session actions (Cmd+Shift+R/F/E), Expand/Collapse (Cmd+Opt+E).

**What to add:** Search (Cmd+K for command palette), Quick Switch (Cmd+Shift+O for session picker), Refresh (Cmd+R), Toggle Inspector (Cmd+Opt+I). All via existing `ILSCommands` + `NotificationCenter` pattern.

**No third-party library needed.** The existing `.keyboardShortcut()` SwiftUI modifier handles all in-app shortcuts. The `sindresorhus/KeyboardShortcuts` package (v2.4.0) is only needed for *global* hotkeys (app in background) -- which is out of scope for v5.0.

#### 4c. Drag and Drop

| Technology | API | Min OS |
|------------|-----|--------|
| `.draggable()` / `.dropDestination()` | SwiftUI (Transferable) | iOS 16+ / macOS 13+ |
| `UTType` | UniformTypeIdentifiers | iOS 14+ / macOS 11+ |

**Use cases:**
- Drag session from sidebar to open in new window (macOS)
- Drop .md skill files onto Browser view to install
- Drag hook definitions to reorder

**Implementation:** Make `ChatSession` conform to `Transferable` (it already conforms to `Codable` + `Identifiable`). Use `.draggable(session)` on session rows and `.dropDestination(for: ChatSession.self)` on window targets.

**Import needed:** `import UniformTypeIdentifiers` -- already a system framework, no SPM addition.

#### 4d. Menu Bar Enhancements

Already have full menu bar via `AppDelegate.setupMenuBar()` and `ILSCommands`. Additional items (Hooks, Host Profiles) are just new `CommandMenu` entries or `Button` items in existing menus. Pure SwiftUI.

#### 4e. Missing macOS Views

| iOS View | macOS Equivalent | Status |
|----------|-----------------|--------|
| HooksManagementView | Need MacHooksView or shared | Missing |
| HostProfilesView | Need MacHostProfilesView or shared | Missing |
| ThemeEditorView | Need MacThemeEditorView or shared | Missing |
| BrowserView tabs | Need Mac browser with sidebar | Missing |
| SystemMonitorView | Need MacSystemView or shared | Missing |

**Approach:** The macOS target already includes iOS source files (see `project.yml` -- ILSMacApp target sources include `ILSApp/` directory with exclusions). Most views use `#if os(iOS)` / `#if os(macOS)` for platform differences. New views should follow this pattern rather than creating separate Mac-only views where possible.

**Confidence:** HIGH -- all APIs are built-in Apple frameworks already available at the project's deployment targets.

---

### Feature 5: "Fleet" -> "Host Profiles" Rename

**New libraries needed: NONE**

This is a pure refactor -- rename across 6 files. The `HostProfile` typealias already exists in `FleetHost.swift`:

```swift
public typealias HostProfile = FleetHost
```

**Files to update:**

| File | Change |
|------|--------|
| `FleetHost.swift` | Rename struct (keep typealias for backward compat) |
| `FleetDTOs.swift` | Rename DTOs |
| `FleetController.swift` | Rename controller, keep `/fleet` routes as aliases |
| `HostProfilesViewModel.swift` | Already uses "HostProfiles" naming |
| `Views/Fleet/HostProfilesView.swift` | Already uses "Host Profiles" naming |
| `Views/Fleet/HostProfileDetailView.swift` | Already uses correct naming |

**API migration strategy:** Add new `/host-profiles` routes alongside existing `/fleet` routes in the backend. Deprecate `/fleet` after one release cycle. Frontend switches to new endpoints immediately.

**Confidence:** HIGH -- typealias already exists; most UI code already uses the new name.

---

### Feature 6: node_modules Filtering

**New libraries needed: NONE**

Backend `SkillsFileService.swift` already has the exclusion set:

```swift
private static let excludedDirectories: Set<String> = [
    "node_modules", ".git", "__pycache__", ".venv", "venv",
    ".build", "build", "dist", ".cache", ".npm", ".yarn",
    "vendor", "Pods", ".swiftpm", "examples", "tests", "test"
]
```

**What might be missing:** Verify that `SessionFileService`, `FileSystemService`, and `ProjectsController` also skip these directories when scanning. The `SystemMetricsService` file scanning (`contentsOfDirectory`) should also apply the filter. This is a backend audit task, not a new library.

**Confidence:** HIGH -- the filter exists; needs coverage audit across all file-scanning services.

---

### Feature 7: 30-Gate Validation Framework

**New libraries needed: NONE**

Same tooling as v3.5 validation (documented in prior STACK.md):

| Tool | Purpose | Status |
|------|---------|--------|
| `xcrun simctl io screenshot` | Screenshot capture | Verified on machine |
| `xcrun simctl openurl` | Deep link navigation | Verified on machine |
| `xcrun simctl status_bar override` | Clean status bar for evidence | Verified on machine |
| `idb describe operation:all` | Accessibility tree for coordinates | Verified on machine |

**Evidence structure for 30-gate:**

```
evidence/phase-{NN}-{name}/
  screenshots/
    {gate-id}-{description}.png
  VERDICT.md
```

The `evidence/` directory already exists at project root with `AUDIT-STATE.md`. Gate verdicts VG-01 and VG-02 already PASS from prior session.

**Confidence:** HIGH -- all tooling verified; pattern established in v3.5 and v4.0.

---

## Full Stack Summary (v5.0)

### No New SPM Packages

Zero new Swift Package Manager dependencies are needed for v5.0. Every feature is implementable with:

- **Foundation** (URLSession, JSONEncoder/Decoder, NSUserActivity, FileManager)
- **SwiftUI** (.keyboardShortcut, .draggable/.dropDestination, .userActivity, DisclosureGroup, Form)
- **UniformTypeIdentifiers** (UTType for drag-and-drop, already a system framework)
- **AppKit** (NSMenu, NSWindow -- already imported in macOS target)

### New Swift Files to Create

| File | Feature | Purpose |
|------|---------|---------|
| `Services/GitHubAPIClient.swift` | GitHub browse | Actor wrapping URLSession for GitHub REST v3 |
| `Models/GitHubModels.swift` | GitHub browse | Codable structs for search/contents responses |
| `ViewModels/GitHubBrowseViewModel.swift` | GitHub browse | Search, list, preview state |
| `Views/Browser/GitHubBrowseView.swift` | GitHub browse | Search + repo list + install UI |
| `Services/SkillInstaller.swift` | GitHub install | Download and write skill files |
| `Views/Hooks/HookEditorView.swift` | Hooks CRUD | Create/edit hook form |
| `ViewModels/ConfigInheritanceViewModel.swift` | Config viz | Multi-scope config loading + diff |
| `Views/Settings/ConfigInheritanceView.swift` | Config viz | Inheritance tree visualization |

### Existing Files to Modify

| File | Change | Feature |
|------|--------|---------|
| `HooksManagementView.swift` | Add create/edit/delete UI | Hooks CRUD |
| `HooksViewModel.swift` | Add save/delete methods | Hooks CRUD |
| `ILSCommands.swift` | Add Cmd+K, Cmd+Shift+O shortcuts | macOS parity |
| `AppDelegate.swift` | Add Host Profiles, Hooks menu items | macOS parity |
| `ILSMacApp.swift` | Add .userActivity() modifier | Handoff |
| `ILSAppApp.swift` | Add .userActivity() + .onContinueUserActivity() | Handoff |
| `Info.plist` (both) | Add NSUserActivityTypes | Handoff |
| `FleetController.swift` | Add `/host-profiles` route aliases | Rename |
| `SettingsView.swift` | Add GitHub token section, config inheritance link | Settings |
| `BrowserView.swift` | Add GitHub tab | GitHub browse |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| OctoKit.swift | Only covers Users/Repos/Stars/Issues, NOT contents/tree/search-by-topic; adds dependency for 4 endpoints | Direct URLSession with Codable models |
| Alamofire | Project uses URLSession exclusively; second HTTP stack adds complexity | Existing URLSession pattern in APIClient |
| sindresorhus/KeyboardShortcuts | Only needed for global hotkeys (app in background); all v5.0 shortcuts are in-app | SwiftUI `.keyboardShortcut()` modifier |
| SwiftUI Charts | No charting features in v5.0 scope | N/A |
| Any testing framework | Project mandate: no mocks, no stubs, no test files | Functional validation with simctl |
| Firebase / Analytics SDK | Not in scope | N/A |
| Combine | Project uses async/await throughout; Combine would be a regression | Swift Concurrency (async/await, Task, actor) |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| GitHub API | Direct URLSession | OctoKit.swift v0.11 | Missing key endpoints (contents/tree, topic search); adds 500+ stars but thin coverage of what we need |
| GitHub API | Direct URLSession | swift-openapi-generator | Massive code generation overhead for 4 endpoints; overkill |
| Config inheritance | Multi-scope GET + client merge | New backend endpoint | Could go either way; `ConfigValidationResult.winningScope` suggests backend was designed for this |
| Hooks CRUD | Modify full config via PUT /config | New PATCH /config/hooks endpoint | PUT full config is simpler and already works; PATCH adds backend complexity |
| macOS shortcuts | SwiftUI .keyboardShortcut() | sindresorhus/KeyboardShortcuts v2.4.0 | Only needed for global hotkeys; all v5.0 shortcuts work when app is focused |
| Drag-and-drop | SwiftUI .draggable/.dropDestination | NSItemProvider (legacy API) | Modern Transferable API is cleaner and type-safe; available at our deployment target |
| Fleet rename | Dual routes + typealias | Hard rename | Typealias preserves backward compatibility during migration |

---

## Installation

No new packages to install. Zero changes to `Package.swift` or `project.yml` dependencies.

```bash
# Existing build commands remain unchanged
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet

PORT=9999 swift run ILSBackend
```

---

## Sources

- **Codebase analysis** (HIGH confidence):
  - `ILSApp/project.yml` -- existing SPM dependencies, target structure, deployment targets
  - `Package.swift` -- backend dependencies (Vapor 4.89+, Fluent 4.9+, Yams 5.0+, Splash 0.16+)
  - `Sources/ILSShared/Models/ClaudeConfig.swift` -- ClaudeConfig, HooksConfig, HookGroup, HookDefinition, ConfigInfo, ConfigScope
  - `Sources/ILSShared/Models/FleetHost.swift` -- FleetHost struct, HostProfile typealias
  - `Sources/ILSShared/DTOs/ResponseDTOs.swift` -- ConfigValidationResult.winningScope
  - `Sources/ILSBackend/Controllers/ConfigController.swift` -- GET/PUT/validate routes
  - `Sources/ILSBackend/Services/SkillsFileService.swift` -- excludedDirectories set with node_modules
  - `ILSApp/ILSApp/Services/APIClient.swift` -- actor-based HTTP client with caching
  - `ILSApp/ILSApp/ViewModels/HooksViewModel.swift` -- read-only hook display
  - `ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift` -- read-only hooks UI
  - `ILSApp/ILSMacApp/Commands/ILSCommands.swift` -- existing keyboard shortcuts
  - `ILSApp/ILSMacApp/AppDelegate.swift` -- existing menu bar setup
  - `ILSApp/ILSMacApp/ILSMacApp.swift` -- .handlesExternalEvents already used
  - `ILSApp/ILSMacApp/Managers/WindowManager.swift` -- multi-window management

- **Apple documentation** (HIGH confidence):
  - [NSUserActivity | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsuseractivity)
  - [Continuing User Activities with Handoff](https://developer.apple.com/documentation/Foundation/continuing-user-activities-with-handoff)
  - [keyboardShortcut(_:modifiers:) | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:))
  - [Adopting drag and drop using SwiftUI | Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Adopting-drag-and-drop-using-SwiftUI)

- **GitHub API documentation** (HIGH confidence):
  - [REST API endpoints for repository contents](https://docs.github.com/en/rest/repos/contents)
  - [Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
  - [Updated rate limits for unauthenticated requests (2025-05)](https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/)

- **Library evaluation** (MEDIUM confidence):
  - [OctoKit.swift](https://github.com/nerdishbynature/octokit.swift) -- evaluated v0.11+, 519 stars, covers Users/Repos/Stars/Issues but not contents/tree/topic-search
  - [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) -- evaluated v2.4.0, macOS only, global hotkeys; not needed for in-app shortcuts
  - [SwiftUI keyboard shortcuts tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-keyboard-shortcuts-using-keyboardshortcut)
  - [SwiftUI drag and drop tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-support-drag-and-drop-in-swiftui)

---

*Stack research for: ILS iOS/macOS v5.0 -- Cross-Platform Feature Completion & 30-Gate Audit*
*Researched: 2026-02-27*
