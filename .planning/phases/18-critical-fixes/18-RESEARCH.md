# Phase 18: CRITICAL Fixes - Research

**Researched:** 2026-02-23
**Domain:** Swift concurrency safety, SwiftUI performance, energy efficiency, architecture patterns, SQLite configuration
**Confidence:** HIGH

## Summary

Phase 18 addresses all 13 CRITICAL-severity findings from the v3.0 comprehensive audit. The fixes span five distinct technical domains: (1) concurrency safety -- eliminating data races in AppLogger and SyntaxHighlighter; (2) energy efficiency -- correcting wasteful polling in Live Activity, MCP health checks, and Teams; (3) architecture violations -- routing macOS API calls through ViewModels and extracting inline async flows; (4) SwiftUI performance -- caching syntax highlighting and pre-computing theme availability sets; and (5) database integrity -- enabling foreign key enforcement across all pooled SQLite connections.

The codebase is a Swift iOS/macOS monorepo (SwiftUI + Vapor backend) targeting iOS 17+ and macOS 14+. All Phase 18 requirements have strong, well-understood solutions using Apple's standard APIs -- no third-party dependencies are needed. The risk profile is moderate: concurrency changes (CONC-01, CONC-02) affect foundational types used across the entire app, and the NewSessionView extraction (ARCH-03) involves moving logic between files, both of which can cascade build errors if handled incorrectly.

**Primary recommendation:** Address requirements in four batches: (1) concurrency + syntax caching, (2) energy/polling fixes, (3) architecture violations + DB, (4) NewSessionView extraction. Build-verify after each batch across iOS, macOS, and backend targets.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `OSAllocatedUnfairLock` | iOS 16+ / macOS 13+ | Thread-safe synchronization for `AppLogger` | Apple's recommended replacement for `os_unfair_lock` with value semantics; avoids actor overhead for synchronous callers |
| `@MainActor` | Swift 5.5+ | Actor isolation for `SyntaxHighlighter` enum | Compiler-enforced thread safety for mutable static state; eliminates `nonisolated(unsafe)` workaround |
| SwiftUI `.task(id:)` | iOS 15+ / macOS 12+ | Cancellable async work tied to view lifecycle and value identity | Standard pattern for triggering async work when a value changes; automatically cancels previous task |
| `SQLiteConfiguration(enableForeignKeys:)` | FluentSQLiteDriver 4.x | Pool-level PRAGMA foreign_keys = ON | SQLiteKit applies the PRAGMA on every new connection created by the pool, not just the initial one |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Splash` | 0.16+ | Syntax highlighting for code blocks | Already in project; wrap in `@MainActor` for thread-safe cache access |
| `Task.sleep(for:)` | Swift 5.7+ | Structured concurrency timer replacement | Use instead of `Timer.scheduledTimer` for polling loops in ViewModels |
| `@ObservationIgnored` | Observation framework | Exclude `Task` properties from observation tracking | Apply to stored `Task<Void, Never>?` properties that should not trigger view updates |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `OSAllocatedUnfairLock` for AppLogger | Convert to `actor` | Actor would require `await` at every call site (50+ locations); `OSAllocatedUnfairLock` preserves synchronous API |
| `@MainActor` for SyntaxHighlighter | Per-call locking | SyntaxHighlighter is only called from SwiftUI views (already on MainActor); explicit locking adds overhead without benefit |
| `.task(id:)` for caching | `onAppear` + manual cache dictionary | `.task(id:)` auto-cancels stale work; manual caching requires explicit invalidation logic |
| `enableForeignKeys: true` | Raw `PRAGMA foreign_keys = ON` in configure.swift | Raw PRAGMA only applies to first connection; `enableForeignKeys` applies to every pooled connection via SQLiteKit's `SQLiteConnectionSource` |

## Architecture Patterns

### Pattern 1: OSAllocatedUnfairLock for Sendable Classes

**What:** Use `OSAllocatedUnfairLock<State>` to protect mutable state in a `final class: Sendable` without requiring `@unchecked Sendable`.

**When to use:** When a class must be `Sendable` and called synchronously from multiple isolation domains (e.g., logging from any thread).

**Example:**
```swift
// Source: Apple docs / observed in AppLogger.swift
final class AppLogger: Sendable {
    private struct BufferState: Sendable {
        var buffer: [String] = []
    }
    private let state = OSAllocatedUnfairLock(initialState: BufferState())

    func info(_ message: String) {
        state.withLock { s in
            s.buffer.append(message)
        }
    }
}
```

**Key detail:** The lock's `withLock` closure must be synchronous and non-escaping. File I/O should happen outside the lock (drain buffer, then write).

### Pattern 2: @State + .task(id:) Caching in SwiftUI

**What:** Store expensive computation results in `@State` and recompute only when the input changes via `.task(id:)`.

**When to use:** When a view's body references an expensive operation (syntax highlighting, date formatting, sorting) that depends on a single value.

**Example:**
```swift
// Source: observed in CodeBlockView.swift
struct CodeBlockView: View {
    let code: String
    @State private var highlightedCode: AttributedString?

    var body: some View {
        Text(highlightedCode ?? AttributedString(code))
            .task(id: code) {
                highlightedCode = SyntaxHighlighter.highlight(code: code, language: language)
            }
    }
}
```

**Key detail:** `.task(id:)` runs when the view appears AND when the `id` value changes. It automatically cancels the previous task if the value changes again before completion.

### Pattern 3: Exponential Backoff for Polling

**What:** Increase poll interval when data hasn't changed; reset to minimum when changes are detected.

**When to use:** Any periodic network polling where data changes are infrequent.

**Example:**
```swift
// Source: observed in TeamsViewModel.swift
private static let minPollInterval: TimeInterval = 15
private static let maxPollInterval: TimeInterval = 120
private static let backoffMultiplier: Double = 1.5

// In polling loop:
let newHash = computeTeamHash()
if newHash == previousTeamHash {
    currentPollInterval = min(currentPollInterval * Self.backoffMultiplier, Self.maxPollInterval)
} else {
    currentPollInterval = Self.minPollInterval
    previousTeamHash = newHash
}
```

### Pattern 4: ViewModel Extraction from Views

**What:** Move async logic (API calls, error handling) from SwiftUI View structs into `@Observable @MainActor` ViewModel classes.

**When to use:** When a View contains inline `Task {}` blocks with API calls, especially without `do/catch` error handling.

**Example:**
```swift
// Source: observed in NewSessionViewModel.swift
@MainActor @Observable
class NewSessionViewModel {
    var isCreating = false
    private var apiClient: APIClient?

    func configure(client: APIClient) { self.apiClient = client }

    func createSession(projectId: UUID?, ...) async -> ChatSession? {
        guard let apiClient else { return nil }
        isCreating = true
        defer { isCreating = false }
        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions", body: request)
            return response.data
        } catch {
            AppLogger.shared.error("Failed to create session: \(error)", category: "ui")
            return nil
        }
    }
}
```

### Anti-Patterns to Avoid

- **`@unchecked Sendable` on mutable classes:** Suppresses compiler safety checks; use `OSAllocatedUnfairLock` or `actor` instead.
- **`nonisolated(unsafe)` on cached state:** Tells compiler to ignore isolation; use proper actor isolation (`@MainActor`) instead.
- **Syntax highlighting in `body` without caching:** `SyntaxHighlighter.highlight()` is non-trivial; calling it directly in `body` causes re-computation on every view evaluation.
- **Full data reload in health checks:** `MCPViewModel.checkHealth()` should NOT call `loadServers()` which rebuilds search cache and triggers observation; a lightweight reachability check suffices.
- **Raw PRAGMA in configure.swift:** `PRAGMA foreign_keys = ON` only applies to the connection that runs it; SQLite connection pools create multiple connections.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread-safe mutable state in Sendable class | Manual `os_unfair_lock` wrapper | `OSAllocatedUnfairLock` | Apple's API handles memory safety, value semantics, and `Sendable` conformance |
| View-lifecycle-aware async caching | Manual `onAppear`/`onDisappear` + dictionary | `.task(id:)` modifier | Automatic cancellation, lifecycle binding, and identity-based re-execution |
| SQLite FK enforcement across pool | Raw PRAGMA query in configure | `SQLiteConfiguration(enableForeignKeys: true)` | Applied per-connection by SQLiteKit; raw PRAGMA misses pool-created connections |
| Timer coalescing for energy | Custom timer wrapper | `timer.tolerance = 0.3` | iOS coalesces timers within tolerance window; standard API |

**Key insight:** Every fix in Phase 18 uses existing Apple APIs or framework features. The CRITICAL findings exist because the original code used lower-level or incorrect patterns, not because the platform lacks solutions.

## Common Pitfalls

### Pitfall 1: OSAllocatedUnfairLock and Async

**What goes wrong:** Attempting to call `async` functions inside `withLock` closure, or holding the lock while performing I/O.

**Why it happens:** `withLock` requires a synchronous closure. File I/O inside the lock blocks all other callers.

**How to avoid:** Drain buffer inside lock, write to disk outside lock. Timer-flush and buffer-full-flush both follow this pattern.

**Warning signs:** Compilation error "cannot call async function in synchronous context" or deadlock under heavy logging.

### Pitfall 2: @MainActor on Enum vs Class

**What goes wrong:** Adding `@MainActor` to an enum with static mutable state causes callers outside MainActor to need `await`.

**Why it happens:** `SyntaxHighlighter` is called from SwiftUI `.task(id:)` which already runs on MainActor, so this is safe. But if it were called from a background Task, compilation would fail.

**How to avoid:** Verify all call sites are already on MainActor before applying. In this case, `.task(id:)` inside a View is MainActor-isolated.

**Warning signs:** Build errors at call sites saying "expression is 'async' but is not marked with 'await'".

### Pitfall 3: enableForeignKeys vs Raw PRAGMA

**What goes wrong:** Using `PRAGMA foreign_keys = ON` in configure.swift only affects the first connection. Subsequent pool connections don't have FK enabled.

**Why it happens:** SQLite connection pools create fresh connections on demand. Each connection starts with foreign_keys = OFF (SQLite default).

**How to avoid:** Use `SQLiteConfiguration(enableForeignKeys: true)` which instructs SQLiteKit to apply the PRAGMA on every new connection.

**Warning signs:** FK violations in production but not in development (single-connection testing vs pool).

### Pitfall 4: Task Cancellation in Polling

**What goes wrong:** Polling task captures `[weak self]` but doesn't check `Task.isCancelled` after sleep, causing one extra poll after `stopPolling()`.

**Why it happens:** `Task.sleep` throws `CancellationError` on cancellation, but `try?` swallows it.

**How to avoid:** Check `Task.isCancelled` after every sleep. Use `guard !Task.isCancelled else { break }` pattern.

**Warning signs:** Log entries showing poll requests after the user navigated away.

### Pitfall 5: ViewModel Extraction Breaking View Bindings

**What goes wrong:** Moving async creation flows from View to ViewModel breaks `$isCreating` bindings if the `isCreating` property moves but the `@State` binding in the View still references the old location.

**Why it happens:** `@State` in the View and `@Observable` in the ViewModel both publish, but the View must reference `sessionViewModel.isCreating` not a local `@State`.

**How to avoid:** After extraction, search for all references to the moved properties and update them to go through the ViewModel.

**Warning signs:** UI not updating (progress spinner not showing) or stale state after session creation.

## Code Examples

Verified patterns from the actual codebase (Phase 18 has been executed and verified):

### AppLogger Thread Safety (CONC-01)
```swift
// Source: ILSApp/ILSApp/Services/AppLogger.swift
final class AppLogger: Sendable {
    private struct BufferState: Sendable { var buffer: [String] = [] }
    private let state = OSAllocatedUnfairLock(initialState: BufferState())
    private let timerState = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    private func enqueueEntry(_ level: String, category: String, message: String) {
        let entriesToFlush: [String]? = state.withLock { s in
            s.buffer.append(entry)
            if s.buffer.count >= self.maxBufferSize {
                let current = s.buffer
                s.buffer.removeAll(keepingCapacity: true)
                return current
            }
            return nil
        }
        if let entries = entriesToFlush { writeEntriesToDisk(entries) }
    }
}
```

### SyntaxHighlighter MainActor Isolation (CONC-02)
```swift
// Source: ILSApp/ILSApp/Utils/SyntaxHighlighter.swift
@MainActor
enum SyntaxHighlighter {
    private static var highlighterCache: [String: Splash.SyntaxHighlighter<AttributedStringOutputFormat>] = [:]

    static func highlight(code: String, language: String?) -> AttributedString {
        // Safe: entire enum is @MainActor; no concurrent access possible
        if let cached = highlighterCache[language] { ... }
    }
}
```

### CodeBlockView Caching (UIPERF-01)
```swift
// Source: ILSApp/ILSApp/Views/Chat/CodeBlockView.swift
struct CodeBlockView: View {
    let code: String
    @State private var highlightedCode: AttributedString?

    var body: some View {
        Text(highlightedCode ?? AttributedString(code))
            .task(id: code) {
                highlightedCode = SyntaxHighlighter.highlight(
                    code: cachedDisplayedLines.joined(separator: "\n"),
                    language: language
                )
            }
    }
}
```

### Teams Exponential Backoff (ENRG-03)
```swift
// Source: ILSApp/ILSApp/ViewModels/TeamsViewModel.swift
private static let minPollInterval: TimeInterval = 15
private static let maxPollInterval: TimeInterval = 120
private static let backoffMultiplier: Double = 1.5

func startPolling(teamName: String) {
    pollingTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64((self?.currentPollInterval ?? 15) * 1_000_000_000))
            guard !Task.isCancelled else { break }
            await self?.loadTeamDetail(name: teamName)
            let newHash = self?.computeTeamHash() ?? 0
            if newHash == self?.previousTeamHash {
                self?.currentPollInterval = min(self!.currentPollInterval * Self.backoffMultiplier, Self.maxPollInterval)
            } else {
                self?.currentPollInterval = Self.minPollInterval
            }
        }
    }
}
```

### SQLite FK Enforcement (DB-01)
```swift
// Source: Sources/ILSBackend/App/configure.swift
let sqliteConfig = SQLiteConfiguration(storage: .file(path: dbPath), enableForeignKeys: true)
app.databases.use(.sqlite(sqliteConfig), as: .sqlite)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@unchecked Sendable` on mutable class | `OSAllocatedUnfairLock` in `Sendable` class | iOS 16 / Swift 5.7 | Compiler-checked thread safety without actor overhead |
| `nonisolated(unsafe)` on cached state | `@MainActor` enum isolation | Swift 5.10 | Eliminates unsafe escape hatch; compiler enforces isolation |
| `Timer.scheduledTimer(withTimeInterval: 0.5)` | `withTimeInterval: 1.0` + `tolerance: 0.3` | Apple Energy guidelines | Reduces wake-ups by 50%+; timer coalescing saves battery |
| Raw `PRAGMA foreign_keys = ON` | `SQLiteConfiguration(enableForeignKeys: true)` | FluentSQLiteDriver 4.x | Applied per-connection automatically by pool |
| Inline `Task {}` in View for API calls | Extracted ViewModel with `do/catch` | SwiftUI architectural best practice | Proper error handling, testability, separation of concerns |

**Deprecated/outdated:**
- `@unchecked Sendable`: Still compiles but defeats purpose of Swift's sendability checking. Use only as last resort.
- `nonisolated(unsafe)`: Swift 5.10 escape hatch for migration; prefer proper isolation.
- Sub-second timer intervals in widgets/Live Activities: Apple's Human Interface Guidelines recommend 1s+ for energy efficiency.

## Cross-Audit Correlations

Phase 18 requirements have significant overlap with other audit findings:

| Shared Root Cause | Requirements Addressed | Fix Strategy |
|-------------------|----------------------|--------------|
| MCPViewModel.checkHealth() | ENRG-02 + SPERF-01 | Single fix: lightweight reachability-only check replaces full loadServers() |
| SyntaxHighlighter isolation | CONC-02 + UIPERF-01 | Combined fix: @MainActor on enum + .task(id:) caching in CodeBlockView |
| NewSessionView extraction | ARCH-03 + error handling | Single extraction: NewSessionViewModel with do/catch covers architecture + error handling |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CONC-01 | Convert AppLogger from `@unchecked Sendable` to actor or `OSAllocatedUnfairLock` | Pattern 1 (OSAllocatedUnfairLock); synchronous callers cannot await, so actor is not viable; OSAllocatedUnfairLock preserves sync API |
| CONC-02 | Add `@MainActor` to SyntaxHighlighter enum, remove `nonisolated(unsafe)` on `highlighterCache` | Pattern 1 (@MainActor isolation); all call sites are SwiftUI views (already MainActor); Pitfall 2 documents call-site verification |
| ENRG-01 | Reduce Live Activity timer from 0.5s to 1.0s or SwiftUI animation | Apple HIG recommends 1s+ for Live Activity updates; `timer.tolerance = 0.3` enables coalescing |
| ENRG-02 | Replace MCP health poll full server reload with lightweight health-only endpoint | Anti-pattern: full loadServers() rebuilds cache + triggers observation; fix: `let _: = try await client.get("/mcp")` (discard response) |
| ENRG-03 | Add exponential backoff to Teams 15s poll | Pattern 3 (exponential backoff); hash-based change detection; 15s min / 120s max / 1.5x multiplier |
| SPERF-01 | MCPViewModel.checkHealth() calls full loadServers() every 30s (same root cause as ENRG-02) | Same fix as ENRG-02; shared root cause documented in Cross-Audit Correlations |
| ARCH-01 | Route MacChatView API calls through SessionsViewModel with do/catch | Pattern 4 (ViewModel extraction); `AppLogger.shared.error()` in catch blocks for error visibility |
| ARCH-02 | Add do/catch to MacChatView unhandled Task error | Covered by ARCH-01 fix; both rename and delete alert handlers need do/catch |
| ARCH-03 | Extract NewSessionView 3 inline async flows to NewSessionViewModel | Pattern 4; new `NewSessionViewModel` with `createSession()`, `forkSession()`, `createProjectAndSession()` |
| ARCH-04 | Add `private` to MacSettingsView @State | SwiftUI best practice: @State should always be private to prevent external mutation |
| UIPERF-01 | Cache SyntaxHighlighter in CodeBlockView with @State + .task(id:) | Pattern 2 (.task(id:) caching); prevents re-tokenization on every body evaluation |
| UIPERF-02 | Pre-compute Set for ThemePickerView.availableThemes | `Set<String>` computed property for O(1) `contains()` instead of O(n) `first(where:)` |
| DB-01 | Set PRAGMA foreign_keys via pool configuration callback | `SQLiteConfiguration(enableForeignKeys: true)` ensures every pooled connection enforces FK constraints |
</phase_requirements>

## Open Questions

1. **MCP health check endpoint optimization**
   - What we know: `checkHealth()` calls `client.get("/mcp")` and discards the response. This still fetches the full MCP server list from the backend.
   - What's unclear: Whether a dedicated `/mcp/health` lightweight endpoint would be more efficient (smaller payload, less backend work).
   - Recommendation: The current fix is sufficient for CRITICAL severity. A dedicated health endpoint can be added in a later phase if profiling shows the MCP list query is expensive.

2. **SyntaxHighlighter call from background contexts**
   - What we know: Adding `@MainActor` to SyntaxHighlighter requires all callers to be on MainActor. Currently, all callers are SwiftUI views inside `.task(id:)` which runs on MainActor.
   - What's unclear: Whether future code might need to call SyntaxHighlighter from a background context.
   - Recommendation: Accept the @MainActor constraint. If background highlighting is needed later, use `await MainActor.run { SyntaxHighlighter.highlight(...) }`.

## Sources

### Primary (HIGH confidence)
- Direct source code inspection of all 13 target files in the ILS-iOS codebase
- Phase 18 Verification Report (18-VERIFICATION.md) -- 13/13 pass, all requirements satisfied
- Apple Developer Documentation: `OSAllocatedUnfairLock`, `@MainActor`, `.task(id:)` modifier
- FluentSQLiteDriver source: `SQLiteConfiguration.enableForeignKeys` parameter

### Secondary (MEDIUM confidence)
- Apple Human Interface Guidelines: Live Activity update frequency recommendations
- Swift Evolution proposals: SE-0302 (Sendable), SE-0316 (@MainActor), SE-0395 (Observation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all solutions use Apple first-party APIs already present in the project
- Architecture: HIGH -- patterns verified against actual executed code (Phase 18 verified 13/13)
- Pitfalls: HIGH -- documented from real issues encountered during implementation (see STATE.md decisions)

**Research date:** 2026-02-23
**Valid until:** 2026-03-23 (stable Apple APIs; no fast-moving dependencies)
**Note:** This research was produced retroactively after Phase 18 execution and verification. All patterns and code examples reflect the verified implementation state.
