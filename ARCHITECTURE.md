# ILS Architecture

## System Overview

ILS is a full-stack Swift monorepo with three main components sharing types through a common Swift package.

```
┌──────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                          │
│                                                              │
│  ┌─────────────────────┐    ┌──────────────────────────┐     │
│  │     iOS App         │    │      macOS App            │     │
│  │  (SwiftUI + MVVM)   │    │  (SwiftUI + Multi-Window) │     │
│  │  122 Swift files    │    │  12 Swift files           │     │
│  │  15 ViewModels      │    │  WindowManager            │     │
│  │  12 Themes          │    │  Touch Bar                │     │
│  └────────┬────────────┘    └──────────┬───────────────┘     │
│           │                             │                    │
│           └──────────┬──────────────────┘                    │
│                      │                                       │
│              ┌───────▼───────┐                               │
│              │  ILSShared    │                               │
│              │  26 files     │                               │
│              │  Models+DTOs  │                               │
│              └───────┬───────┘                               │
└──────────────────────┼───────────────────────────────────────┘
                       │ HTTP/SSE/WebSocket
┌──────────────────────┼───────────────────────────────────────┐
│                      │         SERVER LAYER                   │
│              ┌───────▼───────┐                               │
│              │  ILSBackend   │                               │
│              │  Vapor 4      │                               │
│              │  44 files     │                               │
│              │  Port 9999    │                               │
│              └───────┬───────┘                               │
│                      │                                       │
│         ┌────────────┼────────────┐                          │
│         │            │            │                           │
│    ┌────▼────┐ ┌─────▼─────┐ ┌───▼────┐                     │
│    │ SQLite  │ │ Claude    │ │ File   │                      │
│    │ (Fluent)│ │ Code CLI  │ │ System │                      │
│    └─────────┘ └───────────┘ └────────┘                      │
│                                                              │
│    ~/.claude/     ~/.claude/projects/     ~/.claude.json      │
│    settings.json  */sessions-index.json   (MCP config)       │
└──────────────────────────────────────────────────────────────┘
```

## Component Details

### ILSShared (Swift Package)

**Purpose:** Type-safe contract between iOS/macOS clients and the Vapor backend.

**Location:** `Sources/ILSShared/`

```
ILSShared/
├── Models/          # Domain models (Codable)
│   ├── Session.swift        # ChatSession with Hashable
│   ├── Message.swift        # Chat messages
│   ├── Project.swift        # Claude Code projects
│   ├── Skill.swift          # Skills with YAML frontmatter
│   ├── Plugin.swift         # Plugins with marketplace info
│   ├── MCPServer.swift      # MCP server configuration
│   ├── CustomTheme.swift    # Custom theme definitions
│   ├── StreamMessage.swift  # SSE stream events
│   ├── CLIMessage.swift     # Claude CLI message format
│   ├── ContentBlocks.swift  # Text/ToolUse/ToolResult/Thinking
│   ├── ClaudeConfig.swift   # Settings file structure
│   ├── ServerConnection.swift
│   ├── SetupProgress.swift
│   └── FleetHost.swift
└── DTOs/            # Request/Response transfer objects
    ├── Requests.swift           # CreateSession, ChatRequest, etc.
    ├── ResponseDTOs.swift       # APIResponse<T> wrapper
    ├── PaginatedResponse.swift  # Paginated list responses
    ├── SystemDTOs.swift         # System metrics types
    ├── TeamDTOs.swift           # Team coordination types
    ├── TunnelDTOs.swift         # Tunnel status/config
    ├── SearchResult.swift       # GitHub search results
    ├── ConnectionResponse.swift
    ├── SetupDTOs.swift
    ├── FleetDTOs.swift
    ├── SSHDTOs.swift
    └── RemoteMetricsDTOs.swift
```

**Key design decisions:**
- All API responses wrapped in `APIResponse<T>` for consistent error handling
- Models are `Codable` + `Identifiable` for SwiftUI compatibility
- `ChatSession` conforms to `Hashable` for `navigationDestination(item:)`
- `ContentBlock` is an enum with associated values: `.text`, `.toolUse`, `.toolResult`, `.thinking`
- Stream messages use `StreamMessage` with event type discriminator

### ILSBackend (Vapor Server)

**Purpose:** REST API + real-time streaming server that bridges iOS/macOS apps with Claude Code CLI and local filesystem.

**Location:** `Sources/ILSBackend/`

```
ILSBackend/
├── App/
│   ├── entrypoint.swift     # @main entry
│   ├── configure.swift      # Middleware, DB, routes setup
│   └── routes.swift         # Route registration
├── Controllers/             # 12 REST controllers
│   ├── ChatController       # SSE streaming + WebSocket chat
│   ├── SessionsController   # CRUD + scan + fork + transcript
│   ├── ProjectsController   # List + detail + project sessions
│   ├── SkillsController     # CRUD + GitHub search + install
│   ├── PluginsController    # CRUD + marketplace + enable/disable
│   ├── MCPController        # CRUD + scope filtering
│   ├── ConfigController     # Get/Set/Validate config
│   ├── StatsController      # Dashboard stats + recent sessions
│   ├── SystemController     # Metrics + processes + files + live WS
│   ├── ThemesController     # Custom theme CRUD
│   ├── TeamsController      # Team + member + task + message CRUD
│   └── TunnelController     # Start/stop/status Cloudflare tunnel
├── Services/                # 16 business logic services
│   ├── ClaudeExecutorService   # Spawns Claude CLI subprocess
│   ├── StreamingService        # SSE event formatting
│   ├── WebSocketService        # WS connection management
│   ├── SessionFileService      # Read ~/.claude/projects/ sessions
│   ├── IndexingService         # Session indexing + caching
│   ├── SkillsFileService       # Read ~/.claude/skills/
│   ├── MCPFileService          # Read ~/.claude.json MCP config
│   ├── ConfigFileService       # Read/write settings files
│   ├── SystemMetricsService    # CPU, memory, disk, network
│   ├── GitHubService           # GitHub API for skill search
│   ├── TunnelService           # cloudflared management
│   ├── FileSystemService       # Directory browsing
│   ├── TeamsExecutorService    # Team agent orchestration
│   ├── TeamsFileService        # Team config file management
│   ├── CLIMessageConverter     # Parse CLI output to StreamMessage
│   └── ExecutionOptions        # Chat execution configuration
├── Models/                  # Fluent ORM models
│   ├── SessionModel         # DB sessions table
│   ├── MessageModel         # DB messages table
│   ├── ProjectModel         # DB projects table
│   ├── ThemeModel           # DB custom themes table
│   └── FleetHostModel       # DB fleet hosts table
├── Migrations/              # Database schema
├── Middleware/
│   └── ILSErrorMiddleware   # Consistent error responses
└── Extensions/
    └── VaporContent+Extensions
```

**Key design decisions:**
- Claude Code CLI invoked via `Process` + `DispatchQueue` (not ClaudeCodeSDK - see below)
- Two-tier timeout for CLI: 30s initial response + 5min total execution
- External sessions read from `~/.claude/projects/*/sessions-index.json` files
- Session deduplication: DB sessions take priority over external sessions
- Auto-create session in DB when client sends unknown sessionId (FK constraint handling)
- SSE streaming via `AsyncStream` with proper backpressure
- Project IDs are deterministic UUIDs generated from path using SHA256/CryptoKit

### iOS App (SwiftUI)

**Purpose:** Mobile interface for Claude Code management and chat.

**Location:** `ILSApp/ILSApp/`

**Architecture:** MVVM with `@MainActor` ViewModels and `@StateObject` binding.

```
Views/                      ViewModels/
├── Root/                   ├── SessionsViewModel
├── Home/                   ├── ChatViewModel
├── Chat/                   ├── ProjectsViewModel
├── Sessions/               ├── SkillsViewModel
├── Projects/               ├── PluginsViewModel
├── Skills/                 ├── MCPViewModel
├── Plugins/                ├── SystemViewModel
├── MCP/                    ├── TeamsViewModel
├── System/                 ├── ThemesViewModel
├── Teams/                  ├── FleetViewModel
├── Fleet/                  ├── SettingsViewModel
├── Dashboard/              ├── BrowserViewModel
├── Settings/               ├── DashboardViewModel
├── Themes/                 └── OnboardingViewModel
├── Onboarding/
├── Sidebar/
└── Shared/

Services/
├── APIClient.swift         # REST API communication
├── SSEClient.swift         # Server-Sent Events streaming
├── TunnelService.swift     # Cloudflare tunnel management
└── AppState.swift          # Global app state + navigation
```

**Navigation pattern:**
- Sidebar-based navigation via SwiftUI `.sheet` modifier
- `activeScreen` enum in `SidebarRootView` controls routing
- Deep links handled via `.onOpenURL` in `ILSAppApp.swift`
- URL scheme: `ils://`

**Theme system:**
- `AppTheme` protocol defines full theme interface
- `ThemeSnapshot` concrete struct replaces `any AppTheme` existential (performance)
- 12 built-in themes: Obsidian, Slate, Midnight, GhostProtocol, NeonNoir, ElectricGrid, Ember, Crimson, Carbon, Graphite, CyberPulse, Cyberpunk
- `ThemeManager` handles persistence and switching
- `GlassCard` modifier for theme-aware container styling

### macOS App (SwiftUI)

**Purpose:** Desktop interface with multi-window support and macOS-native features.

**Location:** `ILSApp/ILSMacApp/`

```
ILSMacApp/
├── ILSMacApp.swift          # @main entry with WindowGroup + Settings
├── AppDelegate.swift        # NSApplicationDelegate for lifecycle
├── Views/
│   ├── MacContentView       # Main window with sidebar navigation
│   ├── MacDashboardView     # Dashboard with stat cards
│   ├── MacSessionsListView  # Session list with total count
│   ├── MacProjectsListView  # Project browser
│   ├── MacChatView          # Chat interface
│   ├── MacSettingsView      # Settings with form layout
│   └── SessionWindowView    # Detachable session window
├── Managers/
│   ├── WindowManager        # Multi-window management
│   └── NotificationManager  # macOS notifications
└── TouchBar/
    └── ChatTouchBarProvider # Touch Bar integration
```

**Key differences from iOS:**
- Multi-window via `WindowGroup` + `WindowManager`
- Sidebar navigation (native `NavigationSplitView`)
- Touch Bar support for chat
- macOS-native settings window (`Settings` scene)

## Data Flow

### Chat Streaming Flow

```
User Input --> ChatView --> ChatViewModel.sendMessage()
    |
    v
APIClient.streamChat(sessionId, prompt)
    |
    v
POST /api/v1/chat/stream (SSE)
    |
    v
ChatController --> ClaudeExecutorService
    |                    |
    |                    v
    |              Process("claude", "-p", prompt)
    |                    |
    |                    v
    |              stdout --> DispatchQueue --> parse
    |                    |
    |                    v
    |              CLIMessageConverter --> StreamMessage
    |                    |
    v                    v
SSEClient <-- SSE events <-- StreamingService
    |
    v
ChatViewModel.messages.append(parsed)
    |
    v
ChatView re-renders with new message
```

### Session Discovery Flow

```
App Launch --> DashboardViewModel.loadStats()
    |
    |--> GET /api/v1/stats (DB counts)
    |
    +--> GET /api/v1/sessions (unified list)
              |
              v
         SessionsController
              |
              |--> DB query (ILS-created sessions)
              |
              +--> SessionFileService.scanExternalSessions()
                        |
                        v
                   Read ~/.claude/projects/*/sessions-index.json
                        |
                        v
                   Deduplicate (DB takes priority)
                        |
                        v
                   Paginate + Sort + Return
```

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI integration | Direct `Process` | ClaudeCodeSDK uses RunLoop which Vapor's NIO doesn't pump |
| Database | SQLite via Fluent | Simple deployment, no external DB needed |
| Streaming | SSE + WebSocket | SSE for chat streaming, WS for live system metrics |
| Theme storage | `ThemeSnapshot` struct | Replaced `any AppTheme` existential for 58 occurrences (performance) |
| Project IDs | Deterministic UUID from SHA256(path) | Consistent IDs across sessions without DB storage |
| Session dedup | DB-first priority | DB sessions are authoritative, external fill gaps |
| Port | 9999 | Avoids conflict with ralph-mobile on 8080 |
| iOS navigation | Sidebar sheet | SwiftUI sheet modal triggered by toolbar button |

## Database Schema

```sql
-- Sessions (ILS-managed)
CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    claude_session_id TEXT,
    name TEXT,
    project_id UUID REFERENCES projects(id),
    project_name TEXT,
    model TEXT DEFAULT 'sonnet',
    permission_mode TEXT DEFAULT 'default',
    status TEXT DEFAULT 'active',
    message_count INTEGER DEFAULT 0,
    total_cost_usd DOUBLE DEFAULT 0,
    source TEXT DEFAULT 'ils',
    forked_from UUID,
    first_prompt TEXT,
    created_at TIMESTAMP,
    last_active_at TIMESTAMP
);

-- Messages
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP
);

-- Projects (cached)
CREATE TABLE projects (
    id UUID PRIMARY KEY,
    name TEXT,
    path TEXT,
    default_model TEXT,
    description TEXT,
    session_count INTEGER,
    encoded_path TEXT,
    created_at TIMESTAMP,
    last_accessed_at TIMESTAMP
);

-- Custom Themes
CREATE TABLE themes (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    author TEXT,
    version TEXT,
    colors JSON,
    typography JSON,
    spacing JSON,
    corner_radius JSON,
    shadows JSON
);

-- Fleet Hosts
CREATE TABLE fleet_hosts (
    id UUID PRIMARY KEY,
    hostname TEXT,
    ssh_user TEXT,
    ssh_port INTEGER,
    status TEXT,
    last_seen TIMESTAMP
);
```

## Security Considerations

- Backend binds to `0.0.0.0` (all interfaces) - use Cloudflare tunnel for secure remote access
- No authentication on API endpoints (local-only assumption)
- MCP server env vars displayed as `***` in API responses
- File browser restricted to home directory
- Claude CLI inherits host machine permissions
- No CORS headers (add via reverse proxy for web clients)

## Performance Optimizations

- `ThemeSnapshot` replaces existential `any AppTheme` across 48 views
- Cached regexes for markdown/code parsing
- Timer tolerance set for energy efficiency
- `scenePhase` animation pausing when app backgrounds
- Session pagination (50 per page) with server-side deduplication
- External session scan results cached (bypass with `?refresh=true`)
- Skeleton loading with `ShimmerModifier` for perceived performance
