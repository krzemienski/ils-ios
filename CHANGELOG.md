# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-04

### Added

#### iOS App
- **Dashboard View** - Overview showing project count, session count, skills count, and MCP server status with recent activity feed
- **Sessions Management** - List, create, view, and fork chat sessions with full message history
- **Chat Interface** - Real-time streaming chat with Claude via Server-Sent Events (SSE)
  - Message bubbles with user/assistant styling
  - Typing indicator during streaming
  - Command palette for quick actions
  - Session info sheet with metadata
  - Fork session functionality
- **Projects Browser** - Browse all Claude Code projects with session counts and timestamps
- **Skills Explorer** - Search and browse 1,500+ available Claude Code skills
- **Plugins Management** - View and toggle Claude Code plugins with descriptions
- **MCP Servers** - Monitor Model Context Protocol servers with health status indicators
- **Settings** - Configure backend connection, view API key status, and app preferences
- **Sidebar Navigation** - Sheet-based sidebar with all navigation options and connection status
- **Deep Linking** - Support for `ils://` URL scheme to navigate directly to features
- **Dark Mode** - Native iOS dark theme with custom ILSTheme design system

#### Backend
- **Vapor 4 REST API** - Full-featured backend server on port 9090
- **SQLite Database** - Persistent storage with Fluent ORM
- **Sessions API** - CRUD operations for chat sessions
- **Messages API** - Message history retrieval per session
- **Chat Streaming** - SSE endpoint for real-time Claude responses
- **Projects API** - List and manage Claude Code projects
- **Skills API** - Query available skills from filesystem
- **Plugins API** - List installed plugins
- **MCP API** - List configured MCP servers
- **Config API** - Retrieve Claude Code configuration
- **Stats API** - Dashboard statistics endpoint
- **Health Check** - Simple health endpoint for connectivity testing

#### Shared Library
- **ILSShared** - Common models used by both iOS app and backend
- **ChatSession Model** - Session representation with metadata
- **Message Model** - Chat message with role and timestamps
- **Project Model** - Project with path and session count
- **Skill Model** - Skill definition with description
- **MCPServer Model** - MCP server configuration
- **Plugin Model** - Plugin information with enabled state
- **StreamMessage Model** - Real-time streaming event types

#### Infrastructure
- **Swift Package** - Backend and shared library as Swift Package
- **Xcode Project** - iOS app with proper bundle configuration
- **Database Migrations** - Auto-running migrations for schema setup
- **Docker Support** - Dockerfile and docker-compose for containerized deployment

### Technical Details

- **iOS Minimum Version**: iOS 17.0
- **Swift Version**: 5.9+
- **Backend Framework**: Vapor 4
- **Database**: SQLite via Fluent
- **Architecture**: MVVM for iOS, MVC for backend
- **Networking**: URLSession with async/await, SSE for streaming

### Known Limitations

- Claude Code CLI integration requires local installation
- Physical device requires manual backend URL configuration
- API key management done via terminal (security consideration)

---

## [1.1.0] - 2026-03-05

### Added

#### iOS App — 12 New Screens
- **Workflow Automation** — Create, schedule, execute, pause/cancel repeatable Claude Code workflows
- **Analytics Dashboard** — Session metrics, activity timeline, usage summaries (7/30 day)
- **Agent Queue** — Queue, run, pause, resume, cancel background agent tasks
- **Cross-Session Search** — Full-text search across all messages with user/Claude/date/code filters
- **Activity Feed** — Timeline of session events and system activity
- **Permissions Manager** — Review pending permission requests with approval history
- **Hooks Viewer** — Browse 23 Claude Code hooks across 9 event types
- **Usage Metrics** — Rate limit monitoring, message trends, session statistics
- **Documentation Browser** — In-app reference for 15+ slash commands
- **Backend Manager** — Multi-backend connection management
- **Split View** — Multi-pane layout for side-by-side screens
- **Terminal** — Execute commands with quick action chips (Status, ls, pwd, Git)

#### iOS App — Enhancements
- **Smart Paste** — Auto-detect pasted content type (code, URLs, JSON) with formatting
- **iCloud Sync** — Auto-disable gracefully when iCloud account unavailable
- **Sidebar Navigation** — All 22 screens accessible via sidebar with Workflows added
- **Premium Features** — Feature gating with StoreKit 2 subscription support
- **WidgetKit Extensions** — Home screen widgets
- **Live Activity** — Real-time session status on Lock Screen
- **App Intents** — Siri Shortcuts integration

#### Backend — 15 New Controllers (86 new endpoints)
- WorkflowsController (14 endpoints) — CRUD, execute, schedules, pause/cancel
- AgentQueueController (11) — CRUD, templates, reorder, pause/resume/cancel
- AnalyticsController (5) — Activity, sessions, skills, summary, export
- AutomationRulesController (7) — CRUD, executions, templates
- PermissionsController (4) — Pending, history, decide, clear
- ActivityFeedController (2) — Events list, SSE stream
- UsageController (2) — Stats, export
- SuggestionsController (6) — Sessions, skills, abandoned, prompts, feedback
- TerminalController (3) — Execute, config, reset
- SSHController (4) — Connect, disconnect, status, execute
- SessionHealthController (4) — Summary, export, per-session, projects
- SessionBackupController (4) — Checkpoints, restore
- RecordingController (7) — CRUD, events, export
- CheckpointsController (4) — CRUD, restore
- HostProfileController (9) — Fleet management, activation, health

#### Backend — Improvements
- Graceful degradation for GitHub search endpoints (return empty results vs 502)
- Auto-run pending database migrations on startup

#### macOS App
- Full macOS app with NavigationSplitView, multi-window, keyboard shortcuts, Touch Bar

### Fixed
- Workflows screen unreachable — missing sidebar nav item and deep link handler
- iCloud sync showing false "Sync error" on simulator/devices without iCloud accounts
- ChatInputBar broken .onPaste smart paste integration removed
- Cross-platform build fixes after worktree merges
- GitHub search endpoints (skills, MCP, plugins) returning 502 when API unreachable

### Changed
- Backend port default: 9999 (was 9090)
- API prefix: `/api/v1` auto-added by APIClient
- Architecture: `@Observable` replaces `ObservableObject`, `ThemeSnapshot` struct replaces protocol
- Navigation: `ActiveScreen` enum with 22 cases replaces tab-based navigation

---

## [Unreleased]

### Planned
- watchOS companion app
- Push notifications for session activity
- Offline mode with sync
