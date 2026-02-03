# ILS - Intelligent Language System

A native iOS client for Claude Code with a Swift backend. This monorepo contains both the Vapor-based REST API backend and the SwiftUI iOS application, sharing common models through the `ILSShared` library.

## Project Overview

ILS provides a mobile interface for interacting with Claude Code sessions, managing projects, viewing skills, and configuring MCP servers - all from your iPhone or iPad.

## Features

- 📱 **Native iOS Interface** - SwiftUI-based mobile client for Claude Code
- 💬 **Real-Time Chat** - Server-Sent Events (SSE) for streaming responses
- 📂 **Project Management** - Create and manage Claude Code projects
- 🎯 **Session Management** - Start, track, and resume chat sessions
- 🛠️ **Skills Browser** - View and manage available Claude Code skills
- 🔌 **Plugin Management** - Browse and configure installed plugins
- 🌐 **MCP Server Config** - Manage Model Context Protocol servers
- 📊 **Usage Statistics** - Track API usage and session metrics
- 🔄 **Cross-Platform Sync** - Shared Swift models between iOS and backend

## Project Status

**Current Version:** 0.1.0 (Active Development)
**Completion:** ~65% - Core infrastructure functional

✅ **Completed:**
- Vapor REST API backend with 11 endpoints
- SQLite database with Fluent ORM
- iOS app with 9 major views (tested on simulator)
- Real-time chat streaming via SSE
- Design system with dark theme + hot orange accent
- Shared model library (8 core models)

🚧 **In Progress:**
- Integration testing (Phase 4)
- Physical device deployment
- Error handling improvements

📋 **Planned:**
- GitHub API integration for plugin discovery
- Push notifications for chat responses
- Multi-device sync
- Advanced search and filtering

> For detailed progress tracking, see [docs/evidence/VALIDATION_SUMMARY.md](docs/evidence/VALIDATION_SUMMARY.md)
> For comprehensive testing evidence and validation reports, browse [docs/evidence/](docs/evidence/)

### Architecture

> **Detailed Architecture:** For complete technical specifications, design patterns, and system architecture, see [docs/ils-spec.md](docs/ils-spec.md)

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

> **Advanced Deployment:** For production deployment options including launchd services, Docker containers, systemd units, and more, see [docs/RUNNING_BACKEND.md](docs/RUNNING_BACKEND.md)

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

## Documentation

This README provides a quick start guide. For comprehensive documentation, see the **[docs/evidence/](docs/evidence/)** directory and the following resources:

### Core Documentation

- **[docs/ils-spec.md](docs/ils-spec.md)** - 📋 Complete technical specification, architecture details, and design patterns
- **[docs/RUNNING_BACKEND.md](docs/RUNNING_BACKEND.md)** - 🚀 Advanced backend deployment options (launchd, Docker, systemd, Homebrew services)
- **[docs/CLAUDE.md](docs/CLAUDE.md)** - 🤖 Project instructions for Claude Code agents

### Progress Tracking & Validation

The **[docs/evidence/](docs/evidence/)** directory contains comprehensive testing and validation documentation:

- **[docs/evidence/README.md](docs/evidence/README.md)** - Documentation index with navigation guide for PMs, developers, and QA
- **[docs/evidence/VALIDATION_SUMMARY.md](docs/evidence/VALIDATION_SUMMARY.md)** - Executive dashboard with metrics, phase completion, and project status
- **[docs/evidence/implementation_progress.md](docs/evidence/implementation_progress.md)** - Detailed phase-by-phase implementation breakdown with file inventory

### Testing & Validation Evidence

- **[docs/evidence/test_report.md](docs/evidence/test_report.md)** - iOS simulator testing results (7 views tested with screenshots)
- **[docs/evidence/backend_validation.md](docs/evidence/backend_validation.md)** - API endpoint validation with cURL command examples
- **[docs/evidence/chat_validation.md](docs/evidence/chat_validation.md)** - Real-time messaging and WebSocket integration tests

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository** and create a feature branch
2. **Follow existing patterns** - Study the codebase structure
3. **Run tests** before submitting:
   ```bash
   swift test                    # Backend tests
   cd ILSApp && xcodebuild test  # iOS tests
   ```
4. **Commit conventions**:
   - Use descriptive messages
   - Prefix with component: `backend:`, `ios:`, `shared:`, `docs:`
   - Example: `backend: Add session timeout handling`
5. **Submit a Pull Request** with:
   - Clear description of changes
   - Testing evidence (screenshots for UI changes)
   - Updated documentation if needed

### Development Guidelines

- **Swift Style**: Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Architecture**: MVVM for iOS, service-oriented for backend
- **Models**: Keep `ILSShared` dependency-free (no Vapor/SwiftUI imports)
- **Testing**: Write tests for new backend endpoints and view models
- **Documentation**: Update relevant docs when adding features

For questions or discussions, open an issue on GitHub.

## License

MIT
