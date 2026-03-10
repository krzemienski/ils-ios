# ILS Swift Code Standards & Conventions

**Version:** 1.1.1 | **Last Updated:** 2026-03-10 | **Applies to:** iOS, macOS, and Backend targets

---

## File Organization

### General Rules

1. **One Primary Type Per File** — Each Swift file contains one main struct, class, or enum (exceptions: small extensions, protocols)
2. **Alphabetical Ordering** — Within a type, organize properties and methods alphabetically by category (properties, methods, computed properties)
3. **Sections with MARK** — Use `// MARK: - SectionName` to organize code into logical blocks
4. **File Naming** — Use PascalCase matching the primary type name: `ChatViewModel.swift`, `APIClient.swift`, `ThemeSnapshot.swift`
5. **No Abbreviations in Filenames** — Prefer `ViewController.swift` over `VC.swift`

### Example Structure

```swift
import SwiftUI
import Observation

/// Brief description of what this type does.
/// Multi-line doc comments explain purpose and usage patterns.
@Observable
@MainActor
final class MyViewModel {
    // MARK: - Properties

    var items: [Item] = []
    var isLoading = false
    private var task: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // Setup
    }

    // MARK: - Public Methods

    func loadItems() async {
        // Public interface
    }

    // MARK: - Private Methods

    private func processItems() {
        // Internal implementation
    }

    deinit {
        task?.cancel()
    }
}
```

---

## Naming Conventions

### Variables & Properties

| Category | Style | Example |
|----------|-------|---------|
| Local variables | camelCase | `let sessionId`, `var isStreaming` |
| Boolean properties | `is`/`has`/`should` prefix | `isLoading`, `hasError`, `shouldRefresh` |
| Private properties | camelCase with leading underscore (rare) | Usually just `private let name` |
| Published state | camelCase | `@State var selectedTab` |
| Computed properties | camelCase (verb for actions) | `var isVisible`, `var filteredItems` |

### Functions & Methods

| Category | Style | Example |
|----------|-------|---------|
| Public methods | camelCase verb | `func loadSessions()`, `func sendMessage(_:)` |
| Private helpers | camelCase verb | `private func updateUI()` |
| Closures | camelCase verb | `{ item in process(item) }` |
| Predicates | `is`/`has` prefix | `func isValid()`, `func hasExpired()` |

### Types

| Category | Style | Example |
|----------|-------|---------|
| Classes, structs, enums | PascalCase | `class ChatViewModel`, `struct ThemeSnapshot` |
| Protocols | PascalCase | `protocol AppTheme`, `protocol APIProvider` |
| Type aliases | PascalCase | `typealias SessionID = UUID` |
| Enum cases | camelCase | `.active`, `.paused`, `.completed` |

### Constants

| Category | Style | Example |
|----------|-------|---------|
| Top-level constants | PascalCase (like types) | `let DefaultCacheTTL = 300` |
| Magic numbers in code | Extract to named constant | `let maxRetries = 3` |
| String keys | snake_case | `"notif_sessionCompleteAlerts"` (UserDefaults) |

---

## Type Annotations

### When to Include

```swift
// Required: public/exported APIs
func getSession(id: UUID) -> ChatSession? { }

// Required: properties with complex type inference
var cachedResponses: [String: Response] = [:]

// Optional: simple local variables (inference is clear)
let count = items.count  // clear without annotation
let isActive = true      // clear without annotation
```

### When to Omit

```swift
// Omit when obvious
let items = loadItems()
let isValid = validate()
let first = array.first
```

---

## SwiftUI Patterns

### @State vs @StateObject

```swift
// Local screen state → @State
@State private var isEditing = false

// Lifecycle-managed dependency → @StateObject (pre-iOS 14) or @State (iOS 17+)
@State private var viewModel = MyViewModel()
```

### @Observable ViewModels

```swift
@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false

    // Don't make closure properties observable (infinite loop potential)
    nonisolated(unsafe) var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }
}
```

**Rule:** All ViewModels are `@Observable @MainActor` — never `@EnvironmentObject` or `ObservableObject`.

### View Composition

```swift
// Large views split into sub-views
struct ChatView: View {
    @State var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            ChatHeaderView(title: viewModel.title)
            ChatMessagesView(messages: viewModel.messages)
            ChatInputBar(onSend: viewModel.sendMessage)
        }
    }
}

// Sub-views are single-file components
struct ChatHeaderView: View {
    let title: String
    var body: some View { /* ... */ }
}
```

### Environment Values

```swift
// Define custom environment values
extension EnvironmentValues {
    @Entry var theme: ThemeSnapshot = ILSTheme().snapshot
}

// Access in views
@Environment(\.theme) private var theme
```

**Rule:** Use concrete `ThemeSnapshot` struct, not existential `any AppTheme`. Eliminates container overhead.

---

## Concurrency Patterns

### Actors for Thread Safety

```swift
// Actor for isolated access (like APIClient)
actor APIClient {
    private var inFlightGETs: [String: Task] = [:]

    func get<T>(_ path: String) -> T {
        // Thread-safe by actor isolation
    }
}
```

### MainActor for UI Updates

```swift
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []  // Always accessed from main thread

    func update() {
        // Automatically on main thread
    }
}
```

### Task Management

```swift
class ViewModel {
    nonisolated(unsafe) var task: Task<Void, Never>?

    func load() {
        task = Task {
            // Long operation
        }
    }

    deinit {
        task?.cancel()  // Always cleanup
    }
}
```

### Async/Await Over Completion Handlers

```swift
// Preferred
func loadSessions() async throws -> [Session] {
    let response: SessionsResponse = try await APIClient.shared.get("/sessions")
    return response.data.items
}

// Avoid
func loadSessions(completion: @escaping ([Session]?, Error?) -> Void) {
    // Old style
}
```

---

## Error Handling

### Define Custom Errors

```swift
enum APIError: Error, LocalizedError {
    case networkFailure(URLError)
    case decodingFailure(DecodingError)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .networkFailure: return "Network connection failed"
        case .decodingFailure: return "Invalid response format"
        case .notFound(let resource): return "\(resource) not found"
        }
    }
}
```

### Try-Catch Over try?

```swift
// Preferred: explicit error handling
do {
    let session = try await loadSession(id)
    update(with: session)
} catch APIError.notFound {
    showNotFoundAlert()
} catch {
    showErrorAlert(error.localizedDescription)
}

// Avoid: silent failures
let session = try? await loadSession(id)  // No visibility if it fails
```

### Don't Silently Swallow Errors

```swift
// Bad
_ = try? sendMessage()  // No error feedback to user

// Good
do {
    try await sendMessage()
} catch {
    AppLogger.error("Failed to send message: \(error)")
    showErrorAlert("Could not send message")
}
```

---

## API Client Patterns

### Request Methods

```swift
actor APIClient {
    // Automatic `/api/v1` prefix
    func get<T: Decodable>(_ path: String) async throws -> T
    func post<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T
    func put<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T
    func delete(_ path: String) async throws
}

// Usage
let sessions: SessionsResponse = try await APIClient.shared.get("/sessions")
let session: Session = try await APIClient.shared.post("/sessions", body: createRequest)
```

### Caching Strategy

```swift
// APIClient automatically:
// 1. Caches responses (NSCache with TTL)
// 2. Stores ETags for conditional requests
// 3. Returns 304 Not Modified if unchanged (no re-decoding)
// 4. Deduplicates concurrent GET requests to same path

// TTL configured per endpoint
APIClient.shared.cacheTTL(for: "/sessions", ttl: 300)  // 5 minutes
```

---

## Theme System

### Using Themes

```swift
@Environment(\.theme) private var theme: ThemeSnapshot

// Apply colors
Color(theme.bgPrimary)      // Background
Color(theme.textPrimary)    // Text
Color(theme.accent)         // Interactive elements
Color(theme.success)        // Success states

// Apply typography
Text("Hello").font(theme.fontBody)      // Body text
Text("Section").font(theme.fontTitle)   // Headings
Text("Meta").font(theme.fontCaption)    // Small text
```

### Theme Snapshot Struct

```swift
struct ThemeSnapshot: Sendable {
    // Backgrounds
    let bgPrimary: Color
    let bgSecondary: Color
    let bgTertiary: Color

    // Text
    let textPrimary: Color
    let textSecondary: Color

    // Semantic
    let success: Color
    let warning: Color
    let error: Color
    let info: Color

    // Typography (all UIFont)
    let fontBody: UIFont
    let fontTitle: UIFont
    let fontCaption: UIFont
    // ... more font properties
}
```

**Rule:** Never use `UIColor` directly. Always go through theme.

---

## Memory Safety

### @State vs Properties

```swift
// Good: @State for local screen state
@State private var selectedTab = 0

// Bad: storing mutable state in struct property without @State
struct MyView: View {
    var selectedTab = 0  // Won't persist across body redraws
}
```

### Preventing Retain Cycles

```swift
// Good: [weak self] in closures
Task { [weak self] in
    let result = await operation()
    self?.update(with: result)  // Safe unwrap
}

// Good: Cancel tasks in deinit
deinit {
    task?.cancel()
}

// Bad: strong self in long-lived closures
Task {
    let result = await operation()
    self.update(with: result)  // Holds self alive
}
```

---

## Performance Optimization

### Avoid Existential Containers

```swift
// Bad (existential container overhead at runtime)
@Environment(\.theme) private var theme: any AppTheme

// Good (concrete struct, zero-cost)
@Environment(\.theme) private var theme: ThemeSnapshot
```

### Cache Expensive Computations

```swift
@Observable
@MainActor
class SessionsViewModel {
    // Cache grouped sessions instead of recomputing
    private var _groupedSessions: [String: [Session]]?
    var groupedSessions: [String: [Session]] {
        if let cached = _groupedSessions { return cached }
        let grouped = computeGroups()
        _groupedSessions = grouped
        return grouped
    }
}
```

### Request Deduplication

```swift
// APIClient automatically deduplicates concurrent requests
Task {
    let s1 = try await APIClient.shared.get("/sessions")
    let s2 = try await APIClient.shared.get("/sessions")
}
// Network call made only once (two tasks share result)
```

---

## Documentation & Comments

### Documentation Comments

```swift
/// Sends a message to Claude and streams the response.
///
/// This method establishes an SSE connection to the chat endpoint,
/// decodes incoming tokens as they arrive, and updates the message history.
///
/// - Parameter content: The user message text
/// - Throws: `APIError` if the request fails or stream is interrupted
/// - Returns: The complete assistant response
func sendMessage(_ content: String) async throws -> String { }
```

### Inline Comments

```swift
// Use sparingly — code should be self-documenting
let interval = 300  // 5 minutes

// OK for non-obvious logic
// Validate ETag before making request (saves bandwidth on 304)
if let etag = etagStore[path] {
    // ...
}
```

---

## Testing & Validation

### No Mock Files

**RULE:** Never create test files, mocks, stubs, or test doubles.

Instead:
1. Build the real system
2. Run it in the simulator/device
3. Verify through actual UI interactions
4. Capture screenshots as evidence

---

## Code Review Checklist

Before committing, verify:

- [ ] No compiler warnings or errors
- [ ] File is under 400 LOC (split if needed)
- [ ] All public APIs documented with doc comments
- [ ] Error handling covers all cases (no `try?` unless intentional)
- [ ] Memory safety: `[weak self]` in long-lived closures, `deinit` cleanup
- [ ] No hardcoded secrets, API keys, or test data
- [ ] Follows naming conventions (camelCase, PascalCase)
- [ ] Uses `@Observable @MainActor` for ViewModels
- [ ] Uses concrete `ThemeSnapshot`, not `any AppTheme`
- [ ] Tasks cancelled in `deinit`
- [ ] Runs on actual device/simulator (not just compiles)

---

## Swift Version & Features

**Target:** Swift 5.10+

### Enabled Features
- Concurrency (async/await, actors, @MainActor)
- Observation framework (@Observable)
- Sendable protocol (data safety)
- Opaque types (some -> Never)

### Disabled Features
- Combine framework (use async/await instead)
- `ObservableObject` (use @Observable instead)
- Completion handlers (use async/await instead)

---

## Build Configuration

### Compiler Settings

```
Swift Language Version: Swift 5.10
Strict Concurrency Checking: Strict
Optimize for Speed: Release builds only
Enable Module Stability: No
```

### Linting

Run SwiftLint before commit:

```bash
swiftlint lint --fix
```

Configuration: `.swiftlint.yml` in project root

---

## FAQ

**Q: When should I use `@State` vs `@ObservedObject`?**
A: Always use `@State` with `@Observable` ViewModels. Never use `@ObservedObject` (pre-iOS 17 pattern).

**Q: How do I prevent memory leaks from WebSocket connections?**
A: Implement `deinit` to cancel the connection, store weak references if needed, use `[weak self]` in closures.

**Q: Should I use `@Published` properties?**
A: No. Use `@Observable` structs with computed properties instead.

**Q: How do I handle authentication tokens?**
A: Store in Keychain (never UserDefaults). Use `KeychainService` helper.

**Q: What's the difference between `try?` and `try` with `do-catch`?**
A: `try?` silently returns nil on error (hidden failures). Use `do-catch` to log and inform the user.
