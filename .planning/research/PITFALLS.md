# Pitfalls Research

**Domain:** Adding host CLI config sync, GitHub extension browsing/install, Host Profiles redesign, and navigation/UX overhaul to a hardened SwiftUI iOS/macOS codebase
**Project:** ILS iOS/macOS — v3.1 Comprehensive Audit, Bug Fix & UX Overhaul
**Researched:** 2026-02-24
**Confidence:** HIGH — all findings derived from direct code inspection of this codebase, cross-referenced against project memory from prior milestones

---

## Critical Pitfalls

Mistakes that cause silent data corruption, wrong-host operations, or require architectural rewrites.

---

### Pitfall 1: Host Profile Activation Does Not Rebuild Downstream ViewModels

**What goes wrong:**
`HostProfilesViewModel.activate()` posts to `/fleet/{id}/activate` and updates `activeHostId` locally — but it does NOT call `appState.updateServerURL()` or recreate the `APIClient`/`SSEClient`. All downstream ViewModels (`SkillsViewModel`, `PluginsViewModel`, `SettingsViewModel`, `MCPViewModel`) hold a reference to the old `APIClient` instance captured at `configure(client:)` call time. They silently continue hitting the previously-connected host's backend.

The root cause is in `HostProfilesViewModel.init`:
```swift
init(apiClient: APIClient = APIClient()) {   // completely disconnected from AppState
    self.apiClient = apiClient
}
```
This is a forked, stale client — never updated when the user switches profiles.

**Why it happens:**
The `configure(client:)` injection pattern captures an `APIClient` snapshot at view-`.task` time. There is no reactive mechanism to re-inject a new client when the underlying URL changes. `HostProfilesViewModel` was written before multi-host switching became a product requirement.

**How to avoid:**
Profile activation must propagate through `AppState`. The `activate()` path must:
1. POST to `/fleet/{id}/activate` and get back the activated host's URL
2. Call `appState.updateServerURL(newURL)` — which recreates both `APIClient` and `SSEClient` in `ConnectionManager`
3. Trigger a reload notification or `@Observable` invalidation so all open screens refresh against the new host
4. `HostProfilesViewModel` must receive `AppState` (not a raw `APIClient`) so it can call through

**Warning signs:**
- After switching profiles, `BrowserView` still shows skill/plugin data from the old host
- `SettingsView` loads config from the wrong backend
- No visible loading activity after profile switch despite confirming activation
- Chat sends messages to the wrong host

**Phase to address:** Host Profiles redesign phase — must be the first concern, as every other feature depends on the correct host being targeted.

---

### Pitfall 2: Config Sync Write-Back Silently Drops Unrendered CLI Fields

**What goes wrong:**
`SettingsViewModel.saveConfig()` does a full `ClaudeConfig` struct round-trip: reads `config?.content`, mutates one field (e.g. `model` or `colorScheme`), then PUTs the entire struct back. The `ConfigController` calls `fileSystem.writeConfig()` which serializes whatever is sent — there is no server-side merge.

`ClaudeConfig` has fields the iOS app does not render any UI for: `hooks`, `env`, `extraKnownMarketplaces`, `statusLine`, `permissions.allow`, `permissions.deny`. These are optional and default to `nil` in Swift. If the backend returns a config that omits them (they are absent from the JSON), Swift decodes them as `nil`, and the next PUT from the app writes `nil` back — effectively deleting those fields from `~/.claude/config.json`.

**Why it happens:**
JSON `Codable` with optional fields silently round-trips `nil` as field omission. The in-memory struct faithfully carries whatever the backend returned — but if the backend ever omits a field, the app's next write erases it permanently from disk.

**How to avoid:**
Implement read-then-patch for all app write operations:
- Load fresh config from backend immediately before any PUT
- Apply only the minimal delta (the one field the user changed)
- Treat `hooks`, `env`, `extraKnownMarketplaces`, `statusLine` as read-only in the iOS app — display them but never include them in write payloads
- Add a "fields this app manages" allowlist to `SettingsViewModel` — any field not in the allowlist is stripped from the write payload and preserved from the current server value

**Warning signs:**
- Hook configurations vanish from `~/.claude/config.json` after the user changes the model in Settings
- `CLAUDE_CODE_*` env vars disappear after a settings save
- User reports "Claude CLI stopped responding to hooks after using the iOS app"
- `permissions.allow`/`permissions.deny` entries disappear silently

**Phase to address:** Settings & Defaults Sync phase. Define the write-allowlist before implementing any new config sync UI.

---

### Pitfall 3: GitHub Rate Limit Surfaces as Opaque Error With No Actionable Guidance

**What goes wrong:**
`GitHubService.searchSkills()` throws `Abort(.tooManyRequests)` when the unauthenticated GitHub API rate limit (60 requests/hour) is exceeded. The backend maps this to HTTP 429. `APIClient.validateResponse()` converts 429 into `APIError.httpError(statusCode: 429)`. `SkillsViewModel.searchGitHub()` stores this in `self.error`. The UI then shows "HTTP error: 429 - Too Many Requests" with no explanation that this is a GitHub rate limit, no countdown, and no guidance on how to fix it.

Without `GITHUB_TOKEN` in the backend environment, the limit is hit trivially — 60 searches per hour across all users sharing the same backend host. The 300ms debounce in `debouncedGitHubSearch()` helps but does not prevent it.

**Why it happens:**
`GitHubService` correctly reads `GITHUB_TOKEN` from environment but there is no path in the iOS Settings UI to configure it, no documentation shown to the user, and no 429-specific error handling in `SkillsViewModel`.

**How to avoid:**
1. Add a 429-specific branch in `SkillsViewModel.searchGitHub()` error handling that sets a distinct `isRateLimited: Bool` flag, surfaced as: "GitHub search limit reached. Ask your host administrator to set `GITHUB_TOKEN` in the backend environment to increase limits."
2. Add an informational note in SettingsView under a "GitHub Integration" disclosure: "GitHub search uses the GITHUB_TOKEN environment variable on your connected host."
3. Verify `RateLimitMiddleware` in the backend is applied to `/skills/search` — check `Sources/ILSBackend/Middleware/RateLimitMiddleware.swift` is registered for this route, to prevent the iOS app from hammering GitHub with rapid typing before the debounce fires

**Warning signs:**
- GitHub search returns no results with a terse error after a burst of searches
- Backend logs show repeated 403/429 responses to `api.github.com`
- `isSearchingGitHub` toggles without results appearing

**Phase to address:** Browse, Skills & Plugins phase.

---

### Pitfall 4: GitHub `fetchRawContent` Hardcoded to `main` Branch — Fails Silently on `master` Repos

**What goes wrong:**
`GitHubService.fetchRawContent()` constructs the raw GitHub URL with a hardcoded `main` branch:
```swift
let uri = URI(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/main/\(path)")
```
Repositories using `master` or any other default branch name return HTTP 404. `SkillsController.install()` then throws `Abort(.notFound, reason: "Could not fetch file from GitHub")`. The iOS app receives a 404 and displays "Resource not found" — no indication that the branch name is wrong.

**Why it happens:**
`main` is now the GitHub default for new repositories, so it covers a large majority. But `master` repos (pre-2020, many corporate/academic) fail silently. `GitHubRepository` in `SearchResult.swift` does not include a `defaultBranch` field — the `CodingKeys` only maps `id`, `fullName`, `description`, `stargazersCount`, `updatedAt`.

**How to avoid:**
Two options (implement the simpler first):
1. **Quick fix:** In `GitHubService.fetchRawContent()`, try `main` branch; if 404, try `master`; if still 404, return a descriptive error: "SKILL.md not found on `main` or `master` branches. Repository may use a different default branch."
2. **Proper fix:** Add `defaultBranch: String?` to `GitHubRepository` (mapped from `"default_branch"` in CodingKeys). This field is present in GitHub's Code Search API response — pass it through `GitHubSearchResult` into the install request.

Prefer the quick fix for v3.1 given scope; note the proper fix as a follow-up.

**Warning signs:**
- Install consistently fails for certain GitHub repos
- Repos with "last updated" dates before 2020 fail disproportionately
- Backend logs show 404 from `raw.githubusercontent.com` for a valid-looking path

**Phase to address:** Browse, Skills & Plugins phase, in the GitHub install flow task.

---

### Pitfall 5: Navigation Screen Switch Abandons In-Progress GitHub Installs to Wrong Host

**What goes wrong:**
`SkillsViewModel` is declared as `@State private var skillsVM = SkillsViewModel()` inside `BrowserView`. When `activeScreen` changes (sidebar tap, deep link, profile activation), SwiftUI removes `BrowserView` from the hierarchy and the `@State` is deallocated. `SkillsViewModel.deinit` cancels `searchTask`, but any in-progress `installFromGitHub` Task is NOT explicitly cancelled — it continues running against whatever `APIClient` it captured.

If a user starts a GitHub skill install and then activates a different host profile mid-install, the install completes against the original host. But the user is now looking at the new host's skill list and does not see the installed skill — and the original host has a new skill the user did not intend.

**Why it happens:**
The `installFromGitHub` task is created inline in `BrowserView`'s button action closure:
```swift
Task {
    let installed = await skillsVM.installFromGitHub(result: result)
```
This `Task` is unstructured and holds its own reference to the captured `client`. It is not tracked in `SkillsViewModel` for cancellation on dealloc.

**How to avoid:**
1. Track the install task in `SkillsViewModel`:
   ```swift
   @ObservationIgnored private var installTask: Task<Bool, Never>?
   ```
   Cancel it in `deinit` alongside `searchTask`.
2. Block profile switching while an install is in progress: when `HostProfilesViewModel.activate()` is called, check if any VM has an active install task and show an alert: "A skill installation is in progress. Please wait for it to complete before switching hosts."
3. Alternatively: lift `skillsVM` to `SidebarRootView` level so it survives tab switches and its install task is not abandoned mid-flight.

**Warning signs:**
- Install button shows progress, user switches to Settings, returns to Browser, skill is missing from list
- Skill appears installed on the wrong host's backend
- No error shown after navigation-during-install but skill never appears

**Phase to address:** Navigation/UX overhaul phase (structured cancellation) and Host Profiles phase (guard on profile switch).

---

### Pitfall 6: Every Shared Swift Edit Triggers macOS Build — iOS-Only Imports Break It Silently

**What goes wrong:**
The auto-build hook fires `xcodebuild` on every `.swift` file save. For files in `ILSApp/ILSApp/` (shared between iOS and macOS), the hook builds the iOS scheme — but does NOT automatically build the macOS scheme. A UIKit import or iOS-only API added to a shared ViewModel breaks the macOS build without the auto-hook surfacing it.

For v3.1 specifically:
- New ViewModels for config sync or profile switching that import `UIKit` (e.g., for `UIApplication.shared.open()` to open GitHub URLs in Safari) will fail the macOS build
- `HostProfilesViewModel` is shared — adding iOS-only types to its interface breaks both targets
- New `@Environment(\.openURL)` usage is cross-platform safe; `UIApplication.shared` is not

**Why it happens:**
The auto-build hook maps file paths to schemes:
```
ILSApp/**/*.swift    → xcodebuild ILSApp scheme
ILSMacApp/**/*.swift → xcodebuild ILSMacApp scheme
Sources/**/*.swift   → swift build
```
Shared files build only the iOS scheme automatically. The macOS build is a manual check.

**How to avoid:**
- Always use `@Environment(\.openURL)` for URL opening rather than `UIApplication.shared.open()`
- For platform-specific code, use `#if os(iOS)` / `#else` / `#endif` guards
- After every shared-file edit session, run the macOS build explicitly:
  ```bash
  xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -10
  ```
- Make this the final step of every phase's definition-of-done checklist

**Warning signs:**
- macOS build fails after an iOS-only review session
- `Cannot find type 'UIViewController' in scope` errors in a ViewModel
- `UIApplication` referenced from any file in `ILSApp/ILSApp/` (not `ILSMacApp/`)

**Phase to address:** Every phase — embed macOS build verification in each phase's done criteria.

---

## Moderate Pitfalls

---

### Pitfall 7: APIClient Cache Not Invalidated After Host Profile Switch

**What goes wrong:**
`APIClient` has an `NSCache`-backed response cache with per-endpoint TTLs (5 minutes for skills/plugins/MCP, 60 seconds for config). When a user switches to a different host profile and `ConnectionManager.updateServerURL()` creates a new `APIClient`, the cache starts empty for the new client. However, any ViewModel still holding a reference to the old `APIClient` instance serves stale cached data from the previous host — because the old instance's cache is still alive.

Additionally: if the new host happens to respond at the same paths with different content (same `APIClient` key, different host), any ViewModels that were NOT refreshed after the switch continue to show old data with no indication it is stale.

**How to avoid:**
- After profile switch, explicitly call `appState.apiClient.invalidateCache()` (the parameterless version that clears all entries) before any ViewModel reloads from the new host
- ViewModels that hold a direct `client` reference must re-`configure()` after profile switch — this is best achieved by passing `appState.apiClient` directly at call time rather than caching it at `configure()` time

**Warning signs:**
- Browser shows skills from previous host for several minutes after profile switch
- Config section in Settings shows the previous host's model and settings
- Pull-to-refresh is the only way to get current data after switching hosts

**Phase to address:** Host Profiles redesign phase — coordinate cache invalidation with the profile switch flow.

---

### Pitfall 8: SSEClient Zombie Connection After Host Switch

**What goes wrong:**
`ConnectionManager.updateServerURL()` creates a new `SSEClient`, but any `ChatViewModel` that holds a reference to the old `SSEClient` (captured at ViewModel creation time) maintains an open SSE connection to the old host. This is a zombie connection — it consumes network resources and may receive events that update the wrong UI.

The existing `SSEClient` heartbeat watchdog (`LastActivityTracker`) does not detect host-mismatch, only inactivity. A zombie connection to a still-responsive old host never trips the watchdog.

**How to avoid:**
- When profile switches, disconnect any active `SSEClient` connections before creating the new one: `oldSSEClient.disconnect()` (already implemented in `SSEClient`)
- `ChatViewModel` should observe `appState.isConnected` changes (it already does via `onChange(of: appState.isConnected)`) and reconnect — but it must also detect URL changes, not just connection state changes
- Consider adding `appState.serverURL` to the observation chain in `ChatViewModel`

**Warning signs:**
- After switching profiles, chat messages appear to send successfully but the response comes from the old host's Claude session
- Two SSE connections visible in Instruments → Network when only one should exist
- Old host's chat stream events appear in the new host's chat UI

**Phase to address:** Host Profiles redesign phase.

---

### Pitfall 9: Config Scope Semantics Mismatch — "User" Config Is Not "Effective" Config

**What goes wrong:**
The Settings sync feature loads config via `GET /config?scope=user`, which reads `~/.claude/config.json`. But Claude CLI applies a three-level merge: local (project `.claude/config.json`) overrides project (workspace) overrides user. The app showing "user" scope config as "host defaults" is misleading — if the user has a project-level config overriding their model, the app shows the user-level default, not what Claude CLI actually uses.

`ConfigController.get()` reads the literal file for the requested scope — there is no effective/merged config endpoint.

**How to avoid:**
- Either add a `/config/effective` endpoint to the backend that performs scope merging (the correct approach), or
- Clearly label the displayed config as "User defaults (~/.claude/config.json)" — not "Host defaults" or "Active settings"
- Show a note: "Project-level configs may override these values when Claude Code runs in a specific project"
- Do not advertise this as "inheriting from CLI" when it is only inheriting from user scope

**Warning signs:**
- User sets model to `claude-haiku-4-5` in CLI project config but app shows `claude-sonnet-4-5` as "active"
- Support request: "App shows wrong model — my actual sessions use a different model"

**Phase to address:** Settings & Defaults Sync phase — set correct scope expectations before building the UI.

---

### Pitfall 10: HostProfilesViewModel Duplicated APIClient — Not Sharing AppState's Client

**What goes wrong:**
`HostProfilesViewModel` creates its own `APIClient()` in its initializer with no arguments, which defaults to `AppConstants.defaultServerURL`. This means:
1. The ViewModel always hits `localhost:9999` regardless of what `AppState.serverURL` is set to
2. If the user changes server URL in Settings, `HostProfilesViewModel` does not pick it up
3. When `HostProfilesView` is displayed, it talks to a different endpoint than every other view in the app if the server URL was customized

**How to avoid:**
`HostProfilesViewModel` must receive its `APIClient` from `AppState`, not construct one internally. Either:
- Pass `appState.apiClient` at `HostProfilesView.task` time via `viewModel.configure(client: appState.apiClient)` (consistent with every other ViewModel's pattern)
- Or pass `AppState` directly to the ViewModel so it can read `appState.apiClient` dynamically

The `FleetViewModel` typealias existing at the bottom of `HostProfilesViewModel.swift` suggests this ViewModel predates the AppState architecture — it needs to be brought in line.

**Warning signs:**
- `HostProfilesView` shows different data than other screens for the same host
- Health polling hits `localhost:9999` even when user configured a remote server
- Profile registration fails silently because the request goes to the wrong endpoint

**Phase to address:** Host Profiles redesign phase — fix the APIClient injection before adding any new functionality.

---

### Pitfall 11: `try?` on Fleet Mutating Operations Silently Eats Activation Errors

**What goes wrong:**
In `HostProfilesViewModel.activate()` and `remove()`:
```swift
let updated: FleetHost? = try? await apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
```
If the POST fails (network error, wrong host, 404 because the backend doesn't know about this fleet host), `updated` is `nil` and the error is silently discarded. The UI then shows the profile as "Active" because `activeHostId = id` is set unconditionally after a nil result:
```swift
if updated != nil {
    activeHostId = id
```
Wait — actually this correctly guards, so the UI won't update on nil. But the user gets NO feedback that activation failed — the context menu dismisses and nothing appears to have changed.

**How to avoid:**
Replace `try?` with `do/catch` in all fleet mutation operations. Surface errors to the UI via a `loadError` or a new `activationError` property. The existing `loadError: String?` could be repurposed or a new `actionError: String?` added for transient feedback.

**Warning signs:**
- User taps "Activate" and nothing happens — no feedback, no error, no state change
- Profile switch appears to succeed in the UI but subsequent API calls still go to old host

**Phase to address:** Host Profiles redesign phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `HostProfilesViewModel.init(apiClient: APIClient = APIClient())` | No AppState dependency needed at init | Always hits localhost:9999 regardless of configured URL; profile switching doesn't update the client | Never — fix in Host Profiles phase |
| Full `ClaudeConfig` struct write-back on any field change | Simple one-call save | Silently drops fields not rendered in the app UI (hooks, env, permissions) | Never for write operations — always read-then-patch |
| Hardcoded `main` branch in `fetchRawContent` | Works for 80% of GitHub repos | Silent install failures for `master`-defaulting repos | Acceptable as v3.1 quick fix only if `master` fallback is added |
| `try?` on fleet activation/remove | Shorter code, no error handling boilerplate | User gets no feedback when operations fail | Never for mutating operations visible to the user |
| `isLoading` shared between local list load and GitHub install in `SkillsViewModel` | One flag, simple | Install button shows loading state while local list refreshes post-install, blocking UX unnecessarily | Acceptable for v3.1; separate into `isInstallingFromGitHub` for better UX |
| `@State private var skillsVM` inside `BrowserView` | Clean ownership, simple state | ViewModel destroyed on every screen switch; in-progress installs orphaned | Consider lifting to `SidebarRootView` level for persistence |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `APIClient` actor + `@MainActor` ViewModels | Forgetting `await` when calling actor methods from `@MainActor` context | Always `await` actor calls — actor isolation is compatible with `@MainActor` but explicit `await` is always required |
| GitHub Code Search API | Changing search strategy to search repo descriptions instead of `filename:SKILL.md` | Keep current `filename:SKILL.md` strategy — it correctly limits results to repos with skill files rather than any repo mentioning the search term |
| `ConfigController` `PUT /config` | Sending only changed fields expecting server merge | Server writes the full payload verbatim — always send complete config with delta applied, never partial |
| `FleetController` activate endpoint | Assuming activation also switches the backend's own active client | `POST /fleet/{id}/activate` only persists the selection in SQLite — app must separately call `appState.updateServerURL()` |
| SSEClient after host switch | Assuming new `SSEClient` cancels the old one's connections | `updateServerURL()` creates a new `SSEClient` instance; any ViewModel still holding a reference to the old instance must explicitly call `.disconnect()` |
| `readConfig(scope: "user")` for CLI defaults display | Assuming this returns merged effective config | Returns only the user-scope file content — project and local overrides are not included; label clearly as "User defaults" |
| `GITHUB_TOKEN` configuration | Putting GitHub token in iOS Keychain | Token is needed by the Vapor backend process — must be in the host's shell environment, not in the iOS app; the app only stores the ILS API key in Keychain |
| New ViewModel with `configure(client:)` pattern | Calling `configure()` once at view creation and never again | After `updateServerURL()`, the old captured client is stale — either re-`configure()` on reconnect or read from `appState.apiClient` at call time |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing `GITHUB_TOKEN` in iOS Keychain | Token intended for backend process sent over network to iOS app — unnecessary exposure; the app cannot use it directly | Document that `GITHUB_TOKEN` is a backend environment variable, not an app secret; Settings UI should explain where to set it |
| Displaying raw `config.path` from backend | Exposes full host filesystem layout (e.g., `/Users/nick/.claude/config.json`) to any screen capturer | Truncate displayed paths to relative form (`~/.claude/config.json`); `SettingsView` already uses `.screenshotProtected()` — preserve this modifier on any new config-sync views |
| Installing GitHub skills without content size validation | Malicious `SKILL.md` with extreme size could exhaust host disk | `SkillsController.create()` enforces 1MB content limit — verify `install()` applies the same limit to fetched GitHub content before writing to disk; currently it does not |
| Deep link `ils://profiles/activate/{id}` if added | Malicious app or webpage could silently switch active host | Do not add activation as a deep link parameter — activation requires explicit in-app user gesture only |
| New Host Profile fields (SSH key content) stored in UserDefaults | Plaintext credentials in UserDefaults readable by other processes on a jailbroken device | All credential fields (SSH keys, passwords, passphrases) must use `KeychainService.saveSync()` — never `UserDefaults.standard.set()` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No persistent active host indicator outside Host Profiles screen | User cannot tell which host they are connected to from Home, Chat, or Settings | Add active profile name/icon to `SidebarView` header — one persistent indicator always visible in sidebar |
| Config sync shows raw Claude CLI field names | `alwaysThinkingEnabled`, `includeCoAuthoredBy` are developer-facing names | Map to human labels: "Extended thinking (always on)", "Include Claude attribution in commits" with info tooltips |
| GitHub install success has no durable confirmation | `isLoading` clears and skill appears in list — but list may be long; user may miss it | Show a brief "Installed" badge or `HapticManager.impact(.medium)` + inline HUD for 3 seconds after install |
| Config scope picker not shown in settings sync UI | User does not know whether they are editing user-scope or project-scope defaults | Default to user scope with a visible label "Editing ~/.claude/config.json"; project scope is power-user via a separate disclosure |
| "Activate" buried in context menu ellipsis | Primary action (switch host) two taps deep in an ellipsis; easy to miss | Make row tap = show profile details with a prominent "Set as Active Host" button; ellipsis = secondary actions (edit, remove) |
| No feedback when profile activation fails due to network error | User taps Activate, context menu dismisses, nothing changes — silent failure | Always show success or failure feedback: `HapticManager.impact(.medium)` on success, an error alert on failure |

---

## "Looks Done But Isn't" Checklist

- [ ] **Host Profile switch:** Verify `appState.serverURL` actually changed after activation — check `curl http://{new-host}/health` responds; old host does NOT appear in `lsof -i :9999` if localhost was previous
- [ ] **Config sync read-only fields:** Save a config with hooks configured on the host; change the model in the iOS app; read the config file on the host and verify hooks are still present
- [ ] **GitHub install on correct host:** Install a skill from GitHub; switch profiles; verify the skill is on the originally-intended host's backend, not the newly-switched-to host
- [ ] **GitHub rate limit error:** Exhaust rate limit (or mock HTTP 429 from backend); verify the error message is user-readable with guidance, not "HTTP error: 429"
- [ ] **macOS build:** Every new shared Swift file must compile with `ILSMacApp` scheme — run the macOS build check after every phase
- [ ] **SSEClient cleanup:** After profile switch, verify no zombie SSE connections remain to old host — check Instruments Network or `lsof -i TCP`
- [ ] **Health polling stop:** Navigate away from Host Profiles screen; verify `stopHealthPolling()` was called — no repeated network calls in Console
- [ ] **Keychain storage:** Any new credential fields in Host Profiles redesign — verify they appear in Keychain and not in UserDefaults (check via `UserDefaults.standard.dictionaryRepresentation()`)
- [ ] **Override indicators:** For each config field shown in the sync UI, verify the UI correctly distinguishes "CLI default" from "app override"
- [ ] **Branch fallback:** Install a skill from a GitHub repo with `master` as default branch — verify it succeeds with the fallback or shows a clear error (not a generic 404)
- [ ] **`fetchRawContent` skill content size:** Install a skill from a repo with a large SKILL.md (>1MB) — verify the backend rejects it with a clear error, not a silent truncation

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Profile switch doesn't rebuild downstream clients | HIGH | Refactor `HostProfilesViewModel` to receive `AppState`; update `activate()` to call `appState.updateServerURL()`; add reload triggers to all browser VMs; coordinate with ConnectionManager and SSEClient cleanup |
| Config sync drops CLI hooks/env fields | MEDIUM | Add write allowlist to `SettingsViewModel.saveConfig()`; add read-before-write on all PUT calls; one additional network round-trip per save |
| GitHub install fails on `master` branch repos | LOW | Add branch fallback in `GitHubService.fetchRawContent()` — try `main`, then `master`, then return descriptive error; no model changes required |
| macOS build broken by iOS-only import | LOW | Wrap with `#if os(iOS)` guard or extract to iOS-only file; auto-build hook surfaces this on next edit; typically a 5-minute fix |
| Rate limit shows opaque 429 error | LOW | Add 429 detection in `SkillsViewModel.searchGitHub()` error handler; show user-readable message; no architecture changes needed |
| In-flight install abandoned on navigation | MEDIUM | Track install task in `SkillsViewModel` for cancellation; lift ViewModel to SidebarRootView level OR add profile-switch guard while install is in progress |
| `try?` on fleet mutations hiding errors | LOW | Replace with `do/catch`; add `actionError: String?` property; show error alert or banner in `HostProfilesView` |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Profile switch doesn't rebuild downstream clients | Host Profiles redesign | After activate, confirm `appState.serverURL` changed AND Browser/Settings show data from new host |
| Config sync drops unrendered fields | Settings & Defaults Sync | Change model in app; verify hooks still in `~/.claude/config.json` on host machine |
| GitHub rate limit with no user guidance | Browse, Skills & Plugins | Mock HTTP 429; verify error message is actionable |
| `fetchRawContent` hardcoded to `main` | Browse, Skills & Plugins | Install from a `master`-default repo; verify success or clear error |
| In-flight install abandoned on nav | Navigation/UX overhaul + Host Profiles | Start install, switch profiles, return — verify install completed on intended host |
| macOS build broken by iOS-only code | Every phase | Every phase done criteria must include ILSMacApp build check |
| Credentials in UserDefaults | Host Profiles redesign | Add SSH key via new profile UI; confirm it appears in Keychain, not UserDefaults |
| SSEClient zombie after host switch | Host Profiles redesign | Switch profile while chat is open; verify no old-host SSE connections in Instruments |
| Config scope mismatch (user != effective) | Settings & Defaults Sync | Set UI label to "User defaults"; verify no claim of "active" or "effective" config |
| `try?` hiding fleet activation errors | Host Profiles redesign | Force a network failure during activate; verify error feedback is shown to user |
| No active host indicator | Navigation/UX overhaul | From Home, Settings, Chat — verify which host is active without visiting Host Profiles screen |

---

## Sources

- Direct code inspection: `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` — `init(apiClient: APIClient = APIClient())` disconnected from AppState; `activate()` does not call `appState.updateServerURL()`; `try?` on mutation operations
- Direct code inspection: `ILSApp/ILSApp/Services/ConnectionManager.swift` — `updateServerURL()` recreates `apiClient` and `sseClient` in-place; no broadcast to downstream ViewModels
- Direct code inspection: `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` — full `ClaudeConfig` struct write in `saveConfig()`; no field-level merge; fields like `hooks`, `env` travel as optionals
- Direct code inspection: `Sources/ILSShared/Models/ClaudeConfig.swift` — all config fields are `var` optionals; `nil` means "not set" but round-trips through JSON as field omission
- Direct code inspection: `Sources/ILSBackend/Services/GitHubService.swift` — `main` hardcoded in `fetchRawContent()`; 60-request unauthenticated rate limit; `GITHUB_TOKEN` from environment only
- Direct code inspection: `Sources/ILSShared/DTOs/SearchResult.swift` — `GitHubRepository` has no `defaultBranch` field
- Direct code inspection: `Sources/ILSBackend/Controllers/SkillsController.swift` — `install()` enforces no content size limit on GitHub-fetched content (unlike `create()` which enforces 1MB)
- Direct code inspection: `Sources/ILSBackend/Controllers/ConfigController.swift` — `update()` writes full payload verbatim via `fileSystem.writeConfig()`; no server-side merge
- Direct code inspection: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — `switch activeScreen` in `mainContent()` destroys and recreates destination views on every screen change; `@State private var skillsVM` in BrowserView is lost on screen switch
- Direct code inspection: `ILSApp/ILSApp/AppState.swift` — `updateServerURL()` delegates to `connectionManager`; no automatic broadcast to child ViewModels
- Direct code inspection: `ILSApp/ILSMacApp/ILSMacApp.swift` — 14 macOS-specific files; shared iOS files in `ILSApp/ILSApp/` compile into both targets
- Project memory: Known pitfalls from prior milestones — `CryptoKit` vs `Crypto` import, env var stripping for Claude CLI, `nonisolated(unsafe)` for Task properties in deinit, wrong backend binary at `/Users/nick/ils/ILSBackend/`

---
*Pitfalls research for: ILS iOS/macOS — v3.1 new features (config sync, GitHub browsing/install, Host Profiles redesign, navigation/UX overhaul)*
*Researched: 2026-02-24*
