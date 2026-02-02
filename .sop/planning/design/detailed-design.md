# ILS Application - Detailed Design Document

**Version**: 2.0
**Date**: 2026-02-01
**Status**: Complete Feature Parity with Claude Code

---

## Table of Contents

1. [Overview](#1-overview)
2. [Detailed Requirements](#2-detailed-requirements)
3. [Architecture Overview](#3-architecture-overview)
4. [Components and Interfaces](#4-components-and-interfaces)
5. [Data Models](#5-data-models)
6. [API Specification](#6-api-specification)
7. [Streaming Protocol](#7-streaming-protocol)
8. [Error Handling](#8-error-handling)
9. [UI/UX Design](#9-uiux-design)
10. [Testing Strategy](#10-testing-strategy)
11. [Appendices](#11-appendices)

---

## 1. Overview

### 1.1 Purpose

ILS (Intelligent Local Server) is an iOS application that provides complete feature parity with Claude Code's functionality. It enables users to manage Claude Code installations, conduct AI-powered coding sessions, and configure all aspects of the Claude Code ecosystem from their iOS device.

### 1.2 Goals

- **Full Feature Parity**: Support all Claude Code capabilities (chat, sessions, plugins, MCP, skills, settings)
- **Real-Time Streaming**: Live streaming of Claude Code responses via SSE/WebSocket
- **Project Management**: Organize work by projects with scoped sessions and configurations
- **Mobile-First UX**: Session-centric chat interface optimized for iOS

### 1.3 Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                     HOST MACHINE                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   VAPOR BACKEND                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ REST API     │  │ SSE Routes   │  │ WebSocket    │  │   │
│  │  │ Controllers  │  │ /stream/*    │  │ /ws/*        │  │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │   │
│  │         │                 │                 │           │   │
│  │  ┌──────┴─────────────────┴─────────────────┴───────┐  │   │
│  │  │              SERVICE LAYER                        │  │   │
│  │  │  ┌────────────────┐  ┌────────────────────────┐  │  │   │
│  │  │  │ ClaudeExecutor │  │ Python SDK Sidecar     │  │  │   │
│  │  │  │ (Swift Process)│  │ (Optional)             │  │  │   │
│  │  │  └────────┬───────┘  └────────────┬───────────┘  │  │   │
│  │  └───────────┼───────────────────────┼──────────────┘  │   │
│  └──────────────┼───────────────────────┼──────────────────┘   │
│                 │                       │                       │
│  ┌──────────────┴───────────────────────┴──────────────────┐   │
│  │                    CLAUDE CODE CLI                       │   │
│  │     ~/.claude/  │  .claude/  │  plugins  │  sessions     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    HTTP/SSE/WebSocket
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│                        iOS APP                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    SwiftUI Views                            │ │
│  │  Sessions │ Chat │ Projects │ Plugins │ MCP │ Settings     │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    View Models                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              API Client + Stream Handler                    │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 ILSShared Models                            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Detailed Requirements

### 2.1 Functional Requirements

#### FR-1: Chat Interface
- FR-1.1: Real-time streaming of Claude Code responses
- FR-1.2: Display all message types (text, tool calls, tool results, thinking, errors)
- FR-1.3: Full command palette with slash commands, skills, tools access
- FR-1.4: Cost and usage tracking per response
- FR-1.5: Configurable permission modes (bypass, plan, interactive, acceptEdits)

#### FR-2: Session Management
- FR-2.1: Create new sessions with project/model selection
- FR-2.2: Resume sessions by ID or name
- FR-2.3: Fork sessions to create branches
- FR-2.4: Hybrid storage: ILS database + Claude Code session scan
- FR-2.5: Display session metadata (duration, cost, turns)

#### FR-3: Project Management
- FR-3.1: CRUD operations on projects (directory paths)
- FR-3.2: Project-scoped sessions
- FR-3.3: Project default model settings
- FR-3.4: Project-specific plugins/MCP/settings display

#### FR-4: Plugin System
- FR-4.1: List installed plugins with status
- FR-4.2: Install plugins from marketplaces
- FR-4.3: Uninstall plugins
- FR-4.4: Enable/disable plugins
- FR-4.5: Browse and add marketplaces
- FR-4.6: View plugin details (commands, agents, skills)

#### FR-5: MCP Servers
- FR-5.1: List MCP servers by scope (user, project, local)
- FR-5.2: Add new MCP servers
- FR-5.3: Edit MCP server configurations
- FR-5.4: Delete MCP servers
- FR-5.5: View MCP server status (healthy/error)

#### FR-6: Skills & Commands
- FR-6.1: List available skills
- FR-6.2: View skill content (SKILL.md)
- FR-6.3: Create new skills
- FR-6.4: Edit existing skills
- FR-6.5: Delete skills
- FR-6.6: Invoke skills via command palette

#### FR-7: Settings Management
- FR-7.1: View/edit user settings (~/.claude/settings.json)
- FR-7.2: View/edit project settings (.claude/settings.json)
- FR-7.3: View/edit local settings (.claude/settings.local.json)
- FR-7.4: JSON validation before save
- FR-7.5: Quick toggles for common settings

### 2.2 Non-Functional Requirements

#### NFR-1: Performance
- NFR-1.1: Stream latency < 100ms from Claude Code output to iOS display
- NFR-1.2: API response time < 500ms for CRUD operations
- NFR-1.3: Support sessions with 1000+ messages

#### NFR-2: Reliability
- NFR-2.1: Graceful handling of connection drops
- NFR-2.2: Session state persistence across app restarts
- NFR-2.3: Automatic reconnection for WebSocket

#### NFR-3: Security
- NFR-3.1: Local network operation (no auth required for MVP)
- NFR-3.2: No sensitive data in logs
- NFR-3.3: Secure handling of API keys in MCP configs

---

## 3. Architecture Overview

### 3.1 System Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| iOS App | SwiftUI, iOS 17+ | User interface, state management |
| Vapor Backend | Vapor 4.x, Swift | API server, Claude Code orchestration |
| ILSShared | Swift Package | Shared models and DTOs |
| Claude Executor | Foundation.Process | CLI execution and output parsing |
| Python Sidecar | claude-agent-sdk | Optional advanced SDK features |
| SQLite DB | Fluent + SQLite | Projects, sessions, settings persistence |

### 3.2 Communication Protocols

| Protocol | Use Case | Direction |
|----------|----------|-----------|
| REST/HTTP | CRUD operations, queries | Request/Response |
| SSE | Simple streaming responses | Server → Client |
| WebSocket | Interactive sessions (permissions) | Bidirectional |

### 3.3 Execution Backends

#### Primary: Swift Process (CLI)
```swift
// Execute Claude Code CLI with streaming JSON output
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
process.arguments = ["-p", prompt, "--output-format", "stream-json"]
process.currentDirectoryURL = projectDirectory

let pipe = Pipe()
process.standardOutput = pipe

// Stream output line by line
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    // Parse JSON lines and emit to SSE/WebSocket
}
```

#### Secondary: Python Agent SDK (Optional)
```python
# Sidecar service for advanced features
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt=prompt,
    options=ClaudeAgentOptions(
        setting_sources=["user", "project"],
        plugins=[{"type": "local", "path": plugin_path}],
        hooks=custom_hooks
    )
):
    yield message
```

---

## 4. Components and Interfaces

### 4.1 Vapor Backend Structure

```
Sources/ILSBackend/
├── App/
│   ├── entrypoint.swift
│   ├── configure.swift
│   └── routes.swift
├── Controllers/
│   ├── ChatController.swift        # NEW: Streaming chat
│   ├── SessionsController.swift    # NEW: Session management
│   ├── ProjectsController.swift    # NEW: Project CRUD
│   ├── StatsController.swift
│   ├── SkillsController.swift
│   ├── MCPController.swift
│   ├── PluginsController.swift
│   └── ConfigController.swift
├── Services/
│   ├── ClaudeExecutorService.swift # NEW: CLI execution
│   ├── SessionStorageService.swift # NEW: Session scanning
│   ├── StreamingService.swift      # NEW: SSE/WebSocket
│   ├── GitHubService.swift
│   └── IndexingService.swift
├── Models/
│   └── (Fluent database models)
└── Middleware/
    └── CORSMiddleware.swift
```

### 4.2 iOS App Structure

```
Sources/ILSApp/
├── ILSApp.swift
├── Theme/
│   ├── ILSTheme.swift
│   └── Colors.swift
├── Views/
│   ├── Sessions/
│   │   ├── SessionsListView.swift      # Main screen
│   │   ├── SessionRowView.swift
│   │   └── NewSessionView.swift
│   ├── Chat/
│   │   ├── ChatView.swift              # Session chat
│   │   ├── MessageView.swift
│   │   ├── ToolCallView.swift
│   │   ├── ToolResultView.swift
│   │   ├── ChatInputView.swift
│   │   └── CommandPaletteView.swift
│   ├── Projects/
│   │   ├── ProjectsListView.swift
│   │   ├── ProjectDetailView.swift
│   │   └── ProjectFormView.swift
│   ├── Plugins/
│   │   ├── PluginsListView.swift
│   │   ├── PluginDetailView.swift
│   │   └── MarketplaceView.swift
│   ├── MCP/
│   │   ├── MCPServerListView.swift
│   │   └── MCPServerFormView.swift
│   ├── Skills/
│   │   ├── SkillsListView.swift
│   │   ├── SkillDetailView.swift
│   │   └── SkillEditorView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── ConfigEditorView.swift
│   └── Sidebar/
│       └── SidebarView.swift
├── ViewModels/
│   ├── SessionsViewModel.swift
│   ├── ChatViewModel.swift
│   ├── ProjectsViewModel.swift
│   ├── PluginsViewModel.swift
│   ├── MCPViewModel.swift
│   ├── SkillsViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── APIClient.swift
│   ├── SSEClient.swift
│   ├── WebSocketClient.swift
│   └── StreamParser.swift
└── Resources/
    └── Assets.xcassets
```

### 4.3 Interface Definitions

#### ClaudeExecutorService Protocol
```swift
protocol ClaudeExecutorProtocol {
    /// Execute a prompt and stream results
    func execute(
        prompt: String,
        options: ExecutionOptions,
        onMessage: @escaping (StreamMessage) -> Void
    ) async throws -> ExecutionResult

    /// Cancel running execution
    func cancel() async

    /// Check if Claude Code is available
    func isAvailable() async -> Bool
}

struct ExecutionOptions {
    var workingDirectory: String?
    var model: String?
    var sessionId: String?          // Resume session
    var forkSession: Bool = false
    var permissionMode: PermissionMode?
    var allowedTools: [String]?
    var disallowedTools: [String]?
    var maxTurns: Int?
    var maxBudgetUSD: Double?
    var mcpConfig: String?
    var pluginDirs: [String]?
}
```

#### StreamingService Protocol
```swift
protocol StreamingServiceProtocol {
    /// Start SSE stream for a chat session
    func startSSEStream(
        sessionId: String,
        prompt: String,
        options: ExecutionOptions
    ) -> AsyncThrowingStream<StreamMessage, Error>

    /// Start WebSocket connection for interactive session
    func startWebSocket(
        sessionId: String
    ) -> WebSocketConnection
}

class WebSocketConnection {
    func send(_ message: ClientMessage) async throws
    func receive() -> AsyncThrowingStream<ServerMessage, Error>
    func close() async
}
```

---

## 5. Data Models

### 5.1 Shared Models (ILSShared)

#### Session Models (NEW)
```swift
public struct Session: Codable, Identifiable, Sendable {
    public let id: UUID
    public var claudeSessionId: String?  // Claude Code's session ID
    public var name: String?
    public var projectId: UUID?
    public var model: String
    public var permissionMode: PermissionMode
    public var status: SessionStatus
    public var createdAt: Date
    public var lastActiveAt: Date
    public var messageCount: Int
    public var totalCostUSD: Double?
    public var source: SessionSource
}

public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case error
}

public enum SessionSource: String, Codable, Sendable {
    case ils      // Created through ILS
    case external // Discovered from Claude Code storage
}

public enum PermissionMode: String, Codable, Sendable {
    case `default`
    case acceptEdits
    case plan
    case bypassPermissions
}
```

#### Project Model (NEW)
```swift
public struct Project: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String              // Directory path on host
    public var defaultModel: String?
    public var description: String?
    public var createdAt: Date
    public var lastAccessedAt: Date
}
```

#### Stream Message Models (NEW)
```swift
public enum StreamMessage: Codable, Sendable {
    case system(SystemMessage)
    case assistant(AssistantMessage)
    case result(ResultMessage)
    case permission(PermissionRequest)
    case error(StreamError)
}

public struct SystemMessage: Codable, Sendable {
    public let subtype: String  // "init", "completion"
    public let data: SystemData
}

public struct SystemData: Codable, Sendable {
    public let sessionId: String?
    public let plugins: [PluginInfo]?
    public let slashCommands: [String]?
}

public struct AssistantMessage: Codable, Sendable {
    public let content: [ContentBlock]
    public let model: String?
}

public enum ContentBlock: Codable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case thinking(ThinkingBlock)
}

public struct TextBlock: Codable, Sendable {
    public let text: String
}

public struct ToolUseBlock: Codable, Sendable {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]
}

public struct ToolResultBlock: Codable, Sendable {
    public let toolUseId: String
    public let content: String?
    public let isError: Bool?
}

public struct ThinkingBlock: Codable, Sendable {
    public let thinking: String
    public let signature: String?
}

public struct ResultMessage: Codable, Sendable {
    public let subtype: String
    public let durationMs: Int
    public let durationApiMs: Int
    public let isError: Bool
    public let numTurns: Int
    public let sessionId: String
    public let totalCostUSD: Double?
    public let usage: UsageInfo?
    public let result: String?
}

public struct UsageInfo: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
}

public struct PermissionRequest: Codable, Sendable {
    public let toolName: String
    public let toolInput: [String: AnyCodable]
    public let requestId: String
}

public struct StreamError: Codable, Sendable {
    public let code: String
    public let message: String
    public let details: String?
}
```

### 5.2 Database Models (Fluent)

```swift
// Projects table
final class ProjectModel: Model {
    static let schema = "projects"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "path") var path: String
    @Field(key: "default_model") var defaultModel: String?
    @Field(key: "description") var description: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "last_accessed_at", on: .update) var lastAccessedAt: Date?

    @Children(for: \.$project) var sessions: [SessionModel]
}

// Sessions table
final class SessionModel: Model {
    static let schema = "sessions"

    @ID(key: .id) var id: UUID?
    @Field(key: "claude_session_id") var claudeSessionId: String?
    @Field(key: "name") var name: String?
    @Parent(key: "project_id") var project: ProjectModel
    @Field(key: "model") var model: String
    @Enum(key: "permission_mode") var permissionMode: PermissionMode
    @Enum(key: "status") var status: SessionStatus
    @Field(key: "message_count") var messageCount: Int
    @Field(key: "total_cost_usd") var totalCostUSD: Double?
    @Enum(key: "source") var source: SessionSource
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "last_active_at", on: .update) var lastActiveAt: Date?
}
```

---

## 6. API Specification

### 6.1 Base Configuration

- **Base URL**: `http://{host}:8080/api/v1`
- **Content-Type**: `application/json`
- **Authentication**: None (local network)

### 6.2 Endpoints

#### Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/projects` | List all projects |
| POST | `/projects` | Create project |
| GET | `/projects/{id}` | Get project details |
| PUT | `/projects/{id}` | Update project |
| DELETE | `/projects/{id}` | Delete project |
| GET | `/projects/{id}/sessions` | List project sessions |

#### Sessions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/sessions` | List all sessions |
| POST | `/sessions` | Create new session |
| GET | `/sessions/{id}` | Get session details |
| DELETE | `/sessions/{id}` | Delete session |
| GET | `/sessions/scan` | Scan Claude Code storage |
| POST | `/sessions/{id}/fork` | Fork session |

#### Chat (Streaming)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/chat/stream` | Start SSE chat stream |
| GET | `/chat/ws/{sessionId}` | WebSocket connection |
| POST | `/chat/permission/{requestId}` | Respond to permission |
| POST | `/chat/cancel/{sessionId}` | Cancel execution |

#### Skills (Existing + Enhanced)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/skills` | List installed skills |
| POST | `/skills` | Create skill |
| GET | `/skills/{name}` | Get skill details |
| PUT | `/skills/{name}` | Update skill |
| DELETE | `/skills/{name}` | Delete skill |
| GET | `/skills/search` | Search GitHub for skills |
| POST | `/skills/install` | Install from GitHub |

#### MCP Servers (Existing)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/mcp` | List MCP servers |
| POST | `/mcp` | Add MCP server |
| PUT | `/mcp/{name}` | Update MCP server |
| DELETE | `/mcp/{name}` | Delete MCP server |

#### Plugins (Existing + Enhanced)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/plugins` | List installed plugins |
| GET | `/plugins/marketplace` | List marketplaces |
| POST | `/plugins/marketplace` | Add marketplace |
| POST | `/plugins/install` | Install plugin |
| POST | `/plugins/{name}/enable` | Enable plugin |
| POST | `/plugins/{name}/disable` | Disable plugin |
| DELETE | `/plugins/{name}` | Uninstall plugin |

#### Configuration (Existing)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/config` | Get config by scope |
| PUT | `/config` | Update config |
| POST | `/config/validate` | Validate JSON |

#### Stats (Existing)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/stats` | Dashboard statistics |

### 6.3 Request/Response Examples

#### POST /chat/stream
```json
// Request
{
  "prompt": "Explain this codebase",
  "sessionId": "uuid-or-null-for-new",
  "projectId": "project-uuid",
  "options": {
    "model": "sonnet",
    "permissionMode": "acceptEdits",
    "maxTurns": 10
  }
}

// SSE Response Stream
event: system
data: {"subtype":"init","data":{"sessionId":"abc123","plugins":[...]}}

event: assistant
data: {"content":[{"type":"text","text":"I'll analyze..."}]}

event: assistant
data: {"content":[{"type":"toolUse","id":"tu1","name":"Read","input":{"file_path":"README.md"}}]}

event: assistant
data: {"content":[{"type":"toolResult","toolUseId":"tu1","content":"# Project..."}]}

event: result
data: {"sessionId":"abc123","durationMs":5000,"totalCostUSD":0.05,"numTurns":3}
```

#### WebSocket /chat/ws/{sessionId}
```json
// Client → Server
{"type": "message", "prompt": "Continue the refactor"}
{"type": "permission", "requestId": "perm1", "decision": "allow"}
{"type": "cancel"}

// Server → Client
{"type": "stream", "message": {...}}
{"type": "permission", "request": {"toolName": "Bash", "toolInput": {...}}}
{"type": "error", "error": {...}}
{"type": "complete", "result": {...}}
```

---

## 7. Streaming Protocol

### 7.1 SSE Implementation (Vapor)

```swift
// ChatController.swift
func streamChat(req: Request) async throws -> Response {
    let input = try req.content.decode(ChatStreamRequest.self)

    return Response(
        status: .ok,
        headers: [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        ],
        body: .init(asyncSequence: streamSequence(input, req: req))
    )
}

private func streamSequence(
    _ input: ChatStreamRequest,
    req: Request
) -> AsyncThrowingStream<ByteBuffer, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                let executor = req.application.claudeExecutor

                for try await message in executor.execute(
                    prompt: input.prompt,
                    options: input.options.toExecutionOptions()
                ) {
                    let event = formatSSEEvent(message)
                    continuation.yield(ByteBuffer(string: event))
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

private func formatSSEEvent(_ message: StreamMessage) -> String {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(message)
    let json = String(data: data, encoding: .utf8)!

    return "event: \(message.eventType)\ndata: \(json)\n\n"
}
```

### 7.2 WebSocket Implementation (Vapor)

```swift
// ChatController.swift
func webSocket(req: Request, ws: WebSocket) async {
    guard let sessionId = req.parameters.get("sessionId") else {
        try? await ws.close(code: .unacceptableData)
        return
    }

    let connection = WebSocketConnection(ws: ws, sessionId: sessionId)

    // Handle incoming messages
    ws.onText { ws, text in
        guard let message = try? JSONDecoder().decode(ClientMessage.self, from: text.data(using: .utf8)!) else {
            return
        }

        switch message {
        case .message(let prompt):
            await connection.handlePrompt(prompt)
        case .permission(let requestId, let decision):
            await connection.handlePermission(requestId, decision)
        case .cancel:
            await connection.cancel()
        }
    }

    // Stream Claude output
    Task {
        for try await message in connection.outputStream {
            let json = try JSONEncoder().encode(message)
            try await ws.send(String(data: json, encoding: .utf8)!)
        }
    }
}
```

### 7.3 iOS SSE Client

```swift
// SSEClient.swift
class SSEClient: ObservableObject {
    @Published var messages: [StreamMessage] = []
    @Published var isStreaming = false

    private var task: URLSessionDataTask?

    func startStream(url: URL, body: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body

        isStreaming = true

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        isStreaming = false
    }
}

extension SSEClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Parse SSE events
        for line in text.components(separatedBy: "\n\n") {
            if let message = parseSSEEvent(line) {
                DispatchQueue.main.async {
                    self.messages.append(message)
                }
            }
        }
    }

    private func parseSSEEvent(_ text: String) -> StreamMessage? {
        // Parse "event: type\ndata: json"
        // ...
    }
}
```

---

## 8. Error Handling

### 8.1 Error Categories

| Category | HTTP Status | Description |
|----------|-------------|-------------|
| Validation | 400 | Invalid request parameters |
| NotFound | 404 | Resource not found |
| Conflict | 409 | Resource already exists |
| ClaudeError | 502 | Claude Code CLI error |
| Timeout | 504 | Execution timeout |
| Internal | 500 | Server error |

### 8.2 Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "CLAUDE_EXECUTION_ERROR",
    "message": "Claude Code exited with code 1",
    "details": "Error: Model overloaded, please try again"
  }
}
```

### 8.3 Connection Recovery

```swift
// WebSocketClient.swift
class WebSocketClient {
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    func connect() async throws {
        do {
            // Attempt connection
            try await establishConnection()
            reconnectAttempts = 0
        } catch {
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                let delay = pow(2.0, Double(reconnectAttempts))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await connect()
            } else {
                throw ConnectionError.maxRetriesExceeded
            }
        }
    }
}
```

---

## 9. UI/UX Design

### 9.1 Design System

**Theme**: Dark Mode Only with Hot Orange Accent (from original spec)

| Token | Value | Usage |
|-------|-------|-------|
| `background.primary` | #000000 | Main app background |
| `background.secondary` | #0D0D0D | Card backgrounds |
| `background.tertiary` | #1A1A1A | Input fields |
| `accent.primary` | #FF6B35 | Primary actions |
| `text.primary` | #FFFFFF | Primary text |
| `text.secondary` | #A0A0A0 | Secondary text |

### 9.2 Navigation Structure

```
┌─────────────────────────────────────────┐
│  ≡  Sessions                      + New │  ← Header
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 💬 Refactor auth module         │   │  ← Session Row
│  │    my-project • 5 min ago       │   │
│  │    sonnet • 12 messages         │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 💬 Debug API integration        │   │
│  │    api-project • 2 hours ago    │   │
│  │    opus • 45 messages           │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘

Sidebar Menu:
├── 📁 Projects
├── 🔌 Plugins
├── 🔧 MCP Servers
├── ⚡ Skills
└── ⚙️ Settings
```

### 9.3 Chat View Layout

```
┌─────────────────────────────────────────┐
│  ← Back   Session Name          ⋮ Menu │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │ 👤 Explain this codebase        │   │  ← User message
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🤖 I'll analyze the project...  │   │  ← Claude text
│  │                                 │   │
│  │ ┌─────────────────────────────┐ │   │
│  │ │ 🔧 Read README.md        ▼ │ │   │  ← Tool call (collapsible)
│  │ └─────────────────────────────┘ │   │
│  │                                 │   │
│  │ The project is a...             │   │
│  │                                 │   │
│  │ ──────────────────────────────  │   │
│  │ ⏱ 5.2s • $0.05 • 3 turns       │   │  ← Stats
│  └─────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤
│  [/] Message...                    Send │  ← Input + command palette
└─────────────────────────────────────────┘
```

### 9.4 Command Palette

```
┌─────────────────────────────────────────┐
│  🔍 Search commands...                  │
├─────────────────────────────────────────┤
│  Skills                                 │
│  ├── /code-review                       │
│  ├── /test-generator                    │
│  └── /refactor                          │
│                                         │
│  Actions                                │
│  ├── Switch Model → sonnet/opus/haiku   │
│  ├── Change Project →                   │
│  └── Permission Mode →                  │
│                                         │
│  Built-in                               │
│  ├── /compact                           │
│  ├── /clear                             │
│  └── /help                              │
└─────────────────────────────────────────┘
```

---

## 10. Testing Strategy

### 10.1 3D Shift Validation (MANDATORY)

**CRITICAL**: All validation uses real systems, not mocks or unit tests.

#### Backend Validation Protocol

```bash
# 1. Build production binary
swift build -c release

# 2. Start server
.build/release/ILSBackend &
SERVER_PID=$!

# 3. Validate endpoint with REAL Claude Code
curl -X POST http://localhost:8080/api/v1/chat/stream \
  -H "Content-Type: application/json" \
  -d '{"prompt":"List files in current directory","options":{"model":"sonnet"}}' \
  --no-buffer

# Expected: Real streaming JSON from Claude Code
# Evidence: Terminal output showing actual file listing

# 4. Cleanup
kill $SERVER_PID
```

#### iOS Validation Protocol

```
1. Build iOS app: Cmd+B in Xcode
2. Run in Simulator: Cmd+R
3. Navigate to Sessions screen
4. Create new session with real prompt
5. Verify streaming response appears
6. Capture screenshot
7. Correlate with backend logs

Evidence Required:
- Screenshot: iOS Simulator showing chat with real response
- Log: Backend terminal showing API calls and Claude output
- Correlation: Response in screenshot matches backend log
```

### 10.2 Evidence Artifact Format

```
EVIDENCE_{TASK_ID}:
- Type: Terminal Output | Screenshot | Combined
- Timestamp: YYYY-MM-DD HH:MM:SS
- Command/Action: [what was executed]
- Expected: [what should happen]
- Actual: [what actually happened]
- Correlation: [how frontend/backend match]
- Artifacts:
  - terminal_output.txt
  - screenshot.png
  - backend.log
- Status: PASS | FAIL
- Notes: [any observations]
```

### 10.3 Validation Checklist per Feature

| Feature | Backend Validation | iOS Validation |
|---------|-------------------|----------------|
| Chat Stream | curl with --no-buffer | Screenshot of streaming text |
| Session Create | curl POST /sessions | Screenshot of new session |
| Session Resume | curl with sessionId | Screenshot continuing chat |
| Project CRUD | curl all endpoints | Screenshot of project list |
| Skills List | curl /skills | Screenshot of skills view |
| MCP CRUD | curl all endpoints | Screenshot of MCP list |
| Plugins | curl /plugins | Screenshot of plugins view |
| Settings | curl /config | Screenshot of settings editor |

---

## 11. Appendices

### Appendix A: Technology Choices

| Choice | Rationale |
|--------|-----------|
| Vapor 4.x | Mature Swift web framework, async/await, WebSocket support |
| SwiftUI | Native iOS UI, declarative, state management |
| SQLite | Lightweight, embedded, sufficient for local data |
| SSE + WebSocket | SSE for simple streaming, WebSocket for interactive |
| Foundation.Process | Native CLI execution, no dependencies |

### Appendix B: Claude Code CLI Reference

| Flag | Usage in ILS |
|------|--------------|
| `-p` | Non-interactive mode |
| `--output-format stream-json` | Streaming JSON output |
| `--model` | Model selection |
| `--resume` | Session resumption |
| `--session-id` | Specific session |
| `--fork-session` | Fork session |
| `--permission-mode` | Permission handling |
| `--max-turns` | Limit turns |
| `--mcp-config` | MCP servers |
| `--plugin-dir` | Load plugins |

### Appendix C: Research Findings Summary

1. **Claude Code CLI** provides full headless operation via `-p` flag
2. **stream-json** format enables real-time streaming to UI
3. **Session storage** at `~/.claude/projects/` for session scanning
4. **Agent SDK** provides hooks, custom tools, advanced features (optional)
5. **ClaudeCodeSDK** (Swift) can be used as reference for Process execution

### Appendix D: Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| SSH execution | Works remotely | Latency, complexity | Rejected |
| Agent SDK only | More features | Python dependency | Optional sidecar |
| gRPC | Efficient binary | Overkill for this | Rejected |
| GraphQL | Flexible queries | Complexity | Rejected |

---

## 12. Complete Design System Specification

### 12.1 Color Tokens (Dark Mode Only)

The ILS application uses a dark-mode-only design with Hot Orange (#FF6B35) as the primary accent color.

#### Background Colors

| Token | Hex Value | RGB | Usage |
|-------|-----------|-----|-------|
| `backgroundPrimary` | `#000000` | 0, 0, 0 | Main app background, root views |
| `backgroundSecondary` | `#0D0D0D` | 13, 13, 13 | Card backgrounds, elevated surfaces |
| `backgroundTertiary` | `#1A1A1A` | 26, 26, 26 | Input fields, nested containers, hover states |
| `backgroundQuaternary` | `#262626` | 38, 38, 38 | Deeply nested elements, code blocks |

#### Accent Colors

| Token | Hex Value | RGB | Usage |
|-------|-----------|-----|-------|
| `accentPrimary` | `#FF6B35` | 255, 107, 53 | Primary actions, highlights, active states |
| `accentSecondary` | `#FF8C5A` | 255, 140, 90 | Hover states, secondary emphasis |
| `accentTertiary` | `#FF4500` | 255, 69, 0 | Pressed states, deep emphasis |
| `accentMuted` | `#FF6B35` (30% opacity) | - | Subtle backgrounds, selection highlights |

#### Text Colors

| Token | Hex Value | RGB | Usage |
|-------|-----------|-----|-------|
| `textPrimary` | `#FFFFFF` | 255, 255, 255 | Headings, primary content, important text |
| `textSecondary` | `#A0A0A0` | 160, 160, 160 | Body text, descriptions, secondary labels |
| `textTertiary` | `#666666` | 102, 102, 102 | Placeholder text, disabled states, hints |
| `textInverse` | `#000000` | 0, 0, 0 | Text on light/accent backgrounds |

#### Semantic Colors

| Token | Hex Value | RGB | Usage |
|-------|-----------|-----|-------|
| `success` | `#4CAF50` | 76, 175, 80 | Success states, healthy status, confirmations |
| `warning` | `#FFA726` | 255, 167, 38 | Warning states, caution, pending actions |
| `error` | `#EF5350` | 239, 83, 80 | Error states, destructive actions, failures |
| `info` | `#42A5F5` | 66, 165, 245 | Informational states, tips, neutral status |

#### Border Colors

| Token | Hex Value | RGB | Usage |
|-------|-----------|-----|-------|
| `borderDefault` | `#2A2A2A` | 42, 42, 42 | Card borders, dividers, separators |
| `borderActive` | `#FF6B35` | 255, 107, 53 | Active/focused input borders, selection |
| `borderSubtle` | `#1F1F1F` | 31, 31, 31 | Subtle dividers, section separators |

### 12.2 Typography Scale

All typography uses the SF Pro font family, which is the system font on iOS.

| Token | Font | Weight | Size | Line Height | Tracking | Usage |
|-------|------|--------|------|-------------|----------|-------|
| `largeTitle` | SF Pro Display | Bold | 34pt | 41pt | 0.37 | Screen titles, hero text |
| `title1` | SF Pro Display | Bold | 28pt | 34pt | 0.36 | Section headers, prominent labels |
| `title2` | SF Pro Display | Bold | 22pt | 28pt | 0.35 | Sub-section headers |
| `title3` | SF Pro Display | Semibold | 20pt | 25pt | 0.38 | Card titles, group headers |
| `headline` | SF Pro Text | Semibold | 17pt | 22pt | -0.41 | List item titles, emphasized body |
| `body` | SF Pro Text | Regular | 17pt | 22pt | -0.41 | Primary body text, descriptions |
| `callout` | SF Pro Text | Regular | 16pt | 21pt | -0.32 | Secondary body text, captions |
| `subheadline` | SF Pro Text | Regular | 15pt | 20pt | -0.24 | Tertiary text, metadata |
| `footnote` | SF Pro Text | Regular | 13pt | 18pt | -0.08 | Fine print, legal text |
| `caption` | SF Pro Text | Regular | 12pt | 16pt | 0 | Timestamps, labels, badges |
| `caption2` | SF Pro Text | Regular | 11pt | 13pt | 0.07 | Micro labels, indicators |
| `code` | SF Mono | Regular | 14pt | 18pt | 0 | Code blocks, technical content |
| `codeSmall` | SF Mono | Regular | 12pt | 16pt | 0 | Inline code, file paths |

#### Swift Implementation

```swift
enum ILSTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title1 = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .bold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
}
```

### 12.3 Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4pt | Tight spacing, inline elements |
| `sm` | 8pt | Small gaps, related elements |
| `md` | 16pt | Standard spacing, card padding |
| `lg` | 24pt | Section spacing, major gaps |
| `xl` | 32pt | Page margins, large separations |
| `xxl` | 48pt | Hero spacing, major sections |

#### Swift Implementation

```swift
enum ILSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### 12.4 Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `small` | 8pt | Buttons, inputs, chips, badges |
| `medium` | 12pt | Cards, modals, sheets |
| `large` | 16pt | Large modals, full-screen overlays |
| `pill` | 9999pt | Pill-shaped buttons, tags |

#### Swift Implementation

```swift
enum ILSCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let pill: CGFloat = 9999
}
```

### 12.5 Shadow Definitions

| Token | X | Y | Blur | Spread | Color | Usage |
|-------|---|---|------|--------|-------|-------|
| `shadowSm` | 0 | 1pt | 2pt | 0 | #000000 (25%) | Subtle elevation, buttons |
| `shadowMd` | 0 | 4pt | 6pt | -1pt | #000000 (30%) | Cards, dropdowns |
| `shadowLg` | 0 | 10pt | 15pt | -3pt | #000000 (35%) | Modals, popovers |
| `shadowXl` | 0 | 20pt | 25pt | -5pt | #000000 (40%) | Full-screen sheets |

#### SwiftUI Implementation

```swift
extension View {
    func ilsShadowSm() -> some View {
        self.shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
    }

    func ilsShadowMd() -> some View {
        self.shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 4)
    }

    func ilsShadowLg() -> some View {
        self.shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 10)
    }

    func ilsShadowXl() -> some View {
        self.shadow(color: Color.black.opacity(0.40), radius: 25, x: 0, y: 20)
    }
}
```

### 12.6 Animation Timing

| Token | Duration | Easing | Usage |
|-------|----------|--------|-------|
| `instant` | 0ms | - | Immediate feedback |
| `fast` | 150ms | easeOut | Micro-interactions, hover |
| `normal` | 250ms | easeInOut | Standard transitions |
| `slow` | 350ms | easeInOut | Large transitions, modals |
| `spring` | - | spring(response: 0.3, dampingFraction: 0.7) | Bouncy interactions |

#### SwiftUI Implementation

```swift
extension Animation {
    static let ilsFast = Animation.easeOut(duration: 0.15)
    static let ilsNormal = Animation.easeInOut(duration: 0.25)
    static let ilsSlow = Animation.easeInOut(duration: 0.35)
    static let ilsSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
```

---

## 13. Complete UI Screen Specifications

### 13.1 Server Connection Screen

**Purpose**: Entry point for connecting to a host machine running Claude Code.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `header_icon` | Image | SF Symbol: "desktopcomputer", size: 48pt, color: accentPrimary |
| `header_title` | Text | "Connect to Server", font: title1, color: textPrimary |
| `header_subtitle` | Text | "Connect to a remote host running Claude Code", font: subheadline, color: textSecondary |
| `host_field` | TextField | Label: "Host", placeholder: "192.168.1.100 or hostname", icon: "network" |
| `port_field` | TextField | Label: "Port", placeholder: "22", icon: "number", keyboard: numberPad |
| `username_field` | TextField | Label: "Username", placeholder: "admin", icon: "person.fill" |
| `auth_picker` | SegmentedControl | Options: ["Password", "SSH Key"], default: "SSH Key" |
| `password_field` | SecureField | Label: "Password", placeholder: "Enter password", icon: "lock.fill", conditional |
| `key_picker` | Button | Label: "SSH Key", placeholder: "Select Key File...", icon: "key.fill", conditional |
| `connect_button` | Button | Label: "Connect", style: primary, icon: "arrow.right.circle.fill" |
| `local_dev_button` | Button | Label: "Connect Locally", style: secondary, description: "Use localhost:8080" |
| `recent_connections` | List | Section: "Recent Connections", rows: RecentConnectionRow |

#### Layout Specification

```
┌─────────────────────────────────────┐
│ NavigationStack                      │
│ ├── ScrollView                       │
│ │   ├── VStack(spacing: lg)          │
│ │   │   ├── HeaderCard               │
│ │   │   │   ├── header_icon          │
│ │   │   │   ├── header_title         │
│ │   │   │   └── header_subtitle      │
│ │   │   │                            │
│ │   │   ├── ConnectionFormCard       │
│ │   │   │   ├── host_field           │
│ │   │   │   ├── port_field           │
│ │   │   │   ├── username_field       │
│ │   │   │   ├── auth_picker          │
│ │   │   │   ├── password_field (if)  │
│ │   │   │   ├── key_picker (if)      │
│ │   │   │   └── connect_button       │
│ │   │   │                            │
│ │   │   ├── RecentConnectionsCard    │
│ │   │   │   └── ForEach(connections) │
│ │   │   │                            │
│ │   │   └── LocalDevCard             │
│ │   │       └── local_dev_button     │
│ │   └── Spacer(minLength: xl)        │
│ └── .navigationTitle("ILS")          │
└─────────────────────────────────────┘
```

#### State Management

```swift
struct ServerConnectionViewState {
    var host: String = ""
    var port: String = "22"
    var username: String = ""
    var authMethod: AuthMethod = .sshKey
    var password: String = ""
    var selectedKeyPath: String = ""
    var isConnecting: Bool = false
    var errorMessage: String?
    var recentConnections: [ServerConnection] = []
}
```

#### Validation Rules

| Field | Rule | Error Message |
|-------|------|---------------|
| host | Non-empty, valid hostname/IP | "Please enter a valid host" |
| port | 1-65535, numeric | "Port must be between 1 and 65535" |
| username | Non-empty | "Username is required" |
| password | Non-empty when authMethod == .password | "Password is required" |
| selectedKeyPath | Non-empty when authMethod == .sshKey | "Please select an SSH key" |

---

### 13.2 Dashboard Screen

**Purpose**: Main hub displaying system status and quick actions after connection.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `stats_row` | HStack | Contains 3 StatCards |
| `skills_stat` | StatCard | value: skillCount, label: "Skills", icon: "doc.text.fill", color: accentPrimary |
| `mcp_stat` | StatCard | value: mcpServerCount, label: "MCPs", icon: "server.rack", color: success |
| `plugins_stat` | StatCard | value: pluginCount, label: "Plugins", icon: "shippingbox.fill", color: warning |
| `quick_actions` | Section | Title: "Quick Actions", contains QuickActionRows |
| `discover_skills` | QuickActionRow | icon: "magnifyingglass", title: "Discover New Skills" |
| `browse_plugins` | QuickActionRow | icon: "shippingbox", title: "Browse Plugin Marketplace" |
| `configure_mcp` | QuickActionRow | icon: "server.rack", title: "Configure MCP Servers" |
| `edit_settings` | QuickActionRow | icon: "gearshape.fill", title: "Edit Claude Settings" |
| `recent_activity` | Section | Title: "Recent Activity", contains ActivityRows |
| `sessions_section` | Section | Title: "Active Sessions", link to SessionListView |
| `connection_status` | ToolbarItem | Trailing, shows connection name + status dot |

#### Layout Specification

```
┌─────────────────────────────────────┐
│ NavigationStack                      │
│ ├── .toolbar                         │
│ │   └── connection_status            │
│ ├── ScrollView                       │
│ │   ├── VStack(spacing: lg)          │
│ │   │   ├── stats_row                │
│ │   │   │   ├── skills_stat          │
│ │   │   │   ├── mcp_stat             │
│ │   │   │   └── plugins_stat         │
│ │   │   │                            │
│ │   │   ├── QuickActionsCard         │
│ │   │   │   ├── discover_skills      │
│ │   │   │   ├── browse_plugins       │
│ │   │   │   ├── configure_mcp        │
│ │   │   │   └── edit_settings        │
│ │   │   │                            │
│ │   │   ├── RecentActivityCard       │
│ │   │   │   └── ForEach(activities)  │
│ │   │   │                            │
│ │   │   └── SessionsCard             │
│ │   │       └── sessions_section     │
│ │   └── Spacer(minLength: xl)        │
│ └── .navigationTitle("Dashboard")    │
└─────────────────────────────────────┘
```

#### Data Requirements

```swift
struct DashboardStats: Codable {
    let skillCount: Int
    let mcpServerCount: Int
    let pluginCount: Int
    let activeSessionCount: Int
}

struct ActivityItem: Identifiable {
    let id: UUID
    let icon: String
    let iconColor: Color
    let title: String
    let timestamp: Date
}
```

---

### 13.3 Skills List Screen

**Purpose**: Display installed skills and search for new skills from GitHub.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `installed_section` | Section | Title: "Installed Skills" |
| `skill_row` | SkillRow | icon, name, description, version, status badge |
| `search_field` | TextField | placeholder: "Search Skill Repos...", icon: "magnifyingglass" |
| `discovered_section` | Section | Title: "Discovered from GitHub", conditional |
| `discovered_row` | DiscoveredSkillRow | stars, name, description, install button |
| `add_button` | ToolbarItem | Trailing, SF Symbol: "plus", action: add skill |

#### Skill Row Component

```
┌───────────────────────────────────────────────────┐
│ ┌────┐                                            │
│ │ 📝 │  skill-name                               │
│ └────┘  Description text goes here...             │
│         v1.2.0 │ 🟢 Active                        │
│                                        chevron.right │
└───────────────────────────────────────────────────┘
```

#### Discovered Skill Row Component

```
┌───────────────────────────────────────────────────┐
│ ⭐ 234 │ skill-name                               │
│ Description from GitHub...                        │
│                                    [ Install ]    │
└───────────────────────────────────────────────────┘
```

---

### 13.4 Skill Detail Screen

**Purpose**: Display full skill information with edit and delete actions.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `header` | VStack | icon (48pt), name, version, source info, status |
| `description_section` | Section | Title: "Description", content: skill.description |
| `skillmd_section` | Section | Title: "SKILL.md Preview", content: code block |
| `location_section` | Section | Title: "Location", content: skill.path |
| `uninstall_button` | Button | style: destructive, icon: "trash", label: "Uninstall" |
| `edit_button` | Button | style: secondary, icon: "pencil", label: "Edit SKILL.md" |

#### Layout Specification

```
┌─────────────────────────────────────┐
│ ScrollView                           │
│ ├── VStack(spacing: lg)              │
│ │   ├── HeaderCard                   │
│ │   │   ├── skill_icon (48pt)        │
│ │   │   ├── skill_name               │
│ │   │   ├── version                  │
│ │   │   ├── source_info              │
│ │   │   └── status_badge             │
│ │   │                                │
│ │   ├── DescriptionCard              │
│ │   │   └── description_text         │
│ │   │                                │
│ │   ├── SkillMdPreviewCard           │
│ │   │   └── code_block               │
│ │   │                                │
│ │   ├── LocationCard                 │
│ │   │   └── path_text (monospace)    │
│ │   │                                │
│ │   └── ActionsStack                 │
│ │       ├── uninstall_button         │
│ │       └── edit_button              │
│ └── Spacer(minLength: xl)            │
└─────────────────────────────────────┘
```

---

### 13.5 MCP Servers Screen

**Purpose**: Manage MCP server configurations across scopes.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `scope_picker` | SegmentedControl | Options: ["User", "Project", "Local"] |
| `servers_section` | Section | Title: "Active Servers" |
| `server_row` | MCPServerRow | status dot, name, command, env, action buttons |
| `add_section` | Section | Title: "Add New Server" |
| `add_button` | Button | icon: "plus.circle.fill", label: "Add Custom MCP Server" |
| `add_sheet` | Sheet | AddMCPServerView |

#### MCP Server Row Component

```
┌───────────────────────────────────────────────────┐
│ 🟢 server-name                                    │
│ npx -y @mcp/server-package                        │
│ Env: API_KEY, TOKEN                               │
│ [Disable] [Edit] [Delete]                         │
└───────────────────────────────────────────────────┘
```

#### Status Indicators

| Status | Color | Icon |
|--------|-------|------|
| healthy | success (#4CAF50) | Circle filled |
| error | error (#EF5350) | Circle filled |
| disabled | textTertiary (#666666) | Circle filled |
| unknown | warning (#FFA726) | Circle filled |

---

### 13.6 Plugin Marketplace Screen

**Purpose**: Browse, install, and manage plugins.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `search_field` | TextField | placeholder: "Search plugins...", icon: "magnifyingglass" |
| `category_chips` | ScrollView(horizontal) | CategoryChip buttons |
| `marketplace_section` | Section | Title: "Official Marketplace" |
| `plugin_row` | PluginRow | icon, name, description, stars, official badge, install button |
| `custom_section` | Section | Title: "Custom Marketplaces" |
| `add_marketplace` | Button | icon: "plus.circle.fill", label: "Add from GitHub repo" |

#### Plugin Row Component

```
┌───────────────────────────────────────────────────┐
│ ┌────┐                                            │
│ │ 📦 │  plugin-name                              │
│ └────┘  Description of the plugin...              │
│         ⭐ 2.1k │ Official              [Install] │
└───────────────────────────────────────────────────┘
```

#### Category Chips

| Category | Filter |
|----------|--------|
| All | No filter |
| Productivity | category == "productivity" |
| DevOps | category == "devops" |
| Testing | category == "testing" |
| Documentation | category == "documentation" |

---

### 13.7 Chat Screen

**Purpose**: Primary interface for conducting AI-powered coding sessions.

#### Screen Elements

| Element ID | Type | Properties |
|------------|------|------------|
| `session_header` | SessionHeaderView | project name, path, tap to switch |
| `messages_list` | LazyVStack | ChatMessage bubbles |
| `streaming_indicator` | StreamingIndicator | Animated dots during streaming |
| `input_bar` | ChatInputBar | text field, slash command suggestions, send button |
| `slash_suggestions` | HStack | Horizontal chips when "/" typed |
| `new_session_button` | ToolbarItem | icon: "plus.message" |
| `session_picker_sheet` | Sheet | SessionPickerView |
| `new_session_sheet` | Sheet | NewSessionView |

#### Message Bubble Component

**User Message:**
```
┌───────────────────────────────────────────────────┐
│                                                   │
│                      ┌───────────────────────────┐│
│                      │ User message content      ││
│                      │ with orange background    ││
│                      └───────────────────────────┘│
│                                          12:34 PM │
└───────────────────────────────────────────────────┘
```

**Assistant Message:**
```
┌───────────────────────────────────────────────────┐
│┌───────────────────────────────────────────┐      │
││ Claude's response text                    │      │
││                                           │      │
││ ┌───────────────────────────────────────┐ │      │
││ │ 🔧 Read file.txt                   ▼ │ │      │
││ └───────────────────────────────────────┘ │      │
││                                           │      │
││ More response text continues here...      │      │
│└───────────────────────────────────────────┘      │
│ 12:35 PM                                          │
└───────────────────────────────────────────────────┘
```

**Tool Use Component:**
```
┌───────────────────────────────────────────────────┐
│ 🔧 tool-name                              Running │
│ ───────────────────────────────────────────────── │
│ Input: {"path": "/Users/nick/project"}            │
│ ───────────────────────────────────────────────── │
│ Output: File contents here...                     │
└───────────────────────────────────────────────────┘
```

#### Input Bar Component

```
┌───────────────────────────────────────────────────┐
│ Slash Command Suggestions (when "/" typed)        │
│ [/help] [/skills] [/mcp] [/config] [/clear]       │
├───────────────────────────────────────────────────┤
│ [Message Claude...]                          (⬆)  │
└───────────────────────────────────────────────────┘
```

---

## 14. Complete Data Model Definitions

### 14.1 Core Models

#### Session Model

```swift
/// Represents a chat session with Claude Code
struct Session: Identifiable, Codable {
    /// Unique identifier for the session
    let id: UUID

    /// Associated project (optional for quick sessions)
    var project: Project?

    /// Session creation timestamp
    let createdAt: Date

    /// Last activity timestamp
    var updatedAt: Date

    /// All messages in this session
    var messages: [ChatMessage]

    /// Session metadata
    var metadata: SessionMetadata

    /// Whether this session is currently active
    var isActive: Bool

    /// Claude Code session ID (for resume)
    var claudeSessionId: String?
}

struct SessionMetadata: Codable {
    /// Model used for this session
    var model: String

    /// Total tokens used
    var totalTokens: Int

    /// Total cost incurred
    var totalCost: Decimal

    /// Number of turns (user + assistant pairs)
    var turnCount: Int

    /// Total duration in seconds
    var durationSeconds: Int

    /// Permission mode
    var permissionMode: PermissionMode
}

enum PermissionMode: String, Codable {
    case bypass = "bypass"
    case plan = "plan"
    case interactive = "interactive"
    case acceptEdits = "acceptEdits"
}
```

#### Project Model

```swift
/// Represents a project directory
struct Project: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// Display name (usually directory name)
    var name: String

    /// Full filesystem path
    var path: String

    /// Project-specific settings
    var settings: ProjectSettings?

    /// Last accessed timestamp
    var lastAccessed: Date

    /// Whether this project is pinned
    var isPinned: Bool
}

struct ProjectSettings: Codable {
    /// Default model for this project
    var defaultModel: String?

    /// Default permission mode
    var defaultPermissionMode: PermissionMode?

    /// Custom environment variables
    var environment: [String: String]?
}
```

#### ChatMessage Model

```swift
/// Represents a single message in a chat session
struct ChatMessage: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// Message role
    let role: MessageRole

    /// Text content
    var content: String

    /// Timestamp
    let timestamp: Date

    /// Tool use information (if applicable)
    var toolUse: ToolUse?

    /// Thinking content (if extended thinking enabled)
    var thinking: String?

    /// Cost for this message
    var cost: Decimal?

    /// Token count
    var tokens: Int?
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ToolUse: Codable {
    /// Tool name
    let name: String

    /// Tool input (JSON string)
    let input: String

    /// Tool output
    var output: String?

    /// Execution status
    var status: ToolStatus

    /// Execution duration in milliseconds
    var durationMs: Int?
}

enum ToolStatus: String, Codable {
    case pending
    case running
    case completed
    case error
}
```

#### Skill Model

```swift
/// Represents a Claude Code skill
struct Skill: Identifiable, Codable {
    /// Unique identifier
    var id: UUID { UUID(uuidString: name) ?? UUID() }

    /// Skill name (from YAML frontmatter)
    let name: String

    /// Skill description (from YAML frontmatter)
    let description: String

    /// Version (from YAML frontmatter, optional)
    let version: String?

    /// Whether the skill is currently active
    var isActive: Bool

    /// Filesystem path to the skill
    let path: String

    /// Raw SKILL.md content
    let rawContent: String

    /// Source of the skill
    let source: SkillSource
}

enum SkillSource: Codable {
    case local
    case github(repository: String, stars: Int)
    case plugin(pluginName: String)
}
```

#### MCPServer Model

```swift
/// Represents an MCP server configuration
struct MCPServer: Identifiable, Codable {
    /// Unique identifier
    var id: UUID { UUID(uuidString: name) ?? UUID() }

    /// Server name (key in mcpServers object)
    let name: String

    /// Command to execute
    let command: String

    /// Command arguments
    let args: [String]

    /// Environment variables
    let env: [String: String]

    /// Configuration scope
    let scope: ConfigScope

    /// Current status
    var status: MCPStatus

    enum ConfigScope: String, Codable {
        case user
        case project
        case local
    }
}

enum MCPStatus: String, Codable {
    case healthy
    case error
    case disabled
    case unknown
}
```

#### Plugin Model

```swift
/// Represents a Claude Code plugin
struct Plugin: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// Plugin name
    let name: String

    /// Plugin description
    let description: String

    /// Star count (for marketplace plugins)
    let stars: Int

    /// Whether this is an official plugin
    let isOfficial: Bool

    /// Installation status
    var isInstalled: Bool

    /// Category
    let category: String?

    /// Marketplace source
    let marketplace: String?

    /// Plugin capabilities
    let capabilities: PluginCapabilities?
}

struct PluginCapabilities: Codable {
    let commands: [String]?
    let agents: [String]?
    let skills: [String]?
    let mcpServers: [String]?
}
```

#### ClaudeConfig Model

```swift
/// Represents Claude Code configuration (settings.json)
struct ClaudeConfig: Codable {
    /// Permission settings
    var permissions: PermissionConfig?

    /// Environment variables
    var env: [String: String]?

    /// Default model override
    var model: String?

    /// Hook configurations
    var hooks: HooksConfig?

    /// Enabled plugins
    var enabledPlugins: [String: Bool]?

    /// Extra known marketplaces
    var extraKnownMarketplaces: [MarketplaceConfig]?
}

struct PermissionConfig: Codable {
    var allow: [String]?
    var deny: [String]?
}

struct HooksConfig: Codable {
    var preToolUse: [HookDefinition]?
    var postToolUse: [HookDefinition]?
}

struct HookDefinition: Codable {
    let command: String
    let timeout: Int?
}

struct MarketplaceConfig: Codable {
    let name: String
    let source: String
    let type: String
}
```

### 14.2 Streaming Models

```swift
/// Represents a streaming event from Claude Code
struct StreamMessage: Codable {
    /// Event type
    let type: StreamEventType

    /// Text content (for text events)
    var text: TextData?

    /// Thinking content (for thinking events)
    var thinking: ThinkingData?

    /// Tool use data (for tool_use events)
    var toolUse: ToolUseData?

    /// Tool result data (for tool_result events)
    var toolResult: ToolResultData?

    /// Error data (for error events)
    var error: ErrorData?
}

enum StreamEventType: String, Codable {
    case text
    case thinking
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case error
    case done
}

struct TextData: Codable {
    let content: String
}

struct ThinkingData: Codable {
    let content: String
}

struct ToolUseData: Codable {
    let toolUseId: String
    let name: String
    let input: String
}

struct ToolResultData: Codable {
    let toolUseId: String
    let output: String
    let isError: Bool
}

struct ErrorData: Codable {
    let code: String
    let message: String
}
```

### 14.3 API Response Models

```swift
/// Generic API response wrapper
struct APIResponse<T: Codable>: Codable {
    /// Whether the request succeeded
    let success: Bool

    /// Response data (on success)
    let data: T?

    /// Error message (on failure)
    let error: String?

    /// Error code (on failure)
    let errorCode: String?
}

/// Dashboard statistics
struct DashboardStats: Codable {
    let skillCount: Int
    let mcpServerCount: Int
    let pluginCount: Int
    let activeSessionCount: Int
    let recentActivity: [ActivityItem]?
}

/// GitHub search result for skills
struct GitHubSearchResult: Codable {
    let repository: String
    let name: String
    let description: String?
    let stars: Int
    let lastUpdated: Date
    let htmlUrl: String
}

/// Server connection details
struct ServerConnection: Identifiable, Codable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var lastConnected: Date?
    var status: ConnectionStatus

    enum AuthMethod: Codable {
        case password
        case sshKey(path: String)
    }

    enum ConnectionStatus: String, Codable {
        case connected
        case disconnected
        case error
    }
}
```

---

## 15. Complete API Endpoint Specification

### 15.1 Base Configuration

```
Base URL: http://localhost:8080/api/v1
Content-Type: application/json
Accept: application/json (for REST) or text/event-stream (for SSE)
```

### 15.2 Health & Stats Endpoints

#### GET /health

Returns server health status.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 3600,
  "claudeCodeVersion": "1.0.113"
}
```

#### GET /stats

Returns dashboard statistics.

**Response:**
```json
{
  "success": true,
  "data": {
    "skillCount": 12,
    "mcpServerCount": 8,
    "pluginCount": 3,
    "activeSessionCount": 2,
    "recentActivity": [
      {
        "id": "uuid",
        "icon": "checkmark.circle.fill",
        "iconColor": "#4CAF50",
        "title": "Installed code-review",
        "timestamp": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

### 15.3 Session Endpoints

#### GET /sessions

List all sessions.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| projectId | UUID | No | Filter by project |
| limit | Int | No | Max results (default: 50) |
| offset | Int | No | Pagination offset |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "project": {
        "id": "uuid",
        "name": "my-project",
        "path": "~/projects/my-project"
      },
      "createdAt": "2026-02-01T10:00:00Z",
      "updatedAt": "2026-02-01T12:00:00Z",
      "messageCount": 24,
      "metadata": {
        "model": "claude-sonnet-4",
        "totalTokens": 15000,
        "totalCost": "0.15",
        "turnCount": 12,
        "durationSeconds": 300
      }
    }
  ]
}
```

#### POST /sessions

Create a new session.

**Request:**
```json
{
  "projectPath": "~/projects/my-project",
  "model": "claude-sonnet-4",
  "permissionMode": "interactive"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "project": {
      "id": "uuid",
      "name": "my-project",
      "path": "~/projects/my-project"
    },
    "createdAt": "2026-02-01T12:00:00Z",
    "updatedAt": "2026-02-01T12:00:00Z",
    "messageCount": 0
  }
}
```

#### GET /sessions/:id

Get session details with messages.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "project": {...},
    "createdAt": "...",
    "updatedAt": "...",
    "messages": [
      {
        "id": "uuid",
        "role": "user",
        "content": "Explain this codebase",
        "timestamp": "2026-02-01T12:00:00Z"
      },
      {
        "id": "uuid",
        "role": "assistant",
        "content": "This project is...",
        "timestamp": "2026-02-01T12:00:05Z",
        "toolUse": {
          "name": "Read",
          "input": "{\"file_path\": \"README.md\"}",
          "output": "# Project\n...",
          "status": "completed"
        },
        "cost": "0.01",
        "tokens": 500
      }
    ],
    "metadata": {...}
  }
}
```

#### POST /sessions/:id/chat (SSE)

Send a message and receive streaming response.

**Request:**
```json
{
  "content": "Explain this function"
}
```

**Response (SSE):**
```
event: text
data: {"content": "This function "}

event: text
data: {"content": "handles authentication "}

event: tool_use
data: {"toolUseId": "123", "name": "Read", "input": "{\"file_path\": \"auth.ts\"}"}

event: tool_result
data: {"toolUseId": "123", "output": "export function auth...", "isError": false}

event: text
data: {"content": "by validating the JWT token..."}

event: done
data: {}
```

#### DELETE /sessions/:id

Delete a session.

**Response:**
```json
{
  "success": true,
  "data": true
}
```

### 15.4 Skills Endpoints

#### GET /skills

List installed skills.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "code-review",
      "description": "Automated PR code review",
      "version": "1.2.0",
      "isActive": true,
      "path": "~/.claude/skills/code-review",
      "source": {
        "type": "github",
        "repository": "anthropics/claude-skills",
        "stars": 1234
      }
    }
  ]
}
```

#### GET /skills/search

Search GitHub for skills.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| q | String | Yes | Search query |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "repository": "user/repo",
      "name": "my-skill",
      "description": "A useful skill",
      "stars": 234,
      "lastUpdated": "2026-01-15T00:00:00Z",
      "htmlUrl": "https://github.com/user/repo"
    }
  ]
}
```

#### POST /skills/install

Install a skill from GitHub.

**Request:**
```json
{
  "url": "https://github.com/user/repo"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "name": "my-skill",
    "description": "...",
    "version": "1.0.0",
    "isActive": true,
    "path": "~/.claude/skills/my-skill"
  }
}
```

#### DELETE /skills/:id

Uninstall a skill.

**Response:**
```json
{
  "success": true,
  "data": true
}
```

### 15.5 MCP Server Endpoints

#### GET /mcp

List MCP servers.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| scope | String | No | Filter by scope (user, project, local) |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "github",
      "command": "npx",
      "args": ["-y", "@mcp/server-github"],
      "env": {"GITHUB_TOKEN": "***"},
      "scope": "user",
      "status": "healthy"
    }
  ]
}
```

#### POST /mcp

Add an MCP server.

**Request:**
```json
{
  "name": "postgres",
  "command": "npx",
  "args": ["-y", "@mcp/server-postgres"],
  "env": {"DATABASE_URL": "postgres://localhost/db"},
  "scope": "project"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "name": "postgres",
    "command": "npx",
    "args": [...],
    "env": {...},
    "scope": "project",
    "status": "unknown"
  }
}
```

#### PUT /mcp/:id

Update an MCP server.

**Request:**
```json
{
  "env": {"DATABASE_URL": "postgres://localhost/newdb"}
}
```

**Response:**
```json
{
  "success": true,
  "data": {...}
}
```

#### DELETE /mcp/:id

Delete an MCP server.

**Response:**
```json
{
  "success": true,
  "data": true
}
```

### 15.6 Plugin Endpoints

#### GET /plugins/marketplace

List available plugins from marketplaces.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "github",
      "description": "GitHub integration plugin",
      "stars": 2100,
      "isOfficial": true,
      "isInstalled": true,
      "category": "productivity",
      "marketplace": "claude-plugins-official"
    }
  ]
}
```

#### GET /plugins/installed

List installed plugins.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "github",
      "description": "...",
      "isInstalled": true,
      "capabilities": {
        "commands": ["pr", "issue"],
        "agents": ["github-reviewer"],
        "skills": ["github-pr-review"]
      }
    }
  ]
}
```

#### POST /plugins/install

Install a plugin.

**Request:**
```json
{
  "id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {...}
}
```

#### DELETE /plugins/:id

Uninstall a plugin.

**Response:**
```json
{
  "success": true,
  "data": true
}
```

### 15.7 Config Endpoints

#### GET /config

Get Claude Code configuration.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| scope | String | No | Config scope (user, project, local) |

**Response:**
```json
{
  "success": true,
  "data": {
    "scope": "user",
    "path": "~/.claude/settings.json",
    "content": {
      "model": "claude-sonnet-4",
      "permissions": {
        "allow": ["Bash(npm run *)"],
        "deny": ["Read(.env)"]
      }
    },
    "isValid": true
  }
}
```

#### PUT /config

Update configuration.

**Request:**
```json
{
  "scope": "user",
  "content": {
    "model": "claude-opus-4",
    "permissions": {...}
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {...}
}
```

#### POST /config/validate

Validate configuration JSON.

**Request:**
```json
{
  "content": {...}
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "isValid": true,
    "errors": []
  }
}
```

---

## 16. Error Handling Specification

### 16.1 Error Response Format

```json
{
  "success": false,
  "error": "Human-readable error message",
  "errorCode": "MACHINE_READABLE_CODE",
  "details": {
    "field": "Additional context if available"
  }
}
```

### 16.2 Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_REQUEST` | 400 | Malformed request body or parameters |
| `MISSING_FIELD` | 400 | Required field missing |
| `VALIDATION_ERROR` | 400 | Field validation failed |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Permission denied |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource already exists |
| `CLAUDE_ERROR` | 500 | Claude Code CLI error |
| `INTERNAL_ERROR` | 500 | Unexpected server error |
| `SERVICE_UNAVAILABLE` | 503 | Claude Code not available |

### 16.3 Streaming Error Handling

```
event: error
data: {"code": "CLAUDE_ERROR", "message": "Process terminated unexpectedly"}
```

---

## 17. Integration Patterns

### 17.1 Claude Code CLI Integration

```swift
class ClaudeExecutorService {
    private let claudePath: URL
    private var activeProcess: Process?

    func execute(
        projectPath: String,
        message: String,
        sessionId: UUID?,
        model: String = "claude-sonnet-4",
        permissionMode: PermissionMode = .interactive
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let process = Process()
                process.executableURL = claudePath
                process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

                var arguments = [
                    "-p", message,
                    "--output-format", "stream-json",
                    "--model", model,
                    "--permission-mode", permissionMode.rawValue
                ]

                if let sessionId = sessionId {
                    arguments += ["--session-id", sessionId.uuidString]
                }

                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                // Handle stdout line by line
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    if let line = String(data: data, encoding: .utf8) {
                        for json in line.split(separator: "\n") {
                            if let event = self.parseStreamEvent(String(json)) {
                                continuation.yield(event)
                            }
                        }
                    }
                }

                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: ClaudeError.processExitCode(Int(process.terminationStatus)))
                    }
                }

                do {
                    try process.run()
                    self.activeProcess = process
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func cancel() {
        activeProcess?.terminate()
    }
}
```

### 17.2 GitHub API Integration

```swift
class GitHubService {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!

    func searchSkills(query: String) async throws -> [GitHubSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search/code"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "SKILL.md filename:SKILL.md \(query)")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)

        return response.items.map { item in
            GitHubSearchResult(
                repository: item.repository.fullName,
                name: item.name.replacingOccurrences(of: ".md", with: ""),
                description: item.repository.description,
                stars: item.repository.stargazersCount,
                lastUpdated: item.repository.updatedAt,
                htmlUrl: item.repository.htmlUrl
            )
        }
    }

    func fetchSkillContent(repository: String, path: String) async throws -> String {
        let url = baseURL.appendingPathComponent("repos/\(repository)/contents/\(path)")

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

### 17.3 SKILL.md Parser

```swift
struct SkillParser {
    struct ParsedSkill {
        let name: String
        let description: String
        let version: String?
        let content: String
    }

    static func parse(_ rawContent: String) throws -> ParsedSkill {
        // Split YAML frontmatter from content
        guard rawContent.hasPrefix("---") else {
            throw ParserError.missingFrontmatter
        }

        let parts = rawContent.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else {
            throw ParserError.invalidFormat
        }

        let yamlContent = String(parts[1])
        let markdownContent = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse YAML frontmatter
        var name: String?
        var description: String?
        var version: String?

        for line in yamlContent.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("version:") {
                version = trimmed.replacingOccurrences(of: "version:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        guard let skillName = name, let skillDescription = description else {
            throw ParserError.missingRequiredFields
        }

        return ParsedSkill(
            name: skillName,
            description: skillDescription,
            version: version,
            content: markdownContent
        )
    }
}
```

---

## 18. File Path References

### 18.1 Claude Code File Locations

| Purpose | macOS Path | Description |
|---------|------------|-------------|
| User Settings | `~/.claude/settings.json` | Global user settings |
| User MCP Config | `~/.claude.json` | User-scoped MCP servers |
| User Skills | `~/.claude/skills/` | User-installed skills |
| Plugin Cache | `~/.claude/plugins/cache/` | Downloaded plugins |
| Session Storage | `~/.claude/projects/` | Session history files |
| Project Settings | `.claude/settings.json` | Project-scoped settings |
| Project Local | `.claude/settings.local.json` | Local overrides (gitignored) |
| Project MCP | `.mcp.json` | Project-scoped MCP servers |

### 18.2 ILS Application Paths

| Purpose | Path | Description |
|---------|------|-------------|
| SQLite Database | `~/Library/Application Support/ILS/ils.sqlite` | Session/project persistence |
| Logs | `~/Library/Logs/ILS/` | Application logs |
| Cache | `~/Library/Caches/ILS/` | Temporary data |

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-XX | Initial spec (config manager only) |
| 2.0 | 2026-02-01 | Full feature parity expansion |
| 2.1 | 2026-02-01 | Added complete design tokens, UI specs, data models, API docs |

---

**END OF DETAILED DESIGN DOCUMENT**
