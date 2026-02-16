# ILSBackend

Swift/Vapor REST API server that bridges iOS/macOS clients with Claude Code CLI and local filesystem configuration.

## Overview

The backend provides:
- **REST API** (80+ endpoints) for managing sessions, projects, skills, plugins, MCP servers, config, and teams
- **SSE streaming** for real-time chat with Claude Code
- **WebSocket** for live system metrics and bidirectional chat
- **File scanning** of `~/.claude/` for session discovery and config management
- **Cloudflare tunnel** management for remote access

## Quick Start

```bash
cd /path/to/ils-ios
PORT=9999 swift run ILSBackend
# Server starts at http://localhost:9999
# Health check: curl http://localhost:9999/health
```

See [docs/RUNNING_BACKEND.md](../../docs/RUNNING_BACKEND.md) for deployment options (launchd, Docker, tmux).

## Architecture

```
App/
├── entrypoint.swift          # @main, server bootstrap
├── configure.swift           # Middleware, database, route registration
└── routes.swift              # Maps controllers to route groups

Controllers/                  # 12 REST controllers
├── ChatController            # POST /chat/stream (SSE), WS /chat/ws/:id
├── SessionsController        # CRUD + scan + fork + transcript
├── ProjectsController        # List + detail + project sessions
├── SkillsController          # CRUD + GitHub search + install
├── PluginsController         # CRUD + marketplace + enable/disable
├── MCPController             # CRUD + scope filtering (user/project)
├── ConfigController          # Get/Set/Validate across scopes
├── StatsController           # Dashboard stats + recent sessions + settings
├── SystemController          # Metrics + processes + files + live WS
├── ThemesController          # Custom theme CRUD (database-backed)
├── TeamsController           # Team/member/task/message management
└── TunnelController          # Start/stop/status Cloudflare tunnel

Services/                     # 16 business logic services
├── ClaudeExecutorService     # Spawns `claude -p` subprocess via Process
├── StreamingService          # SSE event formatting
├── WebSocketService          # WS connection lifecycle
├── CLIMessageConverter       # Parses Claude CLI JSON to StreamMessage
├── SessionFileService        # Reads ~/.claude/projects/*/sessions-index.json
├── IndexingService           # Session cache + deduplication
├── SkillsFileService         # Reads ~/.claude/skills/ directories
├── MCPFileService            # Reads/writes MCP config in ~/.claude.json
├── ConfigFileService         # Reads/writes settings.json across scopes
├── SystemMetricsService      # CPU, memory, disk, network via shell commands
├── GitHubService             # GitHub API for skill search
├── TunnelService             # cloudflared process management
├── FileSystemService         # Directory listing (home-restricted)
├── TeamsExecutorService      # Team agent spawning and coordination
├── TeamsFileService          # Team config file reading (~/.claude/teams/)
└── ExecutionOptions          # Chat execution parameter types

Models/                       # Fluent ORM models (SQLite)
├── SessionModel              # sessions table
├── MessageModel              # messages table (FK to sessions)
├── ProjectModel              # projects table (cached)
├── ThemeModel                # themes table (custom only)
└── FleetHostModel            # fleet_hosts table

Migrations/                   # Database schema creation
├── CreateSessions
├── CreateMessages
├── CreateProjects
├── CreateThemes
├── CreateFleetHosts
└── CreateCachedResults

Middleware/
└── ILSErrorMiddleware        # Wraps errors in APIResponse format

Extensions/
└── VaporContent+Extensions   # Convenience extensions
```

## API Routes

All routes are prefixed with `/api/v1` except `/health`.

| Group | Prefix | Controller | Key Operations |
|-------|--------|------------|----------------|
| Health | `/health` | - | GET (plain text "OK") |
| Sessions | `/sessions` | SessionsController | CRUD, scan, fork, transcript, projects |
| Projects | `/projects` | ProjectsController | List, detail, project sessions |
| Chat | `/chat` | ChatController | SSE stream, WebSocket, permission, cancel |
| Skills | `/skills` | SkillsController | CRUD, GitHub search, install |
| Plugins | `/plugins` | PluginsController | CRUD, marketplace, enable/disable, install |
| MCP | `/mcp` | MCPController | CRUD with scope filtering |
| Config | `/config` | ConfigController | Get, set, validate |
| Stats | `/stats` | StatsController | Overview, recent, settings, server status |
| System | `/system` | SystemController | Metrics, processes, files, live WS |
| Themes | `/themes` | ThemesController | Custom theme CRUD |
| Teams | `/teams` | TeamsController | Team/member/task/message CRUD |
| Tunnel | `/tunnel` | TunnelController | Start, stop, status |

Full API reference: [docs/API.md](../../docs/API.md)

## Key Implementation Details

### Claude CLI Integration

The backend spawns Claude Code CLI as a subprocess using `Process` + `DispatchQueue` for stdout reads.

**Why not ClaudeCodeSDK?** The SDK uses `FileHandle.readabilityHandler` + Combine `PassthroughSubject` which requires a RunLoop. Vapor's NIO event loops don't pump RunLoop, so the publisher never emits.

### Session Deduplication

Sessions come from two sources:
1. **DB sessions** - Created through ILS (authoritative)
2. **External sessions** - Read from `~/.claude/projects/*/sessions-index.json`

DB sessions always take priority. External sessions fill gaps. The combined list is paginated server-side.

### Two-Tier Chat Timeout

- Initial response: 30 seconds (abort if no data received)
- Total execution: 5 minutes (hard cap on CLI execution time)

### Deterministic Project IDs

Project IDs are generated from the project path using SHA256 (CryptoKit, not Crypto).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `9999` | Server port |
| `DATABASE_PATH` | `./ils.sqlite` | SQLite database path |
| `VAPOR_ENV` | `development` | Environment mode |

## Dependencies

- **Vapor** 4.89+ - Web framework
- **Fluent** 4.9+ - ORM
- **FluentSQLiteDriver** 4.6+ - SQLite driver
- **Yams** 5.0+ - YAML parsing (skill frontmatter)
- **ILSShared** - Shared models and DTOs

## Gotchas

- Always use `CryptoKit` (not `Crypto`) for SHA256 in Vapor context
- Always call `process.waitUntilExit()` before accessing `process.terminationStatus`
- Use port 9999 to avoid conflicts with ralph-mobile on 8080
- Verify correct binary is running: `lsof -i :9999 -P -n` (path must be in `ils-ios`)
