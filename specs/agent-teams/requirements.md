---
spec: agent-teams
phase: requirements
created: 2026-02-06T15:57:00Z
updated: 2026-02-06T17:04:00Z
---

# Requirements: Agent Teams for ILS iOS

## Goal

Enable ILS iOS users to create, manage, monitor, and interact with Claude Code Agent Teams entirely from the mobile app — including team lifecycle, shared task lists, inter-agent messaging, and experimental settings — while simultaneously fixing **14 identified stub/incomplete features** across the full app that lack real backend integration or functional implementation.

## Executive Summary: Full App Audit

A comprehensive audit of the ILS iOS app uncovered **14 total issues** (up from the initial 9). Three are CRITICAL (user-facing buttons that do nothing or simulate behavior), eleven are HIGH (hardcoded data or missing persistence). Every feature added without functional validation is tracked below. The core concern: **features were shipped incomplete and never verified end-to-end.**

## User Decisions (from Interview)

| Question | Decision |
|----------|----------|
| Primary users | Developers managing teams from iOS + end users monitoring progress |
| Priority tradeoffs | Feature completeness first — full CRUD, messaging, monitoring, settings |
| Success criteria | Every feature screenshot-proven, no stubs, no fakes, real E2E through UI |
| Stub handling | Fix ALL existing stubs as part of this spec (prerequisite for Agent Teams quality bar) |

---

## User Stories

### US-1: Enable Agent Teams Experimental Feature

**As a** developer
**I want to** toggle the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag from Settings
**So that** I can enable/disable Agent Teams without touching the terminal

**Acceptance Criteria:**
- [ ] AC-1.1: New "Experimental" section in SettingsView with Agent Teams toggle
- [ ] AC-1.2: Toggle reads current value from backend (`GET /api/v1/config?scope=user`) and reflects real state
- [ ] AC-1.3: Toggle writes to `~/.claude/settings.json` via backend (`PUT /api/v1/config`) setting `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"1"` or removing it
- [ ] AC-1.4: `teammateMode` picker (in-process / tmux / auto) visible when Agent Teams enabled
- [ ] AC-1.5: Agent Teams navigation entry hidden when toggle is off

### US-2: View All Agent Teams

**As a** developer
**I want to** see a list of all active and completed teams
**So that** I can monitor team progress at a glance

**Acceptance Criteria:**
- [ ] AC-2.1: `AgentTeamsListView` shows teams from `GET /api/v1/teams`
- [ ] AC-2.2: Each team row displays: name, member count, task progress (completed/total), status badge (active/completed/error)
- [ ] AC-2.3: Pull-to-refresh reloads team list from backend
- [ ] AC-2.4: Empty state shown when no teams exist ("No teams yet")
- [ ] AC-2.5: Navigation entry in sidebar/tab bar (gated behind experimental flag)

### US-3: Create a New Agent Team

**As a** developer
**I want to** create a team with a name and initial prompt from the iOS app
**So that** I can start coordinated multi-agent work from mobile

**Acceptance Criteria:**
- [ ] AC-3.1: `CreateTeamView` with fields: team name (required), initial prompt (required), teammate mode picker
- [ ] AC-3.2: Submit calls `POST /api/v1/teams` which spawns a Claude CLI session with team creation
- [ ] AC-3.3: Backend spawns `claude` process with appropriate flags/prompt to create team
- [ ] AC-3.4: Loading state shown during team creation (can take 10-30s)
- [ ] AC-3.5: On success, navigates to `AgentTeamDetailView` for the new team
- [ ] AC-3.6: On failure, shows error message with actionable detail
- [ ] AC-3.7: Validation: team name must be non-empty, alphanumeric + hyphens only

### US-4: View Team Details and Members

**As a** developer
**I want to** see a team's lead, teammates, and overall status
**So that** I can understand who is working on what

**Acceptance Criteria:**
- [ ] AC-4.1: `AgentTeamDetailView` shows team name, status, creation time
- [ ] AC-4.2: Members list shows each member: name, agentType (lead/teammate), model, status (running/idle/stopped)
- [ ] AC-4.3: Lead member visually distinguished (badge or icon)
- [ ] AC-4.4: Data sourced from `GET /api/v1/teams/:name` reading `~/.claude/teams/{name}/config.json`
- [ ] AC-4.5: Auto-refresh via polling (configurable 2-5s interval)

### US-5: Manage Shared Task List

**As a** developer
**I want to** view, create, and update tasks in the team's shared task list
**So that** I can coordinate work across teammates

**Acceptance Criteria:**
- [ ] AC-5.1: `TeamTaskListView` shows all tasks from `GET /api/v1/teams/:name/tasks`
- [ ] AC-5.2: Each task displays: subject, status badge (pending/in_progress/completed), assignee, activeForm text
- [ ] AC-5.3: Status filter tabs: All, Pending, In Progress, Completed
- [ ] AC-5.4: Task detail view shows: full description, blocks/blockedBy dependencies, assignment
- [ ] AC-5.5: Create task: `POST /api/v1/teams/:name/tasks` with subject, description fields
- [ ] AC-5.6: Update task status: `PUT /api/v1/teams/:name/tasks/:id` (status transitions)
- [ ] AC-5.7: Dependency visualization — blocked tasks show which tasks they're waiting on
- [ ] AC-5.8: Backend reads/writes `~/.claude/tasks/{name}/*.json` with file locking

### US-6: Spawn and Shutdown Teammates

**As a** developer
**I want to** add new teammates to a running team or shut down existing ones
**So that** I can scale team capacity up or down

**Acceptance Criteria:**
- [ ] AC-6.1: "Add Teammate" button in team detail view
- [ ] AC-6.2: Spawn form: role/name, model picker (haiku/sonnet/opus), initial prompt
- [ ] AC-6.3: `POST /api/v1/teams/:name/teammates` spawns new Claude CLI teammate process
- [ ] AC-6.4: Backend tracks teammate PID for health checking
- [ ] AC-6.5: Shutdown button per teammate sends `DELETE /api/v1/teams/:name/teammates/:id`
- [ ] AC-6.6: Backend sends graceful shutdown signal; falls back to process termination after timeout
- [ ] AC-6.7: Teammate status updates to "stopped" after shutdown

### US-7: Send and View Inter-Agent Messages

**As a** developer
**I want to** view the message stream between agents and send messages to teammates
**So that** I can monitor coordination and intervene when needed

**Acceptance Criteria:**
- [ ] AC-7.1: `TeamMessagesView` shows message thread (from, to, content, timestamp)
- [ ] AC-7.2: Messages loaded from `GET /api/v1/teams/:name/messages`
- [ ] AC-7.3: Send direct message to specific teammate via `POST /api/v1/teams/:name/messages` with `{to, content}`
- [ ] AC-7.4: Send broadcast message (to=null) to all teammates
- [ ] AC-7.5: Messages auto-refresh via polling (2-5s interval)
- [ ] AC-7.6: Visual distinction between direct messages and broadcasts
- [ ] AC-7.7: Sender role shown (lead vs teammate name)

### US-8: Clean Up / Delete a Team

**As a** developer
**I want to** shut down and clean up a completed or failed team
**So that** orphaned processes don't consume resources

**Acceptance Criteria:**
- [ ] AC-8.1: "Delete Team" button with confirmation dialog
- [ ] AC-8.2: `DELETE /api/v1/teams/:name` sends shutdown to all teammates, then cleans up
- [ ] AC-8.3: Backend terminates all tracked PIDs, removes `~/.claude/teams/{name}/` directory
- [ ] AC-8.4: `~/.claude/tasks/{name}/` optionally preserved (user choice) or deleted
- [ ] AC-8.5: Team removed from list after cleanup

### US-9: Fix SSH Connection Test Stub

**As a** developer
**I want** the SSH "Test Connection" button to actually test SSH connectivity
**So that** I can verify my SSH servers are reachable before using them

**Acceptance Criteria:**
- [ ] AC-9.1: `SSHConnectionManager.testConnection()` calls backend `POST /api/v1/ssh/test` endpoint
- [ ] AC-9.2: Backend endpoint uses existing `SSHService.swift` (Citadel) to attempt real SSH connection
- [ ] AC-9.3: Returns structured result: success/failure, latency, server info (if available)
- [ ] AC-9.4: iOS shows real connection result with latency metric
- [ ] AC-9.5: Timeout after 10s with clear error message

### US-10: Wire Fleet Management to Backend

**As a** developer
**I want** Fleet Management to show real server data from the backend
**So that** I can monitor my actual server fleet instead of hardcoded samples

**Acceptance Criteria:**
- [ ] AC-10.1: `FleetManagementView` loads servers from `GET /api/v1/fleet` endpoint
- [ ] AC-10.2: Backend endpoint aggregates SSH connections + probes status via `SSHService`
- [ ] AC-10.3: Real server status (online/offline/degraded) based on actual SSH probe results
- [ ] AC-10.4: Server details (Claude version, skill count, MCP count) from real remote queries
- [ ] AC-10.5: Pull-to-refresh triggers fresh probe of all servers
- [ ] AC-10.6: Remove all hardcoded `sampleFleet` data

### US-11: Wire Config Management Views to Backend

**As a** developer
**I want** Config Profiles, Overrides, and History to reflect real configuration data
**So that** I can understand my actual Claude Code configuration state

**Acceptance Criteria:**
- [ ] AC-11.1: `ConfigProfilesView` loads profiles from `GET /api/v1/config/profiles` (reads user, project, local scopes)
- [ ] AC-11.2: `ConfigOverridesView` shows real override cascade from all config scopes
- [ ] AC-11.3: `ConfigHistoryView` reads real config change history (if available) or displays git-based diff of settings.json
- [ ] AC-11.4: Remove all hardcoded `defaults`, `sampleData`, `sampleHistory`
- [ ] AC-11.5: Empty states shown when no data exists (not fake data)

### US-12: Fix Settings Quick Toggles (Extended Thinking, Co-Author)

**As a** developer
**I want** the Extended Thinking and Co-Author toggles in Settings to actually save my preference
**So that** I can configure Claude Code behavior from the iOS app

**Acceptance Criteria:**
- [ ] AC-12.1: "Extended Thinking" toggle in Quick Settings section becomes functional (remove `set: { _ in }` + `.disabled(true)`)
- [ ] AC-12.2: Toggling Extended Thinking writes `alwaysThinking: true/false` to backend via `PUT /api/v1/config`
- [ ] AC-12.3: "Include Co-Author" toggle becomes functional (remove `set: { _ in }` + `.disabled(true)`)
- [ ] AC-12.4: Toggling Co-Author writes `includeCoAuthoredBy: true/false` to backend via `PUT /api/v1/config`
- [ ] AC-12.5: Both toggles reflect real saved state on reload (not just local @State)
- [ ] AC-12.6: The read-only `LabeledContent` displays in the Config section (lines 198-207) also update to reflect saved state

**Source files:**
- `SettingsView.swift:270-286` — Quick Settings toggles with `set: { _ in }` and `.disabled(true)`
- `SettingsView.swift:198-207` — Read-only LabeledContent displays in Config section

### US-13: Fix Config History Restore Functionality

**As a** developer
**I want** the "Restore This Version" button in Config History to actually restore the selected config
**So that** I can roll back configuration changes from the iOS app

**Acceptance Criteria:**
- [ ] AC-13.1: Context menu "Restore This Version" button executes a real restore action (replace empty `{ }` closure)
- [ ] AC-13.2: Restore calls `PUT /api/v1/config` with the historical config values
- [ ] AC-13.3: ConfigDiffView "Restore This Version" button (line 111-117) also performs real restore (currently just calls `dismiss()`)
- [ ] AC-13.4: Confirmation dialog before restoring ("Are you sure you want to restore this config?")
- [ ] AC-13.5: Success feedback after restore (toast/alert showing "Config restored")
- [ ] AC-13.6: View refreshes to show the restored config as current

**Source files:**
- `ConfigHistoryView.swift:14-18` — Context menu button with empty `{ }` closure
- `ConfigHistoryView.swift:111-117` — Sheet button that only calls `dismiss()`

### US-14: Fix Session Templates Loading

**As a** developer
**I want** Session Templates to load from the backend API instead of UserDefaults
**So that** templates persist across devices and are managed centrally

**Acceptance Criteria:**
- [ ] AC-14.1: `SessionTemplatesView` loads templates from backend `GET /api/v1/sessions/templates` (or equivalent)
- [ ] AC-14.2: Custom templates saved to backend via `POST /api/v1/sessions/templates`
- [ ] AC-14.3: Template deletion calls `DELETE /api/v1/sessions/templates/:id`
- [ ] AC-14.4: Fallback: if backend endpoint unavailable, retain UserDefaults + `SessionTemplate.defaults` as offline fallback
- [ ] AC-14.5: Remove dependency on `UserDefaults.standard.data(forKey: "sessionTemplates")` as primary store

**Source files:**
- `SessionTemplatesView.swift:90-97` — `loadTemplates()` reads from UserDefaults only
- `SessionTemplatesView.swift:100-104` — `saveTemplates()` writes to UserDefaults only
- `SessionTemplate.swift:40-67` — Hardcoded `defaults` array (4 templates)

### US-15: Fix Plugin Installation (Backend)

**As a** developer
**I want** the plugin install endpoint to actually clone and install plugins from the marketplace
**So that** I can install new plugins from the iOS app

**Acceptance Criteria:**
- [ ] AC-15.1: `POST /api/v1/plugins/install` clones the plugin repository from the marketplace URL
- [ ] AC-15.2: Plugin files written to `~/.claude/plugins/{name}/` directory
- [ ] AC-15.3: Plugin registered in `~/.claude/plugins/installed_plugins.json`
- [ ] AC-15.4: On failure (invalid URL, clone error, disk error), returns structured error with reason
- [ ] AC-15.5: Remove the "In a real implementation" comment and placeholder return

**Source files:**
- `PluginsController.swift:215-233` — `install()` returns fake `Plugin` without cloning; comment says "In a real implementation, this would clone from the marketplace / For now, return a placeholder"

---

## Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-1 | Backend `TeamsFileService` reads `~/.claude/teams/` and `~/.claude/tasks/` directories | P0 | Correct parsing of config.json and task JSON files verified via curl |
| FR-2 | Backend `TeamsController` exposes 11 REST endpoints under `/api/v1/teams/` | P0 | All endpoints return correct JSON; verified via curl |
| FR-3 | Backend `TeamsExecutorService` spawns/manages Claude CLI processes for team operations | P0 | Team creation spawns real process; PID tracked; process terminable |
| FR-4 | Shared models (`AgentTeam`, `TeamMember`, `TeamTask`, `TeamMessage`) in ILSShared | P0 | Models compile in both iOS and backend targets |
| FR-5 | `AgentTeamsListView` displays teams with status, member count, task progress | P0 | Screenshot shows real team data from backend |
| FR-6 | `AgentTeamDetailView` shows members, status, task summary | P0 | Screenshot shows real member data |
| FR-7 | `TeamTaskListView` with CRUD, status filtering, dependency display | P0 | Create task, change status, verify via curl and UI |
| FR-8 | `CreateTeamView` form with validation and backend integration | P0 | Team created, visible in list, config.json written to disk |
| FR-9 | `TeamMessagesView` with send/receive, direct + broadcast | P1 | Message sent from iOS, visible in teammate's context |
| FR-10 | Teammate spawn/shutdown from iOS | P1 | New teammate process running; shutdown terminates it |
| FR-11 | Experimental flag toggle in Settings writes to `~/.claude/settings.json` | P0 | Toggle on -> `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in file |
| FR-12 | `teammateMode` picker persists selection | P1 | Value readable via `GET /api/v1/config` after change |
| FR-13 | Agent Teams navigation gated behind experimental flag | P0 | Tab/sidebar entry hidden when flag off; visible when on |
| FR-14 | Team deletion cleans up processes + filesystem | P1 | No orphaned PIDs; `~/.claude/teams/{name}/` removed |
| FR-15 | Backend file-locking for task writes | P1 | Concurrent task updates don't corrupt JSON files |
| FR-16 | Polling-based auto-refresh for team data (2-5s) | P1 | UI updates without manual refresh within 5s of backend change |
| FR-17 | `SSHConnectionManager.testConnection()` calls real backend SSH test | P0 | Real SSH connection attempt with latency; no sleep simulation |
| FR-18 | `FleetManagementView` loads from API, not hardcoded data | P0 | View shows data from `GET /api/v1/fleet`; `sampleFleet` removed |
| FR-19 | Config views (Profiles, Overrides, History) load from API | P1 | All hardcoded sample data removed; real config data displayed |
| FR-20 | Backend `POST /api/v1/ssh/test` endpoint using `SSHService` | P0 | curl returns real connection result with latency |
| FR-21 | Backend `GET /api/v1/fleet` endpoint aggregating SSH server statuses | P0 | curl returns fleet array with real probe results |
| FR-22 | Extended Thinking toggle saves to backend via `PUT /api/v1/config` | P0 | Toggle on -> `alwaysThinking: true` in `~/.claude/settings.json`; verify via curl |
| FR-23 | Co-Author toggle saves to backend via `PUT /api/v1/config` | P0 | Toggle on -> `includeCoAuthoredBy: true` in `~/.claude/settings.json`; verify via curl |
| FR-24 | Config History "Restore" writes selected config values to backend | P1 | Restore old config -> verify current config matches restored values via curl |
| FR-25 | Session Templates loads from backend API (not UserDefaults) | P1 | Templates visible after fresh install; no UserDefaults dependency |
| FR-26 | Plugin Install endpoint clones from GitHub/marketplace | P1 | `POST /api/v1/plugins/install` -> plugin files exist on disk at `~/.claude/plugins/{name}/` |

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | Team list load time | Response time | < 2s for up to 20 teams |
| NFR-2 | Task list load time | Response time | < 1s for up to 100 tasks |
| NFR-3 | Polling overhead | CPU usage | < 5% background CPU from auto-refresh timers |
| NFR-4 | Process cleanup reliability | Orphan rate | Zero orphaned Claude CLI processes after team deletion |
| NFR-5 | File locking correctness | Data integrity | Zero corrupted task JSON files under concurrent writes |
| NFR-6 | Teammate spawn time | Latency | < 30s from button tap to teammate appearing in member list |
| NFR-7 | SSH test response | Latency | < 10s timeout; < 3s for reachable servers |
| NFR-8 | Fleet probe | Latency | < 15s for up to 10 servers (parallel probing) |
| NFR-9 | Error messages | Clarity | All errors display actionable text (not raw stack traces) |
| NFR-10 | Feature gating | Isolation | Agent Teams code has zero side effects when flag is off |
| NFR-11 | Config write round-trip | Latency | Toggle -> backend save -> re-read < 2s |
| NFR-12 | Plugin clone | Timeout | < 60s for typical plugin repos; clear progress/error on timeout |

---

## Stub Audit Requirements

**14 issues identified** across the full app during comprehensive audit. Each MUST be fixed as part of this spec.

### CRITICAL (3) — User-facing buttons that do nothing or simulate behavior

| # | Stub | File(s) | Current Behavior | Required Fix | Priority |
|---|------|---------|-----------------|--------------|----------|
| S-1 | `SSHConnectionManager.testConnection()` | `SSHConnectionManager.swift:84-88` | `Task.sleep(1.5s)` + checks non-empty fields; never calls backend | Call `POST /api/v1/ssh/test` using real `SSHService` (Citadel) | P0 |
| S-12 | Settings Quick Toggles (Extended Thinking, Co-Author) | `SettingsView.swift:270-286` | Two toggles with `set: { _ in }` and `.disabled(true)` — tapping does nothing | Remove disabled state; write toggle value to backend via `PUT /api/v1/config` | P0 |
| S-13 | Config History "Restore" button | `ConfigHistoryView.swift:14-18, 111-117` | Context menu button has empty `{ }` closure; sheet button only calls `dismiss()` | Call `PUT /api/v1/config` with historical values; show confirmation + success feedback | P0 |

### HIGH (11) — Hardcoded data, missing persistence, or placeholder endpoints

| # | Stub | File(s) | Current Behavior | Required Fix | Priority |
|---|------|---------|-----------------|--------------|----------|
| S-2 | `FleetManagementView` | `FleetManagementView.swift` | `RemoteServer.sampleFleet` (4 hardcoded servers) | Load from `GET /api/v1/fleet` | P0 |
| S-3 | `ConfigProfilesView` | `ConfigProfilesView.swift` | `ConfigProfile.defaults` (3 hardcoded) | Load from `GET /api/v1/config/profiles` | P1 |
| S-4 | `ConfigOverridesView` | `ConfigOverridesView.swift` | `ConfigOverrideItem.sampleData` (7 hardcoded) | Load real config cascade from API | P1 |
| S-5 | `ConfigHistoryView` | `ConfigHistoryView.swift:4, 131-139` | `ConfigChange.sampleHistory` (5 hardcoded entries) | Load from git history or API | P1 |
| S-6 | `CloudSyncView` | `CloudSyncView.swift` | Local `@State` only; "Sync Now" sets `Date()` | Mark as "Coming Soon" or remove from nav | P2 |
| S-7 | `AutomationScriptsView` | `AutomationScriptsView.swift` | `AutomationScript.samples` (3 hardcoded) | Mark as "Coming Soon" or remove from nav | P2 |
| S-8 | `NotificationPreferencesView` | `NotificationPreferencesView.swift` | Local `@State` only; no persistence | Mark as "Coming Soon" or wire to real prefs | P2 |
| S-9 | `LogViewerView` | `LogViewerView.swift` | Empty state; `AppLogger.shared` exists but not wired | Wire to `AppLogger` for real log display | P2 |
| S-10 | `SessionTemplatesView` | `SessionTemplatesView.swift:90-97` | Loads from `UserDefaults` only; defaults to 4 hardcoded `SessionTemplate.defaults` | Load from backend API; use UserDefaults as offline fallback only | P1 |
| S-11 | Plugin Install endpoint | `PluginsController.swift:215-233` | Returns fake `Plugin` object; comment says "In a real implementation, this would clone from the marketplace / For now, return a placeholder" | Actually clone repo from marketplace URL; register in `installed_plugins.json` | P1 |

---

## Validation Requirements

Every feature MUST have evidence before claiming completion. **19 total validation items** (up from 15).

| ID | Feature | Validation Method | Evidence Type |
|----|---------|------------------|---------------|
| V-1 | Experimental flag toggle | Toggle on/off in Settings; verify `~/.claude/settings.json` via curl | Screenshot + curl output |
| V-2 | Team list (empty state) | Open Agent Teams tab with no teams | Screenshot |
| V-3 | Team creation | Create team from iOS; verify `~/.claude/teams/{name}/config.json` exists | Screenshot + curl + file check |
| V-4 | Team detail view | Open created team; verify member list matches config.json | Screenshot |
| V-5 | Task list | View tasks for a team; verify matches `~/.claude/tasks/{name}/` files | Screenshot + curl |
| V-6 | Task creation | Create task from iOS; verify JSON file written | Screenshot + file check |
| V-7 | Task status update | Change task status; verify JSON file updated | Screenshot + curl |
| V-8 | Teammate spawn | Spawn teammate; verify process running (`ps aux`) + config.json updated | Screenshot + process check |
| V-9 | Teammate shutdown | Shutdown teammate; verify process terminated | Screenshot + process check |
| V-10 | Message send | Send message from iOS; verify delivery | Screenshot |
| V-11 | Team deletion | Delete team; verify directory removed + processes killed | Screenshot + file/process check |
| V-12 | SSH real test | Test connection to real SSH server | Screenshot with latency |
| V-13 | Fleet real data | Fleet view with real server statuses | Screenshot (no "sampleFleet") |
| V-14 | Config profiles real | Profiles from real config scopes | Screenshot (no "defaults") |
| V-15 | Feature gating | Toggle off -> Agent Teams nav hidden | Screenshot |
| V-16 | Extended Thinking toggle | Toggle on in Quick Settings; verify `alwaysThinking: true` in settings.json via curl | Screenshot + curl output |
| V-17 | Config Restore | Open Config History; tap "Restore This Version"; verify config changed via curl | Screenshot + curl before/after |
| V-18 | Session Templates | Open New Session -> Templates; verify templates load (not just UserDefaults defaults) | Screenshot + backend API check |
| V-19 | Plugin Install | Install a plugin from marketplace; verify files exist at `~/.claude/plugins/{name}/` | Screenshot + `ls` output |

---

## Glossary

- **Agent Team**: A coordinated group of Claude Code instances (1 lead + N teammates) sharing a task list and mailbox
- **Team Lead**: The primary Claude Code session that creates the team, spawns teammates, and coordinates work
- **Teammate**: A secondary Claude Code instance spawned by the lead, working on assigned tasks
- **Task List**: Shared JSON-file-based work items at `~/.claude/tasks/{team-name}/`; states: pending, in_progress, completed
- **Mailbox**: Inter-agent messaging system for direct and broadcast messages
- **Teammate Mode**: Execution mode for teammates — `in-process` (same terminal), `tmux` (separate pane), `auto` (system decides)
- **Experimental Flag**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var / settings.json entry that gates the feature
- **File Locking**: `.lock` files used to prevent race conditions when multiple agents claim tasks concurrently
- **Stub**: A UI view or service method that uses hardcoded/simulated data instead of real backend integration
- **PID Tracking**: Backend maintains Process ID mapping for spawned teammate processes to enable health checks and cleanup
- **Quick Settings**: The "Quick Settings" section in SettingsView containing toggles for Extended Thinking, Co-Author, and model selection
- **Config Restore**: Rolling back a configuration key to a previously recorded historical value

## Out of Scope

- **Remote teammate spawning** via SSH (teammates run locally only)
- **Nested teams** (teams within teams — not supported by Claude Code)
- **Session resumption** with in-process teammates (Claude Code limitation)
- **Push notifications** for team events (polling only; no APNs integration)
- **iCloud sync** for team data (CloudSyncView remains aspirational)
- **Automation script execution** (AutomationScriptsView remains aspirational)
- **Cost/token tracking** per teammate (no API for this exists)
- **Team templates** or presets (create from scratch only)
- **Multi-machine teams** (all teammates on same machine as backend)
- **WebSocket real-time updates** (polling is sufficient for MVP; WebSocket upgrade is future work)
- **Plugin dependency resolution** (install clones repo only; no transitive dependency management)

## Dependencies

| Dependency | Type | Notes |
|-----------|------|-------|
| Claude CLI installed on backend host | Runtime | Required for team creation and teammate spawning |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` feature flag | Runtime | Must be enabled for any team operations |
| Citadel/NIOSSH (already in Package.swift) | Library | Required for real SSH testing (S-1, S-2) |
| `~/.claude/` filesystem access | Runtime | Backend reads/writes teams, tasks, config, plugins |
| Existing `ClaudeExecutorService` pattern | Code | Reuse Process spawning pattern for teammates |
| Existing `FileSystemService` pattern | Code | Reuse filesystem reading pattern for teams/tasks |
| Existing `SSHService.swift` | Code | Wire to `SSHConnectionManager.testConnection()` |
| Existing `ConfigController` PUT endpoint | Code | Used by Extended Thinking / Co-Author toggles + Config Restore |
| ILSShared package | Code | New models must compile for both iOS and backend |
| Git CLI on backend host | Runtime | Optional: for git-based config history (S-5) |

## Success Criteria

1. **Agent Teams CRUD**: User creates team from iOS, sees it in list, views members, manages tasks, sends messages, and deletes team — all via real backend with zero hardcoded data
2. **Zero stubs remaining for P0/P1 items**: All 8 P0 + 6 P1 items wired to real backend (S-1 through S-5, S-10 through S-13, plus FR-22/23/24/25/26)
3. **Evidence portfolio**: Minimum **19 screenshots + curl outputs** proving every feature works through real UI
4. **Feature isolation**: Toggling experimental flag off completely hides Agent Teams with no side effects on existing features
5. **Process hygiene**: No orphaned Claude CLI processes after team deletion; backend tracks all spawned PIDs
6. **Settings toggles functional**: Extended Thinking and Co-Author toggles read/write real values round-trip through backend
7. **No dead buttons**: Every tappable UI element performs a real action or is explicitly marked "Coming Soon" with visual indication

---

## Unresolved Questions

1. **Mailbox file location**: Where exactly are teammate messages stored on disk? The official docs don't specify a filesystem path. Backend may need to intercept stdout/stderr of teammate processes instead.
2. **Non-interactive team creation**: Does `claude` CLI support creating teams via a single command, or must it go through an interactive session? Backend approach may need to send prompts to stdin.
3. **Filesystem format stability**: The `~/.claude/teams/` and `~/.claude/tasks/` JSON formats are undocumented. Future Claude Code updates could break parsing. Mitigation: version-check on startup + abstract behind service layer.
4. **Config history source**: `ConfigHistoryView` needs a data source. Options: (a) git log of `~/.claude/settings.json`, (b) manual change tracking in backend DB, (c) timestamp-based file snapshots. Needs decision.
5. **Backend restart resilience**: If the Vapor backend restarts, it loses PID tracking for running teammates. Need a strategy to rediscover running team processes (scan `~/.claude/teams/` + check for matching processes).
6. **Fleet probe depth**: How deep should fleet probing go? Options: (a) SSH connectivity only, (b) + Claude CLI version check, (c) + skill/MCP counts. More depth = more latency.
7. **Plugin clone mechanism**: Should `POST /api/v1/plugins/install` use `git clone`, download a tarball, or use a package registry? The marketplace URL format determines the approach.
8. **Session Templates backend endpoint**: No `/api/v1/sessions/templates` endpoint exists yet. Needs new controller route or could be folded into existing config system.

## Next Steps

1. Approve or revise these requirements (14 audit items + Agent Teams features)
2. Design phase: create UI wireframes for 8 new Agent Teams views + settings integration
3. Implementation phase 1: Backend services (`TeamsFileService`, `TeamsExecutorService`, `TeamsController`) + shared models
4. Implementation phase 2: Fix all P0 stubs (SSH test, Fleet Management, Settings toggles, Config Restore) — validates the integration pattern
5. Implementation phase 3: Fix P1 stubs (Config views, Session Templates, Plugin Install)
6. Implementation phase 4: iOS views + view models for Agent Teams
7. Implementation phase 5: Settings integration + feature gating
8. Validation phase: Evidence capture for all **19 validation items**
