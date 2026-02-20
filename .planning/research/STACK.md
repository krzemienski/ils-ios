# Technology Stack

**Project:** ILS (Intelligent Local Server) -- iOS/macOS native client for Claude Code
**Researched:** 2026-02-19

## Recommended Stack (Current -- No Changes Needed)

The stack is fully established and the audit is a verification pass, not a build phase. No stack changes should be made during the audit.

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI | iOS 17+ / macOS 14+ | UI framework | Native Apple declarative UI, required for modern iOS |
| Swift | 5.9+ | Language | Required by SwiftUI and Vapor |
| Xcode | 15+ | IDE/Build | Required for iOS/macOS development |

### Backend

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Vapor | 4.89+ | HTTP server | Swift-native, async/await, works in same monorepo |
| Fluent | 4.9+ | ORM | Vapor's ORM, type-safe database queries |
| FluentSQLiteDriver | 4.6+ | Database driver | Local SQLite for session/project data |
| SQLite | embedded | Database | Zero-config, file-based, sufficient for local data |
| Yams | 5.0+ | YAML parser | Parsing SKILL.md frontmatter |

### iOS App Architecture

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `@Observable` macro | iOS 17+ | State management | Modern replacement for `ObservableObject`, less boilerplate |
| ThemeSnapshot (custom) | N/A | Theming | Concrete struct replacing `any AppTheme` existential (58 occurrences) |
| SSEClient | custom | Server-Sent Events | Chat streaming from backend |
| MetricsWebSocketClient | custom | WebSocket | System monitor real-time metrics |
| APIClient (actor) | custom | Networking | Thread-safe API client with caching |
| CryptoKit | system | Hashing | Deterministic project IDs (NOT `Crypto` -- different SHA256 in Vapor) |

### Chat Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Python claude-agent-sdk | latest | Claude CLI wrapper | Wraps Claude CLI, inherits OAuth auth |
| `scripts/sdk-wrapper.py` | custom | Bridge script | NDJSON parsing, `include_partial_messages=True` |
| ClaudeExecutorService | custom | Process management | Spawns `python3 sdk-wrapper.py`, env var stripping for nesting detection |

### Infrastructure

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Cloudflare Tunnel | N/A | Remote access | Optional tunnel for remote iOS-to-backend connectivity |
| XcodeGen (`project.yml`) | N/A | Project generation | Alternative to manual Xcode project management |

### Supporting Libraries (Current Dependencies)

| Library | Purpose | When to Use |
|---------|---------|-------------|
| Yams | YAML parsing | Skill file frontmatter |
| FluentSQLiteDriver | Database | Session/project persistence |
| Vapor | HTTP + WebSocket | All backend communication |

## Alternatives Considered

| Category | Current | Alternative | Why Not |
|----------|---------|-------------|---------|
| Backend | Vapor (Swift) | Express.js / Fastify | Swift monorepo keeps everything in one language; no Node.js dependency |
| Database | SQLite (Fluent) | PostgreSQL | Overkill for local app; SQLite is zero-config |
| State mgmt | `@Observable` | `ObservableObject` | `@Observable` is modern pattern; `SSEClient` is the only holdout (backlog M5) |
| Theming | ThemeSnapshot struct | `any AppTheme` existential | ThemeSnapshot eliminates protocol witness overhead across 48 views |
| Claude integration | Python SDK wrapper | Direct Anthropic API | SDK inherits OAuth auth; direct API requires ANTHROPIC_API_KEY |
| Claude integration | Python SDK wrapper | ClaudeCodeSDK (Swift) | SDK uses RunLoop which NIO does not pump -- broken in Vapor context |

## Build Commands

```bash
# iOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

# macOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet

# Backend
PORT=9999 swift run ILSBackend

# Backend build only
swift build
```

## Key Port Assignments

| Port | Service | Notes |
|------|---------|-------|
| 9999 | ILS Backend | MUST use this; 8080 is ralph-mobile |
| 8080 | ralph-mobile | DO NOT USE for ILS |

## Sources

- `Package.swift` (root) -- Vapor, Fluent, FluentSQLiteDriver, Yams dependencies
- `ILSApp/ILSApp.xcodeproj` -- Xcode project configuration
- `CLAUDE.md` -- Backend port assignment, build commands, key paths
- Project memory -- Claude SDK migration history, ClaudeCodeSDK failure analysis
