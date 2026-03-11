# ILS iOS/macOS — Key Architectural Patterns

**Last Updated:** 2026-03-10
**Audience:** Developers onboarding to the codebase

---

## 1. ThemeSnapshot Pattern

**Purpose:** Eliminate existential container overhead (`any AppTheme`) on every view body evaluation by capturing all theme properties into a concrete value type injected via SwiftUI Environment.

**Key files:**
- `ILSApp/ILSApp/Theme/AppTheme.swift` — `AppTheme` protocol + `ThemeManager` class
- `ILSApp/ILSApp/Theme/ThemeSnapshot.swift` — concrete snapshot struct
- `ILSApp/ILSApp/Theme/Themes/` — 13 built-in theme implementations

**How it works:**

`AppTheme` is a protocol with ~40 color, spacing, typography, and geometry properties. `ThemeManager` holds `currentTheme: any AppTheme` internally but exposes `currentSnapshot: ThemeSnapshot` — a plain `Sendable` struct built once per theme switch. Views read from the snapshot via `@Environment(\.theme)`.

```swift
// In every view — zero-cost struct access, no dynamic dispatch
@Environment(\.theme) private var theme: ThemeSnapshot

Text("Label")
    .foregroundStyle(theme.textPrimary)
    .padding(theme.spacingMD)
    .font(.system(size: theme.fontBody, design: theme.fontDesign))
```

**Theme switching:**
```swift
ThemeManager.shared.setTheme("obsidian")  // persists to UserDefaults + iCloud KV
```

**Built-in themes (13):** Cyberpunk (default), Obsidian, Slate, Midnight, GhostProtocol, NeonNoir, ElectricGrid, Ember, Crimson, Carbon, Graphite, Paper, Snow.

**Density scaling:** `ThemeSnapshot` is initialized with an `InformationDensity` (.compact / .standard / .comfortable). Spacing multipliers (0.85 / 1.0 / 1.15) and font multipliers (0.90 / 1.0 / 1.10) are baked into the snapshot at init time with HIG minimum floors applied.

**Entity colors** (consistent across all themes — defined in `AppTheme` extension defaults):
| Entity | Hex |
|--------|-----|
| Session | `#3B82F6` (blue) |
| Project | `#8B5CF6` (purple) |
| Skill | `#F59E0B` (amber) |
| MCP | `#10B981` (green) |
| Plugin | `#EC4899` (pink) |
| System | `#06B6D4` (cyan) |

**Gotchas:**
- NEVER use `any AppTheme` in view bodies — always use `ThemeSnapshot` via `@Environment(\.theme)`
- `ThemeEnvironmentKey.defaultValue` is `ThemeSnapshot(CyberpunkTheme())` — previews that omit `.environment(\.theme, ...)` get Cyberpunk
- Custom themes registered via `ThemeManager.registerTheme(_:)` appear alongside built-ins in the theme picker

---

## 2. FeatureGate System

**Purpose:** Single source of truth for premium subscription gating. Prevents ad-hoc `if isPremium` checks scattered across views.

**Key files:**
- `ILSApp/ILSApp/Services/FeatureGate.swift` — `FeatureGate` singleton
- `ILSApp/ILSApp/Services/SubscriptionManager.swift` — StoreKit subscription state
- `ILSApp/ILSApp/Views/Premium/FeatureGateView.swift` — SwiftUI gate wrapper
- `ILSApp/ILSApp/Views/Premium/PremiumView.swift` — paywall sheet

**Feature matrix:**
| Feature | Free | Premium |
|---------|------|---------|
| `.chatExport` | ❌ | ✅ |
| `.customThemes` | 3 themes | All 13 |
| `.advancedMonitoring` | ❌ | ✅ |
| `.unlimitedSessions` | 5 max | Unlimited |

**Imperative check (ViewModels/Services):**
```swift
if FeatureGate.shared.isAvailable(.chatExport) {
    // proceed
}
```

**Declarative gate (Views):**
```swift
FeatureGateView(feature: .chatExport) {
    ExportButton()  // shown only to premium users
}
// Free users see lock icon + "Upgrade to Premium" button → PremiumView sheet
```

**Gotchas:**
- NEVER check `isPremium` directly in views — always use `FeatureGateView`
- NEVER add new gated features without adding to `FeatureGate.Feature` enum first
- Free session limit constant: `FeatureGate.freeSessionLimit` (= 5)

---

## 3. SSE Streaming

**Purpose:** Stream Claude responses from backend to iOS client via Server-Sent Events, with reconnection, heartbeat watchdog, and network-restoration handling.

**Key files:**
- `ILSApp/ILSApp/Services/SSEClient.swift` — SSE connection + reconnection logic
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — orchestrates SSEClient
- `Sources/ILSBackend/Controllers/` — `/api/v1/chat/stream` POST endpoint

**SSEClient lifecycle:**
```swift
// Start stream
sseClient.startStream(request: ChatStreamRequest(...))

// Cancel
sseClient.cancel()

// Cleanup (call from .onDisappear — invalidates URLSession)
sseClient.cleanup()
```

**URLSession config:**
- `timeoutIntervalForRequest`: 300s (5 min) for initial response
- `timeoutIntervalForResource`: 3600s (1 hr) for entire stream
- `allowsConstrainedNetworkAccess`: `false` (Low Data Mode blocks streaming)

**Heartbeat watchdog:** A detached `Task` checks `LastActivityTracker` every 15s. If no data or heartbeat comment received in 45s (90s in Low Power Mode), it cancels the stream task. Uses a generation counter (`streamGeneration`) so stale watchdogs from previous connections do not cancel current ones (CONC-001).

**Reconnection:** Exponential backoff from 2s, capped at 30s, max 10 attempts. Only retries on network-class `URLError` codes (lost connection, timeout, DNS failure, etc.). Non-network errors propagate immediately.

**Network restoration:** `networkObserver` listens for `.networkDidBecomeAvailable`. Cancels any active backoff sleep for immediate retry, or restarts a fully-stopped stream.

**Background handling (iOS):** `UIApplication.didEnterBackgroundNotification` cancels the active stream to conserve battery radio (ENRG-05).

**SSE event parsing:**
```
event: done        → sets isStreaming = false
event: messageId   → stores userMessageId / assistantMessageId
data: {...}        → decoded as StreamMessage, appended to messages
: heartbeat        → resets activity tracker, no message emitted
```

**Gotchas:**
- `@preconcurrency import Foundation` required — URLSession's Sendable conformance triggers false positives in strict concurrency mode
- `LastActivityTracker` uses `OSAllocatedUnfairLock` (not actor) — actor-hops on every SSE line would be too expensive
- `fetchBytes(session:request:)` is `nonisolated static` to avoid SE-0430 `sending` warnings in TaskGroup

---

## 4. SDK Integration (Python Claude Agent SDK)

**Purpose:** Execute Claude queries from the Vapor backend without spawning `claude -p` directly (which hangs when called inside an active Claude Code session due to nesting detection).

**Key files:**
- `scripts/sdk-wrapper.py` — Python wrapper calling `claude_agent_sdk.query()`
- `Sources/ILSBackend/Services/ClaudeExecutorService.swift` — spawns the wrapper, reads NDJSON

**Architecture:**
```
ChatController (Vapor)
  → ClaudeExecutorService.execute()
    → executeWithSDK()
      → Process: /bin/zsh -l -c "python3 scripts/sdk-wrapper.py '<json-config>'"
        → sdk-wrapper.py: asyncio + claude_agent_sdk.query()
          → NDJSON on stdout
      → DispatchQueue reads stdout lines
      → CLIMessageConverter decodes to StreamMessage
    → AsyncThrowingStream<StreamMessage>
  → SSE response to iOS client
```

**Critical: env var stripping (SEC-004):** `filteredEnvironment()` uses an allowlist — only needed vars (`HOME`, `PATH`, `LANG`, `NODE_PATH`, etc.) are forwarded. This strips `CLAUDECODE=1` and `CLAUDE_CODE_*` env vars that Claude CLI's nesting detection uses to block execution inside active CC sessions.

**Two-tier timeout:**
- 30s initial: fires if no stdout data arrives (detects stuck process)
- 5min total: kills runaway processes unconditionally

**NDJSON message types emitted by sdk-wrapper.py:**
| Type | Subtype | Meaning |
|------|---------|---------|
| `system` | `init` | Stream start |
| `assistant` | — | Claude response content blocks |
| `user` | — | Echo of user message |
| `result` | `success` | Completion with cost/usage |
| `result` | `error` | Failure |

**`sdk-wrapper.py` content block types:** `text`, `tool_use`, `tool_result`, `thinking`. Falls back to class name inspection when `.type` attribute is `None` (SDK version variance).

**Benign exception handling:** If `claude_agent_sdk` raises `UnknownMessageType` (e.g., `rate_limit_event`) after content was already received, the wrapper emits a synthetic `result/success` instead of propagating an error.

**Gotchas:**
- SDK wrapper is Python (`claude_agent_sdk` pip package) — not Node.js. The Swift file comments mention `sdk-wrapper.mjs` in some places but the active wrapper is `scripts/sdk-wrapper.py`
- `process.waitUntilExit()` MUST be called before accessing `process.terminationStatus` — omitting it throws `NSInvalidArgumentException`
- SDK inherits OAuth auth from Claude CLI — no `ANTHROPIC_API_KEY` needed or used

---

## 5. Navigation Architecture

**Purpose:** Unified screen routing across iPhone (overlay sidebar) and iPad/macOS (persistent sidebar), driven by `ActiveScreen` enum with `@SceneStorage` persistence.

**Key files:**
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — iOS root, `ActiveScreen` enum definition
- `ILSApp/ILSMacApp/Views/MacContentView.swift` — macOS root, `SidebarSection` enum
- `ILSApp/ILSApp/Views/Root/SidebarView.swift` — sidebar panel (shared iOS/macOS)

**`ActiveScreen` enum:** Defined at top of `SidebarRootView.swift`. Has 22 cases including `.chat(ChatSession)` (with associated value) and simple screens like `.home`, `.settings`, `.browser`.

**iOS layout split:**
- iPhone (compact): `ZStack` overlay sidebar + `DragGesture` from leading edge (x < 30)
- iPad (regular): `NavigationSplitView` with persistent sidebar column

**macOS layout:** 3-column `NavigationSplitView` (sidebar | sessions list | detail). Uses `SidebarSection` enum that maps to `ActiveScreen`.

**Navigation flow:**
```swift
// From anywhere — via AppState
appState.navigationIntent = .settings     // consumed by SidebarRootView.onChange

// Deep links (ils:// URL scheme) → parsed in ILSAppApp.handleURL() → set navigationIntent

// Session navigation always goes through navigateToChat(_:) for back-button support
// Do NOT set activeScreen = .chat(session) directly
```

**`@SceneStorage` persistence:** `activeScreenKey` (String) and `lastChatSessionId` (UUID string) persist across launches. Chat restoration requires async session fetch — done in `.task` after `sessionsVM` is loaded.

**Deep link routes (`ils://`):**
`home`, `sessions`, `sessions/{uuid-lowercase}`, `browser`, `settings`, `system`, `fleet`, `themes`, `mcp`, `skills`, `plugins`

**Gotchas:**
- `activeScreen` default cannot be `.settings` or any screen requiring `@EnvironmentObject` — they're not ready during `@State` init (causes crash)
- Chat deep links must use LOWERCASE UUIDs — uppercase causes lookup failures
- iPhone sidebar: `idb_tap` cannot hit SwiftUI toolbar buttons. Swipe from x=5 to open sidebar programmatically in automation

---

## 6. ViewModel Conventions

**Purpose:** Consistent `@Observable @MainActor` pattern for all ViewModels, with safe Task lifecycle management.

**Key files:**
- `ILSApp/ILSApp/ViewModels/BaseViewModel.swift` — base class (isLoading, error, client)
- Any `*ViewModel.swift` in `ILSApp/ILSApp/ViewModels/`

**Standard shape:**
```swift
@Observable
@MainActor
class FooViewModel: BaseViewModel {
    var items: [Item] = []

    // nonisolated(unsafe) for Task properties accessed in deinit
    @ObservationIgnored nonisolated(unsafe) private var fetchTask: Task<Void, Never>?

    func load() {
        fetchTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            do {
                let response: APIResponse<[Item]> = try await client!.get("/items")
                self.items = response.data ?? []
            } catch {
                self.error = error
            }
        }
    }

    deinit {
        fetchTask?.cancel()
    }
}
```

**Configuration pattern:** ViewModels receive `APIClient` via `configure(client:)` after init (inherited from `BaseViewModel`). Called by `SidebarRootView.task` after `AppState` is available.

**`@ObservationIgnored`:** Required on `Task` properties because `@Observable` synthesizes observation tracking for all stored properties. Task properties are internal lifecycle state, not view-observable.

**`nonisolated(unsafe)`:** Required on any property accessed from `deinit` (which is nonisolated). Only safe because deinit is the sole nonisolated write site after construction.

**Gotchas:**
- `BaseViewModel` uses class inheritance — see `TODO: SUIA-002` for a potential protocol-based alternative
- Never access `client` without checking `configure(client:)` was called first

---

## 7. API Response Envelope

**Purpose:** Consistent JSON structure for all backend responses; shared between iOS client and Vapor backend via `ILSShared` module.

**Key files:**
- `Sources/ILSShared/DTOs/Requests.swift` — `APIResponse<T>`, `APIError`, `ListResponse<T>`
- `Sources/ILSShared/DTOs/PaginatedResponse.swift` — `PaginatedResponse<T>`
- `ILSApp/ILSApp/Services/APIClient.swift` — generic decode methods

**Structures:**
```swift
// Standard envelope — all endpoints
struct APIResponse<T: Codable & Sendable>: Codable {
    let success: Bool
    let data: T?        // nil on error
    let error: APIError? // nil on success
}

struct APIError: Codable, Sendable {
    let code: String    // e.g. "not_found", "validation_error"
    let message: String
}

// List endpoints (non-paginated)
struct ListResponse<T: Codable & Sendable>: Codable {
    let items: [T]
    let total: Int
}

// Paginated list endpoints
struct PaginatedResponse<T: Codable & Sendable>: Codable {
    let items: [T]
    let total: Int
    let hasMore: Bool
}
```

**APIClient usage:**
```swift
// Path auto-prefixed with /api/v1 — never double-prefix
let response: APIResponse<[Session]> = try await client.get("/sessions")
let sessions = response.data ?? []

let created: APIResponse<Session> = try await client.post("/sessions", body: request)
```

**APIClient features:**
- `actor` — thread-safe
- NSCache with per-endpoint TTL (default 300s / 5 min)
- ETag / `If-None-Match` conditional requests (304 Not Modified support)
- In-flight GET deduplication — concurrent requests to same path share one network call
- Bearer token auth via Keychain-persisted API key (lazy-loaded, not in init)

**Gotchas:**
- ALL paths passed to `APIClient` must omit `/api/v1` prefix — it is added automatically
- 304 responses decode from `conditionalCache` (not NSCache) — the conditional cache is never evicted by memory pressure

---

## 8. Cross-Platform Patterns

**Purpose:** Share business logic and models between iOS and macOS while using platform-appropriate navigation.

**Key files:**
- `Sources/ILSShared/` — all models, DTOs, and utilities shared by iOS app + Vapor backend
- `ILSApp/ILSApp/` — iOS source (149 Swift files)
- `ILSApp/ILSMacApp/` — macOS source (18 Swift files)

**What is shared:**
- `ActiveScreen` enum — same routing enum used on both platforms
- `SessionsViewModel`, `ChatViewModel`, `HomeView`, `BrowserView`, `SystemMonitorView`, `SettingsView`, `ThemePickerView`, etc. — most views compile on both targets
- `ThemeSnapshot` + `ThemeManager` — identical theming on both platforms
- `SSEClient` — `#if os(iOS)` guards isolate background observer registration
- `APIClient` — pure Foundation/actor, no platform APIs

**What diverges:**
| Concern | iOS | macOS |
|---------|-----|-------|
| Root container | `SidebarRootView` (ZStack/NSSplitView) | `MacContentView` (3-col NavigationSplitView) |
| Chat view | `ChatView` | `MacChatView` |
| Settings | `SettingsView` | `MacSettingsView` |
| Backend lifecycle | N/A | `BackendLifecycleManager` (starts Vapor on launch) |
| Spotlight | N/A | `SpotlightIndexer.shared.indexSessions()` |
| Context menus | Long-press | Right-click in `List` |

**macOS-specific additions:**
- `AppDelegate` — menu bar commands via `NSNotification`
- `WindowManager` — opens sessions in separate `NSWindow`
- `ILSCommands` — `Commands` struct for macOS menu bar

**`#if os(iOS)` / `#if os(macOS)` usage:** Used sparingly — in `SSEClient` (background observer), `SidebarRootView` toolbar placement, and platform-specific gestures. Prefer shared code with conditional blocks over separate files when possible.

**Compile-time verification:** Every iOS Swift file change MUST also compile on macOS (`xcodebuild -scheme ILSMacApp`). The auto-build hook fires on the appropriate scheme based on file path.

**Gotchas:**
- macOS `MacContentView` uses `@AppStorage("enableAgentTeams")` to feature-flag the Teams sidebar item — the iOS sidebar does not have this guard
- macOS `expandedProjects` is backed by `@AppStorage` as a comma-separated string (no `Set` persistence support in AppStorage)
