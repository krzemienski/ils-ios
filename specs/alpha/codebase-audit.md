# ILS iOS Codebase Audit

**Date:** 2026-02-07
**Branch:** `design/v2-redesign`
**Backend:** Vapor 4 on port 9090 (running, healthy)
**Claude CLI:** v2.1.37 detected and available

---

## Architecture Diagram

```
+---------------------------+       HTTP/SSE        +---------------------------+
|       iOS App (ILSApp)    | <------------------> |    Backend (ILSBackend)    |
|                           |                       |                           |
|  ILSAppApp.swift          |   GET /health         |  entrypoint.swift         |
|    -> AppState            |   GET /api/v1/*       |  configure.swift          |
|    -> ThemeManager        |   POST /api/v1/chat/* |  routes.swift             |
|    -> SidebarRootView     |                       |                           |
|                           |                       |  Controllers/             |
|  Services/                |                       |    SessionsController     |
|    APIClient (actor)      |                       |    ProjectsController     |
|    SSEClient (@MainActor) |                       |    ChatController         |
|    ConnectionManager      |                       |    SkillsController       |
|    PollingManager         |                       |    MCPController          |
|    MetricsWebSocketClient |                       |    PluginsController      |
|    AppLogger              |                       |    ConfigController       |
|                           |                       |    StatsController        |
|  ViewModels/ (MVVM)       |                       |    SystemController       |
|    ChatViewModel          |                       |    TunnelController       |
|    SessionsViewModel      |                       |    AuthController         |
|    ProjectsViewModel      |                       |                           |
|    SkillsViewModel        |                       |  Services/                |
|    MCPViewModel           |                       |    ClaudeExecutorService  |
|    PluginsViewModel       |                       |    StreamingService       |
|    DashboardViewModel     |                       |    SessionFileService     |
|    SystemMetricsViewModel |                       |    FileSystemService      |
|    SettingsViewModel      |                       |    SkillsFileService      |
|    ConfigEditorViewModel  |                       |    MCPFileService         |
|                           |                       |    SystemMetricsService   |
|  Views/                   |                       |    TunnelService          |
|    Root/ (navigation)     |                       |    SSHService             |
|    Home/ (dashboard)      |                       |    GitHubService          |
|    Chat/ (chat UI)        |                       |    ConfigFileService      |
|    Sessions/              |                       |    WebSocketService       |
|    Browser/ (entities)    |                       |    IndexingService        |
|    System/ (monitoring)   |                       |                           |
|    Settings/              |                       |  Models/ (Fluent ORM)     |
|    Onboarding/            |                       |    SessionModel           |
|    Shared/                |                       |    ProjectModel           |
|                           |                       |    MessageModel           |
|  Theme/                   |                       |                           |
|    AppTheme + ILSTheme    |                       |  Migrations/              |
|    12 theme files         |                       |    CreateSessions         |
|    Components/ (reusable) |                       |    CreateProjects         |
|                           |                       |    CreateMessages         |
+---------------------------+                       |    CreateCachedResults    |
            |                                       +---------------------------+
            |                                                   |
            v                                                   v
+---------------------------+               +---------------------------+
|     ILSShared Module      |               |    SQLite (ils.sqlite)    |
|                           |               +---------------------------+
|  Models/                  |               +---------------------------+
|    ChatSession            |               |     Claude CLI            |
|    Project                |               |   (subprocess via         |
|    Skill                  |               |    ClaudeExecutorService) |
|    MCPServer (MCPServerItem) |            |   stream-json output      |
|    Plugin (PluginItem)    |               +---------------------------+
|    Message                |
|    StreamMessage (enum)   |
|    ClaudeConfig           |
|    ServerConnection       |
|                           |
|  DTOs/                    |
|    Requests.swift (all)   |
|    ConnectionResponse     |
|    SearchResult           |
|    SystemDTOs             |
|    TunnelDTOs             |
|    PaginatedResponse      |
+---------------------------+
```

---

## File Inventory

### Backend (Sources/ILSBackend) — 8,178 lines total

| File | Lines | Purpose |
|------|------:|---------|
| Services/ClaudeExecutorService.swift | 710 | Claude CLI subprocess execution with streaming |
| Controllers/PluginsController.swift | 377 | Plugin CRUD, install via git clone, marketplace |
| Services/SystemMetricsService.swift | 353 | CPU/memory/disk/network metrics collection |
| Services/StreamingService.swift | 317 | SSE streaming bridge (executor -> HTTP) |
| Controllers/SessionsController.swift | 295 | Session CRUD, fork, scan external sessions |
| Services/FileSystemService.swift | 251 | Filesystem browsing for System tab |
| Services/SessionFileService.swift | 255 | Read Claude Code session storage files |
| Services/SkillsFileService.swift | 235 | Parse skill YAML files from filesystem |
| Controllers/ProjectsController.swift | 229 | Project listing with deterministic IDs |
| Controllers/SystemController.swift | 219 | System metrics + filesystem browsing endpoints |
| Services/MCPFileService.swift | 218 | Parse MCP server configs from JSON files |
| Services/TunnelService.swift | 214 | Cloudflare tunnel management |
| Extensions/VaporContent+Extensions.swift | 204 | Vapor content encoding helpers |
| Services/SSHService.swift | 202 | SSH connections via Citadel |
| Controllers/SkillsController.swift | 191 | Skill listing, search, CRUD |
| Controllers/ChatController.swift | 185 | Chat streaming endpoint |
| Controllers/StatsController.swift | 157 | Dashboard statistics aggregation |
| Controllers/MCPController.swift | 134 | MCP server listing, CRUD |
| Services/GitHubService.swift | 134 | GitHub API for marketplace |
| Services/WebSocketService.swift | 129 | WebSocket upgrade handler |
| Models/SessionModel.swift | 114 | Fluent ORM model for sessions |
| Controllers/TunnelController.swift | 105 | Tunnel management endpoints |
| Services/IndexingService.swift | 96 | Background indexing of projects |
| Services/ConfigFileService.swift | 91 | Claude config file read/write |
| Middleware/ILSErrorMiddleware.swift | 85 | Structured error response middleware |
| Controllers/ConfigController.swift | 83 | Config read/write/validate endpoints |
| Models/MessageModel.swift | 76 | Fluent ORM model for messages |
| Models/ProjectModel.swift | 73 | Fluent ORM model for projects |
| App/routes.swift | 68 | Route registration + health check |
| Controllers/AuthController.swift | 64 | Auth placeholder (token validation stub) |
| App/configure.swift | 44 | App configuration (DB, CORS, routes) |
| App/entrypoint.swift | 21 | Vapor entrypoint |
| Migrations/CreateSessions.swift | 25 | Session table migration |
| Migrations/CreateProjects.swift | 20 | Project table migration |
| Migrations/CreateMessages.swift | 20 | Message table migration |
| Migrations/CreateCachedResults.swift | 17 | Cache table migration |

### iOS App (ILSApp/ILSApp) — 11,627 lines total

| File | Lines | Purpose |
|------|------:|---------|
| Views/Settings/SettingsViewSections.swift | 594 | Settings sections (appearance, connection, etc.) |
| Views/Chat/ChatView.swift | 555 | Main chat interface with message list |
| Views/Onboarding/ServerSetupSheet.swift | 518 | First-run onboarding with connection modes |
| Views/Settings/TunnelSettingsView.swift | 483 | Cloudflare tunnel configuration |
| ViewModels/ChatViewModel.swift | 433 | Chat state, SSE integration, message handling |
| Views/Browser/BrowserView.swift | 376 | Entity browser (projects/skills/MCP/plugins) |
| Views/Sessions/NewSessionView.swift | 336 | Session creation with advanced options |
| Views/Home/HomeView.swift | 327 | Dashboard with stats and recent sessions |
| Views/Root/SidebarView.swift | 314 | Sidebar navigation panel |
| Services/APIClient.swift | 307 | HTTP client (actor) with caching + retry |
| Theme/Components/ToolCallAccordion.swift | 280 | Expandable tool call display |
| Views/System/FileBrowserView.swift | 274 | Remote filesystem browser |
| Views/Root/SidebarRootView.swift | 255 | Root navigation container |
| Views/System/SystemMonitorView.swift | 255 | CPU/memory/disk/network charts |
| Services/SSEClient.swift | 249 | Server-Sent Events streaming client |
| Theme/ILSTheme.swift | 213 | Theme protocol + environment key |
| ViewModels/SkillsViewModel.swift | 209 | Skills data management |
| Services/MetricsWebSocketClient.swift | 197 | WebSocket client for live metrics |
| Views/Settings/ThemePickerView.swift | 197 | Visual theme selector (12 themes) |
| Controllers/MCPController.swift | 134 | (duplicate count from backend) |
| ViewModels/MCPViewModel.swift | 214 | MCP server data management |
| Views/Browser/MCPServerDetailView.swift | 193 | MCP server detail view |
| Views/Chat/AssistantCard.swift | 179 | Assistant message rendering |
| Views/Chat/CommandPaletteView.swift | 175 | Slash command palette overlay |
| Views/Sessions/SessionInfoView.swift | 174 | Session detail sheet |
| Theme/AppTheme.swift | 171 | Theme manager + 12 theme registry |
| ViewModels/SessionsViewModel.swift | 160 | Sessions list data |
| ViewModels/PluginsViewModel.swift | 149 | Plugins data management |
| Theme/Components/CodeBlockView.swift | 148 | Syntax-highlighted code display |
| ViewModels/ProjectsViewModel.swift | 142 | Projects data management |
| Views/Settings/NotificationPreferencesView.swift | 135 | Notification settings (persisted) |
| Theme/Components/ThinkingSection.swift | 130 | Collapsible thinking display |
| ViewModels/SystemMetricsViewModel.swift | 128 | System metrics state |
| Views/System/ProcessListView.swift | 128 | Running processes list |
| ILSAppApp.swift | 127 | App entry point + AppState |
| Views/Settings/ConfigEditorView.swift | 116 | Claude config editor |
| Views/Chat/MarkdownTextView.swift | 112 | Markdown renderer |
| Services/PollingManager.swift | 106 | Connection health polling |
| Theme/Components/MetricChart.swift | 106 | Chart component for system metrics |
| ViewModels/SettingsViewModel.swift | 105 | Settings state management |
| ViewModels/DashboardViewModel.swift | 102 | Dashboard stats loading |
| Theme/Components/ConnectionSteps.swift | 98 | Connection progress indicator |
| Theme/Components/ConnectionBanner.swift | 94 | Disconnected/connecting banner |
| Views/Chat/UserMessageCard.swift | 90 | User message bubble |
| Views/Root/SidebarSessionRow.swift | 87 | Session row in sidebar |
| Views/Chat/StreamingIndicatorView.swift | 81 | Typing/streaming indicator |
| Models/ChatMessage.swift | 78 | Client-side chat message model |
| Services/AppLogger.swift | 78 | Structured logging utility |
| Theme/Components/ProgressRing.swift | 78 | Circular progress indicator |
| Models/SessionTemplate.swift | 70 | Session creation templates |
| Theme/Components/EmptyEntityState.swift | 70 | Empty state placeholder |
| Theme/Components/StatCard.swift | 68 | Dashboard stat card |
| Services/ConnectionManager.swift | 61 | Server connection orchestration |
| Theme/Themes/ (12 files) | ~708 | 12 visual themes |
| Theme/Components/SkeletonRow.swift | 54 | Loading skeleton |
| ViewModels/ConfigEditorViewModel.swift | 54 | Config editor state |
| Theme/EntityType.swift | 49 | Entity color system (6 types) |
| Theme/Components/ShimmerModifier.swift | 48 | Shimmer loading animation |
| Theme/Components/SparklineChart.swift | 47 | Compact sparkline chart |
| Utils/DateFormatters.swift | 36 | Date formatting utilities |
| Theme/Components/EntityBadge.swift | 38 | Colored entity badge |
| Theme/Components/AccentButton.swift | 33 | Themed button component |
| Views/Chat/ErrorMessageView.swift | 33 | Error message display |
| Theme/GlassCard.swift | 23 | Glassmorphism card effect |
| Views/Chat/SystemMessageView.swift | 22 | System message display |
| Theme/Components/ILSCodeHighlighter.swift | 21 | Code syntax highlighter |
| Views/Shared/ShareSheet.swift | 20 | UIKit share sheet wrapper |

### ILSShared Module — 1,923 lines total

| File | Lines | Purpose |
|------|------:|---------|
| DTOs/Requests.swift | 646 | All API request/response types |
| Models/StreamMessage.swift | 401 | Streaming protocol types + AnyCodable |
| Models/ClaudeConfig.swift | 207 | Claude Code configuration model |
| Models/Session.swift | 167 | ChatSession + ExternalSession models |
| DTOs/SearchResult.swift | 118 | Search result types |
| DTOs/SystemDTOs.swift | 118 | System metrics DTOs |
| Models/Plugin.swift | 98 | Plugin/PluginItem model |
| Models/Skill.swift | 81 | Skill model |
| DTOs/ConnectionResponse.swift | 73 | Connection response types |
| Models/MCPServer.swift | 61 | MCPServerItem model |
| DTOs/TunnelDTOs.swift | 61 | Tunnel configuration DTOs |
| Models/Message.swift | 51 | Chat message model |
| Models/Project.swift | 45 | Project model |
| Models/ServerConnection.swift | 26 | Server connection config |
| DTOs/PaginatedResponse.swift | 14 | Pagination wrapper |

**Grand Total: ~21,728 lines of Swift across all modules**

---

## Backend API Endpoint Catalog

All endpoints prefixed with `/api/v1` unless noted. Backend confirmed running on port 9090.

### Health & System
| Method | Path | Controller | Status | Notes |
|--------|------|-----------|--------|-------|
| GET | `/health` | routes.swift | LIVE | Returns version, claude availability, port |
| GET | `/api/v1/system/metrics` | SystemController | TIMEOUT | Hangs under active Claude session (shell commands slow) |
| GET | `/api/v1/system/files` | SystemController | Exists | Filesystem browsing |
| GET | `/api/v1/system/processes` | SystemController | Exists | Process list |

### Sessions (32 sessions in DB)
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/sessions` | SessionsController | LIVE - 32 sessions returned |
| POST | `/sessions` | SessionsController | LIVE |
| GET | `/sessions/:id` | SessionsController | LIVE |
| PUT | `/sessions/:id` | SessionsController | LIVE (rename) |
| DELETE | `/sessions/:id` | SessionsController | LIVE |
| POST | `/sessions/:id/fork` | SessionsController | LIVE |
| GET | `/sessions/scan` | SessionsController | LIVE (external Claude sessions) |
| GET | `/sessions/recent` | SessionsController | LIVE |

### Chat
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| POST | `/chat/stream` | ChatController | LIVE (SSE streaming) |
| POST | `/chat/cancel` | ChatController | LIVE |
| GET | `/chat/ws/:sessionId` | ChatController | Exists (WebSocket, untested) |

### Projects (373 projects indexed)
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/projects` | ProjectsController | LIVE - 373 projects |
| GET | `/projects/:id` | ProjectsController | LIVE |
| GET | `/projects/search` | ProjectsController | Exists |

### Skills (1,481 skills indexed)
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/skills` | SkillsController | LIVE - 1,481 skills |
| GET | `/skills/:id` | SkillsController | LIVE |
| POST | `/skills` | SkillsController | Exists |
| PUT | `/skills/:id` | SkillsController | Exists |
| DELETE | `/skills/:id` | SkillsController | Exists |
| GET | `/skills/search` | SkillsController | Exists |

### MCP Servers (20 servers, 15 healthy)
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/mcp` | MCPController | LIVE - 20 servers |
| GET | `/mcp/:id` | MCPController | LIVE |
| POST | `/mcp` | MCPController | Exists |
| PUT | `/mcp/:id` | MCPController | Exists |
| DELETE | `/mcp/:id` | MCPController | Exists |

### Plugins (82 plugins, 45 enabled)
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/plugins` | PluginsController | LIVE - 82 plugins |
| GET | `/plugins/:id` | PluginsController | LIVE |
| POST | `/plugins/install` | PluginsController | Exists (git clone) |
| POST | `/plugins/:id/enable` | PluginsController | Exists |
| POST | `/plugins/:id/disable` | PluginsController | Exists |
| DELETE | `/plugins/:id` | PluginsController | Exists |

### Stats
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/stats` | StatsController | LIVE - aggregated dashboard stats |

### Config
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/config` | ConfigController | Exists |
| PUT | `/config` | ConfigController | Exists |
| POST | `/config/validate` | ConfigController | Exists |

### Tunnel
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| GET | `/tunnel/status` | TunnelController | Exists |
| POST | `/tunnel/start` | TunnelController | Exists |
| POST | `/tunnel/stop` | TunnelController | Exists |

### Auth
| Method | Path | Controller | Status |
|--------|------|-----------|--------|
| POST | `/auth/token` | AuthController | Exists (stub) |

---

## Dependencies

### Backend (Package.swift)
| Package | Version | Purpose |
|---------|---------|---------|
| vapor | 4.89.0+ | Web framework |
| fluent | 4.9.0+ | ORM |
| fluent-sqlite-driver | 4.6.0+ | SQLite database |
| Yams | 5.0.0+ | YAML parsing (skill files) |
| Citadel | 0.7.0+ | SSH client (remote connections) |

### iOS App (Xcode project, separate dependency resolution)
| Package | Purpose |
|---------|---------|
| ILSShared | Shared models (local package) |
| (SwiftUI built-in) | UI framework |
| (Combine built-in) | Reactive state management |

---

## Current Capabilities Assessment

### What Works (Confirmed LIVE)
1. **Backend health check** with Claude CLI version detection
2. **Session management** — CRUD, fork, scan external Claude sessions (32 sessions)
3. **Project indexing** — discovers 373 projects from filesystem
4. **Skills indexing** — parses 1,481 YAML skill files
5. **MCP server listing** — reads 20 configured MCP servers from JSON configs
6. **Plugin management** — lists 82 plugins, 45 enabled; install via git clone
7. **Dashboard stats** — aggregated counts across all entity types
8. **Chat streaming (SSE)** — full Claude CLI integration via subprocess:
   - Two-tier timeout (30s initial + 5min total)
   - Stream-JSON output parsing
   - Session tracking + cancellation
   - Content blocks: text, tool_use, tool_result, thinking
9. **12 visual themes** with live switching
10. **System monitoring** — CPU/memory/disk/network (when not under heavy load)
11. **Filesystem browsing** — remote file explorer via backend
12. **Onboarding flow** — Local/Remote/Tunnel connection modes
13. **Config editor** — read/write/validate Claude configuration

### What Works But Has Caveats
1. **SSE streaming** — Claude CLI `-p` hangs as subprocess within active Claude Code session (environment constraint). Works independently.
2. **System metrics** — endpoint times out under heavy load (shell command execution slows)
3. **WebSocket support** — code exists but SSE is the primary transport
4. **SSH connections** — Citadel dependency present, SSHService implemented, but not wired into primary flow

### What Is Stubbed or Incomplete
1. **AuthController** — token validation is a placeholder (64 lines, no real auth)
2. **WebSocket chat** — WebSocketService exists but SSE is used exclusively
3. **Tunnel integration** — TunnelService/TunnelController exist but Cloudflare tunnel binary dependency not bundled
4. **IndexingService** — background indexing exists but is a simple implementation

---

## Technical Debt & Issues

### Architecture
1. **Two separate package resolution systems** — Backend uses SPM Package.swift; iOS app uses Xcode project with its own package resolution. ILSShared is duplicated in both (no unified workspace).
2. **ClaudeCodeSDK not usable** — SDK uses FileHandle.readabilityHandler + Combine PassthroughSubject requiring RunLoop. Vapor's NIO event loops don't pump RunLoop. Custom subprocess implementation used instead.
3. **SQLite file in working directory** — `ils.sqlite` sits at repo root, gets committed/conflicted easily.

### Backend
4. **No authentication** — AuthController is a stub. Any client can hit all endpoints.
5. **Subprocess execution security** — `--dangerously-skip-permissions` is the default when no permission mode specified (ClaudeExecutorService line 331).
6. **SSHService imported but not primary** — Citadel dependency adds build time but SSH isn't the main connection path.
7. **Manual JSON parsing in ClaudeExecutorService** — Uses JSONSerialization instead of Codable for CLI output parsing, with manual snake_case -> camelCase conversion.
8. **No rate limiting** on any endpoint.
9. **CORS allows all origins** — `allowedOrigin: .all` in configure.swift.

### iOS App
10. **Large view files** — ChatView.swift (555 lines), ServerSetupSheet (518), SettingsViewSections (594), TunnelSettingsView (483) exceed recommended 400-line limit.
11. **Empty view directories** — Views/Dashboard/, Views/MCP/, Views/Plugins/, Views/Projects/, Views/ServerConnection/, Views/Sidebar/, Views/Skills/ appear to have no Swift files (content lives in BrowserView.swift and HomeView.swift).
12. **Duplicate type definitions** — APIResponse and ListResponse defined in both ILSShared (Requests.swift) and iOS APIClient.swift.
13. **No offline caching** — APIClient has a 30-second in-memory cache only; no persistent cache for offline use.

### Shared
14. **AnyCodable @unchecked Sendable** — Uses `Any` type erasure with unchecked Sendable conformance (StreamMessage.swift line 348).
15. **Large Requests.swift** — 646 lines with all DTOs in one file; could be split by domain.

---

## Key Metrics Summary

| Metric | Value |
|--------|-------|
| Total Swift LOC | ~21,728 |
| Backend LOC | 8,178 |
| iOS App LOC | 11,627 |
| ILSShared LOC | 1,923 |
| Backend Controllers | 11 |
| Backend Services | 11 |
| iOS ViewModels | 10 |
| iOS Views (directories) | 13 |
| Theme files | 12 + 14 components |
| API Endpoints | ~40 |
| Live/tested endpoints | 15+ |
| SQLite tables | 4 (sessions, projects, messages, cached_results) |
| Dependencies (backend) | 5 SPM packages |
| Visual themes | 12 |
