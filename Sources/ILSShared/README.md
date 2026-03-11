# ILSShared

Shared Swift package containing models and DTOs used by both the iOS/macOS apps and the Vapor backend.

## Purpose

ILSShared is the type-safe contract between client and server. All API request/response types, domain models, and streaming message types are defined here to ensure consistency across the codebase.

## Structure

```
ILSShared/
├── Models/                  # Domain models
│   ├── Session.swift        # ChatSession (Codable, Hashable, Identifiable)
│   ├── Message.swift        # Chat messages with role and content
│   ├── Project.swift        # Claude Code project metadata
│   ├── Skill.swift          # Skill with YAML frontmatter fields
│   ├── Plugin.swift         # Plugin with marketplace info
│   ├── MCPServer.swift      # MCP server configuration
│   ├── CustomTheme.swift    # Custom theme color/typography definition
│   ├── StreamMessage.swift  # SSE stream event types
│   ├── CLIMessage.swift     # Raw Claude CLI output format
│   ├── ContentBlocks.swift  # Text, ToolUse, ToolResult, Thinking blocks
│   ├── ClaudeConfig.swift   # Settings file structure
│   ├── ServerConnection.swift
│   ├── SetupProgress.swift
│   └── FleetHost.swift
├── DTOs/                    # Transfer objects
│   ├── ResponseDTOs.swift       # APIResponse<T> wrapper
│   ├── PaginatedResponse.swift  # PaginatedResponse<T>
│   ├── Requests.swift           # CreateSessionRequest, ChatRequest, etc.
│   ├── SystemDTOs.swift         # SystemMetrics, ProcessInfo
│   ├── TeamDTOs.swift           # TeamInfo, TeamMember, TeamTask
│   ├── TunnelDTOs.swift         # TunnelStatus, TunnelConfig
│   ├── FleetDTOs.swift          # Fleet management types
│   ├── SSHDTOs.swift            # SSH connection types
│   ├── RemoteMetricsDTOs.swift  # Remote system metrics
│   └── ...
└── Utilities/               # Shared utility types
```

## Key Types

### `APIResponse<T>`

Standard envelope for all API endpoints:

```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
}
```

### `PaginatedResponse<T>`

```swift
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let hasMore: Bool?
}
```

### `ChatSession`

Core session model (`Codable`, `Identifiable`, `Hashable`):

- `id: UUID`
- `claudeSessionId: String?` — Claude CLI session reference
- `name: String?`
- `projectId: UUID?`
- `model: String` — sonnet, opus, haiku
- `status: String` — active, completed, etc.
- `source: String` — "ils" (DB) or "external" (filesystem)
- `totalCostUSD: Double`

`Hashable` conformance enables `navigationDestination(item:)` in SwiftUI.

### `ContentBlock`

Chat message content discriminated by type:
- `.text` — human-readable text
- `.toolUse` — tool invocation with name and input
- `.toolResult` — tool execution result
- `.thinking` — extended thinking content

### `StreamMessage`

SSE stream event with type discriminator:
- `system` — session initialization
- `assistant` — response content blocks
- `result` — final result with usage stats
- `error` — error information
- `permission` — permission request from Claude

## Usage

### In iOS/macOS App

```swift
import ILSShared

let response: APIResponse<PaginatedResponse<ChatSession>> = try await apiClient.get("/sessions")
if response.success, let data = response.data {
    self.sessions = data.items
}
```

### In Backend

```swift
import ILSShared

func index(req: Request) async throws -> APIResponse<PaginatedResponse<ChatSession>> {
    let sessions = try await SessionModel.query(on: req.db).all()
    return APIResponse(success: true, data: PaginatedResponse(items: sessions.map { $0.toDTO() }, total: sessions.count), error: nil)
}
```

## Design Decisions

- **Codable everywhere** — all types conform to `Codable` for JSON serialization
- **Identifiable** — all list types conform for SwiftUI `ForEach`
- **camelCase JSON** — uses default Swift encoder (not snake_case)
- **Optional fields** — absent fields use optionals, not defaults
- **`Hashable` sessions** — required for `navigationDestination(item:)`

## Dependencies

- **Splash** 0.16+ — syntax highlighting for code blocks (used by iOS app via this package)
