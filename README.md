# ILS - Intelligent Language System

A native iOS client for Claude Code with a Swift backend. This monorepo contains both the Vapor-based REST API backend and the SwiftUI iOS application, sharing common models through the `ILSShared` library.

## Project Overview

ILS provides a mobile interface for interacting with Claude Code sessions, managing projects, viewing skills, and configuring MCP servers - all from your iPhone or iPad.

### Architecture

```
ils-ios/
├── Sources/                    # Swift Package (Backend + Shared)
│   ├── ILSShared/             # Shared models (used by both)
│   │   ├── Models/            # Session, Project, Message, etc.
│   │   └── DTOs/              # Request/Response types
│   └── ILSBackend/            # Vapor REST API server
│       ├── App/               # Server configuration & routes
│       ├── Controllers/       # API endpoint handlers
│       ├── Models/            # Fluent ORM database models
│       ├── Migrations/        # Database schema migrations
│       └── Services/          # Business logic (Claude, streaming)
├── ILSApp/                    # iOS Application (Xcode project)
│   └── ILSApp/
│       ├── Views/             # SwiftUI views by feature
│       ├── ViewModels/        # MVVM view models
│       ├── Services/          # API client, SSE client
│       └── Theme/             # Design system
├── Tests/                     # Backend tests
├── Package.swift              # Swift Package manifest
└── ils.sqlite                 # SQLite database (created on first run)
```

## Prerequisites

- **macOS** 14.0+ (Sonoma or later)
- **Xcode** 15.0+ with iOS 17 SDK
- **Swift** 5.9+
- **Claude Code CLI** installed and configured

## Quick Start

### 1. Start the Backend

```bash
cd /path/to/ils-ios

# First run - resolves dependencies and runs migrations
swift run ILSBackend

# You should see:
# ILS Backend starting on http://0.0.0.0:8080
```

The backend will:
- Create `ils.sqlite` database on first run
- Run database migrations automatically
- Start listening on port 8080

**Verify it's running:**
```bash
curl http://localhost:8080/health
# Returns: OK
```

> **Want to run as a service?** See [docs/RUNNING_BACKEND.md](docs/RUNNING_BACKEND.md) for launchd, Homebrew services, Docker, and other options.

### 2. Run the iOS App

**Option A: Xcode (Recommended)**
```bash
open ILSApp/ILSApp.xcodeproj
```
Then press `Cmd+R` to build and run on Simulator.

**Option B: Command Line**
```bash
cd ILSApp
xcodebuild -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### 3. Connect iOS to Backend

The iOS app connects to `http://localhost:8080` by default. When running on:

- **Simulator**: Works automatically (shares localhost with Mac)
- **Physical Device**: Change `baseURL` in `APIClient.swift` to your Mac's IP address

## How It Works

### Communication Flow

```
┌─────────────┐     HTTP/REST      ┌─────────────┐     PTY/Exec     ┌─────────────┐
│   iOS App   │ ◄────────────────► │   Backend   │ ◄──────────────► │ Claude Code │
│  (SwiftUI)  │    localhost:8080  │   (Vapor)   │                  │    (CLI)    │
└─────────────┘                    └─────────────┘                  └─────────────┘
       │                                  │
       │                                  │
       ▼                                  ▼
   ILSShared                         ILSShared
   (Models)                      (Models + Fluent)
```

1. **iOS App** sends REST requests to the backend
2. **Backend** persists data to SQLite and executes Claude Code CLI
3. **Chat streaming** uses Server-Sent Events (SSE) for real-time responses
4. **Shared models** ensure type-safe communication between layers

### Shared Models (ILSShared)

Both the iOS app and backend use the same model definitions:

| Model | Purpose |
|-------|---------|
| `Project` | Claude Code project with directory path |
| `Session` | Chat session within a project |
| `Message` | Individual chat message |
| `Skill` | Claude Code skill definition |
| `MCPServer` | Model Context Protocol server config |
| `Plugin` | Installed plugin information |
| `ClaudeConfig` | Claude Code configuration |
| `StreamMessage` | Real-time chat streaming events |

### API Endpoints

Base URL: `http://localhost:8080/api/v1`

| Endpoint | Description |
|----------|-------------|
| `GET /projects` | List all projects |
| `POST /projects` | Create a project |
| `GET /sessions` | List sessions |
| `POST /sessions` | Create a session |
| `POST /chat/send` | Send a chat message |
| `GET /chat/stream/:sessionId` | SSE stream for responses |
| `GET /skills` | List available skills |
| `GET /mcp/servers` | List MCP servers |
| `GET /plugins` | List installed plugins |
| `GET /config` | Get Claude configuration |
| `GET /stats` | Usage statistics |

## Development

### Project Structure Details

**Backend (`Sources/ILSBackend/`)**
- Built with [Vapor](https://vapor.codes) web framework
- Uses [Fluent](https://docs.vapor.codes/fluent/overview/) ORM with SQLite
- Executes Claude Code CLI via `ClaudeExecutorService`
- Streams responses via `StreamingService`

**iOS App (`ILSApp/`)**
- SwiftUI with MVVM architecture
- `APIClient` - REST API communication
- `SSEClient` - Server-Sent Events for streaming
- Feature-based view organization (Chat, Projects, Settings, etc.)

**Shared Library (`Sources/ILSShared/`)**
- Pure Swift models with Codable conformance
- No external dependencies
- Used by both backend and iOS via Swift Package Manager

### Running Tests

**Backend Tests:**
```bash
swift test
```

**iOS UI Tests:**
```bash
cd ILSApp
xcodebuild test -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Database

The backend uses SQLite stored at `ils.sqlite` in the project root.

**Reset database:**
```bash
rm ils.sqlite
swift run ILSBackend  # Recreates with fresh migrations
```

**View database:**
```bash
sqlite3 ils.sqlite
.tables
.schema projects
```

## Troubleshooting

### Backend won't start

```bash
# Check if port 8080 is in use
lsof -i :8080

# Kill existing process if needed
kill -9 <PID>
```

### iOS can't connect to backend

1. Ensure backend is running (`curl http://localhost:8080/health`)
2. For physical device, use Mac's IP instead of localhost
3. Check that CORS is configured (it is by default)

### Build errors

```bash
# Clean Swift Package cache
rm -rf .build
swift package resolve

# Clean Xcode build
cd ILSApp
xcodebuild clean
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend Framework | [Vapor 4](https://vapor.codes) |
| Database | SQLite via [Fluent](https://docs.vapor.codes/fluent/overview/) |
| iOS UI | SwiftUI (iOS 17+) |
| Architecture | MVVM |
| Networking | URLSession + SSE |
| Claude Integration | [ClaudeCodeSDK](https://github.com/krzemienski/ClaudeCodeSDK) |

## License

MIT
