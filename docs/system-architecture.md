# ILS System Architecture

**Version:** 1.2.0 | **Last Updated:** 2026-03-10

---

## System Overview

ILS is a three-tier distributed system:

```
┌─────────────────────────────────────────────────────┐
│         Frontend (iOS & macOS Clients)              │
│  - 405 files (iOS), 18 files (macOS)                │
│  - SwiftUI views, ViewModels, services              │
│  - Local SQLite cache, theme system                 │
└─────────────────────────────────────────────────────┘
            ↕ HTTP + SSE + WebSocket
┌─────────────────────────────────────────────────────┐
│         Backend (Vapor Server)                      │
│  - 123 Swift files (34 controllers, 47 services)    │
│  - REST API (/api/v1), real-time connections        │
│  - SQLite database (ils.sqlite), Python executor    │
└─────────────────────────────────────────────────────┘
            ↕ CLI execution
┌─────────────────────────────────────────────────────┐
│         Claude Code CLI + Anthropic API             │
│  - Python SDK wrapper (sdk-wrapper.py)              │
│  - Agent execution, stream handling                 │
│  - Token counting, message formatting               │
└─────────────────────────────────────────────────────┘
```

---

## Frontend Architecture

### Data Flow (Chat Example)

```
ChatView (displays messages)
    ↓
ChatViewModel (@Observable @MainActor)
    ├─ loadHistory() → APIClient.get("/sessions/{id}/messages")
    ├─ sendMessage() → APIClient.post("/chat/stream")
    └─ connectStream() → SSEClient.connect(to: streamUrl)
         ↓
         SSE stream receives tokens in real-time
         ↓
         ViewModel updates @Observable messages
         ↓
         SwiftUI re-renders ChatView with new content
```

### Service Layer

**APIClient (Actor-Based HTTP)**
```swift
actor APIClient {
    // Thread-safe REST methods
    func get<T>(_ path) async throws -> T
    func post<T, U>(_ path, body: U) async throws -> T

    // Caching (NSCache + ETag)
    // Request deduplication (concurrent GET → single network call)
    // Conditional requests (If-None-Match, 304 Not Modified)
}
```

**SSEClient (Server-Sent Events)**
```swift
struct SSEClient {
    // Real-time streaming
    func connect(to url: URL) async throws -> AsyncStream<SSEEvent>
    // 2-tier timeout (30s initial, 5min total)
    // Auto-reconnection on connection loss
}
```

**LocalDatabase (Offline Cache)**
```
UserDefaults                    NSCache
├─ Theme preference             ├─ API responses (TTL)
├─ Keyboard shortcuts           ├─ ETag backing data
└─ Notification settings        └─ Search cache

SQLite (ils.sqlite)
├─ Sessions (fallback)
├─ Messages (indexed)
└─ Bookmarks, favorites
```

### View Hierarchy

```
ILSAppApp (@main)
└─ SidebarRootView
    ├─ SidebarView (sheet on iPhone, persistent on iPad)
    │   └─ ActiveScreen enum → content routing
    ├─ HomeView
    ├─ UnifiedSessionsView → ChatView
    ├─ BrowserView (Skills, MCP, Plugins, GitHub preview)
    ├─ TeamsView (AgentTeams, TeamDashboard, TeamMessages)
    ├─ WorkflowsListView → WorkflowBuilderView / ExecutionView
    ├─ AuditTrailView → AuditActionDetailSheet
    ├─ SystemMonitorView
    ├─ SettingsView
    ├─ ThemeEditorView
    ├─ HooksView
    ├─ ActivityFeedView
    ├─ AgentQueueView
    ├─ AnalyticsView / UsageDashboardView
    ├─ PermissionsView
    ├─ TerminalView
    ├─ DocumentationView
    ├─ HostProfilesView (Fleet)
    ├─ BackendsView
    └─ [MultiSessionSplitView, GlobalSearchView, ...]
```

**Navigation Pattern:**
```swift
// All routing through SidebarRootView.ActiveScreen enum (22 cases)
enum ActiveScreen: Hashable {
    case home
    case chat(ChatSession)
    case sessionForkTree(ChatSession)
    case system
    case settings
    case browser
    case teams
    case hostProfiles        // also reachable as "fleet"
    case themes
    case hooks
    case activityFeed
    case agentQueue
    case documentation
    case terminal
    case backends
    case unifiedSessions
    case splitView
    case analytics
    case permissions
    case search
    case usage
    case workflows
}

// Changed via @State activeScreen in SidebarRootView
// Deep-link host strings map to cases (e.g. "fleet" → .hostProfiles)
```

**macOS Layout:**
```
ILSMacApp (@main)
└─ MacContentView (NavigationSplitView)
    ├─ MacSessionsListView (sidebar)
    ├─ MacChatView (detail)
    ├─ MacSettingsView
    └─ MacProjectsListView
```

### State Management

**App-Level State (AppState):**
- Backend connection (host, port, API key)
- Current session context
- Deep link handling
- Notification preferences

**Screen-Level State (ViewModels — 53 total):**
- `@Observable @MainActor` classes, one per screen
- All extend `BaseViewModel` (cancel tracking, loading/error state)
- `nonisolated(unsafe)` for `Task` properties stored on `@MainActor` class
- Local `@State` for transient UI interaction (not persisted)

**Persistent State (UserDefaults + Keychain):**
- Theme selection, display density
- Keyboard shortcuts, notification settings
- Backend credentials (Keychain only)

---

## Backend Architecture

### Request Flow

```
HTTP Request (from iOS/macOS)
    ↓
Router (in configure.swift)
    ↓
Middleware (auth, rate limiting, error handling)
    ↓
Controller (SessionsController, ChatController, etc.)
    ├─ Parse request
    ├─ Call services
    └─ Return APIResponse<T>
         ↓
         Services (business logic)
         ├─ SessionManager (CRUD)
         ├─ ClaudeExecutorService (Python SDK)
         ├─ ProcessMonitorService (metrics)
         └─ [36 more]
             ↓
             Models (Fluent ORM → SQLite)
```

### Controllers (34 Total)

| Controller | Purpose | Key Endpoints |
|-----------|---------|-------------|
| **SessionsController** | Session CRUD | list, create, read, update, delete, fork, search |
| **ChatController** | Real-time chat | stream (SSE), loadHistory, search |
| **MCPController** | MCP servers | list, status, health check |
| **PluginsController** | Plugin management | list, install, enable, config |
| **SkillsController** | Skill discovery | list, search, install from GitHub |
| **SystemController** | System info | CPU, memory, disk, network metrics |
| **ProjectsController** | Project management | list, detail, search |
| **WorkflowsController** | Workflow execution | list, create, schedule, run, builder |
| **TeamsController** | Agent teams | list, members, messaging, spawn |
| **AuditController** | Audit trail | list actions, create, rollback |
| **AgentQueueController** | Agent job queue | list, enqueue, dequeue, status |
| **AnalyticsController** | Usage analytics | aggregated stats and trends |
| **AutomationRulesController** | Automation rules | list, create, update, delete |
| **CheckpointsController** | Session checkpoints | create, list, restore |
| **PermissionsController** | Permission history | list, approve, deny |
| **RecordingController** | Session recordings | list, start, stop, playback |
| **TerminalController** | Terminal sessions | open, exec, WebSocket upgrade |
| **SSHController** | SSH tunneling | connect, list profiles |
| **HostProfileController** | Fleet host profiles | list, add, edit, remove |
| [15 more controllers] | Config, hooks, health, data erasure, pairing, stats, etc. |

### Services (47 Total)

| Service | Purpose | Key Method |
|---------|---------|-----------|
| **ClaudeExecutorService** | Execute Claude Code | executeWithSDK() via python subprocess |
| **TeamsExecutorService** | Spawn team agents | spawn teammate, manage lifecycle |
| **WorkflowExecutionEngine** | Run workflows | execute steps with sequencing |
| **WorkflowScheduler** | Schedule workflows | Vapor Jobs + cron |
| **ProcessMonitorService** | Monitor system processes | collect CPU/memory metrics |
| **SystemMetricsService** | System telemetry | CPU, memory, disk, network (top/vmstat) |
| **GitHubService** | GitHub integration | fetch skills, search repositories |
| **FileSystemService** | File operations | watch directories, file access |
| **SessionFileService** | Session file I/O | read/write session files to disk |
| **SessionHealthService** | Session health scoring | score, flag, remediate |
| **RuleExecutionService** | Automation rule engine | evaluate triggers, execute actions |
| **RuleTriggerEvaluator** | Rule conditions | evaluate per-event rule conditions |
| **AgentQueueService** | Job queue | enqueue, dequeue, prioritize agent jobs |
| **TunnelService** | Cloudflare tunnel | start, stop, configure tunnel |
| **TerminalService** | Terminal subprocess | spawn, pipe I/O, WebSocket bridge |
| **TeamMetricsService** | Team analytics | aggregate metrics across teammates |
| **SuggestionService** | AI suggestions | prompt-based suggestions for workflows |
| [30 more services] | APNs, Bonjour, MCP file, model routing, indexing, etc. |

### Database Schema (SQLite)

**Core Tables:**

```sql
sessions
├─ id UUID primary
├─ name String
├─ projectId UUID foreign
├─ model String (claude-3.5-sonnet, etc.)
├─ messageCount Int
├─ lastMessageAt DateTime
├─ createdAt DateTime
└─ [10+ more]

messages
├─ id UUID primary
├─ sessionId UUID foreign
├─ role String (user, assistant)
├─ content String (markdown)
├─ tokens Int
├─ timestamp DateTime
└─ [metadata]

projects
├─ id UUID primary
├─ name String
├─ description String
└─ [path, config, etc.]

skills
├─ id String primary
├─ name String
├─ githubUrl String
├─ installed Boolean
└─ [metadata]

plugins
├─ id String primary
├─ name String
├─ version String
├─ enabled Boolean
└─ [config JSON]

mcp_servers
├─ id String primary
├─ name String
├─ command String
├─ args [String]
└─ [health, status]
```

**Additional tables (18 models total):**
- `audit_actions` — AI action trail with rollback reference
- `automation_rules` — trigger/action rule definitions
- `rule_execution_logs` — rule run history
- `agent_queue_items` — agent job queue entries
- `checkpoints` / `session_checkpoints` — fork-able session snapshots
- `session_recordings` — recorded session playback data
- `host_profiles` — fleet host connection profiles
- `config_profiles` — named configuration snapshots
- `permission_events` — permission approval/deny history
- `templates` — reusable session/workflow templates
- `theme_configs` — user-defined custom themes
- `version_history` — version checkpoint tracking
- `search_history` — cross-session search cache
- `process_history` — system process snapshots

### Real-Time Connections

**Server-Sent Events (SSE) for Chat Streaming:**

```
iOS/macOS
    ↓
POST /chat/stream → ChatController
    ↓
ClaudeExecutorService.executeWithSDK()
    ↓
Python subprocess (sdk-wrapper.py)
    ↓
Claude CLI → Anthropic API
    ↓
Token-by-token responses
    ↓
Backend SSE: event: message, data: {token, metadata}
    ↓
SSEClient parses NDJSON
    ↓
ChatViewModel updates messages
    ↓
ChatView re-renders
```

**WebSocket for Metrics:**

```
iOS/macOS
    ↓
WebSocket upgrade to /ws/metrics
    ↓
MetricsWebSocketClient (backend)
    ↓
SystemMetricsService collects CPU, memory, disk, network
    ↓
Broadcast to all connected clients (~100ms interval)
    ↓
MetricsWebSocketClient (frontend) updates SystemMonitorView
```

---

## Communication Protocol

### HTTP REST API

**Base URL:** `http://localhost:9999/api/v1`

**Response Format:**
```json
{
  "success": true,
  "data": { "items": [...], "total": 100 },
  "error": null
}
```

**Common Endpoints:**

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Health check (plain text "OK") |
| GET | `/sessions` | List sessions (cached, 22K items) |
| POST | `/sessions` | Create session |
| GET | `/sessions/{id}` | Session detail |
| DELETE | `/sessions/{id}` | Delete session |
| POST | `/sessions/{id}/fork` | Fork from checkpoint |
| POST | `/chat/stream` | Stream chat response (SSE) |
| GET | `/projects` | List projects |
| GET | `/skills` | Discover skills (GitHub) |
| POST | `/skills/{name}/install` | Install skill |
| GET | `/plugins` | List installed plugins |
| POST | `/plugins/{id}/enable` | Enable plugin |
| GET | `/mcp` | List MCP servers |
| GET | `/system/metrics` | System info |
| WebSocket | `/ws/metrics` | Real-time metrics stream |
| GET | `/audit` | List audit trail actions |
| POST | `/audit` | Record an AI action |
| POST | `/audit/{id}/rollback` | Roll back a recorded action |
| GET | `/workflows` | List workflows |
| POST | `/workflows` | Create workflow |
| POST | `/workflows/{id}/run` | Execute workflow |
| GET | `/teams` | List agent teams |
| POST | `/teams/{id}/spawn` | Spawn a new teammate |
| GET | `/agent-queue` | List agent job queue |
| GET | `/permissions` | List permission events |
| GET | `/terminal` | Terminal sessions |
| GET | `/host-profiles` | Fleet host profiles |

See `docs/API.md` for complete reference.

### Authentication

**Current:** No authentication (local development)
**Planned (Phase 1):** API key in Authorization header

```
Authorization: Bearer <api_key>
```

Stored in Keychain (never UserDefaults).

### Caching Strategy

**Frontend:**
- **NSCache** (memory) with TTL per endpoint
- **Conditional Requests** (ETags) for bandwidth optimization
- **Request Deduplication** (concurrent GETs share result)
- **LocalDatabase** (SQLite) for offline fallback

**Backend:**
- **Database indexes** on frequently-queried columns
- **Response gzip compression** (planned)
- **Database query caching** for expensive joins

---

## Concurrency Model

### Swift Concurrency (Async/Await)

```
ViewModels (@MainActor)
    ↓
Task { await APIClient.shared.get(...) }
    ↓
APIClient (actor-isolated)
    ├─ URLSession.data(from:) async
    └─ JSONDecoder.decode() (nonisolated)
         ↓
         Returns to @MainActor context
         ↓
         ViewModel updates @Observable properties
         ↓
         SwiftUI re-renders
```

### Thread Safety

- **ViewModels:** @MainActor ensures UI updates happen on main thread
- **APIClient:** actor isolation ensures thread-safe HTTP + caching
- **Services:** @MainActor or actor-isolated as needed
- **Models:** Sendable (value types, no mutable shared state)

---

## Error Handling

### Frontend Error Flow

```
View
    ↓
ViewModel.loadData() catches error
    ↓
Set ViewModel.error property
    ↓
SwiftUI renders error state
    ↓
Show alert or inline error message
```

### Backend Error Responses

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "NOT_FOUND",
    "message": "Session not found"
  }
}
```

**Common Codes:** UNAUTHORIZED, NOT_FOUND, BAD_REQUEST, RATE_LIMITED, INTERNAL_ERROR

---

## Scalability Considerations

### Frontend (iOS/macOS)

- **22K Sessions:** Lazy loading, search cache, pagination
- **Large Message History:** Virtual scrolling (planned), pagination
- **Real-Time Metrics:** 100ms update cycle, fallback polling if WebSocket unavailable
- **Memory:** SQLite local cache (offline support), automatic cleanup of old messages

### Backend

- **Database Indexes:** On sessions.id, messages.sessionId, skills.name (planned)
- **Query Optimization:** Select only needed columns, limit result sets
- **Response Compression:** gzip (planned)
- **Connection Pooling:** SQLite WAL mode for concurrent access
- **Load Balancing:** None (single server), but designed for stateless API

---

## Deployment Architecture

### Development

```
Xcode → iOS Simulator (localhost:9999)
     ↓
Swift run ILSBackend (port 9999)
     ↓
SQLite (./ils.sqlite)
```

### Production (Options)

**Option 1: macOS launchd**
```
~/Library/LaunchAgents/com.ils.backend.plist
    ↓
swift run ILSBackend (port 9999)
    ↓
SQLite backup (~/Desktop/ils-backup.sqlite)
```

**Option 2: Docker**
```
docker-compose up -d
    ↓
ILS Backend container (port 9999)
    ↓
Volume mounts: ils.sqlite, ~/.claude config
```

**Option 3: Remote Access**
```
Cloudflare Tunnel
    ↓
https://ils.example.com (encrypted)
    ↓
Local ILS Backend (port 9999)
```

See `docs/RUNNING_BACKEND.md` for detailed setup.

---

## Performance Metrics

| Operation | Expected | Measured |
|-----------|----------|----------|
| App startup | < 3s | ~2.5s |
| Session list load (22K items) | < 500ms | ~350ms |
| Chat message send | < 1s | ~0.8s |
| First token in response | < 1s | ~0.9s |
| Metrics WebSocket update | < 100ms | ~80ms |
| Session search (search cache) | < 50ms | ~30ms |

---

## Monitoring & Observability

### Frontend Logging

```swift
AppLogger.debug("LoadingSessions")
AppLogger.error("Failed to send message: \(error)")
```

Writes to:
- Console (Xcode debug output)
- Files (NSFileManager, `~/Documents/ils-logs/`)

### Backend Logging

```swift
app.logger.info("Session created", metadata: ["sessionId": "\(id)"])
app.logger.error("Error", metadata: ["error": "\(error)"])
```

Writes to:
- Console
- Files (if configured)

### Metrics Collection

- **System Monitor (frontend):** CPU, memory, disk, network via WebSocket
- **Activity Feed (frontend):** Timeline of session events
- **Analytics Dashboard (frontend):** Session trends, usage patterns

---

## Security Architecture

### Data Protection

- **Credentials:** Keychain (API keys, passwords)
- **Session IDs:** Memory only, not persisted
- **Message Content:** Stored plaintext in SQLite (at-rest encryption planned)

### Network Security

- **HTTPS (TLS 1.3):** Supported for remote access (Cloudflare Tunnel)
- **Local Network:** HTTP (no encryption, assuming secure home network)
- **Certificate Pinning:** Planned for production

### API Security

- **No authentication (current):** Local network only
- **API Key (planned):** Bearer token in Authorization header
- **Rate Limiting (planned):** Per-IP rate limits
- **Input Validation (planned):** Sanitize all user inputs

See `docs/ROADMAP.md` Phase 1 for security hardening timeline.

---

## Integration Points

### External Services

| Service | Purpose | Integration |
|---------|---------|-------------|
| Claude Code CLI | Execute code, run agents | Python SDK wrapper (subprocess) |
| Anthropic API | LLM inference | Claude CLI → API |
| GitHub API | Skill discovery, repo search | GitHubService (REST) |
| Cloudflare | Secure tunneling | Tunnel token, CNAME DNS |

### Plugin System

Plugins extend ILS by:
- Adding custom commands
- Integrating external services
- Customizing UI behavior

**API:** Plugins communicate via REST endpoints to backend.

---

## Future Architecture Improvements

1. **Web Client:** Browser-based dashboard (share backend, custom UI)
2. **Multi-User:** Team collaboration with shared sessions
3. **Event Streaming:** Kafka/RabbitMQ for cross-device sync
4. **GraphQL:** Flexible query language (optional alongside REST)
5. **Distributed Backend:** Horizontal scaling with load balancing
