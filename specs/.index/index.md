# ILS iOS Codebase Index

> Auto-generated: 2026-02-05T21:50:00Z
> Paths indexed: Project root
> Excludes: node_modules, dist, build, .git, __pycache__, .auto-claude, DerivedData, .build

## Summary

| Category | Count |
|----------|-------|
| Controllers | 8 |
| Services (Backend + iOS + ViewModels) | 13 |
| Models | 11 |
| Helpers & Views | 22 |
| External Resources | 8 |
| **Total** | **62** |

---

## Controllers (8)

Backend Vapor route collections handling HTTP endpoints and SSE streaming.

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| ChatController | [controller-chatcontroller.md](components/controller-chatcontroller.md) | SSE streaming, WebSocket chat, permission decisions, cancellation |
| ConfigController | [controller-configcontroller.md](components/controller-configcontroller.md) | Claude Code configuration management (read/write) |
| MCPController | [controller-mcpcontroller.md](components/controller-mcpcontroller.md) | MCP server discovery and management |
| PluginsController | [controller-pluginscontroller.md](components/controller-pluginscontroller.md) | Plugin listing from filesystem |
| ProjectsController | [controller-projectscontroller.md](components/controller-projectscontroller.md) | Project discovery from Claude projects directory |
| SessionsController | [controller-sessionscontroller.md](components/controller-sessionscontroller.md) | Session CRUD, external session scanning, Claude CLI integration |
| SkillsController | [controller-skillscontroller.md](components/controller-skillscontroller.md) | Skill listing from filesystem |
| StatsController | [controller-statscontroller.md](components/controller-statscontroller.md) | Dashboard statistics and health endpoint |

## Services (13)

### Backend Services (4)

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| ClaudeExecutorService | [service-claudeexecutorservice.md](components/service-claudeexecutorservice.md) | Direct Claude CLI execution with Process-based streaming (bypasses SDK) |
| FileSystemService | [service-filesystemservice.md](components/service-filesystemservice.md) | Claude config/session/project/plugin/skill filesystem scanning |
| StreamingService | [service-streamingservice.md](components/service-streamingservice.md) | SSE event broadcasting with heartbeat and persistence |
| WebSocketService | [service-websocketservice.md](components/service-websocketservice.md) | WebSocket connection management |

### iOS Services (2)

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| APIClient | [service-apiclient.md](components/service-apiclient.md) | Typed HTTP client to ILS backend with /api/v1 prefix |
| SSEClient | [service-sseclient.md](components/service-sseclient.md) | SSE streaming client with 60s connection timeout and reconnection |

### ViewModels (7)

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| ChatViewModel | [service-chatviewmodel.md](components/service-chatviewmodel.md) | SSE streaming with 75ms batched updates, dual session support |
| DashboardViewModel | [service-dashboardviewmodel.md](components/service-dashboardviewmodel.md) | Dashboard stats aggregation |
| MCPViewModel | [service-mcpviewmodel.md](components/service-mcpviewmodel.md) | MCP server list management |
| PluginsViewModel | [service-pluginsviewmodel.md](components/service-pluginsviewmodel.md) | Plugin list management |
| ProjectsViewModel | [service-projectsviewmodel.md](components/service-projectsviewmodel.md) | Project list with search |
| SessionsViewModel | [service-sessionsviewmodel.md](components/service-sessionsviewmodel.md) | Session list with external session support |
| SkillsViewModel | [service-skillsviewmodel.md](components/service-skillsviewmodel.md) | Skill list with search |

## Models (11)

### Shared Models (8) — ILSShared package

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| ClaudeConfig | [model-claudeconfig.md](components/model-claudeconfig.md) | Claude Code configuration structures |
| MCPServer | [model-mcpserver.md](components/model-mcpserver.md) | MCP server definition |
| Message | [model-message.md](components/model-message.md) | Chat message with content blocks |
| Plugin | [model-plugin.md](components/model-plugin.md) | Plugin metadata |
| Project | [model-project.md](components/model-project.md) | Codebase directory with metadata |
| Session | [model-session.md](components/model-session.md) | Session with status, source, permissions; ChatSession; ExternalSession |
| Skill | [model-skill.md](components/model-skill.md) | Skill metadata |
| StreamMessage | [model-streammessage.md](components/model-streammessage.md) | SSE stream message types (System, Assistant, Result, Permission, Error) |

### Backend ORM Models (3) — Fluent

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| MessageModel | [model-messagemodel.md](components/model-messagemodel.md) | SQLite message persistence |
| ProjectModel | [model-projectmodel.md](components/model-projectmodel.md) | SQLite project persistence |
| SessionModel | [model-sessionmodel.md](components/model-sessionmodel.md) | SQLite session persistence |

## Helpers & Views (22)

### SwiftUI Views (16)

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| ChatView | [helper-chatview.md](components/helper-chatview.md) | Chat interface with streaming, read-only external session support |
| CommandPaletteView | [helper-commandpaletteview.md](components/helper-commandpaletteview.md) | Command palette overlay |
| MessageView | [helper-messageview.md](components/helper-messageview.md) | Individual message rendering |
| DashboardView | [helper-dashboardview.md](components/helper-dashboardview.md) | Stats dashboard with tappable cards |
| MCPServerListView | [helper-mcpserverlistview.md](components/helper-mcpserverlistview.md) | MCP server list |
| PluginsListView | [helper-pluginslistview.md](components/helper-pluginslistview.md) | Plugin browser |
| NewProjectView | [helper-newprojectview.md](components/helper-newprojectview.md) | Project creation form |
| ProjectDetailView | [helper-projectdetailview.md](components/helper-projectdetailview.md) | Project detail with sessions |
| ProjectSessionsListView | [helper-projectsessionslistview.md](components/helper-projectsessionslistview.md) | Sessions filtered by project |
| ProjectsListView | [helper-projectslistview.md](components/helper-projectslistview.md) | Project list with search |
| NewSessionView | [helper-newsessionview.md](components/helper-newsessionview.md) | Session creation with permission modes |
| SessionInfoView | [helper-sessioninfoview.md](components/helper-sessioninfoview.md) | Session detail/info panel |
| SessionsListView | [helper-sessionslistview.md](components/helper-sessionslistview.md) | Dual-mode sessions with FAB |
| SettingsView | [helper-settingsview.md](components/helper-settingsview.md) | Claude Code configuration management |
| SidebarView | [helper-sidebarview.md](components/helper-sidebarview.md) | Navigation sidebar with connection status |
| SkillsListView | [helper-skillslistview.md](components/helper-skillslistview.md) | Skill browser |

### Configuration & Utilities (6)

| Component | Spec File | Purpose |
|-----------|-----------|---------|
| configure | [helper-configure.md](components/helper-configure.md) | Vapor app configuration (SQLite, CORS, port 9090) |
| routes | [helper-routes.md](components/helper-routes.md) | Route registration |
| entrypoint | [helper-entrypoint.md](components/helper-entrypoint.md) | Vapor server entry point |
| Requests (DTOs) | [helper-requests.md](components/helper-requests.md) | ChatOptions, ChatStreamRequest, and other DTOs |
| ILSTheme | [helper-ilstheme.md](components/helper-ilstheme.md) | V2 dark design system with DESIGN.md colors |
| ILSAppApp | [helper-ilsappapp.md](components/helper-ilsappapp.md) | SwiftUI app entry, AppState, deep linking, backend polling |

## External Resources (8)

### Documentation URLs (5)

| Resource | Spec File | Status |
|----------|-----------|--------|
| Claude Code SDK | [url-claude-code-sdk.md](external/url-claude-code-sdk.md) | fetch-failed (404 redirect) |
| Claude API Docs | [url-claude-api-docs.md](external/url-claude-api-docs.md) | fetch-failed (404 redirect) |
| Vapor Framework | [url-vapor-docs.md](external/url-vapor-docs.md) | Success |
| CLI Reference | [url-cli-reference.md](external/url-cli-reference.md) | Success |
| Sub-agents | [url-sub-agents.md](external/url-sub-agents.md) | Success |

### MCP Servers (3)

| Resource | Spec File | Tools |
|----------|-----------|-------|
| Context7 | [mcp-context7.md](external/mcp-context7.md) | 2 tools (resolve-library-id, query-docs) |
| Firecrawl | [mcp-firecrawl.md](external/mcp-firecrawl.md) | 8 tools (scrape, map, search, crawl, extract, agent, +status) |
| xclaude-plugin | [mcp-xclaude-plugin.md](external/mcp-xclaude-plugin.md) | 22 tools (build, test, simulator, idb UI automation) |

---

## Architecture Overview

```
ILSApp (iOS)                    ILSBackend (Vapor)              ILSShared
├── Views/ (16 SwiftUI)         ├── Controllers/ (8)            ├── Models/ (8)
├── ViewModels/ (7)             ├── Services/ (4)               └── DTOs/ (1)
├── Services/ (2)               ├── Models/ (3 Fluent ORM)
│   ├── APIClient               └── App/ (3 config)
│   └── SSEClient
└── Theme/ (1)

Data Flow:
Views → ViewModels → APIClient/SSEClient → HTTP/SSE → Controllers → Services → FileSystem/Claude CLI
```

## Sparse Areas (Extra Attention Needed)

Per interview, these areas lack comments and need extra analysis:
- **Backend Services**: ClaudeExecutorService, StreamingService, FileSystemService
- **ViewModels**: ChatViewModel and other view models
- **Shared Models**: Session, StreamMessage, Project

---

*Next: Run `/ralph-specum:start` to create specs that reference indexed components.*
