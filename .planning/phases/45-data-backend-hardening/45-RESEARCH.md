# Phase 45: Data & Backend Hardening - Research

**Researched:** 2026-02-27
**Domain:** Swift type safety, caching UX, offline indicators, input validation, draft persistence
**Confidence:** HIGH

## Summary

Phase 45 closes six DATA gaps identified in the v4.0 spec compliance audit. The work spans three layers: the shared model package (ILSShared), the iOS app's caching/UI layer, and the Vapor backend's DTO contracts.

The codebase is already well-structured for these changes. MCPServer already uses a typed `MCPScope` enum, but `ConfigInfo.scope`, `UpdateConfigRequest.scope`, `ConfigOverride.winningScope`, and the backend's `ConfigFileService.readConfig(scope:)` still pass raw `String` values -- DATA-01 requires making these type-safe too. DashboardStats already exists as `StatsResponse` in `ResponseDTOs.swift` with fully typed sub-structs -- DATA-02 needs renaming and relocating to a standalone file in ILSShared. A `CacheStatusView` component already exists and renders "Updated X ago" -- DATA-04 needs it wired into HomeView, BrowserView, and SessionsView (which currently have no `lastUpdated` tracking in their ViewModels). Chat draft persistence (DATA-05) requires adding `@SceneStorage` to the `inputText` field in ChatView keyed by session ID. Input validation (DATA-06) is partially complete -- `precondition` guards exist on most models but `Message`, `ConfigInfo`, `UpdateConfigRequest`, `ConfigOverride`, and several DTO structs lack them.

**Primary recommendation:** Work in two waves -- Wave 1 handles ILSShared type safety (DATA-01, DATA-02, DATA-06) as a backend+shared concern, Wave 2 handles iOS UI changes (DATA-03, DATA-04, DATA-05) which are independent of the backend.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DATA-01 | ConfigScope enum in ILSShared replacing string-based scope handling for MCP servers | MCPScope enum already exists. Need to extend its usage to ConfigInfo.scope, UpdateConfigRequest.scope, ConfigOverride.winningScope, and backend ConfigFileService/ConfigController. See "Architecture Patterns > Pattern 1". |
| DATA-02 | DashboardStats standalone DTO in ILSShared for type-safe stats responses | StatsResponse already exists in ResponseDTOs.swift with CountStat/SessionStat/MCPStat/PluginStat typed fields. Needs renaming to DashboardStats and moving to own file. See "Architecture Patterns > Pattern 2". |
| DATA-03 | Message caching depth verified in CacheService -- messages cached alongside sessions | CacheService already caches messages via cacheMessages/getCachedMessages using GRDB-backed LocalDatabase. Each CachedMessage has cachedAt timestamp. Verification needed that messages are actually cached when sessions load, not just when sent. See "Common Pitfalls > Pitfall 2". |
| DATA-04 | "Last updated X ago" indicator visible in offline-capable views (Home, Sessions, Browser) | CacheStatusView component exists and works. No ViewModel currently tracks lastUpdated timestamps. Need to add Date? properties to DashboardViewModel, SessionsViewModel, MCPViewModel, SkillsViewModel, PluginsViewModel, then wire CacheStatusView into HomeView, SidebarRootView sessions list, and BrowserView. See "Architecture Patterns > Pattern 3". |
| DATA-05 | Message draft queue depth verified in SyncCoordinator -- queued messages survive app restart | SyncCoordinator handles API retry queue (unrelated to drafts). Chat input is `@State private var inputText = ""` in ChatView -- lost on navigation/restart. Need `@SceneStorage("chatDraft_\(session.id)")` or UserDefaults persistence keyed by session ID. See "Architecture Patterns > Pattern 4". |
| DATA-06 | Input validation in model initializers across ILSShared models | precondition guards already exist on MCPServer, ChatSession, ExternalSession, Plugin, Skill, Project, FleetHost, ServerConnection, CustomTheme. Missing on: Message (no validation), ConfigInfo (scope is raw String), UpdateConfigRequest (scope is raw String), ConfigOverride (no validation), CountStat/SessionStat/MCPStat/PluginStat (no non-negative checks). See "Architecture Patterns > Pattern 5". |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 5.10+ | Language | Project standard |
| SwiftUI | iOS 17+ / macOS 14+ | UI framework | Project standard |
| GRDB | (existing) | SQLite cache via LocalDatabase | Already integrated, WAL mode enabled |
| Vapor 4 | (existing) | Backend framework | Already integrated |
| ILSShared | (local package) | Shared models/DTOs | Already the single source of truth for types |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @SceneStorage | SwiftUI built-in | Draft persistence across app lifecycle | DATA-05: chat message drafts |
| @Observable | Swift Observation | ViewModel state tracking | DATA-04: lastUpdated timestamp tracking |
| precondition | Swift stdlib | Input validation in initializers | DATA-06: model validation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @SceneStorage for drafts | UserDefaults keyed by session ID | @SceneStorage is simpler but only persists within scene lifecycle; UserDefaults persists across full app restarts including force-quit. **Recommendation: Use UserDefaults** since the requirement says "kill the app, relaunch, draft is restored" which implies force-quit survival. |
| precondition for validation | Throwing initializers | precondition crashes in debug but is stripped in release; throwing init requires callers to handle errors. **Recommendation: Keep precondition** -- it matches existing pattern used across 9 models already. For Codable models decoded from network, the decoder already validates via custom init(from:). |
| Renaming StatsResponse to DashboardStats | Keeping StatsResponse name | Requirement explicitly says "DashboardStats standalone DTO". **Recommendation: Rename** and add a typealias for backward compat if needed. |

## Architecture Patterns

### Recommended File Changes

```
Sources/ILSShared/
├── DTOs/
│   ├── DashboardStats.swift          # NEW: Moved from ResponseDTOs.swift, renamed
│   └── ResponseDTOs.swift            # MODIFIED: ConfigInfo.scope → ConfigScope, ConfigOverride.winningScope → ConfigScope
├── Models/
│   ├── MCPServer.swift               # NO CHANGE (MCPScope already here)
│   └── Message.swift                 # MODIFIED: Add precondition validation
│
Sources/ILSBackend/
├── Controllers/
│   ├── ConfigController.swift        # MODIFIED: Use ConfigScope enum instead of raw strings
│   └── StatsController.swift         # MODIFIED: Return DashboardStats (renamed)
├── Services/
│   └── ConfigFileService.swift       # MODIFIED: readConfig(scope: ConfigScope)
│
ILSApp/ILSApp/
├── ViewModels/
│   ├── DashboardViewModel.swift      # MODIFIED: Add lastUpdated: Date?
│   ├── SessionsViewModel.swift       # MODIFIED: Add lastUpdated: Date?
│   ├── MCPViewModel.swift            # MODIFIED: Add lastUpdated: Date?
│   ├── SkillsViewModel.swift         # MODIFIED: Add lastUpdated: Date?
│   └── PluginsViewModel.swift        # MODIFIED: Add lastUpdated: Date?
├── Views/
│   ├── Home/HomeView.swift           # MODIFIED: Wire CacheStatusView
│   ├── Browser/BrowserView.swift     # MODIFIED: Wire CacheStatusView per segment
│   ├── Root/SidebarRootView.swift    # MODIFIED: Wire CacheStatusView in sessions section
│   └── Chat/ChatView.swift           # MODIFIED: Persist inputText to UserDefaults
```

### Pattern 1: ConfigScope Enum Unification (DATA-01)

**What:** The `MCPScope` enum already exists in `MCPServer.swift` with cases `.user`, `.project`, `.local`. Rename it to `ConfigScope` (since it applies beyond just MCP) and use it everywhere scope strings currently appear.

**When to use:** Wherever `scope: String` currently passes "user"/"project"/"local".

**Approach:**
```swift
// In ILSShared/Models/MCPServer.swift -- rename MCPScope → ConfigScope
public enum ConfigScope: String, Codable, Sendable {
    case user
    case project
    case local
    // Keep existing custom init(from:) for safe decoding
}

// Backward compatibility
public typealias MCPScope = ConfigScope

// In ResponseDTOs.swift -- change ConfigInfo
public struct ConfigInfo: Codable, Hashable, Sendable {
    public let scope: ConfigScope  // Was: String
    // ...
}

// In ResponseDTOs.swift -- change UpdateConfigRequest
public struct UpdateConfigRequest: Codable, Sendable {
    public let scope: ConfigScope  // Was: String
    // ...
}

// In ResponseDTOs.swift -- change ConfigOverride
public struct ConfigOverride: Codable, Sendable {
    public let winningScope: ConfigScope  // Was: String
    // ...
}

// In ConfigFileService.swift -- change readConfig signature
func readConfig(scope: ConfigScope) throws -> ConfigInfo {
    let path: String
    switch scope {
    case .user: path = userSettingsPath
    case .project: path = ".claude/settings.json"
    case .local: path = ".claude/settings.local.json"
    }
    // ...
}

// In ConfigController.swift -- parse scope from query
let scopeString = req.query[String.self, at: "scope"] ?? "user"
guard let scope = ConfigScope(rawValue: scopeString) else {
    throw Abort(.badRequest, reason: "Invalid scope. Must be one of: user, project, local")
}
```

**Key concern:** The rename from `MCPScope` to `ConfigScope` touches many files. Use `typealias MCPScope = ConfigScope` for zero-breakage migration.

### Pattern 2: DashboardStats Standalone DTO (DATA-02)

**What:** Move `StatsResponse` + its sub-structs (`CountStat`, `SessionStat`, `MCPStat`, `PluginStat`) from `ResponseDTOs.swift` to a new `DashboardStats.swift` file in `ILSShared/DTOs/`. Rename `StatsResponse` to `DashboardStats`.

**Approach:**
```swift
// Sources/ILSShared/DTOs/DashboardStats.swift
public struct DashboardStats: Codable, Sendable {
    public let projects: CountStat
    public let sessions: SessionStat
    public let skills: CountStat
    public let mcpServers: MCPStat
    public let plugins: PluginStat
    // Same fields, same init, renamed type
}

// Backward compatibility in ResponseDTOs.swift
public typealias StatsResponse = DashboardStats
```

**Verification:** `curl -s http://localhost:9999/api/v1/stats | python3 -m json.tool` should show typed fields matching `DashboardStats`.

### Pattern 3: Cache Freshness Indicators (DATA-04)

**What:** Add `lastUpdated: Date?` property to each data-loading ViewModel. Set it to `Date()` after successful API fetch. Pass to `CacheStatusView` in the relevant views.

**Approach:**
```swift
// In each ViewModel (DashboardViewModel, SessionsViewModel, etc.)
var lastUpdated: Date?

func loadAll() async {
    // ... existing load logic ...
    if stats != nil {
        lastUpdated = Date()  // Set on successful load
    }
}

// In HomeView -- add below statsSection
if dashboardVM.stats != nil {
    CacheStatusView(lastUpdated: dashboardVM.lastUpdated)
}

// In BrowserView -- add per segment
CacheStatusView(lastUpdated: mcpVM.lastUpdated)  // or skillsVM, pluginsVM
```

**CacheStatusView already handles:** nil date (shows nothing), relative formatting, 30s update cadence (note: current implementation does NOT auto-refresh -- it recalculates on view re-render only, which is fine for pull-to-refresh pattern).

### Pattern 4: Chat Draft Persistence (DATA-05)

**What:** Persist the chat input text to UserDefaults keyed by session ID so it survives app termination.

**Why not @SceneStorage:** The requirement says "kill the app, relaunch, draft is restored." Force-quit destroys scene state but not UserDefaults. `@SceneStorage` only persists within normal scene lifecycle transitions.

**Approach:**
```swift
// In ChatView.swift
@State private var inputText = ""

// On appear, restore draft
.onAppear {
    let key = "chatDraft_\(session.id.uuidString)"
    inputText = UserDefaults.standard.string(forKey: key) ?? ""
}

// On input change, persist draft (debounced)
.onChange(of: inputText) { _, newValue in
    let key = "chatDraft_\(session.id.uuidString)"
    if newValue.isEmpty {
        UserDefaults.standard.removeObject(forKey: key)
    } else {
        UserDefaults.standard.set(newValue, forKey: key)
    }
}

// On send, clear draft
func sendMessage() {
    // ... existing send logic ...
    let key = "chatDraft_\(session.id.uuidString)"
    UserDefaults.standard.removeObject(forKey: key)
}
```

**Debouncing concern:** `onChange(of: inputText)` fires on every keystroke. UserDefaults writes are lightweight for small strings and are coalesced by the system, so debouncing is not strictly necessary. However, for large drafts, consider a 500ms debounce via a Task with sleep.

**Cleanup concern:** Old drafts accumulate in UserDefaults. Add cleanup: when a session is deleted, also remove its draft key. Optionally, clean up drafts older than 7 days on app launch.

### Pattern 5: Input Validation Gaps (DATA-06)

**What:** Add `precondition` guards to model initializers that currently lack them.

**Models with existing validation (NO CHANGE needed):**
- `MCPServer`: name, command not empty
- `ChatSession`: model not empty, messageCount >= 0
- `ExternalSession`: claudeSessionId not empty
- `Plugin`: name not empty
- `Skill`: name, path not empty
- `Project`: name, path not empty
- `FleetHost`: name, host not empty, ports in range
- `ServerConnection`: host, username not empty, port in range
- `CustomTheme`: name not empty

**Models MISSING validation (NEED CHANGES):**
- `Message`: No validation. Add: `content` should not reject empty (system messages can be empty), but `sessionId` should be validated (UUIDs are always valid from UUID() but worth documenting)
- `CountStat`: Add `precondition(total >= 0)`; if `active` is present, `precondition(active! >= 0)`
- `SessionStat`: Add `precondition(total >= 0)` and `precondition(active >= 0)`
- `MCPStat`: Add `precondition(total >= 0)` and `precondition(healthy >= 0)` and `precondition(healthy <= total)`
- `PluginStat`: Add `precondition(total >= 0)` and `precondition(enabled >= 0)` and `precondition(enabled <= total)`
- `ConfigInfo`: After DATA-01, `scope` becomes `ConfigScope` (enum-validated). Add `precondition(!path.isEmpty)`
- `UpdateConfigRequest`: After DATA-01, `scope` becomes `ConfigScope`. No additional validation needed.
- `ConfigOverride`: After DATA-01, `winningScope` becomes `ConfigScope`. Add `precondition(!key.isEmpty)`

### Anti-Patterns to Avoid

- **Throwing initializers for models already using precondition:** The codebase consistently uses `precondition` for init validation. Don't mix in `throw`-based validation for consistency.
- **Adding validation that breaks Codable round-trips:** `precondition` fires on `init(...)` but NOT on `init(from: Decoder)` (which is auto-synthesized). For models with custom `init(from:)`, validation happens via `DecodingError`. For auto-synthesized Codable, there's no init-time validation path -- `precondition` only guards programmatic construction. This is fine and matches the requirement ("model initializers reject invalid input").
- **Over-validating optional fields:** Don't precondition on optional String fields being non-empty. `nil` is valid; only non-nil empty strings are suspicious, and even then, some fields legitimately can be empty.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Relative time formatting | Custom DateFormatter logic | Existing `CacheStatusView.relativeTime(from:)` | Already implemented correctly with all time ranges |
| Draft persistence | Custom file-based storage | `UserDefaults` with session-keyed strings | Lightweight, atomic, crash-safe, system-coalesced writes |
| Retry queue | Custom queue for drafts | Existing `SyncCoordinator` | Already handles retry with exponential backoff (but note: SyncCoordinator is for API retries, NOT for draft persistence -- keep them separate) |
| Enum-safe Codable | Manual CodingKeys for every enum | Custom `init(from:)` pattern already used | All enums in ILSShared already follow this pattern with descriptive error messages |

**Key insight:** Most of the infrastructure already exists. This phase is about wiring existing components together and closing type-safety gaps, not building new systems.

## Common Pitfalls

### Pitfall 1: MCPScope Rename Cascade
**What goes wrong:** Renaming `MCPScope` to `ConfigScope` breaks every file that imports and uses `MCPScope`.
**Why it happens:** The enum is used in MCPServer, MCPController, Requests.swift, ResponseDTOs.swift, LocalDatabase CachedMCPServer, etc.
**How to avoid:** Add `public typealias MCPScope = ConfigScope` in the same file. Zero files break. The typealias can be deprecated later with a `@available(*, deprecated, renamed: "ConfigScope")` annotation.
**Warning signs:** Build errors referencing `MCPScope` after rename.

### Pitfall 2: Messages Not Cached on History Load
**What goes wrong:** CacheService has `cacheMessages` and `getCachedMessages` methods, but ChatViewModel.loadMessageHistory() does NOT call cacheMessages after fetching from the API.
**Why it happens:** The cache methods exist but were never wired into the load flow -- only session-level caching was connected.
**How to avoid:** After successfully loading messages in `loadMessageHistory()`, call `CacheService.shared.cacheMessages(messages, forSession: sessionId)`. On load failure or offline, fall back to `getCachedMessages`.
**Warning signs:** Messages disappear when going offline after having viewed them.

### Pitfall 3: @SceneStorage vs Force-Quit
**What goes wrong:** Using `@SceneStorage` for draft persistence means drafts are lost on force-quit (swipe-up kill).
**Why it happens:** `@SceneStorage` persists to the scene's state restoration archive, which is only written during normal lifecycle transitions (background, not terminate).
**How to avoid:** Use `UserDefaults` instead. It's persisted immediately on write.
**Warning signs:** Draft survives normal app backgrounding but disappears after force-quit.

### Pitfall 4: UserDefaults Draft Key Pollution
**What goes wrong:** Over time, hundreds of `chatDraft_<UUID>` keys accumulate in UserDefaults.
**Why it happens:** Drafts are created for every session the user types in, but never cleaned up.
**How to avoid:** (1) Remove draft key on successful message send. (2) Remove draft key when session is deleted. (3) Optionally, on app launch, scan for draft keys and remove any whose session no longer exists (expensive -- defer to later).
**Warning signs:** UserDefaults plist grows large; `defaults read com.ils.app` shows hundreds of draft keys.

### Pitfall 5: Backend ConfigFileService String→Enum Migration
**What goes wrong:** Changing `readConfig(scope: String)` to `readConfig(scope: ConfigScope)` requires updating every call site in the backend.
**Why it happens:** Multiple controllers call `fileSystem.readConfig(scope: "user")` with string literals.
**How to avoid:** Update signature to `ConfigScope`, then fix each call site: `readConfig(scope: .user)`. The compiler will catch every missed site.
**Warning signs:** Build errors in backend after signature change.

### Pitfall 6: DashboardStats Rename Breaking API Contract
**What goes wrong:** Renaming `StatsResponse` to `DashboardStats` could theoretically change JSON field names if CodingKeys were type-name-derived.
**Why it happens:** Misunderstanding of Codable -- Swift's auto-synthesized CodingKeys use property names, not type names.
**How to avoid:** Renaming the struct does NOT change JSON encoding. The JSON keys come from property names (`projects`, `sessions`, etc.), which remain unchanged. Add `typealias StatsResponse = DashboardStats` for source compatibility.
**Warning signs:** None -- this is a safe rename. Verify with cURL after the change.

## Code Examples

### Cache Freshness Tracking in ViewModel

```swift
// Pattern for all data-loading ViewModels
@Observable
@MainActor
class SessionsViewModel {
    var sessions: [ChatSession] = []
    var isLoading = false
    var lastUpdated: Date?  // NEW

    func loadSessions(refresh: Bool = false) async {
        isLoading = true
        // ... existing fetch logic ...
        if !sessions.isEmpty {
            lastUpdated = Date()  // Set on success
        }
        isLoading = false
    }
}
```

### CacheStatusView Integration in HomeView

```swift
// In HomeView statsSection, after the stat cards
if dashboardVM.stats != nil {
    HStack {
        Spacer()
        CacheStatusView(lastUpdated: dashboardVM.lastUpdated)
    }
}
```

### Draft Persistence in ChatView

```swift
// Restore on appear
.onAppear {
    let key = "chatDraft_\(session.id.uuidString)"
    if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
        inputText = saved
    }
}

// Persist on change (debounced)
.onChange(of: inputText) { _, newValue in
    draftPersistTask?.cancel()
    draftPersistTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        let key = "chatDraft_\(session.id.uuidString)"
        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

// Clear on send
private func sendMessage() {
    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let prompt = inputText
    inputText = ""
    UserDefaults.standard.removeObject(forKey: "chatDraft_\(session.id.uuidString)")
    viewModel.sendMessage(prompt: prompt, projectId: projectId)
}
```

### ConfigScope Enum with Typealias

```swift
// In MCPServer.swift (or new ConfigScope.swift)
/// Scope of configuration: user-level, project-level, or local override.
public enum ConfigScope: String, Codable, Sendable {
    case user
    case project
    case local

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized ConfigScope: '\(raw)'. Expected: user, project, local"
                )
            )
        }
        self = value
    }
}

/// Backward-compatible alias. Prefer `ConfigScope` in new code.
public typealias MCPScope = ConfigScope
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw string scope ("user"/"project"/"local") | MCPScope enum (already in MCPServer) | Already done for MCP, not for Config | DATA-01 extends enum to all scope usage |
| StatsResponse in ResponseDTOs.swift | Standalone DashboardStats DTO | This phase | Clearer ownership, easier to find |
| No cache freshness UI | CacheStatusView component exists | Built in earlier phase | DATA-04 wires it into views |
| @State inputText (lost on navigation) | UserDefaults-persisted draft | This phase | Drafts survive app kill |
| Inconsistent precondition coverage | All models validated | This phase | DATA-06 closes remaining gaps |

## Open Questions

1. **Draft cleanup strategy**
   - What we know: UserDefaults drafts accumulate per session UUID
   - What's unclear: Should we clean up drafts for deleted sessions immediately, or batch-clean on launch?
   - Recommendation: Clean on session delete (immediate). Skip batch cleanup for now -- it's an optimization, not a correctness issue.

2. **CacheStatusView auto-refresh**
   - What we know: Current implementation recalculates relative time on view re-render, not on a timer
   - What's unclear: Should we add a timer to update "3 min ago" to "4 min ago" live?
   - Recommendation: Skip timer for v4.0. The text updates on any view re-render (scrolling, pull-to-refresh, navigation). Adding a timer adds complexity and battery cost for minimal UX gain.

3. **Message caching scope for DATA-03**
   - What we know: CacheService has message caching methods. ChatViewModel doesn't call them on history load.
   - What's unclear: Should we cache ALL messages or just the current window (50)?
   - Recommendation: Cache the current window. It's what the user has seen and would expect to see offline. Full history caching is expensive and rarely needed offline.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: All ILSShared models (26 files), CacheService, LocalDatabase, CacheStatusView, ChatViewModel, DashboardViewModel, BrowserView, HomeView, SyncCoordinator, ConfigController, ConfigFileService, MCPController, StatsController
- Swift documentation: @SceneStorage behavior during termination (scene state restoration archive)
- Project REQUIREMENTS.md: DATA-01 through DATA-06 definitions

### Secondary (MEDIUM confidence)
- Apple developer documentation: UserDefaults persistence guarantees (writes are coalesced and persisted asynchronously but survive force-quit)
- Swift Observation framework: @Observable property tracking for lastUpdated timestamps

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already in use, no new dependencies
- Architecture: HIGH - patterns follow existing codebase conventions exactly
- Pitfalls: HIGH - identified from direct codebase analysis, not speculation

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable patterns, no external dependency changes)
