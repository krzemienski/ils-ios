# ILS - Intelligent Language System

> A native iOS client for [Claude Code](https://claude.ai/claude-code) with a Swift backend

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Vapor](https://img.shields.io/badge/Vapor-4.0-purple.svg)](https://vapor.codes)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

ILS provides a mobile interface for interacting with Claude Code sessions, managing projects, viewing skills, and configuring MCP servers - all from your iPhone or iPad.

## Features

- **Chat with Claude** - Real-time streaming responses via SSE
- **Session Management** - Create, view, and fork chat sessions
- **Project Browser** - Browse and manage Claude Code projects
- **Skills Explorer** - View 1,500+ available Claude Code skills
- **Plugin Management** - Enable/disable Claude Code plugins
- **MCP Server Status** - Monitor Model Context Protocol servers
- **Dark Mode** - Native iOS dark theme throughout

## Screenshots

| Dashboard | Sessions | Chat |
|-----------|----------|------|
| ![Dashboard](docs/screenshots/dashboard.png) | ![Sessions](docs/screenshots/sessions.png) | ![Chat](docs/screenshots/chat.png) |

## Architecture

This monorepo contains both the Vapor-based REST API backend and the SwiftUI iOS application, sharing common models through the `ILSShared` library.

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
│       └── Services/          # Business logic (streaming, filesystem)
├── ILSApp/                    # iOS Application (Xcode project)
│   └── ILSApp/
│       ├── Views/             # SwiftUI views by feature
│       ├── ViewModels/        # MVVM view models
│       ├── Services/          # API client, SSE client
│       └── Theme/             # Design system
├── Tests/                     # Backend tests
├── Package.swift              # Swift Package manifest
└── ils.sqlite                 # SQLite database (auto-created)
```

## Prerequisites

- **macOS** 15.0+ (Sequoia or later)
- **Xcode** 16.0+ with iOS 18 SDK
- **Swift** 6.0+
- **Claude Code CLI** installed and configured (optional, for full functionality)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/ils-ios.git
cd ils-ios
```

### 2. Start the Backend

```bash
# Build and run the backend server
PORT=9090 swift run ILSBackend

# You should see:
# [ NOTICE ] Server started on http://0.0.0.0:9090
```

The backend will:
- Create `ils.sqlite` database on first run
- Run database migrations automatically
- Start listening on port 9090

**Verify it's running:**
```bash
curl http://localhost:9090/health
# Returns: OK
```

### 3. Run the iOS App

**Option A: Xcode (Recommended)**
```bash
open ILSApp/ILSApp.xcodeproj
```
Press `Cmd+R` to build and run on Simulator.

**Option B: Command Line**
```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

### 4. Configure Connection

The iOS app connects to `http://localhost:9090` by default.

- **Simulator**: Works automatically (shares localhost with Mac)
- **Physical Device**: Go to Settings in the app and update the host to your Mac's IP address

## iOS App Structure

The iOS app follows MVVM architecture with feature-based organization:

```
ILSApp/
├── ILSAppApp.swift           # App entry point & global state
├── ContentView.swift         # Root navigation container
├── Views/
│   ├── Chat/                 # Chat interface with streaming
│   │   ├── ChatView.swift    # Main chat screen
│   │   ├── MessageView.swift # Individual message bubbles
│   │   └── CommandPaletteView.swift
│   ├── Dashboard/            # Stats overview
│   ├── Sessions/             # Session list & creation
│   ├── Projects/             # Project browser
│   ├── Plugins/              # Plugin management
│   ├── MCP/                  # MCP server status
│   ├── Skills/               # Skills explorer
│   ├── Settings/             # App configuration
│   └── Sidebar/              # Navigation sidebar
├── ViewModels/               # Business logic per feature
├── Services/
│   ├── APIClient.swift       # REST API communication
│   └── SSEClient.swift       # Server-Sent Events for streaming
└── Theme/
    └── ILSTheme.swift        # Colors, fonts, spacing
```

## API Endpoints

Base URL: `http://localhost:9090/api/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/projects` | List all projects |
| `GET` | `/sessions` | List all sessions |
| `POST` | `/sessions` | Create a new session |
| `GET` | `/sessions/:id/messages` | Get session messages |
| `POST` | `/sessions/:id/fork` | Fork a session |
| `POST` | `/chat/stream` | Send message (SSE streaming) |
| `GET` | `/skills` | List available skills |
| `GET` | `/mcp` | List MCP servers |
| `GET` | `/plugins` | List installed plugins |
| `GET` | `/config` | Get Claude configuration |
| `GET` | `/stats` | Dashboard statistics |

## Shared Models

Both the iOS app and backend use the same model definitions from `ILSShared`:

| Model | Purpose |
|-------|---------|
| `ChatSession` | Chat session with metadata |
| `Message` | Individual chat message |
| `Project` | Claude Code project with path |
| `Skill` | Skill definition and metadata |
| `MCPServer` | MCP server configuration |
| `Plugin` | Installed plugin information |
| `ClaudeConfig` | Claude Code settings |
| `StreamMessage` | Real-time streaming events |

## Development

### Running Tests

**Backend Tests:**
```bash
swift test
```

**iOS App (Xcode):**
```bash
xcodebuild test \
  -project ILSApp/ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Database Management

The backend uses SQLite stored at `ils.sqlite` in the project root.

**Reset database:**
```bash
rm ils.sqlite
swift run ILSBackend  # Recreates with fresh migrations
```

**Inspect database:**
```bash
sqlite3 ils.sqlite ".tables"
sqlite3 ils.sqlite ".schema sessions"
```

### Adding New Features

1. **Add shared model** in `Sources/ILSShared/Models/`
2. **Add backend controller** in `Sources/ILSBackend/Controllers/`
3. **Add iOS view model** in `ILSApp/ViewModels/`
4. **Add iOS view** in `ILSApp/Views/`

## URL Schemes

The app supports deep linking via the `ils://` URL scheme:

| URL | Action |
|-----|--------|
| `ils://sessions` | Open Sessions tab |
| `ils://projects` | Open Projects tab |
| `ils://plugins` | Open Plugins tab |
| `ils://mcp` | Open MCP Servers tab |
| `ils://skills` | Open Skills tab |
| `ils://settings` | Open Settings tab |

## Troubleshooting

### Backend won't start

```bash
# Check if port 9090 is in use
lsof -i :9090

# Kill existing process if needed
kill -9 <PID>
```

### iOS can't connect to backend

1. Verify backend is running: `curl http://localhost:9090/health`
2. For physical device, use your Mac's IP address in Settings
3. Ensure both devices are on the same network

### Build errors

```bash
# Clean Swift Package cache
rm -rf .build
swift package resolve

# Clean Xcode build
rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend Framework | [Vapor 4](https://vapor.codes) |
| Database | SQLite via [Fluent](https://docs.vapor.codes/fluent/overview/) |
| iOS UI | SwiftUI (iOS 18+) |
| Architecture | MVVM |
| Networking | URLSession + SSE |
| Streaming | Server-Sent Events |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Claude Code](https://claude.ai/claude-code) by Anthropic
- [Vapor](https://vapor.codes) Swift web framework
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) by Apple
