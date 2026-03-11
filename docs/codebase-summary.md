# ILS Codebase Structure & Organization

**Version:** 1.1.1 | **Last Updated:** 2026-03-10 | **Total LOC:** ~152,428

---

## Directory Structure

```
ils-ios/
├── ILSApp/
│   ├── ILSApp/                    # iOS app (149 Swift files, ~100K LOC)
│   │   ├── ILSAppApp.swift        # @main entry point, global state
│   │   ├── Views/                 # 24 screen directories
│   │   │   ├── Chat/              # ChatView + related components (31 files)
│   │   │   ├── Sessions/          # SessionsView, detail, new (25 files)
│   │   │   ├── Settings/          # Settings, profiles, config (19 files)
│   │   │   ├── Dashboard/         # DashboardView with widgets (20 files)
│   │   │   ├── Browser/           # Skills, plugins, MCP (6 files)
│   │   │   ├── Onboarding/        # Setup, connection, auth (11 files)
│   │   │   ├── Teams/             # Agent teams, queue (10 files)
│   │   │   ├── Themes/            # ThemeEditor, switcher (14 files)
│   │   │   └── [15 more] — Hooks, System, Workflows, etc.
│   │   ├── ViewModels/            # 50 @Observable @MainActor classes
│   │   │   ├── ChatViewModel.swift
│   │   │   ├── SessionsViewModel.swift
│   │   │   ├── DashboardViewModel.swift
│   │   │   └── [47 more]
│   │   ├── Services/              # 47 service classes
│   │   │   ├── APIClient.swift    # Actor-based HTTP (400+ LOC)
│   │   │   ├── SSEClient.swift    # Server-Sent Events (200+ LOC)
│   │   │   ├── AuthService.swift
│   │   │   ├── FeatureGate.swift  # Premium tier checks
│   │   │   ├── ThemeManager.swift # Theme selection state
│   │   │   ├── LocalDatabase.swift # SQLite caching
│   │   │   └── [41 more]
│   │   ├── Theme/                 # 8 files, 4.6K LOC
│   │   │   ├── ThemeSnapshot.swift # Concrete struct (not existential)
│   │   │   ├── ILSTheme.swift     # Orange accent, system colors
│   │   │   ├── AppTheme.swift     # Protocol definition
│   │   │   └── [5 more themes]
│   │   ├── Widgets/               # WidgetKit (2-3 files)
│   │   ├── LiveActivity/          # Live activity support
│   │   ├── Intents/               # App Intents + Shortcuts
│   │   └── Utilities/             # Helpers, extensions
│   ├── ILSMacApp/                 # macOS app (14 Swift files, 7.5K LOC)
│   │   ├── MacAppDelegate.swift
│   │   ├── MacContentView.swift   # Dashboard focused
│   │   ├── MacChatView.swift
│   │   └── [11 more]
│   └── ILSApp.xcodeproj           # Xcode project
├── Sources/
│   ├── ILSBackend/                # Vapor backend (52 Swift files, 26.6K LOC)
│   │   ├── App/
│   │   │   ├── configure.swift    # Server config, middleware, routes
│   │   │   ├── Models/            # Database models (Fluent)
│   │   │   └── Migrations/        # Database schema versioning
│   │   ├── Controllers/           # 31 controllers (~15K LOC)
│   │   │   ├── SessionsController.swift (1,464 LOC)
│   │   │   ├── MCPController.swift (846 LOC)
│   │   │   ├── PluginsController.swift (514 LOC)
│   │   │   ├── ChatController.swift (streaming)
│   │   │   └── [27 more]
│   │   ├── Services/              # 39 services (~8K LOC)
│   │   │   ├── ClaudeExecutorService.swift (869 LOC - Python SDK)
│   │   │   ├── ProcessMonitorService.swift (719 LOC)
│   │   │   ├── WorkflowExecutionEngine.swift (535 LOC)
│   │   │   └── [36 more]
│   │   ├── Middleware/            # Auth, rate limiting, error handling
│   │   └── Utils/                 # Extensions, helpers
│   └── ILSShared/                 # Shared models (26 Swift files, 11.7K LOC)
│       ├── Models/                # Domain models
│       │   ├── Session.swift
│       │   ├── ChatMessage.swift
│       │   ├── Skill.swift
│       │   ├── Plugin.swift
│       │   ├── MCPServer.swift
│       │   └── [20 more]
│       ├── DTOs/                  # API request/response types
│       └── Utilities/             # Shared helpers
├── docs/
│   ├── API.md                     # Full API reference (v1.3, 87KB)
│   ├── RUNNING_BACKEND.md         # Backend deployment guide
│   ├── ROADMAP.md                 # 13-phase roadmap (58 days)
│   ├── code-standards.md          # Swift conventions (THIS FILE'S SIBLING)
│   ├── system-architecture.md     # Architecture diagrams
│   ├── design-guidelines.md       # Theme system, component library
│   └── specs/                     # Implementation specs (gap analysis, etc.)
├── scripts/
│   ├── setup.sh                   # Dev environment setup
│   ├── install-backend-service.sh # launchd installation
│   ├── run_regression_tests.sh
│   └── sdk-wrapper.py             # Python Agent SDK wrapper
├── fastlane/                      # CI/CD configuration
│   ├── Fastfile                   # build, beta, screenshots lanes
│   ├── Appfile
│   └── Matchfile                  # Code signing
├── AppStoreMetadata/
│   ├── Screenshots/               # App Store screenshots
│   └── metadata/                  # Localized descriptions
├── .claude/                       # Claude Code configuration
│   ├── rules/                     # Development rules
│   └── skills/                    # Custom skills
├── .planning/                     # Planning documents
├── .github/                       # GitHub Actions CI
├── Package.swift                  # Swift Package dependencies
├── Package.resolved               # Locked dependency versions
└── .swiftlint.yml                 # Linting configuration
```

---

## File Organization Principles

### 1. Views (Screen Components)

Each screen lives in its own directory with cohesion-focused files:

```
Views/Chat/
├── ChatView.swift              # Main container
├── ChatMessageView.swift       # Single message cell
├── ChatInputBar.swift          # Message input
├── StreamingIndicator.swift    # "Claude is responding" UI
├── PermissionRequestView.swift # Permission prompts
├── MessageSearchBar.swift
├── CodeBlockView.swift         # Syntax-highlighted code
└── MessageFormatters.swift     # Date, token, formatting
```

**Rule:** One screen = one directory. No screen files outside their directory.

### 2. ViewModels

- One ViewModel per screen (MVVM pattern)
- File name: `{Screen}ViewModel.swift`
- Annotation: `@Observable @MainActor`
- Size limit: ~300 LOC per file (split if exceeded)

Example:
```swift
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    // ...
}
```

### 3. Services (Business Logic)

Services are singletons or factory-created managers:

```
Services/
├── APIClient.swift         # HTTP, REST methods, caching, ETags
├── SSEClient.swift         # Server-Sent Events streaming
├── AuthService.swift       # Auth token, login/logout
├── KeychainService.swift   # Secure credential storage
├── FeatureGate.swift       # Premium feature checks
├── ThemeManager.swift      # Theme selection + caching
├── LocalDatabase.swift     # SQLite wrapper
├── NotificationService.swift
├── PermissionService.swift # Permission approval logic
└── [39 more]
```

**Access:** `ServiceName.shared` singleton pattern.

### 4. Theme System

```
Theme/
├── ThemeSnapshot.swift     # Concrete struct, 100+ color/text properties
├── AppTheme.swift          # Protocol with required properties
├── ILSTheme.swift          # Hot orange, system-adaptive (main theme)
├── CustomTheme.swift       # User-created theme (Codable)
├── EntityType.swift        # Color associations for data types
├── GlassCard.swift         # Glassmorphism component
├── CyberpunkEffects.swift  # Visual effects
└── DensityManager.swift    # Compact/Normal/Spacious layout
```

**Important:** Use `ThemeSnapshot` (concrete struct), not `any AppTheme` (existential). Eliminates container overhead at 82 sites.

### 5. Shared Models

```
Sources/ILSShared/
├── Models/
│   ├── Session.swift       # Hashable, Codable, Sendable
│   ├── ChatMessage.swift
│   ├── Skill.swift
│   ├── Plugin.swift
│   ├── MCPServer.swift
│   └── [20 more domain models]
├── DTOs/                   # API types (mirroring backend routes)
│   ├── SessionsResponse.swift
│   ├── ChatRequest.swift
│   └── APIResponse<T>.swift
└── Utilities/
    ├── DateFormatters.swift
    ├── Extensions.swift
    └── Constants.swift
```

---

## File Size Distribution

### iOS App (401 files)

| Category | Files | LOC | Avg File |
|----------|-------|-----|----------|
| Views | 108 | 31,425 | 291 |
| ViewModels | 50 | 12,092 | 242 |
| Services | 47 | 12,037 | 256 |
| Theme | 8 | 4,621 | 578 |
| Widgets | 3 | 1,245 | 415 |
| Utilities | 185 | 38,458 | 208 |
| **Total** | **401** | **100,578** | **251** |

**Goal:** Keep individual files under 400 LOC (split large screens into sub-views).

### Backend (52 files)

| Category | Files | LOC | Avg File |
|----------|-------|-----|----------|
| Controllers | 31 | 15,240 | 491 |
| Services | 39 | 8,432 | 216 |
| Models | 15 | 2,100 | 140 |
| Middleware | 4 | 680 | 170 |
| **Total** | **52** | **26,636** | **512** |

### Shared Models (26 files)

| Category | Files | LOC | Avg File |
|----------|-------|-----|----------|
| Models | 18 | 6,234 | 346 |
| DTOs | 5 | 3,456 | 691 |
| Utilities | 3 | 2,072 | 691 |
| **Total** | **26** | **11,762** | **452** |

---

## Module Dependencies

### Frontend → Backend

```
ChatView (iOS)
    ↓
ChatViewModel (@Observable)
    ↓
APIClient.post("/chat/stream") + SSEClient.connect()
    ↓
ChatController → ClaudeExecutorService
    ↓
Python sdk-wrapper.py → Claude CLI → Anthropic API
    ↓
SSE stream → ChatView (real-time)
```

### Data Flow (Session List → Chat)

```
SessionsView
    ↓
SessionsViewModel.loadSessions()
    ↓
APIClient.get("/sessions") [cached, ~22K items]
    ↓
LocalDatabase (fallback if offline)
    ↓
NavigationLink → ChatView
    ↓
ChatViewModel.loadHistory(sessionId)
    ↓
APIClient.get("/sessions/{id}/messages")
    ↓
Display in ChatView
```

---

## Key Architectural Patterns

### 1. Actor-Based Concurrency (APIClient)

```swift
actor APIClient {
    private var inFlightGETs: [String: Task] = [:]  // Request dedup
    func get<T>(_ path: String) async throws -> T {
        // Thread-safe, automatic deduplication
    }
}
```

### 2. Observable ViewModels

```swift
@Observable @MainActor
class MyViewModel {
    var items: [Item] = []  // Automatically observable
    nonisolated(unsafe) var task: Task<Void, Never>?  // For cleanup in deinit

    deinit {
        task?.cancel()  // Prevent memory leaks
    }
}
```

### 3. Server-Sent Events (Chat Streaming)

```swift
let stream = try await SSEClient.shared.connect(to: url)
for try await event in stream {
    // Handle streaming message in real-time
}
```

### 4. Conditional Requests (Bandwidth Optimization)

```swift
// APIClient stores ETags and sends If-None-Match
// Server returns 304 Not Modified if unchanged
// Saves bandwidth for frequently-accessed endpoints
```

### 5. Theme as Environment Value

```swift
@Environment(\.theme) private var theme: ThemeSnapshot
// Use theme.bgPrimary, theme.accent, theme.fontCaption, etc.
```

---

## Database Schema

### SQLite (ils.sqlite)

Managed by Vapor Fluent ORM:

```
sessions
├── id (UUID, primary)
├── name (String)
├── projectId (UUID, foreign)
├── model (String)
├── messageCount (Int)
└── [10+ properties]

messages
├── id (UUID, primary)
├── sessionId (UUID, foreign)
├── role (String: "user" | "assistant")
├── content (String)
├── tokens (Int)
└── timestamp (Date)

[35+ more tables for projects, skills, plugins, etc.]
```

See `Sources/ILSBackend/App/Models/` for complete schema.

---

## Build Artifacts

### Xcode Paths

```
~/Library/Developer/Xcode/DerivedData/
├── ILSApp-{random}/
│   └── Build/Products/
│       └── Debug-iphonesimulator/
│           └── ILSApp.app  ← iOS app binary
└── ILSFullStack-{random}/
    └── Build/Products/
        ├── Debug-iphonesimulator/
        │   └── ILSApp.app  ← iOS app
        └── Debug/
            └── ILSMacApp.app  ← macOS app
```

### Executable Verification

```bash
# iOS
stat ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app/ILSApp

# Backend
swift build 2>&1 | grep -i "product"
./.build/debug/ILSBackend
```

---

## Dependency Management

### Swift Packages (Package.swift)

| Package | Purpose |
|---------|---------|
| Vapor | Web framework (backend) |
| FluentKit | ORM for database access |
| SQLiteKit | SQLite driver |
| Crypto | Secure hashing (backend only) |
| ILSShared | Shared models (SPM local) |

### External (CocoaPods, SPM)

| Pod | Purpose | Target |
|-----|---------|--------|
| StoreKit 2 | In-app purchases (premium) | iOS |
| TipKit | Onboarding tips | iOS |
| UserNotifications | Local notifications | iOS |
| WidgetKit | Lock screen widgets | iOS |

---

## Code Organization Best Practices

1. **One Concern Per File** — Each file has a single responsibility
2. **Alphabetical Within Section** — Services, views, etc. sorted A-Z
3. **No Circular Dependencies** — Views don't import other views
4. **Services at Bottom** — Views depend on services, not vice versa
5. **Tests Parallel Structure** — Tests/Views/Chat/ mirrors ILSApp/Views/Chat/

---

## Next Steps for Navigation

- **Understanding API Routes?** → See `docs/API.md`
- **Backend architecture?** → See `docs/system-architecture.md`
- **Code standards?** → See `docs/code-standards.md`
- **Design tokens & theme?** → See `docs/design-guidelines.md`
