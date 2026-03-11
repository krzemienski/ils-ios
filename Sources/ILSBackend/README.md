# ILSBackend

Swift/Vapor REST API server that bridges iOS/macOS clients with Claude Code CLI and local filesystem configuration.

## Overview

- **REST API** — 216+ endpoints across 33 controllers
- **SSE streaming** — real-time chat via Claude Code CLI subprocess
- **WebSocket** — live system metrics and bidirectional chat
- **File scanning** — reads `~/.claude/` for sessions, skills, MCP config, and plugins
- **Cloudflare tunnel** — managed via `cloudflared` subprocess

## Quick Start

```bash
cd /path/to/ils-ios
PORT=9999 swift run ILSBackend
# Health check:
curl http://localhost:9999/health
```

See [docs/RUNNING_BACKEND.md](../../docs/RUNNING_BACKEND.md) for launchd, Docker, and tmux deployment options.

## Architecture

```
App/
├── entrypoint.swift          # @main, server bootstrap
├── configure.swift           # Middleware, database, route registration
└── routes.swift              # Maps controllers to route groups

Controllers/                  # 33 REST controllers
├── ActivityFeedController    # GET /activity (SSE stream + events)
├── AgentQueueController      # CRUD + templates + reorder + pause/resume
├── AnalyticsController       # Activity, sessions, skills, summary, export
├── AuditController           # Audit trail + rollback checkpoints
├── AutomationRulesController # CRUD + executions + templates
├── ChatController            # POST /chat/stream (SSE), WS /chat/ws/:id
├── CheckpointsController     # CRUD + restore
├── ConfigController          # Get/Set/Validate across scopes
├── DataErasureController     # Full data reset
├── HealthController          # /health, /health/ready, /health/live
├── HostProfileController     # CRUD + activate + health + fleet
├── MCPController             # CRUD + scope filtering (user/project)
├── PairingController         # QR code generation
├── PermissionsController     # Pending + history + decide + clear
├── PluginsController         # CRUD + marketplace + GitHub search + enable/disable
├── ProjectsController        # List + detail + project sessions
├── RecordingController       # CRUD + events + export
├── SessionBackupController   # Checkpoints + restore
├── SessionHealthController   # Summary + export + per-session + projects
├── SessionsController        # CRUD + scan + fork + search + export + messages
├── SkillsController          # CRUD + GitHub search + install
├── SSHController             # Connect + disconnect + status + execute
├── StatsController           # Dashboard stats + recent sessions + settings
├── SuggestionsController     # Sessions, skills, abandoned, prompts
├── SystemController          # Metrics + processes + files + live WS
├── TeamsController           # Team/member/task/message CRUD + spawn
├── TemplatesController       # CRUD + bulk delete
├── TerminalController        # Execute + config + reset
├── ThemesController          # Custom theme CRUD (database-backed)
├── TunnelController          # Start/stop/status/health/logs
├── UsageController           # Usage stats + export
├── WorkflowsController       # CRUD + execute + schedules + pause/cancel
└── SessionBackupController   # Checkpoint + restore

Services/                     # 39 business logic services
├── ClaudeExecutorService     # Spawns `claude -p` via Process + DispatchQueue
├── StreamingService          # SSE event formatting
├── WebSocketService          # WS connection lifecycle
├── CLIMessageConverter       # Parses Claude CLI JSON → StreamMessage
├── SessionFileService        # Reads ~/.claude/projects/*/sessions-index.json
├── IndexingService           # Session cache + deduplication
├── SkillsFileService         # Reads ~/.claude/skills/ directories
├── MCPFileService            # Reads/writes MCP config in ~/.claude.json
├── ConfigFileService         # Reads/writes settings.json across scopes
├── SystemMetricsService      # CPU, memory, disk, network via shell commands
├── GitHubService             # GitHub API for skill/plugin search
├── TunnelService             # cloudflared process management
├── FileSystemService         # Directory listing (home-restricted)
├── TeamsExecutorService      # Team agent spawning and coordination
├── TeamsFileService          # Team config reading (~/.claude/teams/)
├── WorkflowExecutionEngine   # Workflow step execution
├── WorkflowScheduler         # Cron-based workflow scheduling
├── AgentQueueService         # Background agent task queue management
└── ...

Models/                       # Fluent ORM models (SQLite)
├── SessionModel              # sessions table
├── MessageModel              # messages table (FK → sessions)
├── ProjectModel              # projects table (cached)
├── ThemeModel                # themes table (custom only)
└── FleetHostModel            # fleet_hosts table
```

## API Routes

All routes prefixed with `/api/v1` except `/health*`.

| Group | Prefix | Key Operations |
|-------|--------|----------------|
| Health | `/health` | GET, /ready, /live |
| Sessions | `/sessions` | CRUD, scan, fork, search, export, messages |
| Projects | `/projects` | List, detail, sessions |
| Chat | `/chat` | SSE stream, WebSocket, permissions, cancel |
| Skills | `/skills` | CRUD, GitHub search, install |
| Plugins | `/plugins` | CRUD, marketplace, GitHub search, enable/disable |
| MCP | `/mcp` | CRUD, scope filtering |
| Config | `/config` | Get, set, validate, export |
| Stats | `/stats` | Overview, recent, settings, server status |
| System | `/system` | Metrics, processes, files, live WebSocket |
| Teams | `/teams` | CRUD, spawn, tasks, messages, members |
| Workflows | `/workflows` | CRUD, execute, schedules, pause/cancel |
| Agent Queue | `/agent-queue` | CRUD, templates, reorder, pause/resume |
| Audit | `/audit` | Trail, rollback checkpoints |
| Analytics | `/analytics` | Activity, sessions, skills, summary, export |
| Activity Feed | `/activity` | Events, SSE stream |
| Permissions | `/permissions` | Pending, history, decide, clear |
| Host Profiles | `/host-profiles` | CRUD, activate, health, fleet |
| Tunnel | `/tunnel` | Start, stop, status, health, logs |
| Usage | `/usage` | Stats, export |
| SSH | `/ssh` | Connect, disconnect, status, execute |
| Terminal | `/terminal` | Execute, config, reset |
| Themes | `/themes` | Custom theme CRUD |

Full reference: [docs/API.md](../../docs/API.md)

## Key Implementation Details

### Claude CLI Integration

Backend spawns Claude Code CLI as a subprocess using `Process` + `DispatchQueue` for stdout reads.

**Why not ClaudeCodeSDK?** The SDK uses `FileHandle.readabilityHandler` + Combine `PassthroughSubject` which requires a RunLoop. Vapor's NIO event loops don't pump RunLoop — publisher never emits. Fix: use direct `Process` with `DispatchQueue`.

**Env var stripping:** `ClaudeExecutorService` strips `CLAUDECODE=1` and `CLAUDE_CODE_*` env vars before spawning. Without this, Claude CLI's nesting detection blocks execution inside active CC sessions.

### Session Deduplication

Sessions come from two sources:
1. **DB sessions** — created through ILS (authoritative)
2. **External sessions** — read from `~/.claude/projects/*/sessions-index.json`

DB sessions take priority. External sessions fill gaps. Combined list is paginated server-side.

### Two-Tier Chat Timeout

- Initial response: 30 seconds (abort if no data)
- Total execution: 5 minutes (hard cap on CLI time)

### Deterministic Project IDs

Generated from project path using SHA256 via `CryptoKit` (not `Crypto` — different SHA256 in Vapor context).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `9999` | Server port (avoid 8080 — used by ralph-mobile) |
| `DATABASE_PATH` | `./ils.sqlite` | SQLite database path |
| `VAPOR_ENV` | `development` | Environment mode |

## Dependencies

- **Vapor** 4.89+ — web framework
- **Fluent** 4.9+ — ORM
- **FluentSQLiteDriver** 4.6+ — SQLite driver
- **Yams** 5.0+ — YAML parsing (skill frontmatter)
- **ILSShared** — shared models and DTOs

## Gotchas

- Use `CryptoKit` not `Crypto` for SHA256 in Vapor context
- Always call `process.waitUntilExit()` before `process.terminationStatus`
- Use port 9999: `lsof -i :9999 -P -n` — binary path must be in `ils-ios/`, not `ils/ILSBackend`
- Strip `CLAUDECODE=1` env var before spawning claude subprocess
