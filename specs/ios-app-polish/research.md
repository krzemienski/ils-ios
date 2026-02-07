---
spec: ios-app-polish
phase: research
created: 2026-02-06T16:50:00-05:00
---

# Research: ios-app-polish

## Executive Summary

The ILS iOS app has a solid architectural foundation (MVVM + Vapor backend, SwiftUI, SSE streaming) but suffers from **multiple broken end-to-end flows, dead-end features, and misleading UI**. The backend has 30+ endpoints; the iOS client calls roughly half of them. Critical issues: (1) server URL IS configurable in Settings but has no first-run prompt, (2) SSH/Fleet features are stubs with no real functionality, (3) chat works for new sessions but external sessions are read-only by design (poorly communicated), (4) plugin install is a backend placeholder returning fake data, (5) projects are read from `~/.claude/projects/` filesystem (not DB-created), causing confusion when "Create Project" stores to DB but never appears in the list.

## API Endpoint Catalog

### Backend Routes (Sources/ILSBackend/Controllers/)

| # | Route | Method | Controller | iOS Client Calls? | Notes |
|---|-------|--------|------------|-------------------|-------|
| 1 | `/health` | GET | configure.swift | YES (healthCheck) | Plain string or JSON |
| 2 | `/api/v1/sessions` | GET | SessionsController | YES | List sessions, optional `?projectId=` filter |
| 3 | `/api/v1/sessions` | POST | SessionsController | YES | Create session (DB) |
| 4 | `/api/v1/sessions/scan` | GET | SessionsController | **NO** | Scan external Claude Code sessions from `~/.claude/projects/` |
| 5 | `/api/v1/sessions/:id` | GET | SessionsController | **NO** | Get single session |
| 6 | `/api/v1/sessions/:id` | DELETE | SessionsController | YES | Delete session |
| 7 | `/api/v1/sessions/:id/fork` | POST | SessionsController | YES | Fork session |
| 8 | `/api/v1/sessions/:id/messages` | GET | SessionsController | YES | Get messages (DB sessions) |
| 9 | `/api/v1/sessions/transcript/:path/:id` | GET | SessionsController | YES | Read external JSONL transcript |
| 10 | `/api/v1/chat/stream` | POST | ChatController | YES (SSEClient) | SSE streaming via Claude CLI |
| 11 | `/api/v1/chat/ws/:sessionId` | WS | ChatController | **NO** | WebSocket chat (unused) |
| 12 | `/api/v1/chat/permission/:requestId` | POST | ChatController | **NO** | Permission decisions (stub) |
| 13 | `/api/v1/chat/cancel/:sessionId` | POST | ChatController | **NO** | Cancel active CLI process |
| 14 | `/api/v1/projects` | GET | ProjectsController | YES | List from `~/.claude/projects/` filesystem |
| 15 | `/api/v1/projects` | POST | ProjectsController | YES | Create project (DB) |
| 16 | `/api/v1/projects/:id` | GET | ProjectsController | **NO** | Get single project |
| 17 | `/api/v1/projects/:id` | PUT | ProjectsController | YES | Update project |
| 18 | `/api/v1/projects/:id` | DELETE | ProjectsController | YES | Delete project |
| 19 | `/api/v1/projects/:id/sessions` | GET | ProjectsController | **NO** | Sessions for project |
| 20 | `/api/v1/skills` | GET | SkillsController | YES | List skills from filesystem |
| 21 | `/api/v1/skills` | POST | SkillsController | **NO** | Create skill |
| 22 | `/api/v1/skills/search` | GET | SkillsController | **NO** | GitHub search |
| 23 | `/api/v1/skills/install` | POST | SkillsController | **NO** | Install from GitHub |
| 24 | `/api/v1/skills/:name` | GET | SkillsController | **NO** | Get single skill |
| 25 | `/api/v1/skills/:name` | PUT | SkillsController | **NO** | Update skill |
| 26 | `/api/v1/skills/:name` | DELETE | SkillsController | **NO** | Delete skill |
| 27 | `/api/v1/mcp` | GET | MCPController | YES | List MCP servers |
| 28 | `/api/v1/mcp/:name` | GET | MCPController | **NO** | Get single MCP |
| 29 | `/api/v1/mcp` | POST | MCPController | **NO** | Add MCP server |
| 30 | `/api/v1/mcp/:name` | PUT | MCPController | **NO** | Update MCP server |
| 31 | `/api/v1/mcp/:name` | DELETE | MCPController | **NO** | Remove MCP server |
| 32 | `/api/v1/plugins` | GET | PluginsController | YES | List installed plugins |
| 33 | `/api/v1/plugins/search` | GET | PluginsController | YES (marketplace search) | Search installed plugins |
| 34 | `/api/v1/plugins/marketplace` | GET | PluginsController | YES | List marketplaces |
| 35 | `/api/v1/plugins/marketplaces` | POST | PluginsController | YES | Add marketplace |
| 36 | `/api/v1/plugins/install` | POST | PluginsController | YES | **PLACEHOLDER** — returns fake data |
| 37 | `/api/v1/plugins/:name/enable` | POST | PluginsController | YES | Enable plugin |
| 38 | `/api/v1/plugins/:name/disable` | POST | PluginsController | YES | Disable plugin |
| 39 | `/api/v1/plugins/:name` | DELETE | PluginsController | YES | Uninstall plugin |
| 40 | `/api/v1/stats` | GET | StatsController | YES | Dashboard stats |
| 41 | `/api/v1/stats/recent` | GET | StatsController | **NO** | Recent sessions for dashboard |
| 42 | `/api/v1/settings` | GET | StatsController | **NO** | Raw settings.json |
| 43 | `/api/v1/config` | GET | ConfigController | YES | Get config by scope |
| 44 | `/api/v1/config` | PUT | ConfigController | YES | Update config |
| 45 | `/api/v1/config/validate` | POST | ConfigController | **NO** | Validate config |
| 46 | `/api/v1/server/status` | GET | StatsController | **NO** | SSH server status |
| 47 | `/api/v1/auth/connect` | POST | AuthController | **NO** | SSH connect |
| 48 | `/api/v1/auth/disconnect` | POST | AuthController | **NO** | SSH disconnect |

**Summary**: 48 backend endpoints. iOS app calls ~22 (46%). 26 endpoints are completely unused by the iOS client.

## Functional Issues

### P0 — Critical (App non-functional for core use case)

| # | Issue | Location | Root Cause |
|---|-------|----------|------------|
| F1 | **Plugin install is a placeholder** | `PluginsController.install()` L217-233 | Returns hardcoded fake `Plugin` object without actually cloning/installing anything. Comment says "In a real implementation, this would clone from the marketplace." |
| F2 | **Projects list shows filesystem projects but Create saves to DB** | `ProjectsController.index()` reads `~/.claude/projects/` dirs; `create()` saves to `ProjectModel` DB table | Two completely separate data sources. User creates project via UI -> saved to SQLite -> never appears in the list (which reads filesystem). Projects from filesystem get random UUIDs on each request. |
| F3 | **No session cancellation from iOS** | `ChatController.cancel()` exists but iOS never calls it | SSEClient.cancel() only cancels the URLSession task locally; doesn't notify backend to kill the Claude CLI process. |
| F4 | **External sessions are read-only but this is not clear before entering** | `ChatView.swift` L29-33 | `isExternalSession` check shows different banner at bottom, but the session list shows external sessions mixed with ILS sessions with no upfront indicator that they can't be chatted in. |

### P1 — High (Feature broken or misleading)

| # | Issue | Location | Root Cause |
|---|-------|----------|------------|
| F5 | **SSH connection test is simulated** | `SSHConnectionManager.testConnection()` L84-88 | Just sleeps 1.5s and returns `!host.isEmpty && !username.isEmpty`. No real SSH connection attempted. |
| F6 | **Fleet Management is entirely hardcoded** | `FleetManagementView.swift` | Uses local mock `RemoteServer` array. No backend calls, no real server discovery. |
| F7 | **No first-run / onboarding flow** | `ILSAppApp.swift` | App launches to Sessions tab with "No connection to backend" banner but no guided setup. User must navigate to Settings to find server URL field. |
| F8 | **WebSocket chat endpoint unused** | `ChatController.handleWebSocket()` | Backend has WS support but iOS client only uses SSE POST endpoint. |
| F9 | **Permission handling is a no-op** | `ChatController.permission()` L148-162 | Comment: "In a full implementation, this would communicate with the running Claude process." Just logs and returns OK. |
| F10 | **Marketplace search searches installed plugins, not marketplace** | `PluginsController.search()` vs `MarketplaceView.searchable` | Marketplace search bar calls `viewModel.searchMarketplace()` which calls `/plugins/search?q=` — but that endpoint filters INSTALLED plugins only, not marketplace items. |
| F11 | **Chat cancel doesn't notify backend** | `SSEClient.cancel()` | Only cancels local URLSession task. Backend Claude CLI process keeps running. Should call `/chat/cancel/:sessionId`. |
| F12 | **Session scan endpoint never used in sessions list** | `SessionsController.scan()` | Sessions list calls `GET /sessions` (DB only). External sessions from `~/.claude/projects/` would come from `GET /sessions/scan` which is never called by the client. |

### P2 — Medium (Missing feature or poor UX)

| # | Issue | Location | Root Cause |
|---|-------|----------|------------|
| F13 | **No skill detail view** | `SkillsListView` | Skills list exists but tapping a skill does nothing — no detail view, no content preview. |
| F14 | **No MCP server CRUD from iOS** | MCPServerListView | List view only. No add/edit/delete UI despite backend supporting full CRUD. |
| F15 | **No skill install from iOS** | Skills views | Backend has `POST /skills/install` (GitHub fetch) and `GET /skills/search` (GitHub search) but iOS has no UI for either. |
| F16 | **Dashboard doesn't use recent sessions** | DashboardView | Backend has `GET /stats/recent` but Dashboard only uses `GET /stats` for counts. |
| F17 | **Config validation endpoint unused** | ConfigController.validate() | Backend can validate config but iOS never calls it before saving. |
| F18 | **No message deletion** | Chat flow | Can delete sessions but not individual messages. |
| F19 | **Session creation doesn't pass all form fields** | `NewSessionView.createSession()` L195-206 | Form collects systemPrompt, maxBudget, maxTurns, fallbackModel but `CreateSessionRequest` only sends name, projectId, model. Options are built in `buildChatOptions()` but never sent to the backend. |
| F20 | **Project sessions list navigation** | `ProjectDetailView` L57-63 | `ProjectSessionsListView` exists but since projects get random UUIDs per request, filtering sessions by projectId won't work for filesystem-sourced projects. |

## UX Issues

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| U1 | No first-run setup | High | App opens to empty sessions list with red "No connection" banner. User has no guidance on what to do. |
| U2 | Disconnected state is passive | High | Red banner says "No connection to backend" with small "Retry" button. Should actively prompt for server URL if never configured. |
| U3 | External vs ILS sessions not distinguished in list | High | Both types appear in same list. External sessions show small "Claude Code" badge at bottom of row, but it's easy to miss. Tapping leads to read-only view with no warning beforehand. |
| U4 | Two "New Session" buttons | Low | Both toolbar `+` button and FAB button do same thing. FAB was added for automation testing but is redundant UX. |
| U5 | Project picker in NewSession is confusing | Medium | Shows DB-created projects (likely empty) not filesystem projects. User sees "No Project" option and maybe some stale DB entries, not their actual Claude Code project directories. |
| U6 | Settings page is very long | Medium | 11 sections in one scrolling form. Connection, General, Quick Settings, API Key, Permissions, Config Management, Advanced, Statistics, Remote Management, Diagnostics, Cache, About. |
| U7 | Quick Settings duplicates General section | Low | Model picker appears in both "General" (with edit toggle) and "Quick Settings" (always editable). Confusing which to use. |
| U8 | Empty states are inconsistent | Low | Some views show custom `EmptyStateView`, others show `ContentUnavailableView`. Tone/style varies. |
| U9 | No loading indicator for session creation | Medium | `isCreating` shows ProgressView in toolbar but no overlay/blocking indicator. User can navigate away. |
| U10 | SSH has no purpose visible to user | High | SSH Connections view says "Add a remote server to manage Claude Code remotely" but there's nothing to manage. No host metrics, no remote command execution, no log viewing from remote. |
| U11 | Marketplace categories are hardcoded and non-functional | Low | Categories ["All", "Productivity", "DevOps", "Testing", "Documentation"] filter by checking if plugin description contains category name. No actual categorization exists. |
| U12 | No confirmation on server URL change | Medium | Changing server URL in Settings and pressing Enter immediately changes the backend target. No "are you sure?" for destructive action. |

## 10+ User Scenarios (Complete User Journeys)

### Scenario 1: First Launch & Server Setup
**Endpoints**: `/health`, `GET /stats`, `GET /config?scope=user`
1. User installs app, opens for first time
2. Sees "disconnected" state
3. Goes to Settings > Backend Connection
4. Types server URL (e.g., `http://192.168.1.100:9090`)
5. Taps "Test Connection"
6. Sees green "Connected" status
7. Returns to Dashboard, sees real stats
**Current status**: PARTIALLY WORKS — Settings has URL field, test button, and connection indicator. But no first-run prompt, user must discover Settings manually.

### Scenario 2: Browse & Open Existing Claude Code Session (Read-Only)
**Endpoints**: `GET /sessions` (or `GET /sessions/scan`), `GET /sessions/transcript/:path/:id`
1. User sees sessions list populated with Claude Code sessions
2. Identifies an external session (from terminal CLI usage)
3. Taps to open
4. Sees read-only transcript of the conversation
5. Sees "Read-only Claude Code session" banner at bottom
**Current status**: BROKEN — `GET /sessions` returns DB sessions only, not external ones. `GET /sessions/scan` is never called. External sessions never appear in the list.

### Scenario 3: Create New Session & Chat
**Endpoints**: `POST /sessions`, `POST /chat/stream` (SSE), `GET /sessions/:id/messages`
1. User taps "+" to create new session
2. Selects project (optional), model, name
3. Session created, navigates to ChatView
4. Types message, taps send
5. Sees typing indicator, then streamed response
6. Sends follow-up message, conversation continues
**Current status**: PARTIALLY WORKS — Session creation works (DB). Chat streaming works IF Claude CLI is available on the backend host. But session creation doesn't auto-navigate to chat; user must find the new session in the list.

### Scenario 4: Chat in Multiple Projects
**Endpoints**: `GET /projects`, `POST /sessions` (x3), `POST /chat/stream` (x3)
1. User creates sessions in 3 different projects
2. Sends messages in each
3. Switches between sessions to verify isolation
4. Each session maintains its own conversation context
**Current status**: BROKEN — Projects list reads filesystem, session creation uses DB project IDs. The two don't match. Creating a session "in" a filesystem project doesn't link correctly because filesystem projects get random UUIDs per request.

### Scenario 5: Resume Existing Session
**Endpoints**: `GET /sessions`, `GET /sessions/:id/messages`, `POST /chat/stream` (with resume)
1. User opens app, sees previous sessions
2. Taps a session from earlier today
3. Sees message history loaded
4. Sends new message in same session
5. Claude responds with context of previous conversation
**Current status**: PARTIALLY WORKS — History loads. Chat streaming sends `sessionId` and `options.resume` with `claudeSessionId`. But the resume flow depends on Claude CLI `--resume` flag working correctly with the stored session ID.

### Scenario 6: Fork & Experiment
**Endpoints**: `POST /sessions/:id/fork`, `POST /chat/stream`
1. User is in a session, wants to try alternative approach
2. Taps menu > Fork Session
3. Gets confirmation alert with new session name
4. Opens forked session
5. Sends different message to explore alternative
**Current status**: PARTIALLY WORKS — Fork creates DB entry. Alert shows. But forked session doesn't auto-open; user must navigate back to list and find it.

### Scenario 7: MCP Server Management
**Endpoints**: `GET /mcp`, `POST /mcp`, `PUT /mcp/:name`, `DELETE /mcp/:name`, `GET /mcp/:name`
1. User goes to MCP Servers tab
2. Sees list of configured MCP servers
3. Taps "+" to add a new server (name, command, args, env)
4. Edits an existing server's configuration
5. Deletes a server
6. Pulls to refresh
**Current status**: BROKEN — MCPServerListView is read-only. No add/edit/delete UI despite backend supporting full CRUD. Only list + refresh works.

### Scenario 8: Settings Configuration
**Endpoints**: `GET /config?scope=user`, `PUT /config`, `GET /stats`, `GET /health`
1. User goes to Settings
2. Changes default model from Sonnet to Opus
3. Saves configuration
4. Verifies change persisted (pull to refresh)
5. Views statistics (projects, sessions, skills counts)
6. Checks Claude CLI version in About section
**Current status**: WORKS — Model picker saves via PUT /config. Stats load. Claude version shows from health endpoint.

### Scenario 9: Plugin Management
**Endpoints**: `GET /plugins`, `POST /plugins/:name/enable`, `POST /plugins/:name/disable`, `DELETE /plugins/:name`, `GET /plugins/marketplace`, `POST /plugins/install`
1. User views installed plugins list
2. Toggles a plugin on/off
3. Opens Marketplace
4. Finds a plugin to install
5. Taps "Install"
6. Plugin appears in installed list
7. Uninstalls a plugin (swipe to delete)
**Current status**: PARTIALLY BROKEN — List, toggle, uninstall work. Marketplace shows hardcoded entries. Install returns fake data without actually installing. "Add from GitHub" registers marketplace source but doesn't install plugins.

### Scenario 10: Skill Discovery & Install
**Endpoints**: `GET /skills`, `GET /skills/search?q=`, `POST /skills/install`, `GET /skills/:name`, `DELETE /skills/:name`
1. User views skills list
2. Searches for a skill on GitHub
3. Finds one, installs it
4. Views skill content/details
5. Deletes a skill they no longer need
**Current status**: BROKEN — Skills list shows local skills. No search UI, no install UI, no detail view. All 5 skill management endpoints unused from iOS.

### Scenario 11: SSH Remote Server Management
**Endpoints**: `POST /auth/connect`, `GET /server/status`, `POST /auth/disconnect`
1. User goes to Settings > SSH Connections
2. Adds a remote server (host, username, auth)
3. Tests connection
4. Views server status (Claude Code version, system info)
5. Manages Claude Code on remote server
**Current status**: BROKEN — SSH connection form saves to local UserDefaults only. Test is simulated (sleep + return true). No actual SSH connection, no backend API calls, no remote management capability.

### Scenario 12: Config Profiles & Overrides
**Endpoints**: `GET /config?scope=user`, `GET /config?scope=project`, `PUT /config`
1. User views config profiles (user vs project)
2. Sees override visualization (which settings come from where)
3. Views config history
4. Edits raw user config JSON
5. Edits raw project config JSON
**Current status**: PARTIALLY WORKS — Raw config editor for user/project scope works. ConfigProfilesView, ConfigOverridesView, ConfigHistoryView exist but display hardcoded/mock data (not from API).

### Scenario 13: Cancel Active Stream
**Endpoints**: `POST /chat/cancel/:sessionId`
1. User sends message, streaming starts
2. Realizes wrong prompt, taps stop button
3. Stream stops, backend Claude CLI process terminates
4. User can send new message
**Current status**: PARTIALLY BROKEN — Stop button cancels local SSE connection. Backend Claude CLI process may keep running. Should call cancel endpoint.

## Architecture Assessment

### Sound Design Decisions
- **MVVM pattern** with SwiftUI is appropriate
- **Actor-based APIClient** with generic methods prevents boilerplate
- **SSEClient** with proper reconnection logic and batched UI updates
- **Backend reading `~/.claude/` filesystem** directly for projects, skills, MCP, plugins — correct approach
- **ILSShared** package for shared models between iOS and backend
- **Health polling with retry** for connection management

### Fundamental Architecture Problems

1. **Dual data source for projects**: Backend `GET /projects` reads filesystem, `POST /projects` writes to SQLite DB. These never sync. The iOS "Create Project" feature is essentially broken because created projects don't appear in the project list.

2. **Sessions list ignores external sessions**: The sessions list only fetches from DB (`GET /sessions`). The `GET /sessions/scan` endpoint exists to find external Claude Code sessions from `~/.claude/projects/` but is never called. This means the app can't show sessions the user created in their terminal.

3. **SSH is architectural dead weight**: SSHConnectionManager stores connections locally in UserDefaults, tests with a simulated delay, and never communicates with the backend SSHService. The backend has AuthController (connect/disconnect) and StatsController (server/status) for SSH, but the iOS client never calls them.

4. **Plugin install is a stub**: The most user-visible broken feature. The install endpoint returns a fake plugin object. No git clone, no file download, no actual installation.

### What Needs Restructuring vs Quick Fix

| Area | Fix Type | Effort |
|------|----------|--------|
| Server URL first-run | Quick fix — show onboarding sheet on first launch | S |
| External sessions in list | Quick fix — call `/sessions/scan` and merge results | S |
| Cancel notifies backend | Quick fix — call `/chat/cancel/:sessionId` | S |
| Plugin install | Backend change — implement actual git clone or download | M |
| Projects dual data source | **Restructure** — decide: filesystem-only or DB-only for projects | M |
| MCP CRUD UI | New UI — add/edit/delete forms for MCP servers | M |
| Skill detail + install | New UI + integrate existing backend endpoints | M |
| SSH purpose | **Decision needed** — either remove SSH or implement real remote management | L |
| Session auto-navigate after create | Quick fix — NavigationLink after creation | S |

## Related Specs

| Spec | Relevance | mayNeedUpdate |
|------|-----------|---------------|
| `ils-complete-rebuild` | **HIGH** — Comprehensive gap analysis already done. 42 tasks planned. Identifies same dual-data-source problem, SSH issues, missing views. | true — this polish spec may supersede or reprioritize some of those 42 tasks |
| `app-improvements` | **HIGH** — Same goal (UX polish). Stalled at research phase. | true — likely superseded by this spec entirely |
| `agent-teams` | Low — Different domain (agent orchestration). | false |

## Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Build (backend) | `swift build` | Package.swift |
| Run (backend) | `PORT=9090 swift run ILSBackend` | Memory/CLAUDE.md |
| Build (iOS) | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` | Xcode project |
| Lint | Not found | — |
| TypeCheck | Not found (Swift compiler does this during build) | — |
| Unit Test | Not found (per GLOBAL RULES: no unit tests) | — |
| E2E Test | Functional validation via simulator screenshots | GLOBAL RULES |

**Local CI**: `swift build && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build`

## Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | High | All backend endpoints exist. iOS just needs to call them + add UI. |
| Effort Estimate | L | ~15-20 distinct changes across backend (1 real fix) and iOS (15+ view/VM changes) |
| Risk Level | Medium | Projects data source decision is the biggest risk — wrong choice breaks existing data |

## Recommendations for Requirements

1. **Define "projects" source of truth** — Either (a) always read from filesystem and remove DB-based project creation, or (b) sync filesystem projects to DB on startup. Recommend (a) since `~/.claude/projects/` IS the canonical source.

2. **Add first-run onboarding** — Show server URL input sheet on first launch when no URL is saved and connection fails. One screen, one text field, one button.

3. **Merge external sessions into sessions list** — Call `GET /sessions/scan` alongside `GET /sessions`, merge and sort by date. Mark external sessions clearly with icon.

4. **Implement real plugin install** — Backend should `git clone --depth 1` the plugin repo to `~/.claude/plugins/`. The SkillsController already does this pattern for skills.

5. **Add MCP CRUD UI** — PluginsListView-style form for add/edit/delete. Backend already supports it.

6. **Add skill detail view + install flow** — Show skill content, search GitHub, install. Backend endpoints exist.

7. **Remove or defer SSH** — SSH adds complexity with zero user value currently. Recommend removing from v1 Polish pass. The `ils-complete-rebuild` spec can handle SSH later if needed.

8. **Wire cancel to backend** — When user taps stop in chat, call `POST /chat/cancel/:sessionId` before cancelling local stream.

9. **Auto-navigate to chat after session creation** — NewSessionView should emit the created session and ChatView should open immediately.

10. **Clean up Settings** — Merge "General" and "Quick Settings" sections. Remove ConfigProfiles/Overrides/History links if they only show mock data.

11. **Add connection status to session rows** — Show if the backend is connected before letting user attempt to chat.

12. **Fix NewSessionView to pass all options** — System prompt, budget, turns should be sent to the backend or stored for first message.

## Open Questions

1. **Projects: filesystem-only or sync to DB?** — Directly affects session-project linking, project detail/edit, and search.
2. **SSH: remove entirely or stub for future?** — Removing simplifies Settings and removes misleading UI. Keeping means committing to implement real remote management.
3. **External sessions: show in sessions list or separate tab?** — Merged list is simpler; separate tab avoids confusion about read-only vs active.
4. **Plugin install scope** — Should install support only official plugins or any GitHub repo? Current backend marketplace pattern assumes known sources.
5. **Should the app work with zero backend?** — Currently dies ungracefully without backend. Should there be an offline/local mode?

## Sources

- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/SessionsController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ChatController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ProjectsController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/MCPController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/PluginsController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/SkillsController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/StatsController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ConfigController.swift`
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/AuthController.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/APIClient.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/SSEClient.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/SSHConnectionManager.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ILSAppApp.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ContentView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/SettingsView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Sessions/SessionsListView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Sessions/NewSessionView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Chat/ChatView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Plugins/PluginsListView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Projects/ProjectsListView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Projects/ProjectDetailView.swift`
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/SSHConnectionsView.swift`
- `/Users/nick/Desktop/ils-ios/specs/ils-complete-rebuild/.progress.md`
