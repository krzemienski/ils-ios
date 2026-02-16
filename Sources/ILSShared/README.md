# ILSShared

Shared Swift package containing models and DTOs used by both the iOS/macOS apps and the Vapor backend.

## Purpose

ILSShared provides the type-safe contract between client and server. All API request/response types, domain models, and streaming message types are defined here to ensure consistency across the codebase.

## Structure

```
ILSShared/
├── Models/                  # Domain models (14 files)
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
│   ├── ServerConnection.swift  # Connection configuration
│   ├── SetupProgress.swift  # Onboarding state
│   └── FleetHost.swift      # Remote host info
└── DTOs/                    # Transfer objects (12 files)
    ├── ResponseDTOs.swift       # APIResponse<T> wrapper
    ├── PaginatedResponse.swift  # PaginatedResponse<T>
    ├── Requests.swift           # CreateSessionRequest, ChatRequest, etc.
    ├── SystemDTOs.swift         # SystemMetrics, ProcessInfo
    ├── TeamDTOs.swift           # TeamInfo, TeamMember, TeamTask
    ├── TunnelDTOs.swift         # TunnelStatus, TunnelConfig
    ├── SearchResult.swift       # GitHubSearchResult
    ├── ConnectionResponse.swift # Connection status
    ├── SetupDTOs.swift          # Setup flow types
    ├── FleetDTOs.swift          # Fleet management types
    ├── SSHDTOs.swift            # SSH connection types
    └── RemoteMetricsDTOs.swift  # Remote system metrics
```

## Key Types

### APIResponse\<T\>

Standard response wrapper for all API endpoints:

```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
}
```

### PaginatedResponse\<T\>

Paginated list wrapper:

```swift
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let hasMore: Bool?
}
```

### ChatSession

Core session model (conforms to `Codable`, `Identifiable`, `Hashable`):

- `id: UUID` - Unique identifier
- `claudeSessionId: String?` - Claude CLI session reference
- `name: String?` - Display name
- `projectId: UUID?` - Associated project
- `model: String` - Claude model (sonnet, opus, haiku)
- `status: String` - active, completed, etc.
- `source: String` - "ils" (DB-managed) or "external" (filesystem)
- `totalCostUSD: Double` - Accumulated cost

### ContentBlock

Chat message content discriminated by type:
- `.text` - Human-readable text
- `.toolUse` - Tool invocation with name and input
- `.toolResult` - Tool execution result
- `.thinking` - Extended thinking content

### StreamMessage

SSE stream event with type discriminator:
- `system` - Session initialization
- `assistant` - Response content blocks
- `result` - Final result with usage stats
- `error` - Error information
- `permission` - Permission request

## Usage

### In iOS/macOS App

```swift
import ILSShared

let response: APIResponse<PaginatedResponse<ChatSession>> = try await apiClient.get("/sessions")
if response.success, let data = response.data {
    self.sessions = data.items
    self.totalCount = data.total
}
```

### In Backend

```swift
import ILSShared

func index(req: Request) async throws -> APIResponse<PaginatedResponse<ChatSession>> {
    let sessions = try await SessionModel.query(on: req.db).all()
    let dtos = sessions.map { $0.toDTO() }
    return APIResponse(success: true, data: PaginatedResponse(items: dtos, total: dtos.count), error: nil)
}
```

## Dependencies

- **Splash** 0.16+ - Syntax highlighting for code blocks

## Design Decisions

- **Codable everywhere** - All types conform to `Codable` for JSON serialization
- **Identifiable** - All list types conform to `Identifiable` for SwiftUI `ForEach`
- **Hashable sessions** - `ChatSession` conforms to `Hashable` for `navigationDestination(item:)`
- **camelCase JSON** - API uses camelCase (not snake_case) via default Swift encoder
- **Optional fields** - Fields that may be absent use optionals (not defaults)
