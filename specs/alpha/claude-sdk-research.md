# ClaudeCodeSDK & Streaming Research

**Date:** 2026-02-07
**Researcher:** sdk-researcher agent
**Branch:** `design/v2-redesign`

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State of ClaudeCodeSDK](#current-state-of-claudecodesdk)
3. [Our Fork & Integration History](#our-fork--integration-history)
4. [The RunLoop/NIO Problem (Root Cause)](#the-runloopnio-problem-root-cause)
5. [Current Workaround: Direct Process + DispatchQueue](#current-workaround-direct-process--dispatchqueue)
6. [iOS Client Streaming Architecture](#ios-client-streaming-architecture)
7. [Alternative SDKs & Libraries](#alternative-sdks--libraries)
8. [Swift Subprocess (New Foundation Package)](#swift-subprocess-new-foundation-package)
9. [PythonKit & Python Bridging](#pythonkit--python-bridging)
10. [Architecture Proposal](#architecture-proposal)
11. [Recommendation Matrix](#recommendation-matrix)
12. [References](#references)

---

## Executive Summary

The ClaudeCodeSDK (by jamesrochabrun, forked by krzemienski) is **fundamentally broken in Vapor/NIO contexts** due to its reliance on `FileHandle.readabilityHandler` + Combine's `PassthroughSubject`, which requires a RunLoop that Vapor's NIO event loops don't pump. Our current workaround -- direct `Process` management with `DispatchQueue` for stdout reads -- is **production-proven and reliable**.

**Key finding:** The current `ClaudeExecutorService` architecture is the correct approach. The SDK should remain removed from `Package.swift`. Future improvements should focus on:
1. Migrating from `Process` to `swift-subprocess` (when Swift 6.1+ is adopted)
2. Enhancing the SSE streaming pipeline between backend and iOS client
3. Keeping the PTY wrapper as a fallback for edge cases

---

## Current State of ClaudeCodeSDK

### Repository: [jamesrochabrun/ClaudeCodeSDK](https://github.com/jamesrochabrun/ClaudeCodeSDK)

| Attribute | Value |
|-----------|-------|
| Author | James Rochabrun |
| Swift Version | 6.0+ |
| Platform | macOS 13+ only (uses `Process`) |
| License | MIT |
| Dependencies | Foundation, Combine, os.log |
| Backend modes | Headless (`claude -p` CLI), Agent SDK (Node.js) |

### SDK Architecture

```
ClaudeCodeClient (public API)
  └── ClaudeCodeBackend (protocol)
       ├── HeadlessBackend (Process + Combine streaming)
       └── AgentSDKBackend (Node.js bridge)
```

### Key API Surface

```swift
protocol ClaudeCode {
    func runSinglePrompt(prompt:outputFormat:options:) async throws -> ClaudeCodeResult
    func continueConversation(prompt:outputFormat:options:) async throws -> ClaudeCodeResult
    func resumeConversation(sessionId:prompt:outputFormat:options:) async throws -> ClaudeCodeResult
    func listSessions() async throws -> [SessionInfo]
    func cancel()
}

enum ClaudeCodeResult {
    case text(String)
    case json(ResultMessage)
    case stream(AnyPublisher<ResponseChunk, Error>)  // <-- THE PROBLEM
}
```

### Output Formats

| Format | CLI Flag | SDK Result |
|--------|----------|------------|
| `text` | `--output-format text` | `.text(String)` |
| `json` | `--output-format json` | `.json(ResultMessage)` |
| `stream-json` | `--output-format stream-json` | `.stream(AnyPublisher)` |

### Stream JSON Line Types

Each line from `claude -p --output-format stream-json` is a JSON object:

| Type | Subtype | Content |
|------|---------|---------|
| `system` | `init` | Session ID, available tools |
| `system` | `completion` | Token usage updates |
| `assistant` | -- | Content blocks: text, tool_use, tool_result, thinking |
| `result` | `success`/`error` | Cost, duration, usage stats, session info |

---

## Our Fork & Integration History

### Fork: [krzemienski/ClaudeCodeSDK](https://github.com/krzemienski/ClaudeCodeSDK)

- **Revision:** `f626d1d1eab3bf43a1eef2f70b2a493903f7e5e8` (pinned to `main` branch)
- **Still in:** `ILSFullStack.xcworkspace/xcshareddata/swiftpm/Package.resolved` (line 43)
- **Removed from:** `Package.swift` (the actual build dependency was removed)
- **Source checkout cached at:** `ILSApp/build/SourcePackages/checkouts/ClaudeCodeSDK/`

### Integration Timeline

1. **Phase 1 (early Feb 2026):** SDK added as dependency, `runWithSDK()` method created in executor service
2. **Discovery:** Streaming never worked in Vapor context -- publisher never emitted
3. **Root cause identified:** RunLoop/NIO incompatibility (see next section)
4. **Phase 2:** SDK bypassed entirely; direct `Process` + `DispatchQueue` implemented
5. **Phase 3 (ios-app-polish2):** Spec called for removing SDK from `Package.swift` (task 0.2 in `specs/ios-app-polish2/tasks.md`)
6. **Current state:** SDK removed from `Package.swift` dependencies but still in resolved packages file and build caches

---

## The RunLoop/NIO Problem (Root Cause)

### The Bug

In `HeadlessBackend.swift` (line 478):

```swift
outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
    let data = fileHandle.availableData
    // ... process data ...
    subject.send(.assistant(assistantMessage))
}
```

**Why this fails in Vapor:**

1. `FileHandle.readabilityHandler` uses the **RunLoop** of the thread that set it to schedule callbacks
2. Vapor runs on SwiftNIO's `EventLoop` threads, which are **not** RunLoop-based
3. NIO event loops use `epoll`/`kqueue` directly -- they never call `RunLoop.run()`
4. Therefore, `readabilityHandler` callbacks are **never delivered**
5. The `PassthroughSubject` never receives data, the `AnyPublisher<ResponseChunk, Error>` never emits

### Why It Works in macOS Apps

Standard macOS apps have a main RunLoop (pumped by `NSApplication.run()`). The SDK works perfectly in that context because `readabilityHandler` callbacks fire normally on the main RunLoop.

### The Fundamental Mismatch

| Context | Event System | RunLoop Available? | SDK Works? |
|---------|-------------|-------------------|------------|
| macOS GUI app | NSApplication RunLoop | Yes | Yes |
| CLI tool (with RunLoop.main.run()) | Manual RunLoop | Yes | Yes |
| Vapor server | SwiftNIO EventLoop | **No** | **No** |
| Linux server | SwiftNIO EventLoop | **No** | **No** |

### Could the SDK Be Fixed?

Theoretically yes, by replacing `readabilityHandler` with one of:
- `DispatchIO` / `DispatchSource.makeReadSource()` (GCD-based, no RunLoop needed)
- `NIOPipeBootstrap` (NIO-native pipe reading)
- `AsyncStream` with blocking read on a background thread
- `swift-subprocess` AsyncSequence streaming

However, the SDK maintainer has not made this change, and our fork would need to be maintained separately.

---

## Current Workaround: Direct Process + DispatchQueue

### File: `Sources/ILSBackend/Services/ClaudeExecutorService.swift`

Our production implementation that **correctly solves** the RunLoop problem:

```swift
actor ClaudeExecutorService {
    private let readQueue = DispatchQueue(label: "ils.claude-stdout-reader", qos: .userInitiated)

    nonisolated func execute(prompt:workingDirectory:options:) -> AsyncThrowingStream<StreamMessage, Error> {
        AsyncThrowingStream { continuation in
            // 1. Configure Process with pipes
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            // 2. Send prompt via stdin pipe
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            stdinPipe.fileHandleForWriting.write(promptData)
            stdinPipe.fileHandleForWriting.closeFile()

            // 3. Read stdout on dedicated GCD queue (NO RunLoop needed)
            self.readQueue.async {
                let handle = outputPipe.fileHandleForReading
                while true {
                    let chunk = handle.availableData  // Blocks on GCD thread, not NIO
                    if chunk.isEmpty { break }         // EOF
                    // Parse JSON lines and yield to continuation
                }
                process.waitUntilExit()
                continuation.finish()
            }

            // 4. Two-tier timeout: 30s initial + 5min total
        }
    }
}
```

### Why This Works

| Aspect | SDK Approach | Our Approach |
|--------|-------------|--------------|
| Read mechanism | `readabilityHandler` (RunLoop) | `availableData` (blocking on GCD thread) |
| Threading | Depends on caller's RunLoop | Dedicated `DispatchQueue` |
| NIO compatible | No | Yes |
| Streaming | Combine Publisher | AsyncThrowingStream |
| Timeout | Optional `Task.sleep` | GCD `DispatchWorkItem` (30s + 5min) |
| Cancellation | Process.terminate() | Process.terminate() + pipe closeFile() |

### Known Lessons (from project memory)

- **Always call `process.waitUntilExit()` before `process.terminationStatus`** -- otherwise `NSInvalidArgumentException` if process still running after stdout EOF
- **Close file handles on timeout** -- `outputPipe.fileHandleForReading.closeFile()` to unblock the blocking `availableData` call
- **Claude CLI `-p` hangs as subprocess within active Claude Code session** -- environment constraint, works independently

---

## iOS Client Streaming Architecture

### Data Flow

```
Claude CLI (subprocess)
    ↓ stdout (stream-json lines)
ClaudeExecutorService (Vapor backend, port 9090)
    ↓ AsyncThrowingStream<StreamMessage>
ChatController (Vapor route handler)
    ↓ Server-Sent Events (SSE) over HTTP
SSEClient (iOS app, URLSession.bytes)
    ↓ @Published messages: [StreamMessage]
ChatViewModel (message batching, 75ms intervals)
    ↓ @Published messages: [ChatMessage]
ChatView (SwiftUI)
```

### SSEClient (`ILSApp/ILSApp/Services/SSEClient.swift`)

- Uses `URLSession.bytes(for:)` for async streaming
- 60s connection timeout via `withThrowingTaskGroup` race
- Reconnection: 3 attempts with exponential backoff (2s, 4s, 8s, capped 30s)
- Parses SSE format: `event:`, `data:`, `id:`, `:` (heartbeat)
- Custom `URLSessionConfiguration`: 5min request timeout, 1hr resource timeout

### ChatViewModel (`ILSApp/ILSApp/ViewModels/ChatViewModel.swift`)

- Subscribes to SSEClient via Combine `$messages` publisher
- **Message batching**: accumulates stream messages and flushes every 75ms
- Tracks new messages since last flush via `lastProcessedMessageIndex`
- Connection state monitoring with "Taking longer than expected..." after 5s
- Token count estimation: `text.count / 4`
- Supports: retry, delete, fork session, cancel (notifies backend)

---

## Alternative SDKs & Libraries

### 1. [AruneshSingh/ClaudeCodeSwiftSDK](https://github.com/AruneshSingh/ClaudeCodeSwiftSDK)

| Attribute | Value |
|-----------|-------|
| Swift | 6.0+ |
| Platform | macOS 13+ |
| Streaming | `AsyncThrowingStream<Message, Error>` (not Combine!) |
| Dependencies | Zero (pure Swift) |
| Vapor compatible? | **Unknown -- needs investigation** |

**Key advantage:** Uses `AsyncThrowingStream` instead of Combine publishers, which *might* work in NIO contexts if the underlying read mechanism uses GCD or blocking reads rather than RunLoop-based handlers. Needs source code audit.

### 2. [GeorgeLyon/SwiftClaude](https://github.com/GeorgeLyon/SwiftClaude)

- Direct Anthropic API client (not CLI wrapper)
- Streaming via async/await
- Not applicable -- we need CLI wrapper, not API client

### 3. [jamesrochabrun/SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic)

- Direct API client with `AsyncHTTPClient` on Linux
- Server-side Swift compatible
- Not applicable -- we need CLI wrapper for Claude Code features (tools, sessions, MCP)

### 4. [jamf/Subprocess](https://github.com/jamf/Subprocess)

- Pre-Foundation subprocess library by Jamf
- Synchronous and asynchronous interfaces
- macOS only
- Superseded by swift-subprocess

---

## Swift Subprocess (New Foundation Package)

### Repository: [swiftlang/swift-subprocess](https://github.com/swiftlang/swift-subprocess)

| Attribute | Value |
|-----------|-------|
| Released | September 2025 |
| Swift | 6.1+ (6.2 for SubprocessSpan) |
| Platforms | macOS, Linux, Windows |
| Part of | Swift Foundation |

### Key API

```swift
import Subprocess

// Collected output (non-streaming)
let result = try await Subprocess.run(.name("claude"), arguments: ["-p", "--output-format", "json"])
print(result.standardOutput)

// Streaming stdout as AsyncSequence
let executionResult = try await Subprocess.run(
    .name("claude"),
    arguments: ["-p", "--output-format", "stream-json"],
    output: .stream
) { execution, standardOutput in
    for try await line in standardOutput.lines() {
        // Process each JSON line as it arrives
        let message = parseStreamMessage(line)
        continuation.yield(message)
    }
}

// With stdin writing
let result = try await Subprocess.run(
    .name("claude"),
    arguments: ["-p", "--output-format", "stream-json"],
    output: .stream
) { execution, standardInput, standardOutput in
    try await standardInput.write(promptData)
    standardInput.finish()

    for try await line in standardOutput.lines() {
        // Stream processing
    }
}
```

### Why This Is The Future

| Feature | Process + DispatchQueue | swift-subprocess |
|---------|------------------------|------------------|
| API style | Imperative, manual pipes | Structured concurrency |
| Streaming | Manual buffer management | `AsyncSequence` native |
| Cancellation | Manual `terminate()` | Structured (automatic on task cancel) |
| Backpressure | None | Built-in via AsyncSequence |
| NIO compatible | Yes (GCD-based) | Yes (async/await native) |
| Platform | macOS only | macOS, Linux, Windows |
| Error handling | Manual exit code checking | `TerminationStatus` enum |

### Migration Path

Our `ClaudeExecutorService` could be migrated from:
```swift
// Current: Process + DispatchQueue + manual buffer
self.readQueue.async {
    while true {
        let chunk = handle.availableData
        if chunk.isEmpty { break }
        // manual line splitting...
    }
}
```

To:
```swift
// Future: swift-subprocess + AsyncSequence
let result = try await Subprocess.run(
    .path("/bin/zsh"), arguments: ["-l", "-c", command],
    output: .stream
) { execution, stdout in
    for try await line in stdout.lines() {
        Self.processJsonLine(line, continuation: continuation)
    }
}
```

### Blocker

**Requires Swift 6.1+.** Our `Package.swift` currently specifies `swift-tools-version:5.9`. Upgrading is a non-trivial decision that affects all dependencies (Vapor, Fluent, Citadel, etc.).

---

## PythonKit & Python Bridging

### [pvieito/PythonKit](https://github.com/pvieito/PythonKit)

PythonKit allows calling Python code directly from Swift using `@dynamicCallable` and `@dynamicMemberLookup`.

### Assessment for Our Use Case

| Approach | Viability | Notes |
|----------|-----------|-------|
| PythonKit in Vapor | **Not recommended** | Python GIL + NIO event loops = performance disaster |
| Python subprocess | **Already have it** | `claude_pty_wrapper.py` exists |
| Python subprocess via Process | **Viable** | Wrap Python script that wraps Claude CLI |

### Our PTY Wrapper (`Sources/ILSBackend/Scripts/claude_pty_wrapper.py`)

Already exists as a fallback for cases where Claude CLI hangs without a TTY:

```python
# Creates a pseudo-terminal for Claude CLI
master_fd, slave_fd = pty.openpty()
pid = os.fork()
# Child: execvp(claude_args)
# Parent: select() loop reading from master_fd, writing to stdout
```

**When to use:** Only needed if Claude CLI requires a TTY for certain operations (interactive mode). The current `-p` (print mode) flag bypasses this need for most operations.

### Verdict on Python Bridging

**Not recommended.** Our Swift-native approach is cleaner, faster, and has fewer failure modes. The PTY wrapper is a valid fallback but adds complexity (Python runtime dependency, fork/exec overhead, PTY management).

---

## Architecture Proposal

### Current Architecture (Keep)

```
┌─────────────────────────────────────────────────────┐
│                    iOS App                            │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────┐ │
│  │ ChatView    │──│ChatViewModel│──│  SSEClient   │ │
│  │ (SwiftUI)   │  │(batching)  │  │(URLSession)  │ │
│  └─────────────┘  └────────────┘  └──────┬───────┘ │
└──────────────────────────────────────────┼──────────┘
                                           │ SSE over HTTP
┌──────────────────────────────────────────┼──────────┐
│                  Vapor Backend (port 9090)│          │
│  ┌───────────────┐  ┌───────────────────┴────────┐ │
│  │ChatController │──│ ClaudeExecutorService       │ │
│  │(SSE response) │  │ (Process + DispatchQueue)   │ │
│  └───────────────┘  └───────────────┬────────────┘ │
└──────────────────────────────────────┼──────────────┘
                                       │ stdin/stdout pipes
                                       ▼
                              ┌─────────────────┐
                              │ Claude CLI       │
                              │ -p --stream-json │
                              └─────────────────┘
```

### Recommended Improvements (Prioritized)

#### Priority 1: Clean Up SDK Remnants

- Remove `ClaudeCodeSDK` from `Package.resolved`
- Delete cached checkouts from `ILSApp/build/SourcePackages/checkouts/ClaudeCodeSDK/`
- Verify `Package.swift` has no SDK reference (already done)

#### Priority 2: Enhance Current Streaming

- Add `--include-partial-messages` flag support for character-by-character streaming
- Implement heartbeat/keepalive in SSE to detect stale connections
- Add structured error types to `StreamMessage` (currently uses string error codes)

#### Priority 3: Consider AsyncStream Refactor (Medium-term)

Replace the `DispatchQueue`-based reader with a pure `AsyncStream` approach that's still compatible with NIO:

```swift
nonisolated func execute(...) -> AsyncThrowingStream<StreamMessage, Error> {
    AsyncThrowingStream { continuation in
        Task.detached {
            // Blocking read on Task.detached thread (not NIO thread)
            let handle = outputPipe.fileHandleForReading
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                // process and yield...
            }
        }
    }
}
```

This eliminates the GCD dependency while staying NIO-compatible.

#### Priority 4: swift-subprocess Migration (Long-term)

When the project upgrades to Swift 6.1+:
- Replace `Process` with `Subprocess.run()`
- Replace manual buffer management with `stdout.lines()`
- Get structured cancellation for free
- Cross-platform support (for future Linux backend deployment)

#### Priority 5: WebSocket Upgrade (Future)

Replace SSE with WebSocket for bidirectional communication:
- Backend can push heartbeats, progress updates
- Client can send cancel/interrupt without separate HTTP endpoint
- Vapor has native WebSocket support
- Lower overhead than SSE for long-running streams

---

## Recommendation Matrix

| Approach | NIO Compatible | Effort | Risk | Recommendation |
|----------|---------------|--------|------|----------------|
| **Keep current (Process + GCD)** | Yes | None | None | **Use now** |
| Fix ClaudeCodeSDK fork | Needs work | High | Medium (maintenance) | **Do not pursue** |
| AruneshSingh/ClaudeCodeSwiftSDK | Unknown | Medium | High (untested) | **Evaluate only** |
| swift-subprocess migration | Yes | Medium | Low (official package) | **When Swift 6.1+** |
| PythonKit bridging | No | High | High | **Do not pursue** |
| PTY wrapper subprocess | Yes | Low | Low | **Keep as fallback** |
| WebSocket upgrade | Yes | Medium | Low | **Future enhancement** |

### Bottom Line

**The current architecture is sound.** The `ClaudeExecutorService` with direct `Process` + `DispatchQueue` is the right pattern for a Vapor/NIO backend. The ClaudeCodeSDK should stay removed. Future improvements should focus on the streaming pipeline quality (heartbeats, partial messages, structured errors) rather than changing the fundamental subprocess execution approach.

---

## References

- [ClaudeCodeSDK (jamesrochabrun)](https://github.com/jamesrochabrun/ClaudeCodeSDK)
- [ClaudeCodeSDK fork (krzemienski)](https://github.com/krzemienski/ClaudeCodeSDK)
- [ClaudeCodeSwiftSDK (AruneshSingh)](https://github.com/AruneshSingh/ClaudeCodeSwiftSDK)
- [swift-subprocess (swiftlang)](https://github.com/swiftlang/swift-subprocess)
- [swift-subprocess proposal](https://github.com/swiftlang/swift-foundation/blob/main/Proposals/0007-swift-subprocess.md)
- [SwiftClaude (GeorgeLyon)](https://github.com/GeorgeLyon/SwiftClaude)
- [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic)
- [PythonKit](https://github.com/pvieito/PythonKit)
- [Jamf Subprocess](https://github.com/jamf/Subprocess)
- [Swift Package Index: ClaudeCodeSDK](https://swiftpackageindex.com/jamesrochabrun/ClaudeCodeSDK)
- [NIO AsyncSequence APIs](https://github.com/apple/swift-nio/blob/main/docs/public-async-nio-apis.md)
- [Vapor Async docs](https://docs.vapor.codes/basics/async/)
- [Apple AsyncStream docs](https://developer.apple.com/documentation/swift/asyncstream)
- [Xcode Claude Agent SDK announcement](https://www.anthropic.com/news/apple-xcode-claude-agent-sdk)
