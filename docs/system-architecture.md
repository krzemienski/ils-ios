# ILS System Architecture

**Version:** 1.1.1 | **Last Updated:** 2026-03-10

---

## System Overview

ILS is a three-tier distributed system:

```
┌─────────────────────────────────────────────────────┐
│         Frontend (iOS & macOS Clients)              │
│  - 149 files (iOS), 14 files (macOS)                │
│  - SwiftUI views, ViewModels, services              │
│  - Local SQLite cache, theme system                 │
└─────────────────────────────────────────────────────┘
            ↕ HTTP + SSE + WebSocket
┌─────────────────────────────────────────────────────┐
│         Backend (Vapor Server)                      │
│  - 52 Swift files (31 controllers, 39 services)     │
│  - REST API (/api/v1), real-time connections       │
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
    ├─ Sidebar (sheet on iPhone)
    │   └─ NavigationLink → ActiveScreen enum routing
    ├─ SessionsList → ChatView
    ├─ DashboardView
    ├─ SettingsView
    ├─ BrowserView (Skills, Plugins, MCP)
    ├─ SystemMonitor
    ├─ ThemesEditor
    ├─ TeamsView
    └─ [18+ more screens]
```

**Navigation Pattern:**
```swift
// All routing through ActiveScreen enum
enum ActiveScreen {
    case home
    case sessions
    case chat(sessionId: UUID)
    case settings
    case themes
    // ...
}

// Changed via SidebarRootView.activeScreen @State
```

### State Management

**App-Level State (AppState):**
- Backend connection (host, port, API key)
- Current session context
- Deep link handling
- Notification preferences

**Screen-Level State (ViewModels):**
- @Observable classes (one per screen)
- @MainActor for thread safety
- Local @State for UI interaction

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

### Controllers (31 Total)

| Controller | Purpose | Key Methods |
|-----------|---------|-------------|
| **SessionsController** | Session CRUD | list, create, read, update, delete, fork, search |
| **ChatController** | Real-time chat | stream, loadHistory, search |
| **MCPController** | MCP servers | list, status, health check |
| **PluginsController** | Plugin management | list, install, enable, config |
| **SkillsController** | Skill discovery | list, search, install from GitHub |
| **SystemController** | System info | cpu, memory, disk, network metrics |
| **ProjectsController** | Project management | list, detail, search |
| **WorkflowsController** | Workflow execution | list, create, schedule, run |
| **TeamsController** | Agent teams | list, members, messaging |
| **WebSocketController** | Real-time metrics | upgrade for WebSocket (metrics feed) |
| [21 more controllers] | Config, hooks, recordings, activity feed, etc. |

### Services (39 Total)

| Service | Purpose | Key Method |
|---------|---------|-----------|
| **ClaudeExecutorService** | Execute Claude Code | executeWithSDK(python subprocess) |
| **ProcessMonitorService** | Monitor system processes | collect metrics (CPU, memory) |
| **WorkflowExecutionEngine** | Run workflows | execute workflow steps with sequencing |
| **WorkflowScheduler** | Schedule workflows | Vapor Jobs + cron |
| **SessionFileService** | File I/O | read/write session files to disk |
| **SystemMetricsService** | Collect metrics | CPU, memory, disk, network (top, vmstat) |
| **GitHubService** | GitHub integration | fetch skills, search repositories |
| **FileSystemService** | File operations | watch directories, file access |
| **SuggestionService** | Generate suggestions | AI suggestions for workflows |
| **TeamMetricsService** | Team analytics | aggregate metrics across users |
| [29 more services] | Plugins, MCP, config, permissions, etc. |

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

**33+ more tables** for workflows, teams, hooks, checkpoints, recordings, etc.

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
