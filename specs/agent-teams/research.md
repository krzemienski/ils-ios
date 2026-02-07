---
spec: agent-teams
phase: research
created: 2026-02-06T10:49:00Z
---

# Research: agent-teams

## Executive Summary

Agent Teams is an experimental Claude Code feature (launched with Opus 4.6) that coordinates multiple CLI instances via a shared task list and inter-agent messaging. The ILS iOS app currently has **zero** Agent Teams code. The backend already runs Claude CLI as a subprocess (`ClaudeExecutorService`) and can read `~/.claude/` filesystem, making it feasible to add Agent Teams management. However, a thorough codebase audit reveals **6 existing Settings sub-views are stubs with hardcoded data** -- these should be addressed alongside or before Agent Teams work.

## External Research

### Agent Teams Architecture (from Official Docs)

Source: [code.claude.com/docs/en/agent-teams](https://code.claude.com/docs/en/agent-teams)

| Component | Description |
|-----------|-------------|
| **Team lead** | Main Claude Code session; creates team, spawns/coordinates teammates |
| **Teammates** | Separate Claude Code instances working on assigned tasks |
| **Task list** | Shared work items with states: pending, in-progress, completed + dependencies |
| **Mailbox** | Inter-agent messaging (direct + broadcast) |

**On-disk storage (COMPLETE — verified from docs, community research, and local filesystem):**

```
~/.claude/teams/{team-name}/
├── config.json              # Team metadata + members array
└── inboxes/
    ├── team-lead.json       # Lead's mailbox (JSON array of messages)
    ├── worker-1.json        # Teammate 1's mailbox
    └── worker-N.json        # Teammate N's mailbox

~/.claude/tasks/{team-name}/
├── .lock                    # File lock for race-condition prevention
├── .highwatermark           # Highest task ID created (single number)
├── 1.json                   # Task #1
└── N.json                   # Task #N
```

**config.json format** (from community reverse-engineering + official docs):
```json
{
  "name": "my-project",
  "description": "Working on feature X",
  "leadAgentId": "team-lead@my-project",
  "createdAt": 1706000000000,
  "members": [
    {
      "agentId": "team-lead@my-project",
      "name": "team-lead",
      "agentType": "team-lead",
      "color": "#4A90D9",
      "joinedAt": 1706000000000,
      "backendType": "in-process"
    },
    {
      "agentId": "worker-1@my-project",
      "name": "worker-1",
      "agentType": "Explore",
      "model": "haiku",
      "prompt": "Analyze the codebase structure...",
      "color": "#D94A4A",
      "planModeRequired": false,
      "joinedAt": 1706000001000,
      "tmuxPaneId": "in-process",
      "cwd": "/Users/me/project",
      "backendType": "in-process"
    }
  ]
}
```

**Member fields (required):** `agentId`, `name`, `agentType`, `color`, `joinedAt`, `backendType`
**Member fields (optional):** `model`, `prompt`, `planModeRequired`, `tmuxPaneId`, `cwd`

**Task JSON format** (verified from `~/.claude/tasks/` on this machine + team-scoped additions):
```json
{
  "id": "1",
  "subject": "Review authentication module",
  "description": "Review all files in app/services/auth/...",
  "activeForm": "Reviewing auth module...",
  "status": "in_progress",
  "owner": "security-reviewer",
  "blocks": ["3"],
  "blockedBy": [],
  "createdAt": 1706000000000,
  "updatedAt": 1706000001000
}
```
Note: Team tasks add `owner`, `createdAt`, `updatedAt` fields vs regular session tasks.

**Inbox message types** (8 distinct message types):

| Type | Key Fields | Purpose |
|------|-----------|---------|
| (plain message) | `from`, `text`, `timestamp`, `read` | Direct or broadcast text |
| `shutdown_request` | `type`, `requestId`, `from`, `reason` | Lead asks teammate to stop |
| `shutdown_approved` | `type`, `requestId`, `from`, `paneId`, `backendType` | Teammate confirms shutdown |
| `idle_notification` | `type`, `from`, `completedTaskId`, `completedStatus` | Teammate finished a turn |
| `task_completed` | `type`, `from`, `taskId`, `taskSubject` | Teammate finished a task |
| `plan_approval_request` | `type`, `from`, `requestId`, `planContent` | Teammate submits plan for review |
| `join_request` | `type`, `proposedName`, `requestId`, `capabilities` | Agent requests to join team |
| `permission_request` | `type`, `requestId`, `workerId`, `workerName`, `toolName`, `input`, `permissionSuggestions` | Teammate needs permission |

**Environment variables (auto-injected per teammate process):**
```bash
CLAUDE_CODE_TEAM_NAME="my-project"
CLAUDE_CODE_AGENT_ID="worker-1@my-project"
CLAUDE_CODE_AGENT_NAME="worker-1"
CLAUDE_CODE_AGENT_TYPE="Explore"
CLAUDE_CODE_AGENT_COLOR="#4A90D9"
CLAUDE_CODE_PLAN_MODE_REQUIRED="false"
CLAUDE_CODE_PARENT_SESSION_ID="session-xyz"
```

**Configuration:**
- Enable: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in env or settings.json
- `teammateMode`: `"in-process"` (default), `"tmux"`, `"auto"`
- CLI flag: `--teammate-mode in-process`

**Key constraints:**
- One team per session (lead is fixed)
- No nested teams (teammates cannot spawn sub-teams)
- No session resumption with in-process teammates
- Permissions inherited from lead at spawn time
- File-locking for task claiming (race condition prevention)
- Graceful shutdown: lead must clean up; teammates should not run cleanup

### Prior Art

- No known iOS/mobile management UI for Agent Teams exists anywhere
- [Addy Osmani's writeup](https://addyosmani.com/blog/claude-code-agent-teams/) covers CLI-only usage patterns
- [Xcode 26.3](https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/) integrates Claude Agent SDK but does NOT expose Agent Teams management
- [NxCode tutorial](https://www.nxcode.io/resources/news/claude-agent-teams-parallel-ai-development-guide-2026) covers setup from terminal only

### Pitfalls to Avoid

- **Race conditions on task claiming**: Must use file locking or backend serialization
- **Token cost scaling**: Each teammate = separate context window; costs multiply
- **Lead vs teammate confusion**: Only the lead should clean up teams
- **Orphaned processes**: tmux sessions can persist after team cleanup fails
- **Task status lag**: Teammates sometimes forget to mark tasks completed

## Codebase Analysis

### Existing Architecture Pattern

The app follows a clear pattern for each feature domain:

```
ILSShared/Models/   -> Codable structs (shared iOS + backend)
ILSBackend/Services/ -> Business logic (file I/O, Process execution)
ILSBackend/Controllers/ -> Vapor routes (REST API)
ILSApp/Services/    -> APIClient calls + SSEClient for streaming
ILSApp/ViewModels/  -> @MainActor ObservableObject classes
ILSApp/Views/       -> SwiftUI views
```

**Real-time pattern**: ChatController uses SSE streaming via `ClaudeExecutorService.execute()` -> `AsyncThrowingStream<StreamMessage>` -> SSE events. The iOS `SSEClient` consumes these as `URLSession.AsyncBytes.lines`.

### COMPREHENSIVE STUB AUDIT

#### CONFIRMED STUBS (hardcoded/simulated, NO backend integration)

| # | View/Service | Evidence | Severity |
|---|-------------|----------|----------|
| 1 | `SSHConnectionManager.testConnection()` | Line 84-88: `Task.sleep(1.5s)` then returns `!host.isEmpty && !username.isEmpty`. Comment says "Simulated connection test" | HIGH -- backend `SSHService.swift` has real Citadel SSH |
| 2 | `FleetManagementView` | Line 4: `@State private var servers = RemoteServer.sampleFleet` -- 4 hardcoded servers, zero API calls | HIGH -- no `/fleet` endpoint exists |
| 3 | `ConfigProfilesView` | Line 4: `@State private var profiles = ConfigProfile.defaults` -- 3 hardcoded profiles, purely in-memory | MEDIUM -- no persistence or API |
| 4 | `ConfigOverridesView` | Line 4: `let overrides = ConfigOverrideItem.sampleData` -- 7 hardcoded items | MEDIUM -- read-only visualization, could read real config layers |
| 5 | `ConfigHistoryView` | Line 4: `@State private var changes = ConfigChange.sampleHistory` -- 5 hardcoded entries. "Restore" button does nothing | MEDIUM -- no change tracking backend |
| 6 | `CloudSyncView` | All toggles are local `@State` only. "Sync Now" just sets `lastSyncDate = Date()`. No iCloud integration | LOW -- aspirational feature |
| 7 | `AutomationScriptsView` | Line 7: `@State private var scripts = AutomationScript.samples` -- 3 hardcoded entries. No execution engine | LOW -- aspirational feature |
| 8 | `NotificationPreferencesView` | Not audited in detail but follows same `@State` pattern | LOW |
| 9 | `LogViewerView` | Shows "empty state" -- `AppLogger.shared` exists but log viewer may not connect | LOW |

#### CONFIRMED REAL (functional with backend)

| # | Feature | Evidence |
|---|---------|----------|
| 1 | Sessions CRUD | `SessionsController` with Fluent ORM, tested with 9 real sessions |
| 2 | Chat/SSE Streaming | `ChatController.stream()` -> `ClaudeExecutorService` -> real Claude CLI subprocess |
| 3 | Projects list | `ProjectsController` reads `~/.claude/projects/` via `FileSystemService` (371 real projects) |
| 4 | Skills list | `SkillsController` reads `~/.claude/commands/` YAML files (1527 real skills) |
| 5 | MCP Servers list | `MCPController` reads settings.json MCP configs (20 real servers) |
| 6 | Plugins list | `PluginsController` scans installed plugins (78 real plugins) |
| 7 | Config read/write | `ConfigController` reads/writes `~/.claude/settings.json` via `ConfigFileService` |
| 8 | Stats dashboard | `StatsController` aggregates real counts from all services |
| 9 | Health endpoint | Returns Claude CLI version, uptime |
| 10 | External session scan | `FileSystemService.scanExternalSessions()` reads `~/.claude/projects/` |
| 11 | Session transcripts | Reads JSONL files from `~/.claude/projects/*/sessions/*.jsonl` |
| 12 | SSH backend service | `SSHService.swift` uses Citadel/NIOSSH -- real connect, executeCommand, probeServerInfo |
| 13 | Keychain storage | `SSHConnectionManager` stores credentials in real Keychain (CRUD works) |
| 14 | Cache management | `CacheManager.shared` with real disk size calculation |

#### PARTIALLY REAL

| # | Feature | Real Part | Stub Part |
|---|---------|-----------|-----------|
| 1 | SSH Connections | CRUD + Keychain storage | `testConnection()` is simulated |
| 2 | Settings General | Config loading via API | Quick Settings toggles (Extended Thinking, Co-Author) are read-only/disabled |
| 3 | Permission decision | Controller exists | Just logs -- doesn't communicate with running Claude process |

### Dependencies Available

| Dependency | Version | Relevant For |
|-----------|---------|-------------|
| Vapor | 4.89+ | Backend HTTP framework, WebSocket, SSE |
| Fluent + SQLite | 4.9+ / 4.6+ | ORM for sessions, messages |
| ILSShared | local | Shared models between iOS and backend |
| Citadel | 0.7+ | Real SSH (for remote team management) |
| ClaudeCodeSDK (forked) | main | Not used (RunLoop issue), but available |

### Constraints

- **No `~/.claude/teams/` directory exists yet** on this machine (never created a team)
- **`~/.claude/tasks/` exists** with 100+ task directories from regular Claude Code usage
- Backend runs on macOS only (Vapor + Process) -- not a remote server
- iOS app connects to `localhost:9090` -- local-only architecture
- Agent Teams is CLI-level feature -- there is NO API for it. Backend must read/write filesystem directly
- ClaudeCodeSDK doesn't work in Vapor (RunLoop issue) -- must use Process directly

## Proposed Architecture

### New Backend Endpoints

All under `/api/v1/teams/`:

| Method | Endpoint | Description | Implementation |
|--------|----------|-------------|----------------|
| `GET` | `/teams` | List all teams | Read `~/.claude/teams/*/config.json` |
| `POST` | `/teams` | Create team | Spawn Claude CLI with team creation prompt |
| `GET` | `/teams/:name` | Get team details | Read `~/.claude/teams/{name}/config.json` |
| `DELETE` | `/teams/:name` | Clean up team | Send cleanup command to lead |
| `GET` | `/teams/:name/tasks` | List tasks | Read `~/.claude/tasks/{name}/*.json` |
| `POST` | `/teams/:name/tasks` | Create task | Write task JSON to `~/.claude/tasks/{name}/` |
| `PUT` | `/teams/:name/tasks/:id` | Update task | Update task JSON (status, assignment) |
| `POST` | `/teams/:name/teammates` | Spawn teammate | Execute Claude CLI with teammate config |
| `DELETE` | `/teams/:name/teammates/:id` | Shutdown teammate | Send shutdown message to teammate |
| `POST` | `/teams/:name/messages` | Send message | Write to teammate mailbox |
| `GET` | `/teams/:name/messages` | Get messages | Read mailbox contents |

### New Backend Service

`TeamsFileService.swift` -- reads/writes `~/.claude/teams/` and `~/.claude/tasks/` filesystem:
- `listTeams()` -> scan directories
- `getTeamConfig(name:)` -> parse config.json
- `listTasks(teamName:)` -> parse task JSON files
- `createTask(teamName:, task:)` -> write JSON with file locking
- `updateTaskStatus(teamName:, taskId:, status:)` -> update JSON

`TeamsExecutorService.swift` -- wraps Claude CLI for team operations:
- `createTeam(prompt:, teammateMode:)` -> spawn `claude` with team creation prompt
- `spawnTeammate(teamName:, role:, model:, prompt:)` -> spawn new teammate
- `sendMessage(teamName:, to:, message:)` -> write to mailbox
- `shutdownTeammate(teamName:, teammateId:)` -> send shutdown signal

### New Shared Models (ILSShared)

```swift
// AgentTeam.swift
struct AgentTeam: Codable, Identifiable {
    let name: String
    let members: [TeamMember]
    let createdAt: Date
    let status: TeamStatus
    var id: String { name }
}

struct TeamMember: Codable, Identifiable {
    let name: String
    let agentId: String
    let agentType: String  // "lead" or "teammate"
    let model: String?
    let status: MemberStatus
    var id: String { agentId }
}

enum TeamStatus: String, Codable { case active, completed, error }
enum MemberStatus: String, Codable { case running, idle, stopped }

// TeamTask.swift
struct TeamTask: Codable, Identifiable {
    let id: String
    let subject: String
    let description: String
    let activeForm: String?
    let status: TaskStatus
    let blocks: [String]
    let blockedBy: [String]
    let assignedTo: String?
}

enum TaskStatus: String, Codable { case pending, in_progress, completed }

// TeamMessage.swift
struct TeamMessage: Codable, Identifiable {
    let id: UUID
    let from: String
    let to: String?  // nil = broadcast
    let content: String
    let timestamp: Date
}
```

### New iOS Views

| View | Purpose | Priority |
|------|---------|----------|
| `AgentTeamsListView` | List all teams with status badges, create button | P0 |
| `AgentTeamDetailView` | Team overview: lead + teammates + task progress | P0 |
| `TeammateDetailView` | Individual teammate status, messages, current task | P1 |
| `TeamTaskListView` | Shared task list with status filtering, dependency visualization | P0 |
| `TeamTaskDetailView` | Task details, assignment, status transitions | P1 |
| `TeamMessagesView` | Message thread between agents, broadcast support | P1 |
| `CreateTeamView` | Team creation flow: name, prompt, teammate config | P0 |
| `TeamSettingsView` | Enable/disable flag toggle, teammate mode picker | P0 |

### New iOS ViewModels

- `AgentTeamsViewModel` -- list/create/delete teams via APIClient
- `AgentTeamDetailViewModel` -- team details + polling for updates
- `TeamTasksViewModel` -- task CRUD with real-time status updates

### Settings Integration

Add to `SettingsView.swift`:
1. New "Experimental" section with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` toggle
2. `teammateMode` picker (in-process / tmux / auto)
3. NavigationLink to `AgentTeamsListView`

### Navigation Integration

Add "Agent Teams" tab or sidebar entry in `ContentView.swift` (gated behind experimental flag).

## Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | **High** | Backend already runs Claude CLI as subprocess; filesystem access to `~/.claude/` is proven pattern |
| Effort Estimate | **L** | New controller, service, 8+ views, shared models, settings integration |
| Risk Level | **Medium** | Agent Teams is experimental/unstable; filesystem format may change; race conditions with file locking |
| iOS-specific challenges | **Medium** | No direct CLI interaction from iOS; everything proxied through backend. Polling needed (no push from teammates) |

### Key Feasibility Factors

**Why it WILL work:**
1. `ClaudeExecutorService` already spawns `claude` CLI as `Process` -- same pattern for team management
2. `FileSystemService` already reads `~/.claude/projects/` -- same pattern for `~/.claude/teams/` and `~/.claude/tasks/`
3. `SSEClient` pattern can be reused for real-time task/message updates
4. Backend has shell access and full filesystem access

**Why it needs care:**
1. **No official API**: Agent Teams is CLI-only. Backend must reverse-engineer filesystem format
2. **Filesystem format stability**: `~/.claude/teams/` and `~/.claude/tasks/` formats are undocumented and may change
3. **Process management**: Teammates are long-running processes; backend needs to track PIDs
4. **Polling overhead**: iOS app must poll for task/message updates (no push notifications from teammates)
5. **Race conditions**: File-locking for task claiming adds complexity to backend service

## Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Filesystem format changes in future Claude Code versions | Medium | High | Abstract filesystem access behind service layer; version-check on startup |
| Teammate processes orphaned on backend crash | Medium | Medium | PID tracking + health checks; `tmux kill-session` cleanup |
| Race conditions on task claiming | Low | Medium | Backend serializes all task writes; use same file-locking as CLI |
| Token cost surprises from spawning multiple teammates | Medium | Low | Surface cost estimates in UI; warn before spawning |
| Feature removed from Claude Code | Low | High | Gate behind experimental flag; clean separation from core app |

## Related Specs

| Spec | Relevance | Notes | mayNeedUpdate |
|------|-----------|-------|---------------|
| `ils-complete-rebuild` | **High** | Defines comprehensive rebuild plan with 42 tasks. Agent Teams is a new major feature not in that plan. The SSH/remote management work overlaps (spawning teammates on remote servers). | true |
| `app-improvements` | **Medium** | General UX polish. Agent Teams UI should follow same design patterns. Stub audit findings overlap. | false |

## Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Backend Build | `swift build` | Package.swift (Swift Package Manager) |
| Backend Run | `PORT=9090 swift run ILSBackend` | docs/RUNNING_BACKEND.md |
| iOS Build | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build` | Xcode project |
| Lint | Not found | No SwiftLint configured |
| TypeCheck | N/A (Swift compiler) | Built-in to `swift build` / `xcodebuild` |
| Unit Test | Not found | No test targets in Package.swift |
| Integration Test | Not found | Manual validation required |
| E2E Test | Not found | Simulator automation |

**Local CI**: `swift build && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build`

## Recommendations for Requirements

1. **Phase the work**: Start with read-only team/task viewing (filesystem reading), then add team creation/management (process spawning), then messaging
2. **Fix stubs first**: Wire `SSHConnectionManager.testConnection()` to real backend `SSHService`. Wire `FleetManagementView` to API. This builds confidence and exercises the integration pattern needed for Agent Teams
3. **Abstract filesystem access**: Create `TeamsFileService` that reads `~/.claude/teams/` and `~/.claude/tasks/` -- same pattern as existing `FileSystemService`
4. **Gate behind experimental flag**: Add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` toggle in Settings. Hide all Agent Teams UI when disabled
5. **Polling with configurable interval**: Use `Timer` or `Task.sleep` loop for task/message updates (2-5 second intervals); no push mechanism available
6. **Reuse SSE for team lead interactions**: When a team lead is running, use the same SSE streaming pattern as ChatView for real-time output
7. **Track teammate PIDs**: Backend must maintain PID-to-teammate mapping for health checks and cleanup
8. **Add teammate mode support**: Support `in-process` mode first (simpler); `tmux` mode adds complexity but is more powerful

## Open Questions

1. ~~**Filesystem format stability**~~: ANSWERED — Format is undocumented but community has reverse-engineered it. Config.json schema is stable with `name`, `description`, `leadAgentId`, `createdAt`, `members[]`. Feature is experimental so format may change.
2. ~~**Team creation via CLI**~~: ANSWERED — No CLI flags for team creation. Teams are created via natural language prompt to Claude Code session, which uses `TeamCreate` tool internally. Backend must interact via a Claude Code session (Process).
3. ~~**Mailbox location**~~: ANSWERED — `~/.claude/teams/{team-name}/inboxes/{agent-name}.json`. Each agent has its own inbox file (JSON array of messages). 8 message types documented above.
4. **Remote teammates**: UNANSWERED — Official docs say nothing about remote teammates. Likely local-only (each teammate is a local Process). Remote would require SSH + Claude CLI on remote machine.
5. ~~**Team lead session relationship**~~: ANSWERED — Yes, team lead IS a regular Claude Code session that additionally has TeamCreate, SendMessage, TaskList/TaskCreate/TaskUpdate/TaskGet tools. Environment variables injected to identify team context. Lead session is fixed for team lifetime.
6. **Backend long-running processes**: PARTIALLY ANSWERED — Teammates are separate Claude Code processes. Backend can track PIDs. No built-in PID recovery after restart. tmux sessions persist and can be listed/killed. In-process teammates die with lead process.

### NEW Open Questions (from deep research)

7. **`.highwatermark` vs `.lock` semantics**: `.highwatermark` contains next task ID (verified: just a number). `.lock` is empty file used for flock(). Does Claude Code use POSIX flock() or something else?
8. **Inbox file format**: Is each inbox file a JSON array or JSONL (one message per line)? Community examples show individual objects but actual file could be array.
9. **Agent ID format**: Observed pattern is `{name}@{team-name}`. Is this guaranteed? Does it change for tmux/iterm2 backends?
10. **Team cleanup on disk**: Does `TeamDelete` just remove `~/.claude/teams/{name}/` and `~/.claude/tasks/{name}/`? Or are there other locations to clean?

## Sources

- [Official Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams) -- primary reference (re-fetched 2026-02-06)
- [Addy Osmani's Claude Code Swarms writeup](https://addyosmani.com/blog/claude-code-agent-teams/)
- [NxCode Agent Teams Tutorial](https://www.nxcode.io/resources/news/claude-agent-teams-parallel-ai-development-guide-2026)
- [Anthropic Opus 4.6 announcement](https://www.anthropic.com/news/claude-opus-4-6)
- [TechCrunch coverage](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [Kieran Klaassen's Swarm Orchestration Gist](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea) -- **most detailed schema source**: full config.json, task, inbox, env var schemas
- [ClaudeFast Agent Teams Guide](https://claudefa.st/blog/guide/agents/agent-teams) -- architecture overview
- [Paddo.dev "The Switch Got Flipped"](https://paddo.dev/blog/agent-teams-the-switch-got-flipped/) -- file locking and self-claiming details
- [Superpowers Issue #429](https://github.com/obra/superpowers/issues/429) -- TeammateTool, SendMessage, TaskList tool schemas
- `~/.claude/tasks/08434310-*/1.json` -- verified on-disk task format (session-scoped)
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/ClaudeExecutorService.swift` -- existing Process execution pattern
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/FileSystemService.swift` -- existing `~/.claude/` reading pattern
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ChatController.swift` -- SSE streaming pattern
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/SSEClient.swift` -- iOS SSE consumption pattern
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/SSHConnectionManager.swift` -- confirmed simulated testConnection (line 84-88)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/FleetManagementView.swift` -- confirmed hardcoded sampleFleet (line 4)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ConfigProfilesView.swift` -- confirmed hardcoded defaults (line 4)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ConfigOverridesView.swift` -- confirmed sampleData (line 4)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ConfigHistoryView.swift` -- confirmed sampleHistory (line 4)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/CloudSyncView.swift` -- confirmed local-only state
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/AutomationScriptsView.swift` -- confirmed hardcoded samples
