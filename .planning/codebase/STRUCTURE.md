# Codebase Structure

**Analysis Date:** 2026-02-19

## Directory Layout

```
ils-ios/
├── ILSApp/                              # Xcode workspace root for iOS & macOS apps
│   ├── ILSApp.xcodeproj/               # Xcode project (both targets)
│   ├── ILSFullStack.xcworkspace/       # Workspace unifying iOS, macOS, backend SPM
│   ├── ILSApp/                         # iOS app source
│   │   ├── ILSAppApp.swift             # App entry point (@main)
│   │   ├── Views/                      # SwiftUI screens (16 subdirs)
│   │   ├── ViewModels/                 # @Observable view models (10 files)
│   │   ├── Services/                   # Networking, state managers (30+ files)
│   │   ├── Theme/                      # Theme system, components (~30 files)
│   │   ├── Models/                     # iOS-only local models
│   │   ├── Utils/                      # Helpers, extensions
│   │   ├── Assets.xcassets/            # Images, app icons
│   │   ├── Resources/                  # Strings, config files
│   │   └── Intents/                    # Siri shortcuts
│   ├── ILSMacApp/                      # macOS app source
│   │   ├── ILSMacApp.swift             # App entry point with AppDelegate
│   │   ├── Views/                      # macOS-specific SwiftUI screens
│   │   ├── Managers/                   # macOS managers (Window, Notification)
│   │   ├── Services/                   # macOS-specific services
│   │   ├── Commands/                   # Keyboard shortcuts, menu commands
│   │   └── Assets.xcassets/
│   └── ILSAppUITests/                  # UI test bundle
├── Sources/
│   ├── ILSShared/                      # Swift Package: shared models & DTOs
│   │   ├── Models/                     # Session.swift, ChatMessage.swift, etc.
│   │   ├── DTOs/                       # Request/response types (ChatStreamRequest, etc.)
│   │   └── Utilities/                  # Codable helpers, formatters
│   └── ILSBackend/                     # Swift Package: Vapor backend
│       ├── App/                        # configure.swift, routes.swift, main.swift
│       ├── Controllers/                # 14 RouteCollection implementations
│       ├── Services/                   # Business logic, Claude execution, file I/O
│       ├── Models/                     # Fluent ORM models (SessionModel, etc.)
│       ├── Migrations/                 # Database schema (7 AsyncMigration files)
│       ├── Middleware/                 # CORS, logging, rate limiting, errors
│       ├── Helpers/                    # PathSanitizer, extensions
│       ├── Extensions/                 # Vapor, Foundation extensions
│       └── Scripts/                    # Python CLI wrapper
├── Tests/
│   ├── ILSSharedTests/                 # Unit tests for ILSShared package
│   └── ILSBackendTests/                # Vapor integration tests
├── Package.swift                        # Swift Package manifest (5.9+, iOS 17+, macOS 14+)
├── .planning/                           # Planning documents (this file location)
└── docs/, specs/, .claude/, .omc/      # Research, specifications, orchestrator state
```

## Directory Purposes

**ILSApp/ILSApp (iOS App):**
- Purpose: SwiftUI native iOS application
- Contains: UI screens, reactive view models, networking services
- Key files: `ILSAppApp.swift` (entry), `Views/Root/SidebarRootView.swift` (navigation)
- Build target: "ILSApp" scheme in Xcode

**ILSApp/ILSMacApp (macOS App):**
- Purpose: SwiftUI native macOS application (parallel to iOS)
- Contains: macOS-specific views, app delegate, window management
- Key files: `ILSMacApp.swift` (entry with AppDelegate), `MacContentView.swift` (main window)
- Build target: "ILSMacApp" scheme in Xcode
- Differences from iOS: multi-window support, command menu, no sidebar sheet overlay

**Sources/ILSShared (Shared Models Package):**
- Purpose: Single source of truth for types used by iOS and backend
- Contains: Codable models (`ChatSession`, `ChatMessage`), enums (SessionStatus, ClaudeModel), DTOs
- Build target: Swift package library, included in both iOS and backend
- No dependencies except Foundation (+ Splash for code highlighting in shared views)

**Sources/ILSBackend (Vapor Backend Package):**
- Purpose: REST + SSE server for Claude Code sessions
- Contains: 14 controllers, 15+ services, Fluent models, migrations, middleware
- Database: SQLite at `ils.sqlite` in working directory (created by migrations)
- Build target: Executable "ILSBackend", runs on port 9999 (configurable via PORT env var)
- Routes: All under `/api/v1` prefix except `/health` (root)

**ILSApp/ILSApp/Views:**
- Subdirectories by feature: Browser/, Chat/, Components/, Dashboard/, Fleet/, Home/, MCP/, Onboarding/, Plugins/, Premium/, Projects/, Root/, Sessions/, Settings/, Shared/, Sidebar/, Skills/, System/, Teams/, Themes/, Tips/
- Pattern: One .swift file per screen; reusable components in Components/ or Shared/
- Navigation: Driven by `ActiveScreen` enum in `Root/SidebarRootView.swift`

**ILSApp/ILSApp/ViewModels:**
- Files: ChatViewModel.swift, SettingsViewModel.swift, SystemMetricsViewModel.swift, etc.
- Pattern: @Observable classes, marked @MainActor
- Lifecycle: Configured via `configure(client:sseClient:)` in `AppState` or passed via @Environment
- Batching: ChatViewModel batches streaming messages at 75ms intervals for performance

**ILSApp/ILSApp/Services:**
- APIClient.swift: Actor-based HTTP client with caching, retry, auth header support
- SSEClient.swift: Server-Sent Events parser for streaming responses
- ConnectionManager.swift: Manages server URL, creates API/SSE clients
- PollingManager.swift: Health check polling with adaptive intervals
- CacheService.swift: Local SQLite cache for offline message storage
- SyncCoordinator.swift: Queues mutations during offline, replays on reconnect
- KeychainService.swift: Securely stores API key
- ThemeManager.swift: Manages theme selection and theming

**ILSApp/ILSApp/Theme:**
- System: ThemeManager.swift, AppTheme protocol, ThemeSnapshot struct
- Concrete themes: ObsidianTheme.swift, GhostTheme.swift, CyberpunkTheme.swift, etc. (12 total)
- Components: GlassCard.swift, ShimmerModifier.swift, SkeletonRow.swift, ThemedCodeBlockView.swift, etc.
- Pattern: Themes define colors, fonts, spacing as properties; injected via `@Environment(\.theme)`

**Sources/ILSBackend/Controllers:**
- HealthController.swift: GET `/health` for app readiness
- SessionsController.swift: CRUD for sessions, external session scanning
- ChatController.swift: POST `/chat/stream` (SSE), WebSocket `/chat/ws`, permission handling
- ProjectsController.swift: Project list and details
- SkillsController.swift: Skills index and discovery
- MCPController.swift: MCP servers list
- PluginsController.swift: Plugins registry
- ConfigController.swift: Config file I/O
- StatsController.swift: Dashboard stats aggregation
- ThemesController.swift: Theme CRUD
- SystemController.swift: System information
- TeamsController.swift: Agent teams execution
- TunnelController.swift: Cloudflare tunnel settings
- FleetController.swift: Host/fleet management

**Sources/ILSBackend/Services:**
- ClaudeExecutorService.swift: Spawns Claude CLI, streams NDJSON responses, handles permission requests
- FileSystemService.swift: Reads projects, skills, plugins from ~/.cache/claude-code
- ConfigFileService.swift: Manages config files (claude.json, etc.)
- SessionFileService.swift: Reads session transcripts from Claude Code storage
- MCPFileService.swift: Reads MCP server configs
- SystemMetricsService.swift: Collects CPU, memory, network metrics
- TeamsExecutorService.swift: Orchestrates agent execution
- StreamingService.swift: Converts CLI output to StreamMessage events
- IndexingService.swift: Builds searchable indices for skills, MCP servers

**Sources/ILSBackend/Migrations:**
- CreateSessions.swift: Sessions table with model, status, cost, source fields
- CreateProjects.swift: Projects metadata
- CreateMessages.swift: Message history (sessionId, role, content, cost)
- CreateThemes.swift: Theme definitions
- CreateCachedResults.swift: Offline message cache
- CreateFleetHosts.swift: Host/tunnel configurations
- AddDatabaseIndexes.swift: Performance indexes on frequently-queried columns

**Sources/ILSBackend/Middleware:**
- CORSMiddleware: Origin validation, allowed methods/headers, credentials
- RequestLoggingMiddleware: Logs HTTP method, path, status, duration
- ILSErrorMiddleware: Wraps errors in structured ServerErrorBody
- APIKeyMiddleware: Optional Bearer token validation
- RateLimitMiddleware: Per-IP rate limiting (configurable)

## Key File Locations

**Entry Points:**
- `ILSApp/ILSApp/ILSAppApp.swift`: iOS app (@main), initializes AppState, ThemeManager, SidebarRootView
- `ILSApp/ILSMacApp/ILSMacApp.swift`: macOS app (@main), AppDelegate, MacContentView
- `Sources/ILSBackend/App/main.swift`: Backend executable entry
- `Sources/ILSBackend/App/configure.swift`: Database, middleware, migrations setup
- `Sources/ILSBackend/App/routes.swift`: Controller registration

**Configuration:**
- `Package.swift`: Swift Package manifest, platform requirements, dependencies
- `ILSApp/ILSApp.xcodeproj/project.pbxproj`: Xcode project (build settings, targets, schemes)
- `ILSApp/ILSFullStack.xcworkspace/xcshareddata/xcschemes/`: Build schemes for iOS, macOS, backend

**Core Logic:**
- `ILSApp/ILSApp/Services/APIClient.swift`: HTTP client (GET/POST/PUT/DELETE with caching, retry, auth)
- `ILSApp/ILSApp/Services/ConnectionManager.swift`: Server URL, client lifecycle
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`: Message history, SSE streaming, permission requests
- `Sources/ILSBackend/Services/ClaudeExecutorService.swift`: Claude CLI subprocess execution
- `Sources/ILSBackend/Controllers/ChatController.swift`: SSE streaming endpoint

**Testing:**
- `Tests/ILSSharedTests/`: Unit tests for ILSShared models (Codable round-tripping, etc.)
- `Tests/ILSBackendTests/`: Vapor integration tests (controller endpoints, migrations)
- `ILSApp/ILSAppUITests/`: UI tests (currently exploratory, not CI-gated)

## Naming Conventions

**Files:**
- Pattern: PascalCase.swift (one entity per file)
- Examples: `ChatViewModel.swift`, `ConnectionManager.swift`, `SessionsController.swift`
- Views: `HomeView.swift`, `ChatView.swift`, `SettingsView.swift`
- Services: `APIClient.swift`, `SSEClient.swift`, `CacheService.swift`
- Controllers: `ChatController.swift`, `SessionsController.swift` (inherit from RouteCollection)
- Models: `ChatSession.swift`, `ChatMessage.swift`, `SessionModel.swift`

**Directories:**
- Feature-based: `Views/Chat/`, `Views/Settings/`, `Views/Browser/`
- Layer-based: `Services/`, `ViewModels/`, `Models/`, `Controllers/`, `Migrations/`
- Mixed in backend: `Services/`, `Models/`, `Middleware/`, `Helpers/`

**Identifiers:**
- Types: PascalCase (ChatSession, APIClient, HealthResponse)
- Functions/methods: camelCase (sendMessage, loadMessageHistory)
- Properties: camelCase (isStreaming, sessionId, messageCount)
- Constants: camelCase (defaultCacheTTL = 30)
- Enums: PascalCase with lowercased cases (SessionStatus.active, ActiveScreen.home)

**URL Paths:**
- Backend routes: snake_case (e.g., `/api/v1/chat/stream`, `/api/v1/sessions`)
- Deep links: lowercase with slashes (e.g., `ils://sessions/uuid`, `ils://browser`)
- Query params: camelCase (e.g., `?page=1&limit=50`)

## Where to Add New Code

**New Feature (requires UI + backend):**
- **Primary code:**
  - iOS: Create `Views/FeatureName/FeatureView.swift`, `ViewModels/FeatureViewModel.swift`
  - macOS: Create corresponding views in `ILSMacApp/Views/FeatureName/`
  - Backend: Create `Controllers/FeatureController.swift`, service class in `Services/`
  - Shared: Add model to `Sources/ILSShared/Models/FeatureModel.swift` if needed
- **Tests:**
  - iOS: `Tests/ILSSharedTests/FeatureModelTests.swift`
  - Backend: `Tests/ILSBackendTests/FeatureControllerTests.swift`
- **Pattern:** Always add to both iOS and macOS simultaneously (cross-platform parity)

**New Component/Module:**
- **Implementation:**
  - Reusable UI: `ILSApp/ILSApp/Views/Components/ComponentName.swift`
  - Shared model: `Sources/ILSShared/Models/EntityName.swift`
  - Shared DTO: `Sources/ILSShared/DTOs/RequestName.swift`
  - Backend service: `Sources/ILSBackend/Services/ServiceName.swift`
- **Registration:**
  - Backend service: Instantiate in `ChatController` or relevant controller
  - Shared model: Import in `Package.swift` products (automatic via `ILSShared` target)

**Utilities/Helpers:**
- Shared: `Sources/ILSShared/Utilities/HelperName.swift`
- iOS-only: `ILSApp/ILSApp/Utils/HelperName.swift`
- Backend-only: `Sources/ILSBackend/Helpers/HelperName.swift`
- Extensions: Add to existing `*.swift` or create `Extensions/TypeExtension.swift`

**New Theme:**
- Implementation: `ILSApp/ILSApp/Theme/YourTheme.swift` conforming to `AppTheme` protocol
- Registration: Add case to `ThemeManager.allThemes` array
- Properties: Colors (bgPrimary, textSecondary, accent), fonts (fontTitle, fontCaption), spacing (spacingXS, spacingLG)

**New Backend Endpoint:**
- Controller: Add method to existing controller or create new `NewController.swift`
- Route: Add to `boot(routes:)` in controller or register new controller in `routes.swift`
- Model: Add Fluent model if persisting to database
- Migration: Add to migrations if schema change required
- Test: Add to `Tests/ILSBackendTests/NewControllerTests.swift`

**New Migration:**
- File: `Sources/ILSBackend/Migrations/Create[Entity].swift` or `Alter[Entity].swift`
- Registration: Add to `app.migrations.add()` in `configure.swift`
- Pattern: Implement `AsyncMigration` protocol with `prepare()` and `revert()`

## Special Directories

**ILSApp/ILSApp/Assets.xcassets:**
- Purpose: App icons, launch screen images, accent colors
- Generated: No (hand-curated)
- Committed: Yes

**ILSApp/ILSApp/Resources:**
- Purpose: Static strings, Info.plist configuration
- Generated: No
- Committed: Yes

**Sources/ILSBackend/Scripts/:**
- Purpose: Python wrapper for Claude CLI execution (legacy/fallback)
- Generated: No
- Committed: Yes (but unused in current flow; ClaudeExecutorService uses direct Process)

**.planning/codebase/**
- Purpose: Architecture documentation (this directory)
- Generated: No (manually written)
- Committed: Yes

**DerivedData/**
- Purpose: Xcode build artifacts (executables, compiled objects)
- Generated: Yes (by Xcode)
- Committed: No (.gitignored)

**.build/**
- Purpose: Swift Package build cache
- Generated: Yes (by `swift build`)
- Committed: No (.gitignored)

**ILSFullStack.xcworkspace/xcuserdata/**
- Purpose: IDE scheme, breakpoint, and window state per developer
- Generated: Yes (by Xcode)
- Committed: No (.gitignored)

---

*Structure analysis: 2026-02-19*
