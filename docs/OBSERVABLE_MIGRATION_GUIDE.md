# Observable Macro Migration Guide

This guide documents the `@Observable` patterns used throughout the ILS iOS/macOS codebase.
All ViewModels and Services/Managers have been migrated from `ObservableObject` + `@Published`
to Swift's native `@Observable` macro (introduced in iOS 17 / Swift 5.9).

---

## Why @Observable?

| | `ObservableObject` + `@Published` | `@Observable` |
|---|---|---|
| **Tracking granularity** | Whole-object invalidation — any `@Published` property change re-renders all observers | Per-property tracking — SwiftUI only re-renders when a property actually *read* by the View changes |
| **Boilerplate** | `@Published` on every property, `ObservableObject` conformance | Just `@Observable` on the class — no per-property annotation needed |
| **View injection** | `@StateObject` / `@ObservedObject` / `@EnvironmentObject` | `@State` / `@Bindable` / `@Environment` |
| **Property forwarding** | Requires Combine `objectWillChange.send()` chains | Plain computed properties — SwiftUI tracks through the chain automatically |
| **Concurrency** | Requires careful `@MainActor` discipline | Naturally composable with `async/await` and `@MainActor` |

---

## Core ViewModel Pattern

Every ViewModel in ILS follows this exact structure:

```swift
import Foundation
import Observation   // Required for @Observable
import ILSShared

@Observable          // ← replaces ObservableObject conformance
@MainActor           // ← ensures all mutations happen on the main thread
class FooViewModel {
    // Properties — no @Published needed
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    // Private backing — not observed by SwiftUI
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var cache: [UUID: Item] = [:]

    private var apiClient: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.apiClient = client
    }
}
```

**Rules:**
1. `@Observable` replaces `ObservableObject`
2. `@MainActor` goes on the class (not individual methods)
3. All observable state is declared as plain `var` — no `@Published`
4. Private helpers (Tasks, caches, timers) use `@ObservationIgnored`
5. `import Observation` is required (not `Combine`)

### Real Example — ChatViewModel

```swift
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var isLoadingHistory = false
    var error: Error?
    var connectionState: SSEClient.ConnectionState = .disconnected
    var pendingPermissionRequest: PermissionRequest?

    // @ObservationIgnored for infra that SwiftUI shouldn't track
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var connectingTimer: Task<Void, Never>?
    @ObservationIgnored private var batchTask: Task<Void, Never>?
}
```

---

## @ObservationIgnored — When to Use It

Mark a property `@ObservationIgnored` when SwiftUI should **not** re-render on its changes:

```swift
@Observable
@MainActor
class SessionsViewModel {
    // ✅ Observed — SwiftUI re-renders when these change
    var sessions: [ChatSession] = []
    var isLoading = false

    // ✅ @ObservationIgnored — internal state, not for UI
    @ObservationIgnored private var searchCache: [(session: ChatSession, searchText: String)] = []
    @ObservationIgnored private var cachedGroupedSessions: [(key: String, value: [ChatSession])] = []
    @ObservationIgnored private var sessionsMutationVersion: Int = 0

    private var client: APIClient?   // injected dependency — also not observed
}
```

**Good candidates for `@ObservationIgnored`:**
- Active `Task` handles (for cancellation)
- Internal caches and memoised results
- Dependency references (`APIClient`, `SSEClient`)
- Mutation-version counters used only for cache invalidation
- `JSONDecoder` / `JSONEncoder` instances

---

## Computed Properties for Derived State

With `@Observable`, computed properties are tracked automatically — SwiftUI sees the underlying
properties they read and only re-renders when those change:

```swift
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var isLoadingHistory = false
    var connectionState: SSEClient.ConnectionState = .disconnected
    var connectingTooLong = false

    // Computed — SwiftUI tracks messages + isStreaming automatically
    var currentStreamingMessage: ChatMessage? {
        guard isStreaming, let last = messages.last, !last.isUser else { return nil }
        return last
    }

    // Computed — SwiftUI tracks isLoadingHistory + connectionState + isStreaming
    var statusText: String? {
        if isLoadingHistory { return "Loading history..." }
        switch connectionState {
        case .connecting: return connectingTooLong ? "Taking longer than expected..." : "Connecting..."
        case .connected:  return isStreaming ? "Claude is responding..." : nil
        default:          return nil
        }
    }
}
```

**No Combine `objectWillChange.send()` needed** — just write the computed property and return.

---

## Property Forwarding in AppState

`AppState` acts as a thin coordinator. With `@Observable`, SwiftUI tracks *through* property
chains without any Combine wiring:

```swift
@MainActor
@Observable
class AppState {
    let connectionManager: ConnectionManager   // also @Observable

    // Forwarding properties — SwiftUI tracks connectionManager.isConnected directly
    var isConnected: Bool { connectionManager.isConnected }
    var serverURL: String { connectionManager.serverURL }
    var apiClient: APIClient { connectionManager.apiClient }

    // Read-write forwarding
    var showOnboarding: Bool {
        get { connectionManager.showOnboarding }
        set { connectionManager.showOnboarding = newValue }
    }
}
```

With `ObservableObject` this would have required Combine sink/publisher chains. With
`@Observable`, plain computed properties are sufficient — Swift's observation system
follows the chain automatically.

---

## Services and Managers

Services follow the same pattern as ViewModels:

```swift
import Foundation
import Observation

@MainActor
@Observable
class ConnectionManager {
    var isConnected: Bool = false
    var serverURL: String = ""
    var showOnboarding: Bool = false
    var apiClient: APIClient
    var sseClient: SSEClient

    private(set) var isInitialized = false

    init() {
        // Standard init — no Combine setup needed
        let url = /* load from UserDefaults */
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        self.serverURL = url
        self.isInitialized = true
    }
}
```

---

## View Patterns

### @State instead of @StateObject

```swift
// ❌ Old pattern
struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
}

// ✅ New pattern
struct SessionsView: View {
    @State private var viewModel = SessionsViewModel()
}
```

`@State` works because `@Observable` classes are reference types that SwiftUI now understands
natively — no special property wrapper is required.

### @Environment instead of @EnvironmentObject

```swift
// ❌ Old pattern
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
}

// ✅ New pattern
struct SettingsView: View {
    @Environment(AppState.self) var appState
}
```

Injection at the root:

```swift
// ❌ Old
WindowGroup { RootView().environmentObject(appState) }

// ✅ New
WindowGroup { RootView().environment(appState) }
```

### @Bindable for Two-Way Binding

When a child view needs to write back to an `@Observable` object received from a parent:

```swift
struct ChatOptionsSheet: View {
    @Bindable var viewModel: ChatViewModel   // ← @Bindable enables $viewModel.someProperty

    var body: some View {
        Toggle("Stream", isOn: $viewModel.isStreaming)
    }
}
```

Use `@Bindable` instead of `@ObservedObject` when you need `$` binding syntax on
`@Observable` objects passed as parameters.

### Passing ViewModels as Parameters (No Wrapper Needed)

When a sub-view only reads from the ViewModel (no binding needed), pass it as a plain
parameter — no property wrapper required:

```swift
struct SettingsAboutSection: View {
    let viewModel: SettingsViewModel   // ← plain let, not @ObservedObject

    var body: some View {
        Text(viewModel.serverVersion ?? "—")
    }
}
```

---

## withObservationTracking — Manual Observation

For imperative observation (e.g., syncing ViewModel state from a Service), use
`withObservationTracking` instead of Combine publishers:

```swift
// In ChatViewModel.setupBindings():
observationTasks.append(Task { @MainActor [weak self] in
    while let self, !Task.isCancelled {
        // Register interest in SSEClient properties
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            withObservationTracking {
                _ = sseClient.isStreaming
                _ = sseClient.error
                _ = sseClient.connectionState
                _ = sseClient.messages
            } onChange: {
                continuation.resume()   // fires once when any tracked property changes
            }
        }
        guard !Task.isCancelled else { break }

        // Pull new values and update self
        self.isStreaming = sseClient.isStreaming
        self.connectionState = sseClient.connectionState
        self.error = sseClient.error
    }
})
```

**Key points:**
- `withObservationTracking` fires `onChange` **once** per change event — re-register inside the loop
- The access block (`_ = sseClient.isStreaming`) registers observation interest
- Always cancel the task in `deinit` to avoid leaks

---

## nonisolated Properties

For thread-safe values that don't need `@MainActor` isolation, use `nonisolated`:

```swift
@Observable
@MainActor
class ChatViewModel {
    // JSONDecoder is thread-safe — mark nonisolated to avoid actor-hop overhead
    nonisolated private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
```

---

## Migration Checklist

When creating a new ViewModel or migrating an existing one:

- [ ] Replace `class Foo: ObservableObject` with `@Observable @MainActor class Foo`
- [ ] Remove all `@Published` annotations from properties
- [ ] Add `import Observation` (remove `import Combine` if no longer needed)
- [ ] Mark non-UI state (`Task` handles, caches, injected dependencies) with `@ObservationIgnored`
- [ ] In Views: replace `@StateObject` with `@State`
- [ ] In Views: replace `@EnvironmentObject` with `@Environment(Foo.self)`
- [ ] In Views: replace `@ObservedObject` with `@Bindable` (if bindings needed) or plain `let`
- [ ] In injection sites: replace `.environmentObject(x)` with `.environment(x)`
- [ ] Replace Combine forwarding chains with plain computed properties
- [ ] Replace Combine publishers/sinks with `withObservationTracking` loops (if manual tracking needed)

---

## Full Inventory

As of the completed migration, **zero** `ObservableObject` / `@Published` / `@StateObject` /
`@ObservedObject` patterns remain in the codebase. Verified via:

```bash
grep -rn 'ObservableObject\|@Published\|@StateObject\|@ObservedObject' ./ILSApp --include='*.swift'
# → (no output)
```

All 22+ ViewModels and 8+ Services/Managers use `@Observable`.
