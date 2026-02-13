---
spec: agent-teams
phase: tasks
total_tasks: 38
created: 2026-02-06T18:15:00Z
---

# Tasks: Agent Teams for ILS iOS

## Phase 1: Make It Work (POC) — Backend Core

Focus: Build all backend services + controllers, verify via curl. Quality-first.

- [ ] 1.1 Create shared models (AgentTeam, TeamMember, TeamTask, TeamMessage)
  - **Do**:
    1. Create `AgentTeam.swift` with `AgentTeam`, `TaskSummary`, `TeamStatus` — all `public struct/enum: Codable, Identifiable, Sendable` with explicit `public init`
    2. Create `TeamMember.swift` with `TeamMember`, `MemberStatus` — include `Hashable` conformance, `isLead` computed property
    3. Create `TeamTask.swift` with `TeamTask`, `TeamTaskStatus` — `isBlocked` computed, `in_progress` raw value
    4. Create `TeamMessage.swift` with `TeamMessage`, `TeamMessageType` — 8 message type cases with raw values
    5. Follow exact patterns from existing `Session.swift`, `Plugin.swift` — `public` access on all types + properties + inits
  - **Files**:
    - `Sources/ILSShared/Models/AgentTeam.swift` (create)
    - `Sources/ILSShared/Models/TeamMember.swift` (create)
    - `Sources/ILSShared/Models/TeamTask.swift` (create)
    - `Sources/ILSShared/Models/TeamMessage.swift` (create)
  - **Done when**: `swift build` compiles with zero errors
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(shared): add Agent Teams models (AgentTeam, TeamMember, TeamTask, TeamMessage)`
  - _Requirements: FR-4_
  - _Design: Shared Models section_

- [ ] 1.2 Create shared DTOs (TeamRequests.swift)
  - **Do**:
    1. Create `TeamRequests.swift` with all request/response DTOs:
       - `CreateTeamRequest` (name, description, teammateMode, workingDirectory, initialPrompt)
       - `SpawnTeammateRequest` (name, agentType, model, prompt, planModeRequired)
       - `CreateTeamTaskRequest` (subject, description, activeForm, owner, blocks, blockedBy)
       - `UpdateTeamTaskRequest` (status, owner, subject, description, addBlocks, addBlockedBy)
       - `SendTeamMessageRequest` (to, content)
       - `SSHTestRequest` (host, port, username, authMethod, credential)
       - `SSHTestResponse` (success, latencyMs, serverInfo, error)
       - `FleetServer` (id, host, port, username, label, status, latencyMs, claudeVersion, lastProbed)
       - `FleetServerStatus` enum (online, offline, degraded, probing, unknown)
    2. All types: `public struct/enum: Codable, Sendable` with explicit `public init`
    3. Follow pattern from existing `Requests.swift`
  - **Files**:
    - `Sources/ILSShared/DTOs/TeamRequests.swift` (create)
  - **Done when**: `swift build` compiles with zero errors
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(shared): add Agent Teams DTOs and SSH/Fleet request types`
  - _Requirements: FR-4_
  - _Design: Team DTOs section_

- [ ] 1.3 Create TeamsFileService (filesystem read/write with flock)
  - **Do**:
    1. Create `TeamsFileService.swift` as `struct` (stateless, like `ConfigFileService`)
    2. Properties: `teamsDirectory` = `~/.claude/teams/`, `tasksDirectory` = `~/.claude/tasks/`
    3. Implement `listTeams()` — scan directories, parse each `config.json`, populate `taskSummary` from task files
    4. Implement `getTeam(name:)` — read single `config.json`, enrich with task counts
    5. Implement `deleteTeamFiles(name:)` — remove both `teams/{name}/` and `tasks/{name}/`
    6. Implement `listTasks(teamName:)` — read all `*.json` files (excluding `.lock`, `.highwatermark`)
    7. Implement `getTask(teamName:, id:)` — read single task JSON
    8. Implement `createTask(teamName:, task:)` — read `.highwatermark`, increment, write new task JSON inside `withFileLock`
    9. Implement `updateTask(teamName:, id:, update:)` — read-modify-write task JSON inside `withFileLock`
    10. Implement `listMessages(teamName:, agentName:)` — read `inboxes/{agent}.json` files; if agentName nil, aggregate all
    11. Implement `sendMessage(teamName:, message:)` — append to target inbox JSON inside lock
    12. Implement `withFileLock<T>(path:, body:)` — POSIX `flock()` with `LOCK_EX`, 5s timeout, cleanup on failure
    13. Handle edge cases: missing directories (create on demand), corrupt JSON (skip with warning), missing `.highwatermark` (scan for max ID)
  - **Files**:
    - `Sources/ILSBackend/Services/TeamsFileService.swift` (create)
  - **Done when**: `swift build` compiles; service reads/writes team and task JSON correctly
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add TeamsFileService for ~/.claude/teams/ filesystem access`
  - _Requirements: FR-1, FR-15_
  - _Design: TeamsFileService section_

- [ ] 1.4 Create TeamsExecutorService (process spawning + PID tracking)
  - **Do**:
    1. Create `TeamsExecutorService.swift` as `actor` (like `ClaudeExecutorService`)
    2. Track active processes: `[String: ProcessInfo]` keyed by agentId
    3. `ProcessInfo` struct: process, pid, teamName, agentName, startedAt
    4. Implement `createTeam(name:, description:, teammateMode:, workingDirectory:)`:
       - Spawn `claude -p --dangerously-skip-permissions` via `/bin/zsh -l -c`
       - Pass prompt: `"Create a team named '{name}' with description '{desc}'. Use TeamCreate tool."`
       - Set env: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
       - Wait for process exit (with 60s timeout)
       - Read back `~/.claude/teams/{name}/config.json`
       - Return parsed `AgentTeam`
    5. Implement `spawnTeammate(teamName:, config:)`:
       - Spawn `claude -p --dangerously-skip-permissions` with team env vars
       - Set env: `CLAUDE_CODE_TEAM_NAME`, `CLAUDE_CODE_AGENT_NAME`, `CLAUDE_CODE_AGENT_TYPE`, `CLAUDE_CODE_AGENT_COLOR`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
       - Track PID in `activeProcesses`
       - Return `TeamMember`
    6. Implement `shutdownTeammate(teamName:, agentName:)` — SIGTERM, 10s grace, SIGKILL fallback
    7. Implement `shutdownAllTeammates(teamName:)` — iterate all tracked processes for team
    8. Implement `isTeammateRunning(agentId:)` — check PID via `kill(pid, 0)`
    9. Implement `recoverProcesses(teamsService:)` — scan config.json members, check `ps aux` for matching env vars
    10. Use `DispatchQueue` for stdout reads (avoid RunLoop dependency per ClaudeExecutorService pattern)
  - **Files**:
    - `Sources/ILSBackend/Services/TeamsExecutorService.swift` (create)
  - **Done when**: `swift build` compiles; actor tracks PIDs correctly
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add TeamsExecutorService for process spawning and PID tracking`
  - _Requirements: FR-3, FR-10, FR-14_
  - _Design: TeamsExecutorService section_

- [ ] 1.5 [VERIFY] Backend core builds: `swift build`
  - **Do**: Run `swift build` and verify zero errors for shared models + backend services
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -10`
  - **Done when**: Build succeeds with zero errors
  - **Commit**: `chore(backend): fix compilation issues` (only if fixes needed)

- [ ] 1.6 Create TeamsController (12 REST endpoints)
  - **Do**:
    1. Create `TeamsController.swift` as `struct: RouteCollection` (follow `SessionsController` pattern)
    2. Instantiate: `let teamsFile = TeamsFileService()`, `let teamsExecutor = TeamsExecutorService()`
    3. Register routes in `boot(routes:)`:
       - `GET /teams` -> `list` — return `APIResponse<ListResponse<AgentTeam>>`
       - `POST /teams` -> `create` — decode `CreateTeamRequest`, call executor
       - `GET /teams/:name` -> `get` — return single team
       - `DELETE /teams/:name` -> `delete` — shutdown all + delete files
       - `GET /teams/:name/tasks` -> `listTasks`
       - `POST /teams/:name/tasks` -> `createTask`
       - `PUT /teams/:name/tasks/:taskId` -> `updateTask`
       - `GET /teams/:name/teammates` -> `listTeammates` — read config.json members
       - `POST /teams/:name/teammates` -> `spawnTeammate`
       - `DELETE /teams/:name/teammates/:agentName` -> `shutdownTeammate`
       - `GET /teams/:name/messages` -> `listMessages`
       - `POST /teams/:name/messages` -> `sendMessage`
    4. All handlers: `@Sendable`, throw `Abort(.notFound/badRequest)` for errors, return `APIResponse<T>`
    5. Team creation: validate name (alphanumeric + hyphens only, non-empty)
  - **Files**:
    - `Sources/ILSBackend/Controllers/TeamsController.swift` (create)
  - **Done when**: `swift build` compiles; all 12 endpoints registered
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add TeamsController with 12 REST endpoints`
  - _Requirements: FR-2_
  - _Design: TeamsController section_

- [ ] 1.7 Create SSHController + FleetController
  - **Do**:
    1. Create `SSHController.swift`:
       - `struct SSHController: RouteCollection` with `let sshService: SSHService`
       - `init(sshService:)` constructor
       - `POST /ssh/test` — decode `SSHTestRequest`, call `sshService.connect()`, measure latency with `Date()` diff, return `SSHTestResponse`
       - 10s timeout via `withThrowingTaskGroup` race
       - On success: return `{success: true, latencyMs, serverInfo}`
       - On failure: return `{success: false, error: message}`
    2. Create `FleetController.swift`:
       - `struct FleetController: RouteCollection` with `let sshService: SSHService`
       - `GET /fleet` — read SSH connections from UserDefaults or accept query params, probe each via `sshService.connect()` in parallel (TaskGroup), return `[FleetServer]`
       - `POST /fleet/probe` — probe specific server
       - Parallel probing with 10s per-server timeout
    3. Both follow `RouteCollection` pattern with `@Sendable` handlers
  - **Files**:
    - `Sources/ILSBackend/Controllers/SSHController.swift` (create)
    - `Sources/ILSBackend/Controllers/FleetController.swift` (create)
  - **Done when**: `swift build` compiles; endpoints return correct types
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add SSHController and FleetController for real SSH testing`
  - _Requirements: FR-17, FR-18, FR-20, FR-21_
  - _Design: SSHController + FleetController sections_

- [ ] 1.8 Add config routes (profiles, overrides, history) to ConfigController
  - **Do**:
    1. Add routes to `ConfigController.boot(routes:)`:
       - `GET /config/profiles` — read user, project, local scopes via `fileSystem.readConfig(scope:)` for each, return array of `ConfigInfo`
       - `GET /config/overrides` — merge all scopes, show override cascade per key
       - `GET /config/history` — run `git log -p --follow ~/.claude/settings.json` via Process, parse output into `[ConfigChange]` array; empty array if not git-tracked
    2. Add `ConfigChange` model to ILSShared if not already there (check existing code) — needs: `id`, `timestamp`, `source`, `key`, `oldValue`, `newValue`, `description`
    3. If `ConfigChange` already exists in iOS-only code, move to ILSShared
  - **Files**:
    - `Sources/ILSBackend/Controllers/ConfigController.swift` (modify)
    - `Sources/ILSShared/Models/ClaudeConfig.swift` (modify — add `ConfigChange` if needed)
  - **Done when**: `swift build` compiles; new routes registered
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add config profiles, overrides, and history endpoints`
  - _Requirements: FR-19_
  - _Design: Stub Fix Design Group 2_

- [ ] 1.9 Register all new controllers in routes.swift
  - **Do**:
    1. Add to `routes.swift` after existing registrations:
       ```swift
       try api.register(collection: TeamsController())
       try api.register(collection: SSHController(sshService: SSHService(eventLoopGroup: app.eventLoopGroup)))
       try api.register(collection: FleetController(sshService: SSHService(eventLoopGroup: app.eventLoopGroup)))
       ```
    2. Verify all 12 controllers are registered (9 existing + 3 new)
  - **Files**:
    - `Sources/ILSBackend/App/routes.swift` (modify)
  - **Done when**: `swift build` compiles; backend starts and serves all routes
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): register TeamsController, SSHController, FleetController`
  - _Requirements: FR-2_
  - _Design: routes.swift Registration_

- [ ] 1.10 [VERIFY] Full backend build + endpoint smoke test
  - **Do**:
    1. Run `swift build` — must succeed
    2. Start backend: `PORT=9090 swift run ILSBackend &`
    3. Verify teams endpoint: `curl -s http://localhost:9090/api/v1/teams | python3 -m json.tool`
    4. Verify SSH test endpoint exists: `curl -s -X POST http://localhost:9090/api/v1/ssh/test -H 'Content-Type: application/json' -d '{"host":"localhost","username":"test","authMethod":"password","credential":"test"}' | python3 -m json.tool`
    5. Verify fleet endpoint: `curl -s http://localhost:9090/api/v1/fleet | python3 -m json.tool`
    6. Verify config profiles: `curl -s http://localhost:9090/api/v1/config/profiles | python3 -m json.tool`
    7. Kill backend process after testing
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -3 && echo "BUILD OK"`
  - **Done when**: Build succeeds, all endpoints return valid JSON responses
  - **Commit**: `chore(backend): pass backend smoke test` (only if fixes needed)

## Phase 2: Stub Fixes (iOS + Backend)

Focus: Fix all 14 identified stubs. Wire to real backend.

- [ ] 2.1 Fix Extended Thinking + Co-Author toggles (S-12)
  - **Do**:
    1. In `SettingsView.swift`, locate `quickSettingsSection` (around line 270-286)
    2. Replace Extended Thinking toggle's `set: { _ in }` with real save closure:
       ```swift
       set: { newValue in
           Task {
               var updated = config
               updated.alwaysThinkingEnabled = newValue
               _ = await viewModel.saveConfig(alwaysThinking: newValue)
               await viewModel.loadConfig()
           }
       }
       ```
    3. Remove `.disabled(true)` from Extended Thinking toggle
    4. Same for Co-Author toggle — write `includeCoAuthoredBy` value
    5. Remove `.disabled(true)` from Co-Author toggle
    6. Add `saveConfigToggle(key:value:)` method to `SettingsViewModel` that does `PUT /config` with updated field
    7. Update the read-only `LabeledContent` displays (lines 198-207) to also reflect current toggle state
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (modify)
  - **Done when**: Both toggles save real values via backend; no `.disabled(true)` remains
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire Extended Thinking and Co-Author toggles to real backend config`
  - _Requirements: FR-22, FR-23, AC-12.1 through AC-12.6_
  - _Design: Stub Fix Design Group 1_

- [ ] 2.2 Fix Config History Restore buttons (S-13)
  - **Do**:
    1. In `ConfigHistoryView.swift`, add `@EnvironmentObject var appState: AppState` and `@State private var showRestoreConfirmation = false`, `@State private var restoreTarget: ConfigChange?`
    2. Replace empty context menu closure (line 14-18) with:
       - Set `restoreTarget = change`, `showRestoreConfirmation = true`
    3. Replace `ConfigDiffView` "Restore" button (line 111-117):
       - Call restore API then dismiss on success
    4. Add `.confirmationDialog` for restore confirmation
    5. Add restore method: `PUT /api/v1/config` with key-value from `ConfigChange.key` and `ConfigChange.oldValue`
    6. Show success alert after restore, refresh the list
    7. Wire `ConfigHistoryView` to load from `GET /api/v1/config/history` instead of `sampleHistory`
    8. Remove `ConfigChange.sampleHistory` static property (or keep as fallback if API unavailable)
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/ConfigHistoryView.swift` (modify)
  - **Done when**: Both Restore buttons perform real restore; data loads from API
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire Config History restore buttons and load from API`
  - _Requirements: FR-24, AC-13.1 through AC-13.6_
  - _Design: Stub Fix Design Group 1_

- [ ] 2.3 Wire SSHConnectionManager.testConnection() to real API (S-1)
  - **Do**:
    1. In `SSHConnectionManager.swift`, add `var apiClient: APIClient?` property
    2. Add `configure(client:)` method
    3. Replace `testConnection(_:)` body (remove `Task.sleep` simulation):
       - Build `SSHTestRequest` from connection fields
       - Load credential from Keychain via `loadCredential(for:)`
       - Call `POST /api/v1/ssh/test` via `apiClient.post<SSHTestResponse, SSHTestRequest>("/ssh/test", body:)`
       - Return `result.success`
    4. Change return type to `SSHTestResult` struct (success, latencyMs, error) for richer feedback
    5. Update callers (SSHConnectionFormView) to handle new return type
  - **Files**:
    - `ILSApp/ILSApp/Services/SSHConnectionManager.swift` (modify)
  - **Done when**: `testConnection()` calls real backend SSH; no `Task.sleep` simulation
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire SSH testConnection to real backend SSHService`
  - _Requirements: FR-17, AC-9.1 through AC-9.5_
  - _Design: Stub Fix Design Group 1_

- [ ] 2.4 [VERIFY] iOS build after stub fixes batch 1: `xcodebuild`
  - **Do**: Run iOS build to catch any compilation errors from tasks 2.1-2.3
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -10`
  - **Done when**: Build succeeds with zero errors
  - **Commit**: `chore(ios): fix compilation issues from stub fixes` (only if fixes needed)

- [ ] 2.5 Wire FleetManagementView to /fleet API (S-2)
  - **Do**:
    1. In `FleetManagementView.swift`:
       - Remove `@State private var servers: [RemoteServer] = RemoteServer.sampleFleet`
       - Add `@EnvironmentObject var appState: AppState`
       - Add `@State private var servers: [FleetServer] = []`, `@State private var isLoading = false`
       - Add `.task { await loadFleet() }` and `.refreshable { await loadFleet() }`
       - Implement `loadFleet()`: `GET /api/v1/fleet` via `appState.apiClient`
    2. Update view to use `FleetServer` instead of `RemoteServer` (adapt field names)
    3. Remove all `RemoteServer.sampleFleet` references
    4. Add empty state when no servers configured
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/FleetManagementView.swift` (modify)
  - **Done when**: Fleet data loads from API; zero hardcoded data
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire FleetManagementView to real /fleet API`
  - _Requirements: FR-18, AC-10.1 through AC-10.6_
  - _Design: Stub Fix Design Group 2_

- [ ] 2.6 Wire Config views (Profiles, Overrides, History data) to API (S-3, S-4, S-5)
  - **Do**:
    1. `ConfigProfilesView.swift`:
       - Remove `@State private var profiles = ConfigProfile.defaults`
       - Add `@EnvironmentObject var appState: AppState`
       - Load from `GET /api/v1/config/profiles` in `.task {}`
       - Show empty state if no profiles
    2. `ConfigOverridesView.swift`:
       - Remove `let overrides = ConfigOverrideItem.sampleData`
       - Load from `GET /api/v1/config/overrides`
       - Show real override cascade
    3. `ConfigHistoryView.swift` (if not already done in 2.2):
       - Remove `ConfigChange.sampleHistory` usage
       - Load from `GET /api/v1/config/history`
    4. Remove all `defaults`, `sampleData`, `sampleHistory` static properties or mark them as offline fallbacks only
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/ConfigProfilesView.swift` (modify)
    - `ILSApp/ILSApp/Views/Settings/ConfigOverridesView.swift` (modify)
    - `ILSApp/ILSApp/Views/Settings/ConfigHistoryView.swift` (modify if needed)
  - **Done when**: All 3 views load real data from API; zero hardcoded sample data
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire Config Profiles, Overrides, History views to real API`
  - _Requirements: FR-19, AC-11.1 through AC-11.5_
  - _Design: Stub Fix Design Group 2_

- [ ] 2.7 Mark Coming Soon views + wire LogViewer (S-6, S-7, S-8, S-9)
  - **Do**:
    1. `CloudSyncView.swift`:
       - Add "Coming Soon" banner overlay at top of view
       - Disable all toggles with `.disabled(true)` and reduced opacity
       - Add descriptive text explaining planned feature
    2. `AutomationScriptsView.swift`:
       - Same "Coming Soon" treatment
       - Remove hardcoded `AutomationScript.samples` if used
    3. `NotificationPreferencesView.swift`:
       - Same "Coming Soon" treatment
    4. `LogViewerView.swift`:
       - Wire to `AppLogger.shared.recentLogs()` on appear (it already has a refresh button that calls this)
       - Add `.task { logs = AppLogger.shared.recentLogs() }` to auto-load on appear
       - Verify logs actually display (the refresh button at line 26 already works)
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/CloudSyncView.swift` (modify)
    - `ILSApp/ILSApp/Views/Settings/AutomationScriptsView.swift` (modify)
    - `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift` (modify)
    - `ILSApp/ILSApp/Views/Settings/LogViewerView.swift` (modify)
  - **Done when**: 3 views show "Coming Soon"; LogViewer loads logs on appear
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): mark CloudSync/Automation/Notifications as Coming Soon, wire LogViewer`
  - _Requirements: S-6, S-7, S-8, S-9_
  - _Design: Stub Fix Design Group 3_

- [ ] 2.8 Wire SessionTemplatesView to backend (S-10) + fix plugin install (S-11)
  - **Do**:
    1. Add session templates routes to `SessionsController`:
       - `GET /sessions/templates` — return `SessionTemplate.defaults` initially (later from file/DB)
       - `POST /sessions/templates` — save custom template
       - `DELETE /sessions/templates/:id` — delete template
    2. In `SessionTemplatesView.swift`:
       - Add API loading in `loadTemplates()` — try API first, fall back to UserDefaults
       - Save to API in `saveTemplates()` — write to API, keep UserDefaults as cache
    3. In `PluginsController.swift` `install()` method (line 215-233):
       - Replace placeholder with real `git clone` via `Process`:
       - Clone URL from marketplace to `~/.claude/plugins/{name}/`
       - Register in config via `writeConfig`
       - Return real `Plugin` with actual data
       - Handle errors: invalid URL, clone failure, disk error
  - **Files**:
    - `Sources/ILSBackend/Controllers/SessionsController.swift` (modify — add template routes)
    - `ILSApp/ILSApp/Views/Sessions/SessionTemplatesView.swift` (modify)
    - `Sources/ILSBackend/Controllers/PluginsController.swift` (modify — real install)
  - **Done when**: Templates load from API; plugin install clones real repo
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix: wire SessionTemplates to API and implement real plugin install`
  - _Requirements: FR-25, FR-26, AC-14.1 through AC-14.5, AC-15.1 through AC-15.5_
  - _Design: Stub Fix Design Group 2_

- [ ] 2.9 [VERIFY] Full build after all stub fixes: `swift build && xcodebuild`
  - **Do**: Run both backend and iOS builds to verify all stub fixes compile
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore: pass full build after stub fixes` (only if fixes needed)

## Phase 3: iOS Agent Teams UI

Focus: Build all iOS views, viewmodels, navigation, and settings integration.

- [ ] 3.1 Create iOS ViewModels (AgentTeamsViewModel, AgentTeamDetailViewModel, TeamTasksViewModel)
  - **Do**:
    1. Create `AgentTeamsViewModel.swift`:
       - `@MainActor class: ObservableObject`
       - `@Published var teams`, `isLoading`, `error`
       - `configure(client:)`, `loadTeams(refresh:)`, `createTeam(request:)`, `deleteTeam(name:)`
       - Follow `SessionsViewModel` pattern exactly
    2. Create `AgentTeamDetailViewModel.swift`:
       - `@Published var team`, `tasks`, `messages`, `isLoading`, `error`
       - `configure(client:, teamName:)`
       - Polling: `startPolling()` / `stopPolling()` with `Task.sleep` loop at 3s
       - Poll fetches team detail + tasks + messages in parallel via `async let`
       - Stop polling on `deinit` and when `scenePhase != .active`
       - `spawnTeammate(request:)`, `shutdownTeammate(agentName:)`, `sendMessage(request:)`
    3. Create `TeamTasksViewModel.swift`:
       - `@Published var tasks`, `isLoading`, `error`, `selectedFilter: TeamTaskStatus?`
       - `filteredTasks` computed property
       - `loadTasks()`, `createTask(request:)`, `updateTask(id:, update:)`
  - **Files**:
    - `ILSApp/ILSApp/ViewModels/AgentTeamsViewModel.swift` (create)
    - `ILSApp/ILSApp/ViewModels/AgentTeamDetailViewModel.swift` (create)
    - `ILSApp/ILSApp/ViewModels/TeamTasksViewModel.swift` (create)
  - **Done when**: All 3 viewmodels compile; follow existing MVVM pattern
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add Agent Teams ViewModels with polling support`
  - _Requirements: FR-5, FR-6, FR-7, FR-16_
  - _Design: iOS ViewModels section_

- [ ] 3.2 Create AgentTeamsListView + CreateTeamView
  - **Do**:
    1. Create `Views/Teams/` directory
    2. Create `AgentTeamsListView.swift`:
       - `@EnvironmentObject var appState: AppState`
       - `@StateObject private var viewModel = AgentTeamsViewModel()`
       - `List` with team rows: name, member count pill, task progress bar, status badge
       - Pull-to-refresh via `.refreshable`
       - FAB button for "Create Team" (NavigationLink or sheet)
       - Empty state: "No Agent Teams" with create button
       - `.task { viewModel.configure(client: appState.apiClient); await viewModel.loadTeams() }`
       - Tap row -> NavigationLink to `AgentTeamDetailView(teamName:)`
    3. Create `CreateTeamView.swift`:
       - Form with: name TextField (validated: non-empty, alphanumeric + hyphens), description TextEditor, initial prompt TextEditor, teammate mode Picker
       - Submit button calls `viewModel.createTeam(request:)`
       - Loading state during creation (10-30s)
       - On success: dismiss and navigate to detail
       - On error: alert with message
  - **Files**:
    - `ILSApp/ILSApp/Views/Teams/AgentTeamsListView.swift` (create)
    - `ILSApp/ILSApp/Views/Teams/CreateTeamView.swift` (create)
  - **Done when**: List view shows teams; create form validates and submits
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add AgentTeamsListView and CreateTeamView`
  - _Requirements: FR-5, FR-8, AC-2.1 through AC-2.5, AC-3.1 through AC-3.7_
  - _Design: AgentTeamsListView + CreateTeamView sections_

- [ ] 3.3 Create AgentTeamDetailView + SpawnTeammateView
  - **Do**:
    1. Create `AgentTeamDetailView.swift`:
       - Header section: team name, status badge, creation time
       - Members section: List of `TeamMember` rows with name, agentType, model, status badge
       - Lead member distinguished with crown/star icon
       - Task summary section: progress bar (completed/total), pending/in-progress counts
       - Action buttons: "View Tasks" (NavigationLink), "Messages" (NavigationLink), "Add Teammate" (sheet), "Delete Team" (confirmation dialog)
       - Auto-poll via `AgentTeamDetailViewModel`
       - `.onAppear { viewModel.startPolling() }`, `.onDisappear { viewModel.stopPolling() }`
    2. Create `SpawnTeammateView.swift`:
       - Sheet form: name TextField, agent type Picker (Explore, executor, researcher, etc.), model Picker (haiku/sonnet/opus), prompt TextEditor
       - Submit: `POST /teams/:name/teammates`
       - Dismiss on success
  - **Files**:
    - `ILSApp/ILSApp/Views/Teams/AgentTeamDetailView.swift` (create)
    - `ILSApp/ILSApp/Views/Teams/SpawnTeammateView.swift` (create)
  - **Done when**: Detail view shows members with status; spawn form submits
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add AgentTeamDetailView and SpawnTeammateView`
  - _Requirements: FR-6, FR-10, AC-4.1 through AC-4.5, AC-6.1 through AC-6.7_
  - _Design: AgentTeamDetailView + SpawnTeammateView sections_

- [ ] 3.4 [VERIFY] iOS build after views batch 1: `xcodebuild`
  - **Do**: Run iOS build to verify viewmodels + views compile
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -10`
  - **Done when**: Build succeeds with zero errors
  - **Commit**: `chore(ios): fix compilation issues` (only if fixes needed)

- [ ] 3.5 Create TeamTaskListView + TeamMessagesView
  - **Do**:
    1. Create `TeamTaskListView.swift`:
       - Segmented control filter: All, Pending, In Progress, Completed
       - Task rows: subject, status badge (color-coded), owner pill, activeForm italic text, blocked indicator ("Blocked by #X, #Y")
       - Tap row -> detail sheet with full description, dependencies, assignment
       - "+" toolbar button -> create task sheet (subject, description fields)
       - Swipe actions for status transitions (pending -> in_progress -> completed)
       - Uses `TeamTasksViewModel`
    2. Create `TeamMessagesView.swift`:
       - Chat-bubble style message list, color-coded by sender
       - System messages (shutdown, idle, task_completed) shown with type badges
       - Sender role label (lead vs teammate name)
       - Broadcast messages visually distinct (wider bubble, different background)
       - Send interface: text field + recipient picker (specific agent or "Broadcast")
       - Auto-poll every 2s via detail viewmodel
       - Scroll to bottom on new messages
  - **Files**:
    - `ILSApp/ILSApp/Views/Teams/TeamTaskListView.swift` (create)
    - `ILSApp/ILSApp/Views/Teams/TeamMessagesView.swift` (create)
  - **Done when**: Task list with filtering and CRUD; message view with send
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add TeamTaskListView and TeamMessagesView`
  - _Requirements: FR-7, FR-9, AC-5.1 through AC-5.8, AC-7.1 through AC-7.7_
  - _Design: TeamTaskListView + TeamMessagesView sections_

- [ ] 3.6 Add Experimental section to SettingsView + AppState flag
  - **Do**:
    1. In `ILSAppApp.swift` `AppState` class:
       - Add `@Published var isAgentTeamsEnabled: Bool = false`
       - Load on init: check config env for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
    2. In `SettingsView.swift`:
       - Add `experimentalSection` between `diagnosticsSection` and `cacheSection` in `body`
       - Agent Teams toggle (orange tint) — reads/writes `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` via `PUT /config`
       - When enabled: show `teammateMode` Picker (In-Process/Tmux/Auto) + "Manage Teams" NavigationLink
       - Toggle updates `appState.isAgentTeamsEnabled`
    3. Add `@Published var teammateMode: String = "in-process"` to SettingsViewModel
    4. Add `toggleAgentTeams(enabled:)` and `setTeammateMode(_:)` methods
  - **Files**:
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify — add isAgentTeamsEnabled to AppState)
    - `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (modify — add experimentalSection)
  - **Done when**: Experimental section visible; toggle writes real config; flag propagates to AppState
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add Experimental section in Settings with Agent Teams toggle`
  - _Requirements: FR-11, FR-12, FR-13, AC-1.1 through AC-1.5_
  - _Design: Settings Integration section_

- [ ] 3.7 Add Agent Teams to navigation (SidebarItem + ContentView routing)
  - **Do**:
    1. In `ContentView.swift`:
       - Add `case agentTeams = "Agent Teams"` to `SidebarItem` enum
       - Add `var icon` case: `case .agentTeams: return "person.3"`
       - Add to `selectedTab` computed property: `case "agentteams": return .agentTeams`
       - Add to `detailView` switch: `case .agentTeams: AgentTeamsListView()`
       - Add to sidebar binding set switch: `case .agentTeams: appState.selectedTab = "agentteams"`
    2. In `SidebarView.swift`:
       - Filter `SidebarItem.allCases` to exclude `.agentTeams` when `!appState.isAgentTeamsEnabled`
       - Use: `ForEach(SidebarItem.allCases.filter { item in item != .agentTeams || appState.isAgentTeamsEnabled })`
    3. In `AppState.handleURL(_:)`:
       - Add `case "agentteams": selectedTab = "agentteams"`
  - **Files**:
    - `ILSApp/ILSApp/ContentView.swift` (modify)
    - `ILSApp/ILSApp/Views/Sidebar/SidebarView.swift` (modify)
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify — add URL handler case)
  - **Done when**: Agent Teams tab visible when flag on; hidden when off; navigation works
  - **Verify**: `cd <project-root> && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add Agent Teams navigation gated behind experimental flag`
  - _Requirements: FR-13, AC-2.5_
  - _Design: Navigation Integration section_

- [ ] 3.8 [VERIFY] Full local CI: `swift build && xcodebuild`
  - **Do**: Run complete build for both targets
  - **Verify**: `cd <project-root> && swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore: pass full local CI` (only if fixes needed)

## Phase 4: Functional Validation

Focus: Evidence-based validation of every feature. Screenshots + curl.
Simulator UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14

- [ ] 4.1 Validate experimental flag toggle (V-1, V-15)
  - **Do**:
    1. Start backend: `PORT=9090 swift run ILSBackend &`
    2. Build and install app on simulator
    3. Navigate to Settings -> Experimental section
    4. Screenshot: toggle OFF state
    5. Toggle Agent Teams ON
    6. Verify via curl: `curl -s http://localhost:9090/api/v1/config?scope=user | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['content'].get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS','NOT SET'))"`
    7. Screenshot: toggle ON state with teammateMode picker visible
    8. Verify sidebar shows "Agent Teams" entry
    9. Toggle OFF -> verify sidebar hides "Agent Teams"
    10. Screenshot: sidebar without Agent Teams (feature gating proof)
  - **Files**: Evidence screenshots to `.omc/evidence/agent-teams/`
  - **Done when**: Toggle writes real config; nav entry appears/disappears
  - **Verify**: curl shows `"1"` when on, absent when off
  - **Commit**: None (validation only)
  - _Requirements: V-1, V-15_

- [ ] 4.2 Validate team list empty state + team creation (V-2, V-3)
  - **Do**:
    1. Open Agent Teams tab
    2. Screenshot: empty state ("No Agent Teams")
    3. Tap Create Team
    4. Fill form: name="test-team", description="Test team", prompt="Hello"
    5. Submit and wait for creation (10-30s)
    6. Screenshot: loading state during creation
    7. Verify config exists: `ls ~/.claude/teams/test-team/config.json`
    8. Verify via curl: `curl -s http://localhost:9090/api/v1/teams/test-team | python3 -m json.tool`
    9. Screenshot: team appears in list
  - **Done when**: Team created; config.json on disk; visible in list
  - **Verify**: `ls ~/.claude/teams/test-team/config.json && curl -s http://localhost:9090/api/v1/teams | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['items']))"`
  - **Commit**: None (validation only)
  - _Requirements: V-2, V-3_

- [ ] 4.3 Validate team detail + task CRUD (V-4, V-5, V-6, V-7)
  - **Do**:
    1. Navigate to test-team detail view
    2. Screenshot: team detail showing members
    3. Compare member list against: `cat ~/.claude/teams/test-team/config.json | python3 -m json.tool`
    4. Navigate to Tasks
    5. Screenshot: empty task list
    6. Create task: subject="Review code", description="Review all files"
    7. Verify file: `ls ~/.claude/tasks/test-team/`
    8. Screenshot: task in list with "pending" badge
    9. Change task status to "in_progress" (swipe or tap)
    10. Verify via curl: `curl -s http://localhost:9090/api/v1/teams/test-team/tasks | python3 -m json.tool`
    11. Screenshot: task with updated status
  - **Done when**: Detail shows real data; task CRUD works end-to-end
  - **Verify**: Task JSON files exist on disk and match API response
  - **Commit**: None (validation only)
  - _Requirements: V-4, V-5, V-6, V-7_

- [ ] 4.4 Validate teammate spawn/shutdown + messages (V-8, V-9, V-10)
  - **Do**:
    1. From team detail, tap "Add Teammate"
    2. Fill: name="worker-1", type="Explore", model="haiku", prompt="Analyze codebase"
    3. Submit and wait
    4. Verify process: `ps aux | grep CLAUDE_CODE_TEAM_NAME | grep -v grep`
    5. Screenshot: new teammate in members list
    6. Navigate to Messages
    7. Send message to worker-1: "Status update please"
    8. Screenshot: message in thread
    9. Go back to detail, tap shutdown on worker-1
    10. Verify process gone: `ps aux | grep worker-1 | grep -v grep | wc -l` (should be 0)
    11. Screenshot: member status = "stopped"
  - **Done when**: Teammate spawns (PID visible), messages send, shutdown kills process
  - **Verify**: `ps aux | grep CLAUDE_CODE_TEAM_NAME` shows/hides processes
  - **Commit**: None (validation only)
  - _Requirements: V-8, V-9, V-10_

- [ ] 4.5 Validate team deletion (V-11)
  - **Do**:
    1. From team detail, tap "Delete Team"
    2. Confirm in dialog
    3. Verify directory removed: `ls ~/.claude/teams/test-team/ 2>&1` (should fail)
    4. Verify no orphaned processes: `ps aux | grep test-team | grep -v grep | wc -l` (should be 0)
    5. Screenshot: team removed from list
  - **Done when**: Directory gone, processes killed, list updated
  - **Verify**: `test ! -d ~/.claude/teams/test-team && echo "DELETED"`
  - **Commit**: None (validation only)
  - _Requirements: V-11_

- [ ] 4.6 Validate SSH real test (V-12)
  - **Do**:
    1. Navigate to Settings -> SSH Server Connection
    2. Add connection: host=home.hack.ski, port=22, username=nick, password=Usmc12345!
    3. Tap "Test Connection"
    4. Screenshot: real connection result with latency (not simulated 1.5s sleep)
    5. Verify backend received real SSH attempt (check logs or curl output)
  - **Done when**: Real SSH connection test with latency metric; no `Task.sleep`
  - **Verify**: Connection result shows real latency, not hardcoded delay
  - **Commit**: None (validation only)
  - _Requirements: V-12_

- [ ] 4.7 Validate Fleet, Config, Toggles (V-13, V-14, V-16, V-17)
  - **Do**:
    1. Navigate to Fleet Management
    2. Screenshot: real server data (or empty state if no SSH connections configured) — NOT hardcoded sampleFleet
    3. Navigate to Config Profiles
    4. Screenshot: real config scopes from API
    5. Navigate to Settings -> Quick Settings
    6. Toggle "Extended Thinking" ON
    7. Verify: `curl -s http://localhost:9090/api/v1/config?scope=user | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['content'].get('alwaysThinkingEnabled'))"`
    8. Screenshot: toggle in ON state
    9. Navigate to Config History
    10. Tap "Restore This Version" on any entry
    11. Screenshot: confirmation dialog
    12. Confirm restore, verify via curl
  - **Done when**: All views show real data; toggles save; restore works
  - **Verify**: curl confirms real config values after toggle/restore
  - **Commit**: None (validation only)
  - _Requirements: V-13, V-14, V-16, V-17_

- [ ] 4.8 Validate Session Templates + Plugin Install (V-18, V-19)
  - **Do**:
    1. Navigate to Sessions -> New Session -> Templates
    2. Screenshot: templates loaded (verify not just hardcoded defaults)
    3. Check API: `curl -s http://localhost:9090/api/v1/sessions/templates | python3 -m json.tool`
    4. Navigate to Plugins -> Install
    5. Attempt install of a plugin
    6. Verify files: `ls ~/.claude/plugins/ | head -5`
    7. Screenshot: install result
  - **Done when**: Templates from API; plugin install attempts real clone
  - **Verify**: API returns templates; plugin directory exists after install
  - **Commit**: None (validation only)
  - _Requirements: V-18, V-19_

- [ ] 4.9 [VERIFY] AC checklist — all 19 validation items confirmed
  - **Do**:
    1. Review all screenshots captured in 4.1-4.8
    2. Cross-reference each V-1 through V-19 item against evidence
    3. Document any gaps — fix and re-validate
    4. Compile evidence summary in `.progress.md`
  - **Verify**: All 19 validation items have corresponding screenshots + automated checks
  - **Done when**: Every validation item has evidence; zero gaps
  - **Commit**: None (validation only)

## Phase 5: Quality Gates + PR

- [ ] 5.1 Local quality check
  - **Do**: Run ALL quality checks locally
  - **Verify**: All commands must pass:
    - Backend: `cd <project-root> && swift build 2>&1 | tail -5`
    - iOS: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds pass with zero errors
  - **Commit**: `fix(agent-teams): address build issues` (if fixes needed)

- [ ] 5.2 Create PR and verify CI
  - **Do**:
    1. Verify current branch: `git branch --show-current` (should be `design/v2-redesign` or feature branch)
    2. If on default branch, STOP
    3. Stage all changes: `git add -A`
    4. Create commit with summary: `feat(agent-teams): complete Agent Teams implementation with 14 stub fixes`
    5. Push: `git push -u origin $(git branch --show-current)`
    6. Create PR: `gh pr create --title "feat: Agent Teams + 14 stub fixes" --body "..."`
  - **Verify**: `gh pr checks --watch` (if CI configured)
  - **Done when**: PR created, CI passes (if available)

- [ ] 5.3 [VERIFY] Final AC checklist
  - **Do**:
    1. Read requirements.md
    2. Verify each AC-* is satisfied:
       - AC-1.x: Experimental toggle reads/writes real config
       - AC-2.x: Team list shows real data
       - AC-3.x: Create team works end-to-end
       - AC-4.x: Team detail shows members
       - AC-5.x: Task CRUD works
       - AC-6.x: Teammate spawn/shutdown
       - AC-7.x: Messages send/receive
       - AC-8.x: Team deletion cleans up
       - AC-9.x: SSH test is real
       - AC-10.x: Fleet shows real data
       - AC-11.x: Config views show real data
       - AC-12.x: Toggles save real values
       - AC-13.x: Config restore works
       - AC-14.x: Templates from API
       - AC-15.x: Plugin install is real
    3. Grep codebase for remaining stubs: `grep -r "sampleFleet\|sampleHistory\|sampleData\|defaults\|Task.sleep.*1_500\|set: { _ in" ILSApp/ --include="*.swift" -l`
    4. Verify zero matches (all stubs fixed)
  - **Verify**: grep returns zero matches for stub patterns
  - **Done when**: All AC confirmed; zero stubs remaining
  - **Commit**: None

## Notes

- **POC shortcuts**: None — quality-first approach per user decision
- **Production TODOs**:
  - WebSocket upgrade for real-time team updates (currently polling)
  - Cost/token tracking per teammate (no API exists yet)
  - Remote teammate spawning via SSH (currently local-only)
  - Team templates/presets
  - iCloud sync for team data
- **Risk areas**:
  - Team creation via `claude -p` prompt is untested — may need fallback to direct filesystem write
  - PID recovery after backend restart relies on `ps aux` scan — may miss processes
  - Config history git log approach depends on `~/.claude/` being git-tracked
  - File locking must match CLI's flock() behavior exactly
- **Key dependencies**:
  - Citadel/NIOSSH already in Package.swift (for SSH testing)
  - Existing `ClaudeExecutorService` Process pattern (for team/teammate spawning)
  - Existing `ConfigController` PUT endpoint (for toggle saves + config restore)
  - Existing `APIClient` generic methods (for all iOS API calls)
