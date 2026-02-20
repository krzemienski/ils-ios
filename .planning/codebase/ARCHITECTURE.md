# Architecture

**Analysis Date:** 2026-02-19

## Pattern Overview

**Overall:** Client-Server with Shared Models + Multi-Platform UI

**Key Characteristics:**
- **iOS/macOS dual apps** sharing backend communication layer and business models
- **MVVM + @Observable** state management in SwiftUI
- **Actor-based async** networking and background operations
- **Vapor + Fluent ORM** backend with SQLite persistence
- **Server-Sent Events (SSE)** for real-time chat streaming
- **Deep linking** with `ils://` URL scheme for cross-app navigation

## Layers

**Presentation Layer (iOS/macOS):**
- Purpose: SwiftUI views, navigation, user interaction
- Location: `ILSApp/ILSApp/Views/` (iOS) and `ILSApp/ILSMacApp/Views/` (macOS)
- Contains: Screen views (Home, Chat, Browser, Settings, etc.), reusable components
- Depends on: ViewModels, AppState, Theme system, ILSShared models
- Used by: Users directly interact with screens

**ViewModel Layer (iOS/macOS):**
- Purpose: Coordinate between UI and services, manage state for screens
- Location: `ILSApp/ILSApp/ViewModels/` (iOS) and `ILSApp/ILSMacApp/` (macOS uses limited VMs)
- Contains: `ChatViewModel`, `SettingsViewModel`, `SystemMetricsViewModel`, `TeamsViewModel`, etc.
- Depends on: APIClient, SSEClient, services (e.g., ConnectionManager, CacheService)
- Used by: Views observe @Observable VMs to reactively update

**Service Layer (iOS/macOS):**
- Purpose: Network communication, local state management, singleton managers
- Location: `ILSApp/ILSApp/Services/` (iOS)
- Contains: `APIClient` (HTTP), `SSEClient` (streaming), `ConnectionManager`, `PollingManager`, `CacheService`, `SyncCoordinator`, `KeychainService`, `ThemeManager`
- Depends on: Foundation, ILSShared models, URLSession
- Used by: AppState, ViewModels, directly by views

**Shared Models:**
- Purpose: Type definitions used by both iOS and backend
- Location: `Sources/ILSShared/Models/` and `Sources/ILSShared/DTOs/`
- Contains: `ChatSession`, `ChatMessage`, `StreamMessage`, `ClaudeModel`, `SessionStatus`, `PermissionRequest`, API response wrappers
- Depends on: Foundation
- Used by: Frontend and backend for serialization/deserialization

**Backend API Layer (Vapor):**
- Purpose: HTTP request handling, routing, middleware
- Location: `Sources/ILSBackend/Controllers/`
- Contains: 14 controllers (Health, Sessions, Chat, Projects, Skills, MCP, Plugins, Config, Stats, Themes, System, Teams, Tunnel, Fleet)
- Depends on: Vapor framework, models
- Used by: iOS/macOS apps via REST + SSE

**Backend Service Layer (Vapor):**
- Purpose: Business logic, Claude CLI execution, file system operations
- Location: `Sources/ILSBackend/Services/`
- Contains: `ClaudeExecutorService` (runs Claude CLI), `FileSystemService`, `ConfigFileService`, `SessionFileService`, `MCPFileService`, `SystemMetricsService`, etc.
- Depends on: Foundation, Process APIs, file I/O
- Used by: Controllers

**Backend Data Layer (Vapor):**
- Purpose: Database models, migrations, ORM mapping
- Location: `Sources/ILSBackend/Models/` and `Sources/ILSBackend/Migrations/`
- Contains: Fluent models (SessionModel, ProjectModel, MessageModel, ThemeModel, etc.), migration scripts
- Depends on: Fluent ORM
- Used by: Services and Controllers for persistence

**App State & Coordination:**
- Purpose: Global app lifecycle, connection state, navigation routing
- Location: `ILSAppApp.swift` (iOS) and `ILSMacApp.swift` (macOS)
- Contains: `AppState` (@Observable), scene phase handling, URL routing
- Depends on: ConnectionManager, services
- Used by: All views via @Environment

## Data Flow

**Chat Message Flow (User → Claude → Display):**

1. User taps send in `ChatView`
2. `ChatViewModel.sendMessage()` calls `apiClient.post("/chat/stream", body: ChatStreamRequest)`
3. Backend `ChatController.stream()` receives request, validates, executes Claude CLI
4. Backend spawns `ClaudeExecutorService.executeWithSDK()` which runs Claude via subprocess
5. Backend streams response as SSE events, iOS `SSEClient` receives and parses NDJSON
6. `ChatViewModel` batches streamed `StreamMessage` events, appends to `messages` array
7. `ChatView` observes `messages` changes, re-renders with new content
8. On completion, backend persists message to database

**Session Fetch Flow:**

1. `HomeView` or sidebar loads on app launch
2. View/VM calls `apiClient.get("/sessions")` → returns `APIResponse<[ChatSession]>`
3. Backend `SessionsController.list()` queries Fluent `SessionModel` from SQLite
4. Decoded `ChatSession` objects populate list view
5. User taps session row → navigates via `navigationDestination(item:)` to `ChatView`
6. `activeScreen` state changes to `.chat(session)` → triggers message history load

**Server Connection Flow:**

1. App launches, `AppState.init()` creates `ConnectionManager`
2. `ConnectionManager` loads server URL from `UserDefaults` (or defaults to `http://localhost:9999`)
3. `PollingManager` periodically calls `apiClient.healthCheck()`
4. If health check fails, UI shows `OfflineIndicator`, enables retry queue in `SyncCoordinator`
5. When connection restored, queued operations replay via `apiClient.rawRequest()`

**State Management:**

- Global: `AppState` (@Observable) manages connection, navigation, selected project
- View-level: `@State` in individual views for UI-only state (text input, sheet presentation)
- ViewModel-level: `@Observable` classes manage fetched data (messages, sessions, metrics)
- Persistent: `UserDefaults` for server URL, theme preference, API key (migrated to Keychain)
- Cache: `APIClient` caches GET responses for 30 seconds (configurable per call)

## Key Abstractions

**APIResponse<T> Wrapper:**
- Purpose: Consistent envelope for all API responses (success, data, error)
- Examples: `APIResponse<[ChatSession]>`, `APIResponse<ChatMessage>`
- Pattern: Decoded by `APIClient.get/post/put/delete()` generically
- File: `ILSApp/ILSApp/Services/APIClient.swift` (lines 306-310)

**ActiveScreen Enum:**
- Purpose: Navigation routing with associated values
- Examples: `.home`, `.chat(ChatSession)`, `.browser`, `.settings`
- Pattern: Drives `@State activeScreen` in `SidebarRootView`, switches rendering via `switch activeScreen`
- File: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (lines 6-43)

**ChatSession Model:**
- Purpose: Represents a conversation with optional persistence
- Properties: id, name, model (Claude version), status, messageCount, cost, source (.ils or .external)
- Serialization: Codable for JSON encoding/decoding
- File: `Sources/ILSShared/Models/Session.swift` (lines 114-203)

**SSEClient:**
- Purpose: Parse Server-Sent Events stream from backend
- Mechanism: Opens persistent connection to `/chat/stream` endpoint
- Output: Emits `StreamMessage` events (token deltas, thinking, permissions)
- Pattern: Injected into `ChatViewModel.configure()`, observed via `@ObservationIgnored` cancellables
- File: `ILSApp/ILSApp/Services/SSEClient.swift`

**ClaudeExecutorService:**
- Purpose: Execute Claude CLI as subprocess with streaming stdout capture
- Mechanism: Uses `Process` + `DispatchQueue` to read NDJSON from Claude SDK
- Output: Parses structured messages (text, tool_use, thinking, permission_request)
- Pattern: Invoked by `ChatController.stream()`, timeouts at 30s initial + 5min total
- File: `Sources/ILSBackend/Services/ClaudeExecutorService.swift`

**ThemeSnapshot + ThemeManager:**
- Purpose: Runtime theme colors, fonts, spacing (not Xcode assets)
- Mechanism: `ThemeManager` holds current theme, generates `ThemeSnapshot` for `@Environment(\.theme)`
- Themes: Concrete types (ObsidianTheme, GhostTheme, etc.) conform to `AppTheme` protocol
- Pattern: All views inject via `@Environment(\.theme)` and access colors/sizes directly
- Files: `ILSApp/ILSApp/Theme/` directory (~30 theme + component files)

## Entry Points

**iOS App:**
- Location: `ILSAppApp.swift` (lines 6-70)
- Triggers: `@main` struct, launches `SidebarRootView()`
- Responsibilities: Scene setup, theme injection, AppState initialization, LaunchScreen display, TipKit config

**macOS App:**
- Location: `ILSMacApp.swift` (lines 18-88)
- Triggers: `@main` struct with `AppDelegate`, launches `MacContentView()`
- Responsibilities: App delegate attachment, multi-window support (WindowGroup + Session windows), command menu

**Backend App:**
- Location: `Sources/ILSBackend/App/main.swift`
- Triggers: Swift Package executable target runs `Application` initialization
- Responsibilities: Vapor app configuration via `configure()`, route registration via `routes()`

**Deep Link Handling:**
- iOS: `ILSAppApp.onOpenURL` → `appState.handleURL(url)` (lines 32-34)
- macOS: `MacContentView.onOpenURL` → `appState.handleURL(url)`
- Supported: `ils://home`, `ils://sessions/{uuid}`, `ils://browser`, `ils://settings`, `ils://system`, `ils://teams`, `ils://fleet`, `ils://themes`
- Pattern: Parses URL host, sets `navigationIntent` which triggers `onChange` → screen switch

## Error Handling

**Strategy:** Layered try-catch with user-friendly messages at presentation layer

**Patterns:**

- **APIError enum** (ILSApp/ILSApp/Services/APIClient.swift, lines 343-435):
  - Categorizes failures: network, HTTP status, decoding, unauthorized, server error
  - Provides `localizedDescription` and `isRetriable` computed properties
  - Automatically retried on transient errors (3 attempts with exponential backoff)

- **Backend Error Middleware** (`Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift`):
  - Catches all Vapor errors, wraps in structured `ServerErrorBody` with code/reason
  - iOS receives structured error, maps to user-facing message

- **Offline Handling**:
  - `SyncCoordinator` queues failed mutations (POST/PUT/DELETE) to local database
  - On reconnection, replays via `apiClient.rawRequest()`
  - UI shows `OfflineIndicator` while disconnected

- **Streaming Errors**:
  - SSE connection timeout: 60s initial, 5min total (configurable in ChatViewModel)
  - `ClaudeExecutorService` catches process errors, returns structured error response
  - UI displays error message in chat view, allows retry

## Cross-Cutting Concerns

**Logging:**
- Approach: Swift `os.Logger` in backend, print-based in iOS
- Files: `Sources/ILSBackend/Middleware/RequestLoggingMiddleware.swift` logs HTTP requests
- Backend logs Claude execution, database operations

**Validation:**
- Backend: `PathSanitizer` validates string lengths, file paths before processing
- Frontend: `ChatViewModel` validates prompt non-empty before send, form validation in Settings
- File: `Sources/ILSBackend/Helpers/PathSanitizer.swift`

**Authentication:**
- Optional API key via `ILS_API_KEY` env var on backend (stored in Keychain on iOS)
- Middleware: `APIKeyMiddleware` enforces Bearer token in Authorization header
- iOS: `APIClient.applyAuth()` adds header if key configured

**Rate Limiting:**
- Backend: `RateLimitMiddleware` with in-memory store (configurable IP/endpoint limits)
- File: `Sources/ILSBackend/Middleware/RateLimitMiddleware.swift`

**CORS:**
- Configured in `Sources/ILSBackend/App/configure.swift` (lines 6-37)
- Allows localhost:3000, localhost:8080, localhost:9999 by default
- Configurable via `ILS_CORS_ORIGINS` env var for production

---

*Architecture analysis: 2026-02-19*
