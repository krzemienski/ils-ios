# Coding Conventions

**Analysis Date:** 2026-02-19

## Naming Patterns

**Files:**
- PascalCase for all Swift files (e.g., `ChatViewModel.swift`, `APIClient.swift`, `MetricsWebSocketClient.swift`)
- Descriptive names indicating the primary type/responsibility (ViewModel, Service, View, Manager)
- Related files grouped in directories by feature/domain (e.g., `ViewModels/`, `Services/`, `Views/Chat/`)

**Functions:**
- camelCase for all functions (e.g., `loadMessageHistory()`, `processStreamMessages()`, `handleMetricsData()`)
- Verb-based names for async functions that perform actions (e.g., `loadSessions()`, `createSession()`, `deleteSession()`)
- Query-style names for computed properties and getters (e.g., `currentStreamingMessage`, `filteredSessions`, `groupedSessions`)
- Private helper functions prefixed with underscore or marked `private` (e.g., `private func processJsonLine()`)

**Variables & Properties:**
- camelCase for all variables, properties, and parameters (e.g., `isStreaming`, `sessionId`, `baseURL`)
- Boolean properties prefixed with `is`, `has`, or `can` (e.g., `isLoading`, `hasMore`, `isConnected`)
- Tuple destructuring uses clear names (e.g., `(data, response)`, `(key: String, value: [ChatSession])`)

**Types:**
- PascalCase for all types, enums, structs, classes, protocols (e.g., `ChatViewModel`, `APIError`, `SessionStatus`)
- Enum cases in camelCase (e.g., `.haiku`, `.sonnet`, `.opus`, `.unknown(String)`)
- Enum raw values using descriptive strings (e.g., `case active = "active"`, not `case active`)

## Code Style

**Formatting:**
- SwiftLint enforced via `.swiftlint.yml` configuration
- Line length warning: 200 chars, error: 300 chars
- File length warning: 600 lines, error: 1000 lines
- Function body length warning: 80 lines, error: 150 lines
- Type body length warning: 400 lines, error: 800 lines
- 4-space indentation (standard Swift)

**Linting:**
- SwiftLint enabled with `opt_in_rules` for cleaner code
- Key disabled rules: `trailing_whitespace`, `todo`, `opening_brace`, `identifier_name`, `type_name`, `nesting` (too strict)
- Key enabled rules: `empty_count`, `closure_spacing`, `contains_over_filter_count`, `empty_string`, `first_where`, `last_where`
- Force cast/try warnings elevated to prevent unsafe patterns

**Comments:**
- Documentation comments (///) for public APIs, key functions, and complex logic
- Line comments (//) for implementation notes and reasoning
- Mark sections: `// MARK: - Section Name` for grouping related methods
- Example from `ChatViewModel.swift` (lines 6-21): Comprehensive doc comments with Topics sections

## Import Organization

**Order:**
1. Foundation and system frameworks (e.g., `import Foundation`, `import Combine`)
2. Apple UI frameworks (e.g., `import SwiftUI`, `import Observation`)
3. Custom project frameworks (e.g., `import ILSShared`)

**Pattern observed in ViewModels:**
```swift
import Foundation
import Observation
import ILSShared
```

**Pattern in views with theme:**
```swift
import SwiftUI
import ILSShared
```

**Backend services:**
```swift
import Foundation
@preconcurrency import Dispatch
import Vapor
import ILSShared
import Logging
```

**Path Aliases:**
- No explicit path aliases detected; imports use full module names
- ILSShared is the shared framework imported by both iOS and macOS targets

## State Management

**@Observable Pattern (iOS 17+):**
- Preferred pattern throughout the codebase for reactive state
- Used on ViewModels: `@Observable @MainActor class ChatViewModel`, `@Observable class SettingsViewModel`
- @MainActor enforced to ensure UI updates on main thread
- Automatic observation tracking through @Observable macro — no Combine publisher forwarding needed

**Example from `ILSAppApp.swift` (lines 73-101):**
```swift
@MainActor
@Observable
class AppState {
    var isConnected: Bool { connectionManager.isConnected }  // Computed property forwarding
    var showOnboarding: Bool {
        get { connectionManager.showOnboarding }
        set { connectionManager.showOnboarding = newValue }
    }
}
```

**Combine Usage:**
- Still used for legacy stream subscriptions (e.g., SSEClient publishers)
- Subscriptions stored in `Set<AnyCancellable>` and stored in `&cancellables`
- Example: `ChatViewModel.swift` lines 81, 111-151 use Combine `.sink()` and `.store(in:)`

**@State & @AppStorage:**
- @State for local transient UI state in Views
- @AppStorage for persisted user preferences (e.g., `@AppStorage("colorScheme")`)
- Example: `ILSAppApp.swift` line 11: `@AppStorage("colorScheme") private var colorSchemePreference: String = "dark"`

**@Environment:**
- Used for dependency injection (e.g., theme, accessibility settings)
- Example: `ChatInputBar.swift` line 20: `@Environment(\.theme) private var theme: ThemeSnapshot`
- Example: `ChatViewModel.swift` line 10 (implied): environment state forwarding through AppState

## Error Handling

**Pattern: do/catch with explicit error assignment:**
- All async operations use `do { try await ... } catch { self.error = error }`
- Errors assigned to view model `error` property for UI display
- Example from `ChatViewModel.swift` (lines 227-290):
```swift
do {
    let response: APIResponse<ListResponse<Message>> = try await apiClient.get(path)
    // Process response
} catch {
    let isNotFound = (error as? APIError)?.isNotFound == true
    if !isNotFound {
        self.error = error
    }
    AppLogger.shared.error("Failed to load message history: \(error)", category: "chat")
}
```

**Pattern: defer for cleanup:**
- Used for automatic cleanup without explicit finally
- Example from `SettingsViewModel.swift` (lines 69-70):
```swift
defer { isTestingConnection = false }
```

**Pattern: guard with nil check:**
- guard statements used to validate prerequisites before proceeding
- Example from `APIClient.swift` (line 98-99):
```swift
guard let url = URL(string: "\(baseURL)/health") else {
    throw APIError.invalidURL("\(baseURL)/health")
}
```

**Custom Error Enums:**
- APIError uses associated values for context (e.g., `.serverError(code: String, reason: String)`)
- Errors implement LocalizedError for user-facing messages
- Example from `APIClient.swift` (lines 343-435): Comprehensive error cases with localized descriptions

**Error Logging:**
- Structured logging via `AppLogger.shared` with category parameter
- Example: `AppLogger.shared.error("Failed to load: \(error)", category: "chat")`
- Warnings for non-fatal operations: `AppLogger.shared.warning("Backend cancel failed", category: "chat")`

## Logging

**Framework:** AppLogger (custom logger, likely wraps OS Log or print)

**Patterns:**
- Log after try/catch: `AppLogger.shared.error(..., category: "...")`
- Log informational events: `AppLogger.shared.info("Session initialized: \(sessionId)", category: "chat")`
- Always include category string for filtering
- Example from `ChatViewModel.swift` (line 511): `AppLogger.shared.info("Session initialized: \(sysMsg.data.sessionId)", category: "chat")`

## Function Design

**Size Guidelines:**
- SwiftLint enforces 80 line warning, 150 line error for function bodies
- Observe in practice: ChatViewModel streaming logic uses helper functions to stay within bounds
- Example: `processStreamMessages()` delegates to `handleAssistantMessage()`, `handleUserMessage()`, `handleStreamEvent()`

**Parameters:**
- Limited parameter count: most functions take 1-3 parameters
- Use structs for multiple related parameters (e.g., ChatOptions struct vs. individual parameters)
- Example from `ChatViewModel.swift` (line 258): `func createSession(projectId: UUID?, name: String?, model: String, permissionMode: PermissionMode? = nil, ...)`

**Return Values:**
- Async functions return specific types wrapped in Task/async context
- Computed properties return derived values efficiently
- Example from `SessionsViewModel.swift` (line 75-81): Computed property with cached filtering
- Void + side effects for state mutations (e.g., `func addUserMessage()`)

## Module Design

**Exports (Shared Framework):**
- Public types in `Sources/ILSShared/Models/` (e.g., ChatSession, ClaudeModel, SessionStatus)
- Public enums with Codable, Sendable, Hashable conformances for cross-module use
- Example from `Session.swift` (lines 10-72): Public enums with init(rawValue:), init(from:), encode(to:)

**Barrel Files:**
- No explicit barrel files detected in this codebase
- Direct imports of specific types preferred (e.g., `import ILSShared`)

**Internal Access Control:**
- ViewModels marked @MainActor for thread safety
- Private properties and helper functions marked explicitly
- Example from `APIClient.swift` (line 9): `nonisolated private let decoder: JSONDecoder`
- Actor-based concurrency for network operations (e.g., `actor APIClient`)

## Async/Await Patterns

**Structured Concurrency:**
- All async operations use Task-based concurrency, not old-style completion handlers
- Example from `ChatViewModel.swift` (line 181): `Task { [weak self] in ... }`
- Capture self weakly in async contexts to prevent retain cycles

**Task Sleep & Timing:**
- `Task.sleep(for: .seconds(...))` for delays
- Example from `MetricsWebSocketClient.swift` (line 192): `try? await Task.sleep(for: .seconds(delay))`
- Task cancellation checked with `Task.isCancelled` guard

**Streaming with AsyncThrowingStream:**
- Used for SSE streaming and Claude execution output
- Example from `ClaudeExecutorService.swift` (lines 137-147): AsyncThrowingStream<StreamMessage, Error>
- Continuation.yield() for emitting values, continuation.finish() for completion

## Actor-Based Concurrency

**Actor Usage:**
- `actor APIClient` for thread-safe HTTP client (no concurrent access issues)
- `actor ClaudeExecutorService` for subprocess management and state coordination
- Nonisolated properties for thread-safe types (JSONDecoder, JSONEncoder)
- Example from `APIClient.swift` (lines 8-9): `nonisolated private let decoder: JSONDecoder`

**@MainActor:**
- ViewModels marked `@MainActor @Observable` to ensure UI updates happen on main thread
- @MainActor property: `@MainActor @Observable class ChatViewModel`

**Sendable Conformance:**
- Models marked Sendable for safe cross-actor passing
- Example from `Session.swift` (line 114): `public struct ChatSession: Codable, Identifiable, Sendable, Hashable`

## Memory Management

**Weak References:**
- Used in async closures to prevent retain cycles
- Example from `ChatViewModel.swift` (line 112): `[weak self]` in sink/map closures
- Example from `ClaudeExecutorService.swift` (line 215): `Task { [weak self] in ... }`

**nonisolated(unsafe) Usage:**
- Documented with comments explaining thread safety guarantees
- Example from `ClaudeExecutorService.swift` (lines 82-84):
```swift
/// nonisolated(unsafe) because this is read from nonisolated execute() — safe since
/// the value is effectively constant after initialization.
nonisolated(unsafe) var useAgentSDK: Bool = true
```

**Task Cleanup:**
- Tasks stored as properties and cancelled in deinit
- Example from `ChatViewModel.swift` (lines 102-106):
```swift
deinit {
    batchTask?.cancel()
    connectingTimer?.cancel()
    cancellables.removeAll()
}
```

## Immutability

**Mutation Patterns:**
- Properties reassigned rather than mutated (immutable by default)
- Example from `ChatViewModel.swift` (line 244): `messages = loadedMessages` (not append)
- Arrays replaced rather than modified when possible (prevents SwiftUI update issues)

**Message Streaming Optimization:**
- Index-based mutation used in streaming to reduce @Observable notifications
- Example from `ChatViewModel.swift` (lines 541-542):
```swift
// Single mutation: update message in place instead of removeLast+append
messages[messageIndex] = currentMessage
```

**Caching:**
- Search results cached and rebuilt when inputs change
- Example from `SessionsViewModel.swift` (lines 57-95): Precomputed search cache

---

*Convention analysis: 2026-02-19*
