# ILS - Intelligent Local Server

> A native iOS & macOS client for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with a Swift backend

[![Build](https://github.com/krzemienski/ils-ios/actions/workflows/build.yml/badge.svg)](https://github.com/krzemienski/ils-ios/actions/workflows/build.yml)
[![Swift](https://img.shields.io/badge/Swift-5.10+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://developer.apple.com/macos/)
[![Vapor](https://img.shields.io/badge/Vapor-4.0-purple.svg)](https://vapor.codes)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

ILS provides a full-featured mobile and desktop interface for interacting with Claude Code — managing sessions, browsing projects, monitoring systems, and coordinating multi-agent teams from your iPhone, iPad, or Mac.

## Features

### Core
- **Chat with Claude** — Real-time SSE streaming with markdown rendering, code highlighting, and message history
- **Session Management** — Create, view, fork, rename, export, and search across 22,000+ sessions
- **Cross-Session Search** — Full-text search across all messages with filters (user/Claude/date/code)

### Discovery & Management
- **Browser** — Unified browser for MCP servers, Skills, Plugins, and Discover marketplace
- **Project Browser** — Browse and manage 370+ Claude Code projects
- **Plugin Marketplace** — Install, enable/disable plugins with GitHub search integration
- **MCP Server Status** — Monitor Model Context Protocol servers with health checks

### Operations
- **System Monitoring** — Live CPU, memory, disk, network metrics and 1,300+ process monitoring
- **Agent Queue** — Queue, run, pause, and cancel background agent tasks
- **Workflow Automation** — Create and schedule repeatable Claude Code workflows
- **Team Coordination** — Manage multi-agent teams with tasks, messaging, and member control
- **Host Profiles / Fleet** — Manage multiple backend host connections
- **Hooks** — View and manage Claude Code hook configurations (23 hooks, 9 event types)

### Configuration & UX
- **Custom Themes** — 13 built-in themes (Obsidian, Neon Noir, Ember, etc.) plus custom theme editor
- **Analytics Dashboard** — Session metrics, activity timeline, usage summaries over 7/30 day windows
- **Usage Tracking** — Rate limit monitoring, message trends, session metrics
- **Permissions** — Review and manage pending permission requests with history
- **Activity Feed** — Timeline of session events and system activity
- **Documentation** — In-app documentation browser with 15+ slash command references
- **Settings** — Backend connection, remote access, appearance, keyboard shortcuts
- **Split View** — Multi-pane layout for side-by-side screen viewing
- **Cloudflare Tunnel** — Expose your local backend via secure tunnel for remote access

### Platform
- **iOS & iPad** — Full SwiftUI app with sidebar navigation and deep linking
- **macOS Native** — 3-column NavigationSplitView, multi-window, keyboard shortcuts, Touch Bar
- **Dark Mode** — Native dark theme throughout with 13 theme variants
- **Premium Features** — Feature gating with StoreKit subscription support

## Architecture

```
ils-ios/
├── Sources/                    # Swift Package (Backend + Shared)
│   ├── ILSShared/             # Shared models & DTOs (26 files)
│   └── ILSBackend/            # Vapor REST API server (52 files)
│       ├── App/               # Server config, routes, middleware
│       ├── Controllers/       # 31 API controllers (216+ endpoints)
│       ├── Models/            # Fluent ORM database models (5 models)
│       ├── Migrations/        # Database schema migrations
│       ├── Services/          # 18 business logic services
│       ├── Middleware/        # Request/response middleware
│       └── Extensions/        # Utility extensions
├── ILSApp/                    # Xcode project
│   ├── ILSApp/               # iOS app (149+ Swift files)
│   │   ├── Views/            # 24 screen directories
│   │   ├── ViewModels/       # 51+ @Observable @MainActor view models
│   │   ├── Services/         # 15+ services (APIClient, SSEClient, ICloudSync, etc.)
│   │   ├── Theme/            # ThemeSnapshot + 13 built-in themes
│   │   ├── Widgets/          # WidgetKit extensions
│   │   ├── LiveActivity/     # Live Activity support
│   │   ├── Intents/          # App Intents + Shortcuts
│   │   └── Resources/        # Localization strings
│   ├── ILSMacApp/            # macOS app (14+ Swift files, 3-pane layout)
│   └── ILSWidgets/           # Widget target with Info.plist
├── fastlane/                  # CI/CD: build, beta, screenshots
├── scripts/                   # Setup, backend service, automation, SDK wrapper
├── docs/                      # Documentation
├── Package.swift              # Swift Package manifest
└── ils.sqlite                 # SQLite database (auto-created on startup)
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design, data flow diagrams, and technical decisions.

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, data flow diagrams, technical decisions |
| [docs/API.md](docs/API.md) | Full API reference — 216 endpoints across 31 controllers |
| [docs/RUNNING_BACKEND.md](docs/RUNNING_BACKEND.md) | Backend deployment: dev, launchd, Homebrew, Docker, PM2 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Development roadmap and milestone tracking |
| [DESIGN.md](DESIGN.md) | Design system: color tokens, typography, UI components |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines, branching, PR checklist |
| [CHANGELOG.md](CHANGELOG.md) | Release history and version notes |
| [SECURITY.md](SECURITY.md) | Security policy and vulnerability reporting |

## Prerequisites

- **macOS** 15.0+ (Sequoia)
- **Xcode** 16.0+ with iOS 18 SDK
- **Swift** 5.10+
- **Claude Code CLI** installed and configured (optional, for chat functionality)

## Quick Start

### 1. Clone

```bash
git clone https://github.com/krzemienski/ils-ios.git
cd ils-ios
```

### 2. Start the Backend

```bash
PORT=9999 swift run ILSBackend
# Server starts on http://127.0.0.1:9999
# Database created automatically on first run
```

Verify:
```bash
curl http://localhost:9999/health
# {"status":"healthy","checks":{"database":"ok","claudeCLI":"ok","filesystem":"ok"}}
```

### 3. Run the iOS App

```bash
open ILSApp/ILSApp.xcodeproj
# Select ILSApp scheme → Cmd+R
```

Or via command line:
```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -quiet build
```

### 4. Run the macOS App

Select **ILSMacApp** scheme in Xcode → `Cmd+R`

### 5. Connect

- **Simulator**: Connects to `localhost:9999` automatically
- **Physical device**: Update host in Settings to your Mac's IP

## Deep Links

The app supports the `ils://` URL scheme for navigation:

| URL | Screen |
|-----|--------|
| `ils://home` | Home dashboard |
| `ils://sessions/{uuid}` | Specific chat session |
| `ils://unified-sessions` | All sessions list |
| `ils://browser` | Browser (MCP/Skills/Plugins) |
| `ils://system` | System monitor |
| `ils://terminal` | Terminal |
| `ils://activity` | Activity feed |
| `ils://documentation` | Documentation |
| `ils://search` | Cross-session search |
| `ils://permissions` | Permissions |
| `ils://teams` | Teams |
| `ils://agent-queue` | Agent queue |
| `ils://fleet` | Host profiles |
| `ils://usage` | Usage metrics |
| `ils://backends` | Backend management |
| `ils://hooks` | Hooks configuration |
| `ils://themes` | Theme browser |
| `ils://settings` | Settings |
| `ils://analytics` | Analytics dashboard |
| `ils://workflows` | Workflow automation |
| `ils://split-view` | Split view |

## API Overview

Base URL: `http://localhost:9999/api/v1` — 216 endpoints across 31 controllers.

| Controller | Endpoints | Description |
|------------|-----------|-------------|
| Sessions | 26 | CRUD, fork, search, export, scan, messages |
| Projects | 7 | CRUD, bulk delete, project sessions |
| Chat | 3 | SSE streaming, permissions, cancel |
| Skills | 10 | List, search, install, enable/disable |
| MCP | 14 | CRUD, search, marketplace, health, logs |
| Plugins | 11 | CRUD, search, marketplace, GitHub search |
| Themes | 5 | CRUD for custom themes |
| Teams | 12 | CRUD, spawn, tasks, messages, members |
| System | 14 | Metrics, processes, files, version, limits |
| Analytics | 5 | Activity, sessions, skills, summary, export |
| Workflows | 14 | CRUD, execute, schedules, pause/cancel |
| Agent Queue | 11 | CRUD, templates, reorder, pause/resume |
| Automation Rules | 7 | CRUD, executions, templates |
| Permissions | 4 | Pending, history, decide, clear |
| Config | 6 | Get, update, validate, export |
| Health | 3 | Health, ready, live |
| Usage | 2 | Usage stats, export |
| Activity Feed | 2 | Events, SSE stream |
| Suggestions | 6 | Sessions, skills, abandoned, prompts |
| Terminal | 3 | Execute, config, reset |
| SSH | 4 | Connect, disconnect, status, execute |
| Host Profiles | 9 | CRUD, activate, health, fleet |
| Tunnel | 5 | Start, stop, status, health, logs |
| Templates | 6 | CRUD, bulk delete |
| Checkpoints | 4 | CRUD, restore |
| Recordings | 7 | CRUD, events, export |
| Session Health | 4 | Summary, export, per-session, projects |
| Session Backup | 4 | Checkpoints, restore |
| Stats | 4 | Dashboard stats, recent, settings, server |
| Data Erasure | 1 | Full data reset |
| Pairing | 2 | QR code generation |

Full reference: [docs/API.md](docs/API.md)

## CI/CD

ILS uses [Fastlane](https://fastlane.tools/) for builds and TestFlight:

| Lane | Command | Purpose |
|------|---------|---------|
| `build` | `bundle exec fastlane build` | Debug iOS build |
| `beta` | `bundle exec fastlane beta` | Increment build, upload to TestFlight |
| `screenshots` | `bundle exec fastlane screenshots` | Capture App Store screenshots |
| `build_macos` | `bundle exec fastlane build_macos` | Debug macOS build |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | [Vapor 4](https://vapor.codes) (Swift) |
| Database | SQLite via [Fluent ORM](https://docs.vapor.codes/fluent/overview/) |
| iOS/macOS UI | SwiftUI (iOS 17+ / macOS 14+) |
| Architecture | MVVM with `@Observable @MainActor` |
| Concurrency | Swift actors, `@MainActor`, async/await |
| Networking | URLSession + Server-Sent Events (SSE) |
| Code Execution | Python Agent SDK + CLI fallback |
| Code Highlighting | [Splash](https://github.com/JohnSundell/Splash) |
| YAML | [Yams](https://github.com/jpsim/Yams) |
| Sync | iCloud CloudKit (with graceful degradation) |
| CI/CD | [Fastlane](https://fastlane.tools/) |
| Subscriptions | StoreKit 2 |
| Localizations | 7,175+ string keys (Localizable.xcstrings) |

## Development

### Database

```bash
# Reset database
rm ils.sqlite && PORT=9999 swift run ILSBackend

# Inspect
sqlite3 ils.sqlite ".tables"
```

### Adding Features

1. Add shared model in `Sources/ILSShared/Models/`
2. Add backend controller in `Sources/ILSBackend/Controllers/`
3. Add view model in `ILSApp/ILSApp/ViewModels/`
4. Add view in `ILSApp/ILSApp/Views/`
5. Add sidebar nav item in `SidebarView.swift`
6. Add deep link in `AppState.swift`

### Troubleshooting

```bash
# Backend won't start
lsof -i :9999        # Check port
kill -9 <PID>        # Kill stale process

# Clean builds
rm -rf .build        # Swift Package cache
rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic
- [Vapor](https://vapor.codes) Swift web framework
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) by Apple
