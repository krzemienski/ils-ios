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
- Two execution backends: Agent SDK (default, via `node scripts/sdk-wrapper.mjs`) and CLI fallback (`claude -p`) — see "Execution Backends" section
- Both backends use `Process` + `DispatchQueue` for stdout reading (not ClaudeCodeSDK — Vapor's NIO doesn't pump RunLoop)
- Two-tier timeout: 30s initial response + 5min total execution
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

## Execution Backends

`ClaudeExecutorService` supports two execution backends, selected via the `useAgentSDK` static flag (default: `true`).

### Agent SDK (Default)

Spawns `node scripts/sdk-wrapper.mjs '<json-config>'` which invokes the `@anthropic-ai/claude-agent-sdk` npm package. The SDK calls the Anthropic API **directly** — no `claude` subprocess is involved — which avoids the hang that occurs when spawning `claude -p` inside an active Claude Code session.

```
ClaudeExecutorService.executeWithSDK()
    |
    v
/bin/zsh -l -c "node scripts/sdk-wrapper.mjs '<json-config>'"
    |
    v
sdk-wrapper.mjs  -->  @anthropic-ai/claude-agent-sdk
                              |
                              v
                      Anthropic API (HTTPS)
                              |
                              v
                       stdout (NDJSON)
    |
    v
DispatchQueue reads line-by-line
    |
    v
CLIMessageConverter --> StreamMessage
```

**Why SDK is preferred:**
- Running `claude -p` as a subprocess inside an active Claude Code session causes the parent Claude process to detect the spawn and hang, preventing any output from being returned.
- The Agent SDK bypasses this by making direct HTTPS calls to the Anthropic API — no `claude` subprocess is involved.
- Authentication is inherited from the environment (Claude Code's auth tokens); `ANTHROPIC_API_KEY` is not required.
- The prompt and all options are passed as a JSON argument to `sdk-wrapper.mjs`, keeping the interface clean and shell-injection-safe.

### CLI Fallback

Spawns `claude -p --output-format stream-json` directly as a subprocess. Use this backend when running the ILS backend **outside** a Claude Code session (e.g., standalone development on a machine where only the `claude` CLI is installed).

```
ClaudeExecutorService.executeWithCLI()
    |
    v
/bin/zsh -l -c "claude -p --output-format stream-json ..."
    |
    v
stdout (NDJSON)
    |
    v
DispatchQueue reads line-by-line
    |
    v
CLIMessageConverter --> StreamMessage
```

**When to use CLI fallback:**
- Set `ClaudeExecutorService.useAgentSDK = false` in `configure.swift` (or toggle at runtime).
- Use when running the backend as a standalone process outside a Claude Code session.
- Required if Node.js / the Agent SDK npm package is not installed on the host.

### Shared Output Processing

Both backends produce NDJSON on stdout in the same format. The following pipeline is identical for both:

| Stage | Implementation | Notes |
|-------|---------------|-------|
| stdout reading | `DispatchQueue` + `readDataToEndOfFile` | Avoids `RunLoop` dependency (Vapor's NIO doesn't pump RunLoop) |
| JSON parsing | `JSONDecoder` with `.convertFromSnakeCase` | Maps `session_id` → `sessionId`, `tool_use` → `toolUse`, etc. |
| Message conversion | `CLIMessageConverter` | Produces typed `StreamMessage` events for SSE delivery |
| Initial timeout | 30 seconds (no stdout data) | Detects a stuck CLI or failed SDK spawn |
| Total timeout | 5 minutes | Kills runaway processes unconditionally |

### Switching Backends

```swift
// In Sources/ILSBackend/App/configure.swift

// Use Agent SDK (default — required when running inside Claude Code)
ClaudeExecutorService.useAgentSDK = true

// Use CLI fallback (standalone mode, no Node.js dependency)
ClaudeExecutorService.useAgentSDK = false
```

## CLIMessage → StreamMessage Conversion

Claude Code CLI (and the Agent SDK wrapper) emit NDJSON on stdout using **snake_case** field names, which is the native format of the Claude API wire protocol. The iOS app consumes **camelCase** `StreamMessage` types that are ergonomic in Swift. `CLIMessageConverter` bridges the two, and `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` handles the bulk of field renaming automatically.

### Two-Type Design

| Layer | Type | Source | Key Convention |
|-------|------|--------|----------------|
| Raw CLI output | `CLIMessage` (enum) | `Sources/ILSShared/Models/CLIMessage.swift` | snake_case field names; mirrors Claude API wire protocol |
| iOS-facing events | `StreamMessage` (enum) | `Sources/ILSShared/Models/StreamMessage.swift` | camelCase field names; idiomatic Swift |
| Converter | `CLIMessageConverter` | `Sources/ILSBackend/Services/CLIMessageConverter.swift` | Stateless `enum`; `convert(_:CLIMessage) -> StreamMessage?` |

### Message Type Mapping

Each `CLIMessage` case maps to a corresponding `StreamMessage` case. The critical rename is `stream_event` → `streamEvent` — the string value of the `"type"` JSON field changes, not just the Swift enum case name.

| `CLIMessage` case | JSON `"type"` value | `StreamMessage` case | JSON `"type"` value |
|-------------------|---------------------|----------------------|---------------------|
| `.system` | `"system"` | `.system` | `"system"` |
| `.assistant` | `"assistant"` | `.assistant` | `"assistant"` |
| `.user` | `"user"` | `.user` | `"user"` |
| `.result` | `"result"` | `.result` | `"result"` |
| `.streamEvent` | `"stream_event"` | `.streamEvent` | `"streamEvent"` ⚠️ renamed |
| `.permission` | `"permission"` | `.permission` | `"permission"` |
| *(none)* | — | `.error` | `"error"` | Injected by backend on exception |

> **⚠️ `stream_event` → `streamEvent`:** The raw CLI emits `"type":"stream_event"` (snake_case). `CLIMessage.init(from:)` matches the string `"stream_event"` and decodes it as the `.streamEvent` case. `CLIMessageConverter` re-encodes it with `"type":"streamEvent"` (camelCase) so `StreamMessage` decoding on the iOS side matches the `"streamEvent"` case.

### Field Renames via `.convertFromSnakeCase`

`JSONDecoder` is configured with `.keyDecodingStrategy = .convertFromSnakeCase` when parsing raw CLI NDJSON. This handles all standard snake_case → camelCase transformations automatically:

| Raw CLI field (snake_case) | Decoded Swift property (camelCase) | Struct |
|----------------------------|------------------------------------|--------|
| `session_id` | `sessionId` | `CLISystemMessage`, `CLIAssistantMessage`, `CLIUserMessage`, `CLIResultMessage` |
| `parent_tool_use_id` | `parentToolUseId` | `CLIAssistantMessage`, `CLIUserMessage` |
| `stop_reason` | `stopReason` | `CLIAssistantPayload` |
| `tool_use_id` | `toolUseId` | `CLIContentBlock` |
| `is_error` | `isError` | `CLIContentBlock`, `CLIResultMessage` |
| `duration_ms` | `durationMs` | `CLIResultMessage`, `CLIToolUseResultMeta` |
| `duration_api_ms` | `durationApiMs` | `CLIResultMessage` |
| `num_turns` | `numTurns` | `CLIResultMessage` |
| `total_cost_usd` | `totalCostUsd` | `CLIResultMessage` |
| `input_tokens` | `inputTokens` | `CLIUsage`, `CLIModelUsageEntry` |
| `output_tokens` | `outputTokens` | `CLIUsage`, `CLIModelUsageEntry` |
| `cache_read_input_tokens` | `cacheReadInputTokens` | `CLIUsage` |
| `cache_creation_input_tokens` | `cacheCreationInputTokens` | `CLIUsage` |
| `model_usage` | `modelUsage` | `CLIResultMessage` |
| `api_key_source` | `apiKeySource` | `CLISystemMessage` |
| `permission_mode` | `permissionMode` | `CLISystemMessage` |
| `claude_code_version` | `claudeCodeVersion` | `CLISystemMessage` |
| `slash_commands` | `slashCommands` | `CLISystemMessage` |
| `mcp_servers` | `mcpServers` | `CLISystemMessage` |
| `num_files` | `numFiles` | `CLIToolUseResultMeta` |

### Content Block Type Mapping

Content blocks embedded in `CLIAssistantMessage.message.content` and `CLIUserMessage.message.content` use a `"type"` discriminator. `CLIMessageConverter.convertContentBlock(_:)` maps these string values to typed `ContentBlock` enum cases:

| Raw `"type"` string | `ContentBlock` case | Swift struct | Notes |
|---------------------|---------------------|--------------|-------|
| `"text"` | `.text` | `TextBlock` | Plain text content |
| `"tool_use"` | `.toolUse` | `ToolUseBlock` | Tool invocation with `id`, `name`, `input` |
| `"tool_result"` | `.toolResult` | `ToolResultBlock` | Result of a tool call; content may be `String` or `[[String:Any]]` |
| `"thinking"` | `.thinking` | `ThinkingBlock` | Extended thinking content |
| *(unknown)* | `.text` | `TextBlock("[unsupported: ...]")` | Graceful fallback for unrecognised types |

### Structural Differences

Beyond field name changes, `CLIMessageConverter` also handles structural reshaping:

| CLI structure | StreamMessage structure | Reason |
|---------------|------------------------|--------|
| `CLISystemMessage` has flat fields (`sessionId`, `model`, `cwd`, etc.) | `SystemMessage` wraps them in a nested `SystemData` struct | Cleaner grouping for iOS consumers |
| `CLIAssistantMessage.message.content[]` (nested payload) | `AssistantMessage.content[]` (direct) | Flattened for simpler access |
| `CLIUserMessage.message.content[]` (nested payload) | `UserMessage.content[]` (direct) | Flattened for simpler access |
| `CLIResultMessage.totalCostUsd` (snake strategy → camelCase) | `ResultMessage.totalCostUSD` (all-caps USD) | `USD` is an acronym; mapped explicitly |
| `CLIToolUseResultMeta` | `ToolUseResultMeta` | Field-by-field copy with identical camelCase names |

### Code Path Summary

```
subprocess stdout (NDJSON line)
    |
    v
JSONDecoder                                         [keyDecodingStrategy = .convertFromSnakeCase]
    |
    v
CLIMessage                                          [snake_case → camelCase applied automatically]
  .system / .assistant / .user / .result / .streamEvent / .permission
    |
    v
CLIMessageConverter.convert(_:)                     [Sources/ILSBackend/Services/CLIMessageConverter.swift]
    |
    ├── system    → SystemMessage(data: SystemData(...))
    ├── assistant → AssistantMessage(content: [ContentBlock])
    │                   └── convertContentBlock():
    │                         "text"        → .text(TextBlock)
    │                         "tool_use"    → .toolUse(ToolUseBlock)
    │                         "tool_result" → .toolResult(ToolResultBlock)
    │                         "thinking"    → .thinking(ThinkingBlock)
    ├── user      → UserMessage(content: [ContentBlock], toolUseResult: ToolUseResultMeta?)
    ├── result    → ResultMessage(totalCostUSD:, usage: UsageInfo, modelUsage: [...])
    ├── streamEvent → StreamEventMessage(type: "streamEvent", eventType:, delta:)
    └── permission → PermissionRequest(requestId:, toolName:, toolInput:)
    |
    v
StreamMessage                                       [camelCase; iOS-facing]
    |
    v
StreamingService → SSE wire → SSEClient → ChatViewModel
```

## Data Flow

### Chat Streaming Flow

The full pipeline from user keystroke to rendered message spans 15 distinct stages across iOS client, HTTP transport, and Vapor backend.

```
┌─────────────────────────────── iOS CLIENT ───────────────────────────────────┐
│                                                                               │
│  1. ChatInputBar                                                              │
│     User types message and taps Send                                          │
│          │                                                                    │
│          ▼                                                                    │
│  2. ChatView                                                                  │
│     Receives onSubmit callback, calls viewModel.sendMessage(_:)               │
│          │                                                                    │
│          ▼                                                                    │
│  3. ChatViewModel.sendMessage()                          [MainActor]          │
│     Appends optimistic user message to messages[]                             │
│     Calls sseClient.startStream(request:)                                     │
│          │                                                                    │
│          ▼                                                                    │
│  4. SSEClient.startStream(request:)                                           │
│     Cancels any existing stream, resets messages/error state                  │
│     Sets connectionState = .connecting                                        │
│     Spawns Task { await performStream(request:) }                             │
│          │                                                                    │
│          ▼                                                                    │
│  5. URLSession.bytes(for: urlRequest)                                         │
│     POST /api/v1/chat/stream                                                  │
│     Headers: Content-Type: application/json                                   │
│              Accept: text/event-stream                                        │
│              Last-Event-ID: <id>  (if reconnecting)                           │
│     Races against 60s connection timeout (withThrowingTaskGroup)              │
│     URLSession configured: 5min request timeout, 1hr resource timeout        │
│     On connect: connectionState = .connected                                  │
│                                                                               │
│     ┌─ Heartbeat Watchdog (Task.detached) ───────────────────────────┐       │
│     │  Checks every 15s; throws URLError(.timedOut) if no            │       │
│     │  activity (data or SSE heartbeat) received in 45s              │       │
│     └────────────────────────────────────────────────────────────────┘       │
│                                                                               │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ SSE wire (HTTP/1.1 chunked)
┌───────────────────────────────────┼──────────────────────── VAPOR BACKEND ───┐
│                                   ▼                                           │
│  6. ChatController                                                            │
│     Routes POST /api/v1/chat/stream                                           │
│     Validates request, resolves sessionId, creates user MessageModel in DB    │
│     Calls ClaudeExecutorService.execute(prompt:options:)                      │
│          │                                                                    │
│          ▼                                                                    │
│  7. ClaudeExecutorService.execute()                                           │
│     Returns AsyncThrowingStream<StreamMessage, Error>                         │
│     Two-tier timeout: 30s for first stdout byte, 5min total                  │
│          │                                                                    │
│          │           useAgentSDK?                                             │
│          ├──── YES ──────────────────────────────────── NO ──────────┐       │
│          ▼                                                            ▼       │
│  executeWithSDK()                                          executeWithCLI()   │
│  /bin/zsh -l -c                                            /bin/zsh -l -c    │
│  "node scripts/sdk-wrapper.mjs '<json>'"                   "claude -p         │
│  → @anthropic-ai/claude-agent-sdk                           --output-format   │
│  → Anthropic API (HTTPS direct)                             stream-json ..."  │
│          │                                                            │       │
│          └────────────────────────┬───────────────────────────────────┘       │
│                                   ▼                                           │
│  8. subprocess stdout (NDJSON)                                                │
│     DispatchQueue reads line-by-line via readDataToEndOfFile                  │
│     (not RunLoop — Vapor's NIO does not pump RunLoop)                         │
│          │                                                                    │
│          ▼                                                                    │
│  9. CLIMessageConverter                                                       │
│     JSONDecoder with .convertFromSnakeCase                                    │
│     Parses raw CLIMessage → typed StreamMessage events:                       │
│       .text(TextDelta)           — incremental text content                   │
│       .toolUse(ToolUseBlock)     — tool call initiated                        │
│       .toolResult(ToolResult)    — tool execution result                      │
│       .thinking(ThinkingBlock)   — extended thinking content                  │
│       .system(SystemMessage)     — session metadata (sessionId, cost)         │
│       .error(StreamError)        — error propagation                          │
│          │                                                                    │
│          ▼                                                                    │
│  10. StreamingService.createSSEResponseWithPersistence()                      │
│      Formats each StreamMessage as SSE event with monotonic event ID          │
│      Stores events in ring buffer (capacity 1000) for reconnection replay     │
│      Sends SSE heartbeat ping every 15s to keep connection alive              │
│                                                                               │
│      ┌─ Persistence (onMessage closure) ──────────────────────────────┐      │
│      │  Accumulates content during streaming:                         │      │
│      │    .text        → appends to accumulatedContent string         │      │
│      │    .toolUse     → appends JSON to toolCalls[]                  │      │
│      │    .toolResult  → appends JSON to toolResults[]                │      │
│      │    .system      → captures claudeSessionId, totalCostUSD       │      │
│      │  On stream end: saves MessageModel to DB, updates session      │      │
│      │  metadata (message_count, total_cost_usd, last_active_at)      │      │
│      └────────────────────────────────────────────────────────────────┘      │
│                                                                               │
│      SSE wire format:                                                         │
│        id: <monotonic-int>\n                                                  │
│        event: <type>\n                                                        │
│        data: <json>\n\n                                                       │
│        : ping\n\n   (heartbeat, every 15s)                                    │
│        event: done\ndata: {}\n\n   (stream complete)                          │
│                                                                               │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ SSE wire (HTTP/1.1 chunked)
┌───────────────────────────────────┼──────────────────────── iOS CLIENT ───────┐
│                                   ▼                                            │
│  11. SSEClient (asyncBytes.lines loop)                                         │
│      Parses SSE protocol: event:/data:/id: prefixes                            │
│      Decodes data JSON → StreamMessage via JSONDecoder                         │
│      Calls messages.append(decoded) → triggers @Published $messages            │
│      Reconnect on network error: exponential backoff, max 3 attempts           │
│      (2s → 4s → 8s, capped at 30s)                                            │
│          │                                                                     │
│          ▼                                                                     │
│  12. SSEClient.$messages (Combine Publisher)                                   │
│      Observed by ChatViewModel via .sink { streamMessages in ... }             │
│          │                                                                     │
│          ▼                                                                     │
│  13. ChatViewModel — Message Batching (75ms timer)                             │
│      Computes newMessages = streamMessages.dropFirst(lastProcessedIndex)       │
│      Appends only new items to pendingStreamMessages[]                         │
│      Starts batchTask if not running (fires every 75ms)                        │
│          │                                                                     │
│      ┌─ batchTask loop (every 75ms) ──────────────────────────────────┐       │
│      │  flushPendingMessages():                                        │       │
│      │    Converts StreamMessage → ChatMessage content blocks          │       │
│      │    Appends/updates messages[] on @MainActor                     │       │
│      │    Updates streamTokenCount and streamElapsedSeconds            │       │
│      │  On stream end: final flush + stopBatchTimer()                  │       │
│      └────────────────────────────────────────────────────────────────┘       │
│          │                                                                     │
│          ▼                                                                     │
│  14. ChatViewModel.messages[] (@Observable)                                    │
│      SwiftUI observation triggers ChatView body re-evaluation                  │
│          │                                                                     │
│          ▼                                                                     │
│  15. ChatMessageList re-render                                                 │
│      Renders updated messages[] — text deltas coalesced into assistant         │
│      message bubble, tool calls shown inline, thinking blocks collapsible      │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Key timing and reliability details:**

| Stage | Detail |
|-------|--------|
| Connection timeout | 60s race via `withThrowingTaskGroup` in SSEClient |
| Heartbeat watchdog | SSEClient checks every 15s; kills stream if no activity for 45s |
| SSE heartbeat | StreamingService sends `: ping` comment every 15s |
| Client batching | ChatViewModel flushes pending StreamMessages every 75ms (`batchInterval = 0.075`) |
| Persistence | StreamingService accumulates full response during stream; writes to DB only after stream ends |
| Reconnection | SSEClient retries on network errors up to 3×; sends `Last-Event-ID` for ring-buffer replay |
| Executor timeout | 30s for first stdout byte; 5min hard kill for runaway processes |

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

### Permission Request Flow

When Claude needs to execute a tool in `delegate` permission mode, it pauses execution and emits a permission request message. The iOS client displays a modal, collects the user's decision, and forwards it back to the CLI process via stdin — allowing the stream to continue.

**Prerequisites:** The session must be started with `permissionMode: .delegate`. In any other mode (`default`, `auto`, `bypassPermissions`), Claude either auto-approves or auto-denies tool calls without this round-trip.

```
┌─────────────────────────────── VAPOR BACKEND ────────────────────────────────┐
│                                                                               │
│  Claude CLI subprocess (in delegate mode)                                     │
│  Wants to execute a tool → writes permission request to stdout (NDJSON):      │
│                                                                               │
│    {"type":"permission","request_id":"<uuid>",                                │
│     "tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/foo"}}            │
│          │                                                                    │
│          ▼                                                                    │
│  ClaudeExecutorService (DispatchQueue stdout reader)                          │
│  Reads line → processJsonLine() → JSONDecoder → CLIMessage.permission         │
│          │                                                                    │
│          ▼                                                                    │
│  CLIMessageConverter.convert()                                                │
│  CLIMessage.permission → StreamMessage.permission(PermissionRequest)          │
│    PermissionRequest {                                                         │
│      requestId:  "<uuid>"                                                     │
│      toolName:   "Bash"                                                       │
│      toolInput:  AnyCodable({"command": "rm -rf /tmp/foo"})                   │
│    }                                                                           │
│          │                                                                    │
│          ▼                                                                    │
│  StreamingService                                                             │
│  Formats as SSE event:                                                        │
│    id: <n>                                                                    │
│    event: permission                                                          │
│    data: {"type":"permission","requestId":"<uuid>",                           │
│           "toolName":"Bash","toolInput":{...}}                                │
│                                                                               │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ SSE wire (HTTP/1.1 chunked)
┌───────────────────────────────────┼──────────────────────── iOS CLIENT ───────┐
│                                   ▼                                            │
│  SSEClient                                                                     │
│  Parses SSE line → decodes data JSON → StreamMessage.permission(req)           │
│  Appends to messages[] → triggers $messages Combine publisher                  │
│          │                                                                     │
│          ▼                                                                     │
│  ChatViewModel.flushPendingMessages()                                          │
│  Handles .permission(permissionReq):                                           │
│    pendingPermissionRequest = permissionReq   ← @Observable triggers UI        │
│          │                                                                     │
│          ▼                                                                     │
│  ChatView                                                                      │
│  .sheet(item: $viewModel.pendingPermissionRequest) { req in                    │
│      PermissionRequestModal(request: req, onDecision: { decision in            │
│          viewModel.respondToPermission(requestId: req.requestId,               │
│                                        decision: decision)                     │
│      })                                                                        │
│  }                                                                             │
│          │                                                                     │
│   User taps "Allow" or "Deny"                                                  │
│          │                                                                     │
│          ▼                                                                     │
│  ChatViewModel.respondToPermission(requestId:decision:)                        │
│    pendingPermissionRequest = nil    ← dismisses modal immediately             │
│    Task { POST /api/v1/chat/permission/{sessionId}/{requestId}                 │
│           body: PermissionDecision { decision: "allow" | "deny" }             │
│    }                                                                           │
│                                                                               │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ HTTP POST
┌───────────────────────────────────┼──────────────────────── VAPOR BACKEND ───┐
│                                   ▼                                           │
│  ChatController.permission(req:)                                              │
│  Extracts sessionId + requestId from path params                              │
│  Decodes PermissionDecision body                                              │
│  Calls executor.sendPermissionResponse(sessionId:requestId:decision:)         │
│          │                                                                    │
│          ▼                                                                    │
│  ClaudeExecutorService.sendPermissionResponse()   [actor-isolated]            │
│  Looks up activeStdinHandles[sessionId]                                       │
│  Encodes PermissionResponsePayload as JSON line:                              │
│                                                                               │
│    {"type":"permission_response","id":"<uuid>","decision":"allow"}            │
│                                                                               │
│  Appends "\n" and writes to subprocess stdin (FileHandle.write())             │
│  Returns true → ChatController returns 200 AcknowledgedResponse              │
│          │                                                                    │
│          ▼                                                                    │
│  Claude CLI subprocess reads JSON line from stdin                             │
│  Proceeds with tool execution ("allow") or skips it ("deny")                 │
│  Continues streaming remaining NDJSON output to stdout                        │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Stdin JSON format (written to Claude CLI process stdin):**

```json
{"type":"permission_response","id":"<requestId>","decision":"allow|deny"}\n
```

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `type` | String | `"permission_response"` | Fixed discriminator required by Claude CLI |
| `id` | String | UUID string | Must match the `requestId` from the permission request |
| `decision` | String | `"allow"` or `"deny"` | Whether Claude may proceed with the tool call |

**Key implementation details:**

| Aspect | Detail |
|--------|--------|
| Permission mode | Must be `delegate` — set at session creation time via `ExecutionOptions.permissionMode` |
| Stdin handle lifecycle | `ClaudeExecutorService` stores `FileHandle` in `activeStdinHandles[sessionId]` when the subprocess starts; removed on process exit |
| Modal dismissal | `pendingPermissionRequest` is cleared to `nil` immediately on user tap (before the HTTP POST completes) for instant UI responsiveness |
| Process-gone handling | If `activeStdinHandles[sessionId]` has no entry (process already exited), `sendPermissionResponse` returns `false` and `ChatController` throws `HTTP 410 Gone` |
| Concurrent sessions | Each session has its own stdin handle keyed by session ID — multiple simultaneous sessions each route independently |

### SSE Wire Protocol

All streaming responses from `StreamingService` use the standard SSE (Server-Sent Events) wire format over HTTP/1.1 chunked transfer encoding.

#### Event Frame Format

Each event occupies three lines terminated by a blank line (`\n\n`):

```
id: <monotonic-int>\n
event: <event-type>\n
data: <json-payload>\n
\n
```

**Example — assistant text delta:**
```
id: 42
event: assistant
data: {"type":"text","text":"Hello, world!"}

```

**Example — system event (session metadata):**
```
id: 1
event: system
data: {"sessionId":"abc123","model":"claude-opus-4-5","costUSD":0.0012}

```

**Example — error event:**
```
id: 99
event: error
data: {"code":"STREAM_ERROR","message":"Process exited with code 1"}

```

#### Event Types

| Event Type | `StreamMessage` Case | Payload | Description |
|------------|---------------------|---------|-------------|
| `system` | `.system(SystemMessage)` | Session ID, model, cost | First event; carries Claude session ID and model info |
| `assistant` | `.text`, `.toolUse`, `.toolResult`, `.thinking` | Content block JSON | Incremental assistant output (text deltas, tool calls, tool results, thinking blocks) |
| `user` | `.user(UserMessage)` | User message content | Echo of the user's message |
| `result` | `.result(ResultMessage)` | Final result + cost | End-of-turn summary with total cost |
| `streamEvent` | `.streamEvent(StreamEvent)` | Raw SDK event | Low-level streaming events from Agent SDK |
| `permission` | `.permission(PermissionRequest)` | Tool name, details | Permission required before tool execution |
| `error` | `.error(StreamError)` | Error code + message | Stream error; sent on exception, then stream ends |

#### Special Control Frames

**Heartbeat (every 15 seconds):**
```
: ping\n
\n
```
SSE comment syntax (`: ` prefix) — keeps the TCP connection alive and resets client inactivity timers. Sent by `StreamingService` every 15 seconds regardless of message activity. The client-side heartbeat watchdog in `SSEClient` expects at least one activity (data or ping) every 45 seconds.

**Stream Complete:**
```
event: done\n
data: {}\n
\n
```
Sent when the `AsyncThrowingStream` is exhausted normally (no error). Signals the client that no more events will follow. The iOS `SSEClient` treats this as a clean stream end and does not attempt reconnection.

#### Reconnection and Ring Buffer

`StreamingService` maintains a shared `EventBuffer` actor with a **capacity of 1000 events**. Every event written to any SSE stream is stored in this ring buffer with its monotonic integer ID.

**Reconnection flow:**
1. Client disconnects (network error, app backgrounded, etc.)
2. On reconnect, `SSEClient` sends `Last-Event-ID: <last-seen-id>` request header
3. `StreamingService.writeSSEStream()` parses the header and calls `eventBuffer.eventsSince(lastId)`
4. All missed events (up to 1000-event buffer capacity) are replayed immediately before the live stream resumes

```
Client reconnects with Last-Event-ID: 850
    |
    v
eventBuffer.eventsSince(850)
    |
    v
Replay events 851..N immediately
    |
    v
Resume live stream from current position
```

**Ring buffer eviction:** When the buffer exceeds 1000 events the oldest entries are removed (`removeFirst`). Events older than the buffer window are permanently lost — clients reconnecting after a long gap receive only the most recent 1000 events.

#### SSE Response Headers

Every SSE response includes these headers:

| Header | Value | Purpose |
|--------|-------|---------|
| `Content-Type` | `text/event-stream` | Signals SSE protocol to client |
| `Cache-Control` | `no-cache` | Prevents proxy/CDN caching of the stream |
| `Connection` | `keep-alive` | Keeps TCP connection open for streaming |
| `X-Accel-Buffering` | `no` | Disables nginx proxy buffering (required for real-time delivery) |

Persistence responses (chat streaming with DB writes) additionally include:

| Header | Value | Purpose |
|--------|-------|---------|
| `X-User-Message-ID` | `<UUID>` | User message DB record ID for client correlation |
| `X-Session-ID` | `<UUID>` | Session DB record ID |

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Execution backend | Agent SDK (default) | Spawns `node scripts/sdk-wrapper.mjs`; SDK calls Anthropic API directly, avoiding subprocess hang inside Claude Code session |
| CLI fallback | `claude -p --output-format stream-json` | Used when running backend standalone outside Claude Code; toggle via `ClaudeExecutorService.useAgentSDK = false` |
| CLI integration | Direct `Process` + `DispatchQueue` | ClaudeCodeSDK uses RunLoop which Vapor's NIO doesn't pump |
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

## Session Identity Model

ILS uses two distinct session identifier types that serve different purposes and have a specific relationship for session resumption and deduplication.

### Identity Types

| Identifier | Type | Where stored | Source |
|-----------|------|-------------|--------|
| **ILS Session UUID** | `UUID` | SQLite `sessions.id` (PK) | Auto-generated by ILS or provided by iOS client |
| **Claude Session ID** | `String` | SQLite `sessions.claude_session_id` (nullable) | Returned by Claude CLI/SDK in the `system` message |
| **External Session ID** | `String` | `~/.claude/projects/*/sessions-index.json` | Written by Claude CLI independent of ILS |

#### 1. ILS Session UUID

The primary key for every ILS-managed session in SQLite. Created in one of two ways:

- **Server-generated:** `SessionModel` auto-assigns `UUID()` when a new session is created via `POST /api/v1/sessions` or when `ChatController.stream()` creates one on the fly.
- **Client-provided:** The iOS client can pre-generate a UUID and send it in `ChatStreamRequest.sessionId`. If the UUID doesn't exist in the DB, `ChatController` creates a `SessionModel` with that exact UUID — this handles the "New Session" optimistic UI pattern where the client needs an ID before the first network round-trip completes.

```swift
// ChatController.swift — client-provided UUID handling
if let existingSessionId = input.sessionId {
    if try await SessionModel.find(existingSessionId, on: req.db) != nil {
        sessionId = existingSessionId         // session already exists
    } else {
        let newSession = SessionModel(id: existingSessionId, ...)  // create on the fly
        try await newSession.save(on: req.db)
        sessionId = existingSessionId
    }
}
```

The ILS Session UUID is used for all API calls: `/api/v1/sessions/{uuid}`, `/api/v1/chat/ws/{uuid}`, `/api/v1/chat/cancel/{uuid}`, etc.

#### 2. Claude Session ID

A string token assigned by the Claude CLI/SDK to identify a conversation thread. It is:

- **Emitted** in the first SSE event of every conversation — the `system` message payload includes `sessionId` (see `CLISystemMessage.sessionId`, decoded from the `session_id` JSON field via `.convertFromSnakeCase`).
- **Stored** in `sessions.claude_session_id` by `StreamingService` when it receives the system message during the stream. The column is `NULL` until at least one message has completed.
- **Used for resume** — passing this value as the `--resume` flag (CLI) or `resume` option (SDK) continues the Claude conversation thread from where it left off.

#### 3. External Session IDs

Claude CLI writes session metadata directly to `~/.claude/projects/<url-encoded-path>/sessions-index.json` — independent of ILS. Each entry in that JSONL index has a `sessionId` field containing the Claude session ID for that conversation.

`SessionFileService.scanExternalSessions()` reads these files and produces `ExternalSession` values with `claudeSessionId = entry.sessionId`.

For external sessions (not in the ILS SQLite DB), a **deterministic UUID** is derived from the Claude session ID using SHA256 so the same external session always maps to the same UUID across app restarts and index rescans:

```swift
// SessionFileService.swift — deterministic UUID generation
private func deterministicUUID(from claudeSessionId: String) -> UUID {
    let input = "ils-external-session:\(claudeSessionId)"
    let hash = SHA256.hash(data: Data(input.utf8))
    var bytes = Array(hash.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x40  // version 4 (RFC 4122)
    bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 1 (RFC 4122)
    return UUID(uuid: (...))
}
```

### Resume Flow

When a user continues a previous session, the backend retrieves the stored `claudeSessionId` and passes it as the `--resume` flag to the Claude CLI (or `resume` field to the Agent SDK):

```
iOS client sends: POST /api/v1/chat/stream
    body: { sessionId: "<ILS-UUID>", prompt: "continue..." }
         |
         v
ChatController.stream()
    Looks up SessionModel by ILS-UUID
    Reads session.claudeSessionId    ← captured from prior conversation's system message
         |
         v
ExecutionOptions.resume = session.claudeSessionId
         |
         v
ClaudeExecutorService.execute(options: options)
    CLI:  claude -p --resume <claudeSessionId> ...
    SDK:  sdk-wrapper.mjs  { "resume": "<claudeSessionId>", ... }
         |
         v
Claude CLI/SDK resumes the conversation thread
```

**Priority rule:** The DB-stored `claudeSessionId` always takes precedence over any `options.resume` value the client sends — this prevents the client from hijacking a session's conversation thread:

```swift
// ChatController.swift — DB claudeSessionId takes priority
if let dbClaudeId = session.claudeSessionId {
    options.resume = dbClaudeId            // DB wins
}
// else: keep options.resume from client (first message in an external session)
```

**External session resume:** External sessions discovered from `~/.claude/projects/` can also be resumed. The iOS client sets `ChatStreamRequest.options.resume = session.claudeSessionId`. If the session is not yet in the DB, `ChatController` creates a new `SessionModel` with `claudeSessionId = input.options?.resume` — subsequent messages in that session then use the DB-stored value.

### Deduplication Rules

When `SessionsController` returns the unified session list, it merges DB sessions and external file-scanned sessions with these rules:

1. **DB sessions always win.** Every session in SQLite is authoritative and is included as-is.
2. **External sessions fill the gaps.** An external session is included only if its `claudeSessionId` does **not** match any DB session's `claudeSessionId`. If a DB session shares the same `claudeSessionId`, the external entry is suppressed.
3. **Deterministic UUIDs for external sessions.** SHA256-derived UUIDs ensure stable identity across index rescans.
4. **Source tagging.** Each `ChatSession` carries a `source` field (`.ils` for DB sessions, `.external` for file-scanned sessions) — the iOS client uses this to display the session origin badge.

```
DB sessions:        [UUID-A (claudeId=X), UUID-B (claudeId=Y)]
External sessions:  [det-UUID-X (claudeId=X), det-UUID-C (claudeId=Z)]

After dedup:
  UUID-A (DB, claudeId=X)           ← DB wins; det-UUID-X suppressed
  UUID-B (DB, claudeId=Y)
  det-UUID-C (external, claudeId=Z) ← no DB match; included
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
