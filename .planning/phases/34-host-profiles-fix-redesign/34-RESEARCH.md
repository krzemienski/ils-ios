# Phase 34: Host Profiles Fix + Redesign - Research

**Researched:** 2026-02-25
**Domain:** SwiftUI reactive state propagation, multi-host switching architecture, ViewModel invalidation
**Confidence:** HIGH

## Summary

Phase 34 fixes the architecturally broken host activation flow and completes the "Fleet" to "Host Profiles" rename. The core bug is that `HostProfilesViewModel` creates a standalone `APIClient()` (always `localhost:9999`) rather than receiving AppState's managed client. When a user activates a different host, the backend records the selection in SQLite via `POST /fleet/{id}/activate`, but the iOS app's `AppState.serverURL`, `APIClient`, and `SSEClient` are never updated -- all subsequent API calls from every ViewModel still target the previous host.

The fix is architectural but narrow: inject `AppState` into `HostProfilesViewModel`, call `appState.updateServerURL()` on activation (which rebuilds `APIClient` + `SSEClient` in `ConnectionManager`), then trigger reactive data reloads in all downstream ViewModels. The existing `configure(client:)` pattern used by 10+ ViewModels means the reconfiguration mechanism already exists -- the missing piece is invoking it on host switch. The sidebar already has the `activeHostName` display wired (from Phase 33) but it reads `nil` because no code sets it yet.

**Primary recommendation:** Wire `AppState` into `HostProfilesViewModel` via init injection. On `activate()`, build the new host URL from `FleetHost.host` + `FleetHost.backendPort`, call `appState.updateServerURL()`, set `appState.activeHostName`, and rely on SwiftUI's `@Observable` tracking to propagate the change. Add `.onChange(of: appState.serverURL)` handlers in BrowserView, SettingsView, HomeView, and SystemMonitorView to reconfigure their ViewModels with `appState.apiClient` and reload data.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HP-01 | Host activation propagates to `AppState.serverURL` -- `HostProfilesViewModel` uses `AppState` injection, not standalone `APIClient()` | Core architecture fix: HostProfilesViewModel.init must accept AppState, activate() must call appState.updateServerURL(). See Architecture Pattern 1. |
| HP-02 | All ViewModels reload data on host switch -- reactive invalidation via `AppState` observable change | 10 ViewModels use `configure(client:)` pattern. Add `.onChange(of: appState.serverURL)` to re-invoke configure + reload. See Architecture Pattern 2. |
| HP-03 | Active profile indicator visible on list row and sidebar | Sidebar UI already wired (SidebarView lines 140-165 reads `appState.activeHostName`). HostProfilesView already has "Active" capsule badge. Just need activate() to set `appState.activeHostName`. See Architecture Pattern 3. |
| HP-04 | Health status badges per host with colored dot | Already implemented: `healthBadge()` in HostProfilesView renders colored Circle per `FleetHost.HealthStatus`. `startHealthPolling()` / `refreshAllHealth()` poll `GET /fleet/{id}/health`. Verify health endpoint works after AppState injection refactor. |
| HP-05 | Fleet to Host Profiles naming consistency in all UI strings | Partially done. Remaining: FleetManagementView title says "Backend Profiles", some doc comments say "fleet". FleetManagementView and FleetHostDetailView are dead code (replaced by HostProfilesView/HostProfileDetailView). See Naming Audit. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `@Observable` | iOS 17+ | Reactive state propagation from AppState through ViewModel chain | Already used by all ViewModels in the project; `@Observable` tracks property access automatically |
| `ConnectionManager` | Internal | Manages `APIClient` + `SSEClient` lifecycle, URL persistence | Already owns `updateServerURL()` which rebuilds both clients atomically |
| `APIClient` (actor) | Internal | HTTP client with NSCache, request dedup, in-flight GET sharing | Already cached per-path with 30s TTL; has `invalidateCache()` for full purge |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `FleetHost` model | ILSShared | Host profile data (id, name, host, port, healthStatus, isActive) | Already used; `HostProfile` typealias exists |
| `FleetController` | Backend | CRUD + activate (atomic transaction) + health check | No changes needed; backend API is correct |
| `FleetDTOs` | ILSShared | Request/response types for fleet API | Already has migration typealiases (RegisterHostProfileRequest, etc.) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.onChange(of: appState.serverURL)` in each View | Single Notification/Combine publisher from AppState | `.onChange` is simpler, more SwiftUI-idiomatic, and doesn't require additional infrastructure. Notification approach adds indirection. |
| Passing AppState to HostProfilesViewModel.init | Using `configure(appState:)` like other VMs | Init injection is safer for this VM because `activate()` must always have access to AppState -- configure() could be missed |
| Rebuilding all ViewModels on host switch | Re-calling `configure(client:)` + reload | Re-calling configure + reload reuses existing VM state (search text, filters); rebuilding loses user context |

## Architecture Patterns

### Recommended Change Topology

```
HostProfilesViewModel
  |-- init(appState: AppState)  ← NEW: replaces init(apiClient: APIClient = APIClient())
  |-- activate(id: UUID)
  |     |-- POST /fleet/{id}/activate  (using appState.apiClient)
  |     |-- build URL: "http(s)://{host.host}:{host.backendPort}"
  |     |-- appState.updateServerURL(newURL)   ← KEY FIX
  |     |     |-- ConnectionManager.updateServerURL()
  |     |     |     |-- serverURL = url
  |     |     |     |-- apiClient = APIClient(baseURL: url)    ← new client
  |     |     |     |-- sseClient = SSEClient(baseURL: url)    ← new SSE
  |     |     |-- pollingManager.checkConnection()
  |     |-- appState.activeHostName = host.name  ← sidebar indicator
  |     |-- update local hosts[] array
  |
  Views observing appState.serverURL:
    BrowserView     → .onChange(of: appState.serverURL) → reconfigure 3 VMs + reload
    SettingsView    → .onChange(of: appState.serverURL) → reconfigure VM + reload
    HomeView        → .onChange(of: appState.serverURL) → reconfigure dashboard VM + reload
    SystemMonitor   → .onAppear already checks baseURL mismatch (line 156)
    SidebarRootView → .task reconfigures sessionsVM (needs onChange too)
```

### Pattern 1: AppState Injection into HostProfilesViewModel (HP-01)

**What:** Replace the standalone `APIClient()` default with `AppState` injection. The ViewModel uses `appState.apiClient` for all fleet API calls and calls `appState.updateServerURL()` on activation.

**When to use:** This is the core fix. Every other requirement depends on this.

**Current code (BROKEN):**
```swift
// HostProfilesViewModel.swift line 16
init(apiClient: APIClient = APIClient()) {
    self.apiClient = apiClient
}

// activate() line 51-59 -- never touches AppState
func activate(_ id: UUID) {
    Task { [weak self] in
        guard let self else { return }
        let updated: FleetHost? = try? await apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
        if updated != nil {
            activeHostId = id
            for i in hosts.indices { hosts[i].isActive = hosts[i].id == id }
        }
    }
}
```

**Fixed code:**
```swift
private let appState: AppState

init(appState: AppState) {
    self.appState = appState
}

// Use appState.apiClient instead of private apiClient throughout

func activate(_ id: UUID) {
    guard let host = hosts.first(where: { $0.id == id }) else { return }
    Task { [weak self] in
        guard let self else { return }
        do {
            let _: FleetHost = try await appState.apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
            activeHostId = id
            for i in hosts.indices { hosts[i].isActive = hosts[i].id == id }

            // KEY: Propagate URL change through AppState
            let scheme = host.backendPort == 443 ? "https" : "http"
            let newURL = "\(scheme)://\(host.host):\(host.backendPort)"
            appState.updateServerURL(newURL)
            appState.activeHostName = host.name
        } catch {
            loadError = "Failed to activate \(host.name): \(error.localizedDescription)"
        }
    }
}
```

### Pattern 2: Reactive ViewModel Reconfiguration on Host Switch (HP-02)

**What:** Views that own ViewModels with `configure(client:)` add `.onChange(of: appState.serverURL)` to re-inject the new client and reload.

**When to use:** BrowserView, SettingsView, HomeView (via SidebarRootView), and any view that calls `vm.configure(client:)` in `.task`.

**Example (BrowserView already has `.onChange(of: appState.isConnected)` at line 128):**
```swift
.onChange(of: appState.serverURL) { _, _ in
    // Re-inject new APIClient and invalidate stale data
    mcpVM.configure(client: appState.apiClient)
    skillsVM.configure(client: appState.apiClient)
    pluginsVM.configure(client: appState.apiClient)
    Task { await loadAll() }
}
```

**ViewModels with `configure(client:)` that need this pattern:**
1. `MCPViewModel` -- used in BrowserView
2. `SkillsViewModel` -- used in BrowserView + SkillDetailView
3. `PluginsViewModel` -- used in BrowserView
4. `SettingsViewModel` -- used in SettingsView
5. `ConfigEditorViewModel` -- used in ConfigEditorView
6. `DashboardViewModel` -- used in HomeView
7. `HooksViewModel` -- used in HooksManagementView
8. `ThemesViewModel` -- used in ThemesListView
9. `SessionsViewModel` -- used in SidebarRootView (shared VM)
10. `NewSessionViewModel` -- created per-sheet, not persistent

**SystemMonitorView** already handles this: line 156 checks `viewModel.metricsClient.baseURL != appState.serverURL` on `.onAppear` and recreates the WebSocket client.

### Pattern 3: Active Host Indicator (HP-03)

**What:** `appState.activeHostName` is set during `activate()` and read by the sidebar.

**Current state:** SidebarView lines 140-165 already render the indicator:
- If `appState.activeHostName` is non-nil, show the host name with a desktop computer icon
- If `nil` but connected, show "Local"

The only missing piece is setting `appState.activeHostName` -- this happens in the `activate()` method (Pattern 1). Also needs to be loaded on app startup from the fleet list (the host where `isActive == true`).

### Anti-Patterns to Avoid

- **Creating a second `APIClient` for the new host before switching:** `ConnectionManager.updateServerURL()` already handles this atomically. Do not create temporary clients.
- **Using Combine/NotificationCenter for host change propagation:** `@Observable` handles this automatically through SwiftUI's observation tracking. Adding Combine layers would be redundant.
- **Modifying `FleetHostModel` or adding DB migrations:** The rename is UI-only. The backend model, routes (`/fleet/*`), and database schema stay exactly as-is.
- **Trying to merge the two detail views:** `FleetHostDetailView` and `HostProfileDetailView` are functionally identical but serve different code paths. Only `HostProfileDetailView` is actively used (via `HostProfilesView`). `FleetHostDetailView` + `FleetManagementView` are dead code and should be deleted, not merged.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL construction from FleetHost | String concatenation with edge cases | `"\(scheme)://\(host.host):\(host.backendPort)"` where scheme = port 443 ? "https" : "http" | Matches the pattern in `FleetController.health()` line 136. Simple and already proven. |
| API cache invalidation on host switch | Custom cache invalidation per-ViewModel | `appState.apiClient.invalidateCache()` (already exists, line 354-358) | The old APIClient instance and its cache are discarded when `ConnectionManager.updateServerURL()` creates a new `APIClient`. No manual invalidation needed. |
| Reactive state propagation | Combine publishers, NotificationCenter | SwiftUI `.onChange(of:)` on `@Observable` properties | The entire project uses `@Observable` pattern. Adding Combine would be inconsistent. |
| Health polling per-host | Custom Timer-based polling | Existing `startHealthPolling()` / `refreshAllHealth()` in HostProfilesViewModel | Already handles interval, cancellation, Low Power Mode doubling (ENRG-03) |

**Key insight:** `ConnectionManager.updateServerURL()` is the single point of truth. When it creates new `APIClient` and `SSEClient` instances, the old instances become unreferenced. Any ViewModel that re-calls `configure(client: appState.apiClient)` automatically gets the new client. The NSCache on the old APIClient is garbage-collected with the old instance.

## Common Pitfalls

### Pitfall 1: HostProfilesView Creates ViewModel with @State (No AppState)

**What goes wrong:** `HostProfilesView` line 38 does `@State private var viewModel = HostProfilesViewModel()` which calls `init(apiClient: APIClient())` -- always targeting localhost:9999 regardless of the actual configured URL.

**Why it happens:** The ViewModel predates the AppState architecture. It was written as a standalone component.

**How to avoid:** Change to `@State private var viewModel: HostProfilesViewModel?` and initialize in `.task` with `viewModel = HostProfilesViewModel(appState: appState)`. Or use a factory pattern. The view already has `@Environment(AppState.self) var appState`.

**Warning signs:** After switching hosts, the host list still shows hosts from localhost:9999 (the local backend's fleet table, not the remote one).

### Pitfall 2: activate() Uses `try?` Silently Swallowing Errors

**What goes wrong:** Current `activate()` at line 54 uses `try? await apiClient.post(...)`. If the POST fails (network error, 404, 500), the user sees the UI update locally but the backend state is unchanged.

**Why it happens:** `try?` was used for simplicity during initial implementation.

**How to avoid:** Replace with `do/catch`. On error, show `loadError` message. Do NOT update local state (activeHostId, hosts[].isActive) until the server confirms success.

**Warning signs:** User taps "Activate" on an unreachable host, sees "Active" badge, but all API calls still target the old host.

### Pitfall 3: Stale ViewModel Data After Host Switch

**What goes wrong:** BrowserView calls `.task { mcpVM.configure(client: appState.apiClient) }` once on first appearance. If the user switches hosts while BrowserView is already mounted, the old APIClient is still in use. `.task` does not re-fire.

**Why it happens:** `.task` only runs once per view identity. It does not re-trigger when `appState.apiClient` changes.

**How to avoid:** Add `.onChange(of: appState.serverURL)` to re-invoke `configure(client:)` and reload data. This pattern must be added to every view that owns a ViewModel with `configure()`.

**Warning signs:** Skills list shows skills from the previous host after switching.

### Pitfall 4: SSEClient Zombie Connections

**What goes wrong:** `ConnectionManager.updateServerURL()` creates a new `SSEClient` instance, but any ChatViewModel holding a reference to the old `SSEClient` may still have an open connection.

**Why it happens:** ChatViewModel calls `configure(client:, sseClient:)` and stores the SSEClient reference. The old SSEClient instance is not explicitly disconnected.

**How to avoid:** ChatView should observe `appState.serverURL` changes and either reconnect with the new SSEClient or warn the user that the host has changed mid-conversation.

**Warning signs:** After host switch, chat messages from the old host continue to stream in.

### Pitfall 5: activeHostName Not Restored on App Launch

**What goes wrong:** `appState.activeHostName` is `nil` on cold start. The sidebar shows "Local" even when a remote host was previously active.

**Why it happens:** `activeHostName` is not persisted to UserDefaults, and no code loads the fleet list on startup to find the active host.

**How to avoid:** Either (a) persist `activeHostName` to UserDefaults and restore in AppState.init, or (b) load the fleet list on startup and set `activeHostName` from the active host. Option (a) is simpler and faster (no network call on cold start).

**Warning signs:** App restart always shows "Local" in sidebar even though a remote host is configured as active.

### Pitfall 6: Dead Code Duplication

**What goes wrong:** `FleetManagementView` and `FleetHostDetailView` are near-identical copies of `HostProfilesView` and `HostProfileDetailView`. Fixing bugs in one without the other creates divergence.

**Why it happens:** The rename created new files but kept the old ones.

**How to avoid:** Delete `FleetManagementView.swift` and `FleetHostDetailView.swift`. They are not referenced from any active navigation path -- `SidebarRootView.hostProfilesScreen` routes to `HostProfilesView()`, and `MacContentView` also uses `HostProfilesView()`.

**Warning signs:** Grep shows "Backend Profiles" title in FleetManagementView but it never appears in the app because the view is unreachable.

## Code Examples

### Host Activation with AppState Propagation

```swift
// HostProfilesViewModel.swift — fixed activate()
func activate(_ id: UUID) {
    guard let host = hosts.first(where: { $0.id == id }) else { return }
    Task { [weak self] in
        guard let self else { return }
        do {
            let _: FleetHost = try await appState.apiClient.post(
                "/fleet/\(id)/activate", body: EmptyBody()
            )
            // Update local state
            activeHostId = id
            for i in hosts.indices {
                hosts[i].isActive = hosts[i].id == id
            }
            // Propagate to AppState — triggers all downstream rebuilds
            let scheme = host.backendPort == 443 ? "https" : "http"
            let newURL = "\(scheme)://\(host.host):\(host.backendPort)"
            appState.updateServerURL(newURL)
            appState.activeHostName = host.name
        } catch {
            loadError = "Failed to activate \(host.name): \(error.localizedDescription)"
        }
    }
}
```

### View-Side Reactive Reconfiguration

```swift
// BrowserView.swift — add below existing .onChange(of: appState.isConnected)
.onChange(of: appState.serverURL) { _, _ in
    mcpVM.configure(client: appState.apiClient)
    skillsVM.configure(client: appState.apiClient)
    pluginsVM.configure(client: appState.apiClient)
    Task { await loadAll() }
}
```

### HostProfilesView Init with AppState

```swift
// HostProfilesView.swift — replace @State initialization
@State private var viewModel: HostProfilesViewModel?

// In .task:
.task {
    if viewModel == nil {
        viewModel = HostProfilesViewModel(appState: appState)
    }
    await viewModel?.loadHosts()
}
```

### Startup Restoration of Active Host Name

```swift
// AppState.init — restore persisted active host name
init() {
    let cm = ConnectionManager()
    self.connectionManager = cm
    self.pollingManager = PollingManager(connectionManager: cm)
    self.networkMonitor = NetworkMonitor.shared
    self.activeHostName = UserDefaults.standard.string(forKey: "activeHostName")
    pollingManager.checkConnection()
}

// In activate(), persist alongside setting:
appState.activeHostName = host.name
UserDefaults.standard.set(host.name, forKey: "activeHostName")
```

## Naming Audit (HP-05)

### Files to Rename/Delete

| File | Action | Reason |
|------|--------|--------|
| `Views/Fleet/FleetManagementView.swift` | DELETE | Dead code; unreachable from navigation. `HostProfilesView` is the active replacement. |
| `Views/Fleet/FleetHostDetailView.swift` | DELETE | Dead code; unreachable from navigation. `HostProfileDetailView` is the active replacement. |
| `ViewModels/FleetViewModel.swift` | DELETE | Contains only a comment pointing to HostProfilesViewModel.swift. The typealias is in HostProfilesViewModel.swift already. |

### UI Strings Already Correct (No Changes Needed)

| Location | Current Text | Status |
|----------|-------------|--------|
| SidebarView line 182 | "Host Profiles" | Correct |
| HostProfilesView line 87 | "Host Profiles" (navigationTitle) | Correct |
| HostProfilesView line 72 | "No Host Profiles" (empty state) | Correct |
| MacContentView line 14 | "Host Profiles" (SidebarSection enum) | Correct |
| AppState line 122 | `ils://fleet` and `ils://profiles` both route to `.hostProfiles` | Correct |

### Doc Comments to Update

| File | Line(s) | Current | Replacement |
|------|---------|---------|-------------|
| HostProfilesViewModel.swift | 73, 99-100 | "fleet health poll", "FleetViewModel" typealias | Update comments; can remove FleetViewModel typealias if dead files are deleted |
| HostProfileDetailView.swift | 4, 8-9 | "fleet host detail", "fleet discovery flow", "fleet API" | "host profile detail", "host profiles flow", "fleet API" (API path stays `/fleet`) |

### Backend API Routes Stay as `/fleet/*`

The backend routes (`/fleet`, `/fleet/register`, `/fleet/:id/activate`, etc.) do NOT need renaming. Changing API routes would require:
- Backend route changes in `FleetController.swift`
- Frontend path changes in `HostProfilesViewModel.swift`
- Testing both old and new paths
- Potential breaking changes for any external consumers

The `FleetHost` model, `FleetHostModel` Fluent model, `FleetDTOs`, and `FleetController` all stay as-is. The rename is purely UI-facing.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Standalone `APIClient()` in HostProfilesViewModel | AppState-injected APIClient | This phase | Fixes multi-host switching entirely |
| `.task` only for ViewModel configuration | `.task` + `.onChange(of: serverURL)` | This phase | Enables reactive reconfiguration on host switch |
| "Fleet" UI label | "Host Profiles" UI label | Partially done (Phase 33 sidebar) | This phase completes the rename |
| Two parallel view hierarchies (Fleet* + HostProfile*) | Single HostProfile* hierarchy | This phase | Removes dead code |

## Open Questions

1. **Should activate() do a health check before switching?**
   - What we know: `FleetController.health()` already performs real HTTP GET to the target host. The UI already shows health badges.
   - What's unclear: Should we block the switch until health is confirmed, or allow switching to an unreachable host?
   - Recommendation: Allow the switch (user may know the host is temporarily down). Show a warning toast if health is `.unreachable` or `.unknown` at switch time but do not block. The existing health polling will update the status.

2. **Should SidebarRootView's sessionsVM reload on host switch?**
   - What we know: `sessionsVM` is configured in `.task` with `appState.apiClient`. After host switch, it still has the old client.
   - What's unclear: Users may not expect the sessions list to change immediately on host switch (it's more of a navigation-level concern).
   - Recommendation: Yes, reconfigure `sessionsVM` on host switch. Sessions are host-specific. Show a brief loading indicator while sessions reload.

3. **Should `activeHostName` persist or be loaded fresh each launch?**
   - What we know: `activeHostName` is currently in-memory only (nil on startup). The fleet list from the backend has `isActive` flags.
   - What's unclear: UserDefaults persistence is fast but could become stale if the user switches hosts from another app/device.
   - Recommendation: Persist to UserDefaults for instant sidebar display on cold start. Overwrite from fleet list when it loads (the fleet list is loaded when the user visits Host Profiles, so it's not immediate on every launch).

## Sources

### Primary (HIGH confidence)

- Codebase: `ILSApp/ILSApp/AppState.swift` -- `updateServerURL()` method, `activeHostName` property (already stubbed for Phase 34)
- Codebase: `ILSApp/ILSApp/Services/ConnectionManager.swift` -- `updateServerURL()` rebuilds APIClient + SSEClient atomically
- Codebase: `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` -- current broken `init(apiClient: APIClient = APIClient())` and `activate()`
- Codebase: `ILSApp/ILSApp/Views/Fleet/HostProfilesView.swift` -- current view using `@State private var viewModel = HostProfilesViewModel()`
- Codebase: `ILSApp/ILSApp/Views/Root/SidebarView.swift` -- lines 140-165, `activeHostName` display already wired
- Codebase: `ILSApp/ILSApp/Views/Browser/BrowserView.swift` -- `.task` configure pattern and existing `.onChange(of: appState.isConnected)`
- Codebase: `Sources/ILSBackend/Controllers/FleetController.swift` -- activate endpoint with atomic transaction
- Codebase: `.planning/research/PITFALLS.md` -- Pitfall 1 (broken activation), Pitfall 7 (cache staleness), Pitfall 10 (standalone APIClient), Pitfall 11 (try? swallowing errors)
- Codebase: `.planning/research/ARCHITECTURE.md` -- Feature 4 architecture, option (a) for sidebar access

### Secondary (MEDIUM confidence)

- Codebase: `.planning/research/FEATURES.md` -- Feature 3 gap analysis confirming missing propagation path
- Codebase: `.planning/research/STACK.md` -- confirms no new packages/migrations needed

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components already exist in the codebase; no new dependencies
- Architecture: HIGH -- the fix pattern is clear from existing `ConnectionManager.updateServerURL()` and `configure(client:)` patterns
- Pitfalls: HIGH -- thoroughly documented in project research files; all pitfalls verified against current code
- Naming audit: HIGH -- exhaustive grep of all "Fleet"/"fleet"/"Backend Profile" strings completed

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable -- internal architecture, no external dependencies)
