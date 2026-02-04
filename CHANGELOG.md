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

## [Unreleased]

### Planned
- iPad optimization with split view
- watchOS companion app
- Push notifications for session activity
- Offline mode with sync
- Multiple backend profiles
- Export/import session history
