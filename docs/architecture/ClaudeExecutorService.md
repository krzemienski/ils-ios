# ClaudeExecutorService Architecture

The `ClaudeExecutorService` is a Swift actor that wraps the [ClaudeCodeSDK](https://github.com/krzemienski/ClaudeCodeSDK) to execute Claude Code CLI commands with streaming output. It serves as the bridge between the ILS backend and the Claude Code CLI, handling session management, streaming response conversion, and cancellation.

## Overview

**File:** `Sources/ILSBackend/Services/ClaudeExecutorService.swift` (313 lines)

**Purpose:**
- Execute Claude Code CLI commands via ClaudeCodeSDK
- Stream responses in real-time using AsyncThrowingStream
- Convert ClaudeCodeSDK's `ResponseChunk` types to ILSShared's `StreamMessage` types
- Manage active sessions with cancellation support
- Ensure thread-safe access using Swift's actor model

## Architecture

### Actor Model

`ClaudeExecutorService` is implemented as a Swift **actor** to ensure thread-safe access to its mutable state:

```swift
actor ClaudeExecutorService {
    private var client: ClaudeCodeClient?
    private var cancellables = Set<AnyCancellable>()
    private var activeSessions: [String: AnyCancellable] = [:]

    // All methods are actor-isolated by default
    // Nonisolated methods explicitly marked
}
```

**Why an Actor?**

Swift actors provide automatic synchronization and data-race safety, making them ideal for services managing shared mutable state across concurrent requests:

1. **Thread Safety**: Multiple concurrent requests can safely access the service
   - Actor ensures only one task can access mutable state at a time
   - All property mutations are serialized through the actor's executor
   - Prevents data races without manual locking mechanisms

2. **Session Isolation**: `activeSessions` dictionary is protected from race conditions
   - Concurrent cancellation requests won't corrupt the dictionary
   - Session cleanup (removeSession) is guaranteed atomic
   - Multiple simultaneous execute() calls safely modify the shared dictionary

3. **Async/Await Native**: Integrates seamlessly with Vapor's async request handlers
   - Actor methods marked `async` automatically suspend when waiting for actor access
   - No callback hell or completion handlers needed
   - Cooperative cancellation works naturally with Swift's structured concurrency

4. **Memory Safety**: Actor isolation prevents data races at compile time
   - Swift compiler enforces actor isolation rules
   - Sendable conformance checked for data crossing actor boundaries
   - Reference cycles automatically managed through actor context

**Alternative Approaches Considered:**

| Approach | Pros | Cons | Why Not Used |
|----------|------|------|--------------|
| **Serial DispatchQueue** | Simple, familiar | Manual synchronization, error-prone | No compile-time safety, can deadlock |
| **NSLock/OSAllocatedUnfairLock** | Fine-grained control | Verbose, manual lock/unlock | Easy to forget unlock, no async/await support |
| **Class with @MainActor** | Simple annotation | Ties to main thread | Unnecessary main thread blocking for I/O |
| **Struct (no shared state)** | No synchronization needed | Can't manage sessions | Need to track active sessions globally |

### Concurrency Model & Best Practices

#### Actor Isolation Strategy

The service uses a **hybrid isolation model**:

```swift
actor ClaudeExecutorService {
    // ACTOR-ISOLATED (requires await):
    private var client: ClaudeCodeClient?
    private var activeSessions: [String: AnyCancellable] = [:]

    // NONISOLATED (callable without await):
    nonisolated func execute(...) -> AsyncThrowingStream<StreamMessage, Error>
    nonisolated private func convertChunk(...) -> StreamMessage
}
```

**Isolation Decisions:**

| Member | Isolation | Rationale |
|--------|-----------|-----------|
| `client` | Actor-isolated | Mutable state accessed by multiple methods |
| `activeSessions` | Actor-isolated | Shared dictionary modified during session lifecycle |
| `execute()` | **Nonisolated** | Must return stream immediately without blocking |
| `convertChunk()` | **Nonisolated** | Pure function, no state access, called from non-isolated context |
| `runWithSDK()` | Actor-isolated | Accesses `client` and calls `storeSession()` |
| `cancel()` | Actor-isolated | Mutates `activeSessions` dictionary |

#### Thread Safety Guarantees

**What is Protected:**

✅ **Guaranteed Thread-Safe:**
- Concurrent modifications to `activeSessions` dictionary
- Multiple simultaneous calls to `cancel(sessionId:)`
- Session ID generation and storage during `execute()`
- `ClaudeCodeClient` configuration updates in `runWithSDK()`

✅ **Data Race Free:**
- Reading/writing `client` property
- Adding sessions via `storeSession()`
- Removing sessions via `removeSession()`
- Checking session existence in `cancel()`

**What is NOT Protected:**

❌ **Caller Responsibility:**
- Session ID uniqueness (caller must provide unique IDs)
- Consuming `AsyncThrowingStream` (caller manages iteration)
- Error handling on stream (caller's `for try await` handles errors)

**Sendable Conformance:**

Data crossing actor boundaries must be `Sendable` (thread-safe):

```swift
// ✅ Sendable - can safely cross actor boundary
func execute(
    prompt: String,              // String is Sendable
    workingDirectory: String?,   // Optional<String> is Sendable
    options: ExecutionOptions    // Struct with Sendable fields
) -> AsyncThrowingStream<...>    // AsyncThrowingStream is Sendable

// ✅ Sendable - continuation is Sendable
continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation

// ✅ Sendable - all StreamMessage cases contain Sendable types
continuation.yield(.assistant(message))
```

#### Nonisolated Function Usage

##### Why `execute()` is Nonisolated

```swift
nonisolated func execute(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions
) -> AsyncThrowingStream<StreamMessage, Error> {
    AsyncThrowingStream { continuation in
        Task {
            await self.runWithSDK(
                prompt: prompt,
                workingDirectory: workingDirectory,
                options: options,
                continuation: continuation
            )
        }
    }
}
```

**Critical Design Choice:**

1. **Immediate Return**: Stream creation must not wait for actor availability
   - Caller gets stream immediately, can start consuming
   - No blocking on actor's executor queue

2. **Asynchronous Execution**: Work happens inside `Task { await ... }`
   - `Task` schedules work on actor's executor
   - Stream yields happen asynchronously as SDK produces chunks

3. **Backpressure Handling**: AsyncThrowingStream naturally handles slow consumers
   - If caller iterates slowly, `continuation.yield()` suspends
   - Prevents memory buildup from fast SDK producing to slow consumer

**What if it was actor-isolated?**

```swift
// ❌ BAD: Would require await to get stream
func execute(...) async -> AsyncThrowingStream<...> {
    // Caller must: let stream = await executor.execute(...)
    // Adds unnecessary latency before streaming can begin
}
```

##### Why `convertChunk()` is Nonisolated

```swift
nonisolated private func convertChunk(_ chunk: ResponseChunk) -> StreamMessage {
    // Pure transformation, no actor state access
}
```

**Rationale:**

1. **Pure Function**: No access to `client`, `activeSessions`, or any mutable state
   - Input: `ResponseChunk` (from SDK, Sendable)
   - Output: `StreamMessage` (to ILSShared, Sendable)
   - No side effects

2. **Called from Non-Isolated Context**:
   ```swift
   publisher.sink(
       receiveValue: { chunk in
           // This closure runs on Combine's scheduler (not actor-isolated)
           let message = self.convertChunk(chunk)  // No await needed
           continuation.yield(message)
       }
   )
   ```

3. **Performance**: Avoids unnecessary actor hop
   - If actor-isolated, would require `await` inside `receiveValue`
   - Adds latency to every chunk conversion
   - No benefit since no state is accessed

**Pattern:**

> Mark methods `nonisolated` if they:
> 1. Don't access actor-isolated properties
> 2. Are called from non-isolated contexts (closures, publishers)
> 3. Are pure transformations

#### Combining Actors with Combine

**Challenge**: Combine publishers run on arbitrary schedulers, not actor-isolated.

**Solution**: Use `Task { await ... }` to hop back to actor context:

```swift
let cancellable = publisher.sink(
    receiveCompletion: { completion in
        // ⚠️ This closure is NOT actor-isolated
        // ⚠️ Cannot directly access self.activeSessions

        switch completion {
        case .finished:
            continuation.finish()
        case .failure(let error):
            continuation.yield(.error(...))
            continuation.finish()
        }

        // ✅ Use Task to re-enter actor context
        Task {
            await self.removeSession(sessionId)  // Now actor-isolated
        }
    },
    receiveValue: { chunk in
        // ⚠️ This closure is also NOT actor-isolated

        // ✅ Call nonisolated method directly
        let message = self.convertChunk(chunk)

        // ✅ continuation.yield is thread-safe (Sendable)
        continuation.yield(message)
    }
)
```

**Key Points:**

1. **Combine closures are non-isolated**: `sink(receiveCompletion:receiveValue:)` runs on publisher's scheduler
2. **Use `Task` for actor calls**: Wrapping in `Task { await ... }` schedules work on actor
3. **Nonisolated methods are safe**: Can call `self.convertChunk()` without `await`
4. **Continuation is thread-safe**: `yield()` and `finish()` are `Sendable`, safe to call anywhere

#### Best Practices Applied

**1. Minimize Actor Surface Area**

Only actor-isolate what needs protection:

```swift
// ✅ Good: Only mutable state is actor-isolated
actor ClaudeExecutorService {
    private var client: ClaudeCodeClient?           // Needs protection
    private var activeSessions: [String: ...] = [:] // Needs protection

    nonisolated func execute(...) { ... }           // No state access
    nonisolated private func convertChunk(...) { ... } // Pure function
}

// ❌ Bad: Over-isolation hurts performance
actor ClaudeExecutorService {
    func execute(...) async { ... }  // Unnecessary actor hop
    func convertChunk(...) async { ... } // Unnecessary await
}
```

**2. Avoid Actor Reentrancy Issues**

Actor reentrancy occurs when an actor-isolated method awaits, allowing other tasks to interleave:

```swift
private func runWithSDK(...) async {
    // Point A: Actor-isolated

    let result = try await client.runSinglePrompt(...)  // Suspension point

    // Point B: Actor-isolated again
    // ⚠️ Another task could have run between A and B
    // ⚠️ activeSessions might have changed
}
```

**Mitigation:**

- **Atomic operations**: `storeSession()` and `removeSession()` are single statements
- **Immutable captures**: Session ID captured in closure, not re-read from state
- **Careful ordering**: Store cancellable AFTER creating sink (no suspension point between)

**3. Structured Concurrency**

Use `Task` for unstructured work from non-isolated contexts:

```swift
receiveCompletion: { completion in
    // Create unstructured Task to enter actor context
    Task {
        await self.removeSession(sessionId)
    }
    // Task continues in background, doesn't block completion handler
}
```

**Why unstructured?**
- Completion handler can't be `async`, so can't directly `await`
- `Task` creates detached async context
- Cleanup (removeSession) happens asynchronously after stream finishes

**4. Error Isolation**

Errors are yielded to stream, never thrown from nonisolated methods:

```swift
nonisolated func execute(...) -> AsyncThrowingStream<StreamMessage, Error> {
    // Never throws, always returns stream
    AsyncThrowingStream { continuation in
        Task {
            // Errors caught inside runWithSDK, yielded to continuation
            await self.runWithSDK(..., continuation: continuation)
        }
    }
}

private func runWithSDK(...) async {
    do {
        // ...
    } catch {
        // ✅ Yield error to stream
        continuation.yield(.error(...))
        continuation.finish()
        // ❌ Never re-throw, caller can't catch (nonisolated execute doesn't throw)
    }
}
```

**5. Session Cleanup Guarantees**

Every session is guaranteed cleanup through Combine's completion:

```swift
let cancellable = publisher.sink(
    receiveCompletion: { completion in
        // ✅ ALWAYS called, even on cancellation or error
        continuation.finish()

        Task {
            await self.removeSession(sessionId)  // Guaranteed cleanup
        }
    },
    receiveValue: { ... }
)
```

**Cleanup Paths:**
- **Success**: Publisher finishes → `removeSession()` called
- **Error**: Publisher fails → `removeSession()` called
- **Cancellation**: User cancels → `cancel()` removes session → publisher completion fires → `removeSession()` called (idempotent)

### Session Management and Cancellation

`ClaudeExecutorService` maintains active session state to support long-running conversations and graceful cancellation. The actor tracks each active streaming session using Combine's cancellation mechanism, ensuring resources are properly cleaned up whether sessions complete successfully, fail, or are explicitly cancelled.

#### activeSessions Dictionary Structure

The service uses a simple dictionary to map session IDs to their Combine cancellables:

```swift
actor ClaudeExecutorService {
    private var activeSessions: [String: AnyCancellable] = [:]

    // Helper methods for session management
    private func storeSession(_ sessionId: String, cancellable: AnyCancellable) async {
        activeSessions[sessionId] = cancellable
    }

    private func removeSession(_ sessionId: String) async {
        activeSessions.removeValue(forKey: sessionId)
    }
}
```

**Design Rationale:**

| Aspect | Choice | Reasoning |
|--------|--------|-----------|
| **Key Type** | `String` (Session ID) | Matches SDK's session identifier format, client-controlled |
| **Value Type** | `AnyCancellable` | Combine's type-erased cancellable, stores publisher subscription |
| **Access Level** | `private` | Implementation detail, only accessed within actor |
| **Actor Isolation** | Yes (implicit) | Dictionary mutations protected by actor synchronization |

**Why not `Set<AnyCancellable>`?**

The service also declares `private var cancellables = Set<AnyCancellable>()`, which is currently unused. The `activeSessions` dictionary was chosen instead because:

1. **Selective Cancellation**: Need to cancel specific sessions by ID, not all at once
2. **Session Lookup**: Can check if a session is active: `activeSessions[sessionId] != nil`
3. **Explicit Lifecycle**: Dictionary clearly maps session ID → subscription
4. **Cleanup Verification**: Can verify session was removed after cancellation

The `Set<AnyCancellable>` pattern is common for "fire-and-forget" publishers where you don't need per-subscription control.

#### Combine Cancellables Usage

When the SDK returns a streaming result, the service creates a Combine subscription that produces `ResponseChunk` events:

```swift
case .stream(let publisher):
    let sessionId = options.sessionId ?? UUID().uuidString

    let cancellable = publisher.sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                continuation.finish()
            case .failure(let error):
                continuation.yield(.error(StreamError(code: "STREAM_ERROR", message: error.localizedDescription)))
                continuation.finish()
            }
            Task {
                await self.removeSession(sessionId)  // Cleanup on completion
            }
        },
        receiveValue: { chunk in
            let message = self.convertChunk(chunk)
            continuation.yield(message)
        }
    )

    await storeSession(sessionId, cancellable: cancellable)
```

**What is `AnyCancellable`?**

`AnyCancellable` is Combine's mechanism for managing publisher subscriptions:

- **Subscription Handle**: Represents the active connection between publisher and subscriber
- **Automatic Cleanup**: When deallocated, automatically calls `cancel()` on the subscription
- **Manual Cancellation**: Can explicitly call `cancellable.cancel()` to stop receiving events
- **Reference Type**: Class-based, can be stored and passed around

**Publisher Lifecycle:**

1. **Subscription Created**: `publisher.sink(...)` creates the subscription
2. **Events Flow**: `receiveValue` closure called for each chunk from SDK
3. **Completion**: `receiveCompletion` called when publisher finishes or fails
4. **Cancellation**: Either automatic (dealloc) or manual (`cancel()` method)

**Memory Management:**

```swift
// ✅ Stored in actor-isolated dictionary
await storeSession(sessionId, cancellable: cancellable)

// ✅ Strongly referenced by dictionary, won't be deallocated
// Publisher keeps sending chunks

// ✅ Removed after completion (automatic cleanup)
Task {
    await self.removeSession(sessionId)  // Removes strong reference
}
// ⚠️ If cancellable isn't removed, dictionary retains it forever
```

**Critical Ordering:**

The cancellable is stored **after** creating the `sink()`, not before:

```swift
// ✅ Correct: Create sink first, then store
let cancellable = publisher.sink(...)  // No suspension points
await storeSession(sessionId, cancellable: cancellable)

// ❌ Wrong: Race condition if stored before sink
await storeSession(sessionId, cancellable: nil)  // Can't store yet
let cancellable = publisher.sink(...)  // Might receive cancel() before storage
```

This prevents a race where `cancel()` is called between storage and sink creation.

#### cancel() Method Flow

The `cancel()` method provides explicit cancellation of active sessions:

```swift
func cancel(sessionId: String) async {
    if let cancellable = activeSessions[sessionId] {
        cancellable.cancel()
        activeSessions.removeValue(forKey: sessionId)
    }
    client?.cancel()
}
```

**Execution Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                      cancel(sessionId:)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Lookup Session       │
                  │ activeSessions[id]   │
                  └──────────┬───────────┘
                             │
                   ┌─────────┴─────────┐
                   │                   │
                   ▼                   ▼
          ┌────────────────┐    ┌──────────────┐
          │ Session Found  │    │ Not Found    │
          └───────┬────────┘    │ Return Early │
                  │             └──────────────┘
                  ▼
       ┌────────────────────────┐
       │ Call cancellable.cancel()│
       │ (stops publisher)        │
       └──────────┬───────────────┘
                  │
                  ▼
       ┌────────────────────────┐
       │ Remove from Dictionary │
       │ activeSessions[id] = nil│
       └──────────┬───────────────┘
                  │
                  ▼
       ┌────────────────────────┐
       │ Cancel SDK Client      │
       │ client?.cancel()       │
       └────────────────────────┘
```

**Step-by-Step Breakdown:**

1. **Session Lookup** (`if let cancellable = activeSessions[sessionId]`):
   - Checks if session exists in active sessions
   - Thread-safe due to actor isolation
   - Returns early if session not found (already completed or invalid ID)

2. **Cancel Subscription** (`cancellable.cancel()`):
   - Stops the Combine publisher from emitting further events
   - `receiveValue` closure will not be called again
   - `receiveCompletion` **will** be called with `.finished` (Combine guarantee)
   - SDK's underlying process may continue briefly, but chunks are ignored

3. **Remove from Dictionary** (`activeSessions.removeValue(forKey: sessionId)`):
   - Removes strong reference to cancellable
   - Prevents future cancellation attempts on same session
   - If `receiveCompletion` later calls `removeSession()`, it's idempotent (no-op)

4. **SDK-Level Cancellation** (`client?.cancel()`):
   - Calls ClaudeCodeSDK's `cancel()` method
   - Terminates the underlying `claude` CLI process
   - Closes PTY and releases system resources
   - **Note**: This cancels **all** SDK operations, not just this session

**Concurrency Considerations:**

```swift
// ✅ Thread-safe: Actor serializes access
Task {
    await executor.cancel(sessionId: "session-1")
}
Task {
    await executor.cancel(sessionId: "session-2")
}
// Both cancellations execute safely, no dictionary corruption
```

**Idempotency:**

```swift
await executor.cancel(sessionId: "session-1")  // Cancels and removes
await executor.cancel(sessionId: "session-1")  // No-op, already removed
```

The method is safe to call multiple times on the same session ID.

**Why call `client?.cancel()` every time?**

This is a current implementation quirk:

- ⚠️ **Global Effect**: Cancels all SDK operations, not scoped to session
- ⚠️ **Multi-Session Risk**: Cancelling session A might stop session B
- ✅ **Fail-Safe**: Ensures SDK resources are released
- 🔄 **Potential Improvement**: SDK could expose per-session cancellation

In practice, this works because:
1. Most deployments run one session at a time
2. ClaudeCodeSDK manages process lifecycle robustly
3. Completion handlers clean up activeSessions correctly

**Error Handling:**

The method has no error handling because:
- `cancellable.cancel()` never throws
- `activeSessions.removeValue()` is always safe
- `client?.cancel()` failure is logged internally by SDK
- Cancellation is best-effort; failures don't block caller

#### Session Lifecycle

A session progresses through these stages:

```
┌──────────────┐
│   Creation   │  execute() called with sessionId or generates UUID
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Waiting    │  Task scheduled, waiting for actor to run runWithSDK()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Storage    │  storeSession() adds to activeSessions dictionary
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│              Active Streaming                │
│  • receiveValue called for each chunk        │
│  • convertChunk() transforms SDK → ILS types │
│  • continuation.yield() sends to caller      │
└──────┬───────────────────────────────────────┘
       │
       ├─────────────┬─────────────┬────────────┐
       ▼             ▼             ▼            ▼
┌─────────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐
│  Completed  │ │  Error  │ │ Canceled │ │ Timeout  │
│  (success)  │ │ (failed)│ │ (manual) │ │ (budget) │
└──────┬──────┘ └────┬────┘ └────┬─────┘ └────┬─────┘
       │             │            │            │
       └─────────────┴────────────┴────────────┘
                     │
                     ▼
            ┌─────────────────┐
            │    Cleanup      │
            │ removeSession() │
            └─────────────────┘
```

**Phase Details:**

**1. Creation** (execute() method):
```swift
nonisolated func execute(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions
) -> AsyncThrowingStream<StreamMessage, Error> {
    // Session ID provided by caller or generated
    let sessionId = options.sessionId ?? UUID().uuidString

    AsyncThrowingStream { continuation in
        Task {
            await self.runWithSDK(...)  // Schedules actor-isolated work
        }
    }
}
```

- Session ID determined: Use `options.sessionId` or generate with `UUID()`
- Stream returned immediately to caller
- No actor access yet (nonisolated method)

**2. Waiting** (Task scheduling):
```swift
Task {
    await self.runWithSDK(...)  // Waits for actor to become available
}
```

- `Task` enqueued on actor's executor
- If actor is busy with other sessions, waits in queue
- Actor processes one task at a time (serialized execution)

**3. Storage** (storeSession):
```swift
case .stream(let publisher):
    let cancellable = publisher.sink(...)
    await storeSession(sessionId, cancellable: cancellable)
```

- Happens only for streaming results (not `.text` or `.json`)
- Cancellable stored in `activeSessions[sessionId]`
- Session now visible to `cancel()` method
- Publisher starts emitting chunks

**4. Active Streaming**:
```swift
receiveValue: { chunk in
    let message = self.convertChunk(chunk)  // Transform chunk
    continuation.yield(message)             // Send to caller
}
```

- SDK produces `ResponseChunk` events as CLI outputs JSON
- Each chunk converted to `StreamMessage` via `convertChunk()`
- Caller's `for try await` loop receives messages in real-time
- Can last seconds to hours depending on Claude's task

**5. Termination** (four paths):

| Path | Trigger | Flow |
|------|---------|------|
| **Completed** | SDK finishes successfully | `receiveCompletion(.finished)` → `continuation.finish()` → `removeSession()` |
| **Error** | SDK error or exception | `receiveCompletion(.failure(error))` → yield error → `continuation.finish()` → `removeSession()` |
| **Canceled** | Client calls `cancel()` | `cancel()` removes session → `cancellable.cancel()` → `receiveCompletion(.finished)` → `removeSession()` (idempotent) |
| **Timeout** | SDK budget/turn limit | SDK stops publisher → `receiveCompletion(.finished)` → `continuation.finish()` → `removeSession()` |

All paths eventually call `removeSession()` via the completion handler.

**6. Cleanup** (removeSession):
```swift
receiveCompletion: { completion in
    continuation.finish()  // Close stream

    Task {
        await self.removeSession(sessionId)  // Remove from activeSessions
    }
}
```

- Session removed from `activeSessions` dictionary
- Cancellable reference released (may dealloc if no other refs)
- Session ID can be reused for future requests
- No memory leaks; guaranteed cleanup

**Cleanup Guarantees:**

✅ **Always Cleaned Up:**
- Combine's `receiveCompletion` is **always** called exactly once
- Even if publisher is cancelled, completion fires with `.finished`
- `Task { await removeSession() }` always executes
- Actor ensures `removeSession()` eventually runs

✅ **Idempotent Cleanup:**
- `removeSession()` safe to call multiple times
- `cancel()` might call it, then completion handler calls it again
- Dictionary's `removeValue(forKey:)` is idempotent
- No double-free or corruption issues

⚠️ **Not Cleaned If:**
- Actor is deallocated before completion (app termination)
- Extremely rare: `Task` is cancelled before `removeSession()` runs
- In practice, never happens in normal operation

**Session Resumption:**

For multi-turn conversations, sessions can be resumed:

```swift
// First request
let options1 = ExecutionOptions(...)
options1.sessionId = "session-123"
let stream1 = executor.execute(prompt: "Hello", options: options1)

// Later request (resume)
let options2 = ExecutionOptions(...)
options2.resume = "session-123"  // Resume previous session
let stream2 = executor.execute(prompt: "Continue", options: options2)
```

**Resume vs. Active Sessions:**

- `options.resume`: Tells SDK to continue a previous conversation (SDK manages history)
- `activeSessions`: Tracks currently streaming requests (service manages lifecycle)
- These are **orthogonal**: Can resume a completed session (new entry in `activeSessions`)

**Why Separate `resume` and `sessionId`?**

```swift
if let resume = options.resume {
    result = try await client.resumeConversation(
        sessionId: resume,  // SDK's session ID (history lookup)
        prompt: prompt,
        ...
    )
} else {
    result = try await client.runSinglePrompt(...)
}

// Later...
let sessionId = options.sessionId ?? UUID().uuidString  // Our tracking ID
await storeSession(sessionId, cancellable: cancellable)
```

- `options.resume`: SDK's session ID for conversation history
- `options.sessionId`: Our tracking ID for cancellation
- Can be different: Resuming old conversation with new tracking ID
- Allows multiple concurrent requests to same historical session

### Data Flow

```
┌─────────────────┐
│  ChatController │  (Vapor Route Handler)
└────────┬────────┘
         │ execute(prompt, workingDirectory, options)
         ▼
┌─────────────────────────┐
│ ClaudeExecutorService   │  (Actor - Thread Safe)
│                         │
│  • runWithSDK()         │  Configures ClaudeCodeClient
│  • convertChunk()       │  Maps ResponseChunk → StreamMessage
│  • storeSession()       │  Tracks active sessions
└────────┬────────────────┘
         │ ClaudeCodeClient.runSinglePrompt()
         │ or resumeConversation()
         ▼
┌─────────────────────────┐
│    ClaudeCodeSDK        │  (External Library)
│                         │
│  • Spawns PTY           │  Executes `claude` CLI
│  • Parses stream-json   │  Line-by-line JSON parsing
│  • Publishes chunks     │  Combine Publisher<ResponseChunk>
└────────┬────────────────┘
         │ Publisher<ResponseChunk>
         ▼
┌─────────────────────────┐
│  AsyncThrowingStream    │
│  <StreamMessage, Error> │  Streamed back to controller
└─────────────────────────┘
```

## Streaming Flow and AsyncThrowingStream Usage

The streaming architecture is the core of how `ClaudeExecutorService` delivers real-time responses from the Claude Code CLI to the ILS backend. This section explains the complete flow from request initiation through message delivery, focusing on how `AsyncThrowingStream`, continuations, and Combine publishers work together.

### Complete execute() Function Flow

The `execute()` method orchestrates the entire streaming pipeline. Here's the complete flow from caller invocation to message delivery:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CALLER (ChatController)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ let stream = executor.execute(prompt, dir, options)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               execute() - NONISOLATED METHOD                    │
│  • Returns immediately (no await needed)                        │
│  • Creates AsyncThrowingStream                                  │
│  • Spawns Task for actor-isolated work                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
     ┌──────────────────────┐   ┌─────────────────────────┐
     │  Return to Caller    │   │  Task { await ... }     │
     │  (stream available)  │   │  (background execution) │
     └──────────────────────┘   └──────────┬──────────────┘
                                           │
                                           ▼
                              ┌─────────────────────────────┐
                              │  runWithSDK() - ACTOR-ISOLATED│
                              │  • Waits for actor availability│
                              │  • Configures ClaudeCodeClient│
                              │  • Executes SDK call           │
                              └──────────┬──────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────────────┐
                              │  ClaudeCodeSDK Execution    │
                              │  • Spawns claude CLI        │
                              │  • Returns publisher        │
                              └──────────┬──────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────────────┐
                              │  publisher.sink(...)        │
                              │  • receiveValue: yields     │
                              │  • receiveCompletion: finish│
                              └──────────┬──────────────────┘
                                         │
                                         │ ResponseChunk events
                                         ▼
                              ┌─────────────────────────────┐
                              │  convertChunk()             │
                              │  ResponseChunk → StreamMessage│
                              └──────────┬──────────────────┘
                                         │
                                         │ continuation.yield(message)
                                         ▼
                              ┌─────────────────────────────┐
                              │  AsyncThrowingStream        │
                              │  Delivers to caller's loop  │
                              └──────────┬──────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────────────┐
                              │  CALLER                     │
                              │  for try await msg in stream│
                              └─────────────────────────────┘
```

**Flow Breakdown:**

**Step 1: Caller Invokes execute()**

```swift
// In ChatController
let stream = executor.execute(
    prompt: "Implement user authentication",
    workingDirectory: "/path/to/project",
    options: options
)
// Stream returned immediately, no await needed!
```

**Step 2: execute() Creates AsyncThrowingStream**

```swift
nonisolated func execute(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions
) -> AsyncThrowingStream<StreamMessage, Error> {
    // ✅ Immediate return - caller doesn't wait
    AsyncThrowingStream { continuation in
        // Closure captures continuation and parameters
        Task {
            // Spawns background work on actor's executor
            await self.runWithSDK(
                prompt: prompt,
                workingDirectory: workingDirectory,
                options: options,
                continuation: continuation
            )
        }
    }
}
```

**Why nonisolated?**
- Allows synchronous return of stream
- Caller can start consuming immediately
- Actual work happens asynchronously in background `Task`
- No blocking on actor's executor queue

**Step 3: Background Task Executes runWithSDK()**

The `Task { await ... }` schedules work on the actor's executor. The actor serializes access, so if multiple requests arrive concurrently, they queue up and execute one at a time.

```swift
private func runWithSDK(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions,
    continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
) async {
    // Actor-isolated - safe access to self.client
    guard let client = client else {
        continuation.yield(.error(StreamError(code: "CLIENT_ERROR", message: "ClaudeCodeClient not initialized")))
        continuation.finish()
        return
    }

    // Configure and execute SDK...
}
```

**Step 4: SDK Returns Publisher**

ClaudeCodeSDK executes the `claude` CLI and returns a Combine publisher that emits `ResponseChunk` events as the CLI outputs JSON lines.

**Step 5: Publisher Sink Yields to Continuation**

The `sink()` method connects the publisher to the continuation, bridging Combine's push-based model with AsyncSequence's pull-based model.

**Step 6: Caller Consumes Stream**

```swift
for try await message in stream {
    // Receives messages in real-time
    print("Received: \(message)")
}
```

### AsyncThrowingStream Creation and Mechanics

`AsyncThrowingStream` is Swift's bridge between callback-based APIs (like Combine) and async/await. It provides backpressure handling and integrates seamlessly with `for try await` loops.

#### How AsyncThrowingStream Works

```swift
AsyncThrowingStream<StreamMessage, Error> { continuation in
    // This closure is called ONCE when the stream is created
    // It receives a 'continuation' object that can yield values

    Task {
        // Background work that will yield values
        await self.runWithSDK(..., continuation: continuation)
    }

    // Closure returns immediately
    // Stream is now "live" and ready to emit values
}
```

**Key Components:**

1. **Element Type**: `StreamMessage` - The type of values yielded to the stream
2. **Failure Type**: `Error` - The stream can throw errors
3. **Continuation**: Object that controls the stream lifecycle
   - `yield(_:)` - Emit a value to the stream
   - `finish()` - Close the stream (no more values)
   - `finish(throwing:)` - Close with an error

**Lifecycle:**

```
┌──────────────────────────┐
│  Stream Created          │  AsyncThrowingStream { continuation in ... }
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│  Continuation Captured   │  continuation is Sendable, can be used across threads
└───────────┬──────────────┘
            │
            ├─────────────────┐
            │                 │
            ▼                 ▼
┌───────────────────┐   ┌─────────────────┐
│  Caller Iterates  │   │  Producer Yields│
│  for try await    │◄──┤  continuation.  │
│  message in stream│   │  yield(message) │
└───────────┬───────┘   └─────────────────┘
            │
            ▼
┌──────────────────────────┐
│  Stream Finishes         │  continuation.finish()
└──────────────────────────┘
```

**Backpressure Handling:**

AsyncThrowingStream provides automatic backpressure:

```swift
// If caller is slow...
for try await message in stream {
    await slowOperation(message)  // Takes 1 second
}

// ...then continuation.yield() suspends!
receiveValue: { chunk in
    let message = self.convertChunk(chunk)
    continuation.yield(message)  // ⚠️ Suspends if caller hasn't consumed previous message
}
```

This prevents memory buildup when the producer (SDK) is faster than the consumer (caller).

**Buffer Size:**

By default, `AsyncThrowingStream` has a buffer of 1 element. You can specify a different buffer:

```swift
// Custom buffering strategy
AsyncThrowingStream(bufferingPolicy: .bufferingNewest(10)) { continuation in
    // Up to 10 messages buffered before yield() suspends
}
```

We use the default (unbuffered) to ensure real-time delivery and immediate backpressure.

### Continuation Usage Patterns

The continuation is the "producer" side of the stream. It's used in three ways:

#### 1. Yielding Values

```swift
receiveValue: { chunk in
    // Convert SDK chunk to our message type
    let message = self.convertChunk(chunk)

    // ✅ Yield to stream - caller receives this immediately
    continuation.yield(message)
}
```

**How yield() Works:**

- **Non-blocking (if consumer ready)**: If caller is waiting on `for try await`, message delivered immediately
- **Suspending (if consumer busy)**: If caller hasn't consumed previous message, `yield()` suspends until buffer has space
- **Thread-safe**: Can call from any thread (Combine's scheduler, actor's executor, etc.)
- **Returns Immediately**: Returns `Void`, doesn't indicate delivery success

**Yield Lifecycle:**

```
Producer Thread                  Consumer Thread
─────────────────               ─────────────────
continuation.yield(msg1)        for try await msg in stream {
    │                               │
    ├──────────────────────────────►│ msg1 received
    │                               │ await process(msg1)
continuation.yield(msg2)            │ (processing msg1...)
    │ (suspends, buffer full)       │
    │                               │ msg1 done
    └──────────────────────────────►│ msg2 received
                                    │ await process(msg2)
continuation.yield(msg3)            │
    │                               │
    └──────────────────────────────►│ msg3 received
```

#### 2. Finishing the Stream

```swift
receiveCompletion: { completion in
    switch completion {
    case .finished:
        // ✅ Normal completion - close the stream
        continuation.finish()

    case .failure(let error):
        // ✅ Error completion - yield error then close
        continuation.yield(.error(StreamError(
            code: "STREAM_ERROR",
            message: error.localizedDescription
        )))
        continuation.finish()
    }

    // Clean up resources
    Task { await self.removeSession(sessionId) }
}
```

**finish() Behavior:**

- **Closes the stream**: No more `yield()` calls will succeed
- **Wakes up consumer**: If consumer is waiting on `for try await`, loop exits
- **Idempotent**: Safe to call multiple times (subsequent calls are no-ops)
- **No error thrown**: Stream completes successfully
- **After finish()**: `yield()` calls are ignored (no crash, just no-op)

**finish(throwing:) Behavior:**

```swift
// Alternative: Close with error
continuation.finish(throwing: MyError.failed)

// Caller receives:
do {
    for try await message in stream {
        // ...
    }
} catch {
    // Catches the error passed to finish(throwing:)
}
```

We don't use `finish(throwing:)` in this service because we yield errors as messages:

```swift
// ✅ Our pattern: Errors are messages
continuation.yield(.error(StreamError(...)))
continuation.finish()  // Still finish normally

// ❌ Not used: Errors thrown from stream
continuation.finish(throwing: error)
```

This allows the caller to handle errors as part of the message stream rather than via exception handling.

#### 3. Error Handling

```swift
do {
    let result = try await client.runSinglePrompt(...)
    // Handle result...
} catch {
    // ✅ Convert exception to error message
    continuation.yield(.error(StreamError(
        code: "EXECUTION_ERROR",
        message: error.localizedDescription
    )))
    continuation.finish()
}
```

**Error Propagation Strategies:**

| Strategy | When to Use | Example |
|----------|-------------|---------|
| **Yield + Finish** | Error is part of stream semantics | SDK execution fails, yield error message then close |
| **Finish(throwing)** | Unexpected/fatal error | Stream creation fails (not used in this service) |
| **Ignore** | Recoverable error | Single chunk parse fails, skip and continue |

We use "Yield + Finish" because errors from the SDK are expected outcomes (e.g., invalid prompts, rate limits) that should be presented to the user as messages.

### Integration with ClaudeCodeSDK Publisher

The service bridges Combine's `Publisher` (push-based) with AsyncThrowingStream (pull-based with backpressure). This integration happens in the `runWithSDK()` method.

#### Publisher to Stream Bridge

```swift
case .stream(let publisher):
    // publisher: AnyPublisher<ResponseChunk, Error> from ClaudeCodeSDK
    let sessionId = options.sessionId ?? UUID().uuidString

    // ✅ Create Combine subscription (sink)
    let cancellable = publisher.sink(
        receiveCompletion: { completion in
            // Called once when publisher finishes or fails
            switch completion {
            case .finished:
                continuation.finish()
            case .failure(let error):
                continuation.yield(.error(StreamError(code: "STREAM_ERROR", message: error.localizedDescription)))
                continuation.finish()
            }

            // Clean up session
            Task {
                await self.removeSession(sessionId)
            }
        },
        receiveValue: { chunk in
            // Called for each ResponseChunk emitted by publisher
            // ⚠️ This closure runs on Combine's scheduler (not actor-isolated!)

            // Convert SDK type to our type (nonisolated method, no await)
            let message = self.convertChunk(chunk)

            // Yield to stream (thread-safe, may suspend on backpressure)
            continuation.yield(message)
        }
    )

    // Store cancellable for manual cancellation support
    await storeSession(sessionId, cancellable: cancellable)
```

#### Combine Publisher Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│               ClaudeCodeSDK.runSinglePrompt()               │
│  Returns: AnyPublisher<ResponseChunk, Error>               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  publisher.sink(     │  Creates subscription
              │    receiveCompletion:│
              │    receiveValue:     │
              │  )                   │
              └──────────┬───────────┘
                         │
                         │ Returns: AnyCancellable
                         ▼
              ┌──────────────────────────┐
              │  Subscription Active     │
              │  • Claude CLI running    │
              │  • Emitting JSON chunks  │
              └──────────┬───────────────┘
                         │
                         ├────────────────────────┐
                         │                        │
                         ▼                        ▼
            ┌────────────────────┐    ┌──────────────────────┐
            │  receiveValue      │    │  receiveCompletion   │
            │  (0..N times)      │    │  (exactly once)      │
            └────────┬───────────┘    └──────────┬───────────┘
                     │                           │
                     │ chunk events              │ finish/error
                     ▼                           ▼
          ┌────────────────────┐     ┌──────────────────────┐
          │ convertChunk()     │     │ continuation.finish()│
          │ continuation.yield │     │ removeSession()      │
          └────────────────────┘     └──────────────────────┘
```

**Event Flow:**

1. **Subscription Created**: `publisher.sink()` subscribes to the SDK's publisher
2. **CLI Starts**: SDK spawns `claude` process, begins outputting JSON
3. **Chunks Emitted**: For each line of JSON output, SDK parses and emits a `ResponseChunk`
4. **receiveValue Called**: Closure invoked with each chunk
5. **Conversion**: `convertChunk()` transforms SDK type to our type
6. **Yield to Stream**: `continuation.yield()` sends message to caller
7. **Completion**: When CLI exits, SDK finishes publisher
8. **receiveCompletion Called**: Closure invoked once with `.finished` or `.failure(error)`
9. **Stream Closed**: `continuation.finish()` closes the stream
10. **Cleanup**: `removeSession()` removes cancellable from dictionary

#### Publisher Scheduler Considerations

Combine publishers run on **arbitrary schedulers**:

```swift
receiveValue: { chunk in
    // ⚠️ WARNING: This closure is NOT actor-isolated!
    // ⚠️ Running on Combine's internal scheduler (could be any thread)

    // ❌ WRONG: Can't access actor-isolated properties
    self.activeSessions[sessionId] = ...  // Compile error!

    // ✅ CORRECT: Call nonisolated method
    let message = self.convertChunk(chunk)  // No await needed

    // ✅ CORRECT: Continuation is Sendable (thread-safe)
    continuation.yield(message)

    // ✅ CORRECT: Use Task to re-enter actor context
    Task {
        await self.someActorMethod()
    }
}
```

**Why convertChunk() is nonisolated:**

If `convertChunk()` were actor-isolated:

```swift
// ❌ BAD: Actor-isolated version
private func convertChunk(_ chunk: ResponseChunk) async -> StreamMessage { ... }

// Required usage:
receiveValue: { chunk in
    // ❌ Can't await in non-async closure!
    let message = await self.convertChunk(chunk)  // Compile error
}
```

By making it `nonisolated`, we can call it directly:

```swift
// ✅ GOOD: Nonisolated version
nonisolated private func convertChunk(_ chunk: ResponseChunk) -> StreamMessage { ... }

// Usage:
receiveValue: { chunk in
    let message = self.convertChunk(chunk)  // ✅ Works, no await
    continuation.yield(message)
}
```

#### Cancellation Integration

The `AnyCancellable` returned by `sink()` enables manual cancellation:

```swift
// Store cancellable
await storeSession(sessionId, cancellable: cancellable)

// Later, user cancels:
func cancel(sessionId: String) async {
    if let cancellable = activeSessions[sessionId] {
        // ✅ Stops the publisher
        cancellable.cancel()

        // ⚠️ Important: receiveCompletion will STILL be called!
        // Combine guarantees completion closure runs even on cancellation
        // So removeSession() happens automatically via completion handler

        // Remove from dictionary (cleanup now, don't wait for completion)
        activeSessions.removeValue(forKey: sessionId)
    }

    // Stop SDK process
    client?.cancel()
}
```

**Cancellation Flow:**

```
User calls cancel(sessionId)
    │
    ▼
cancellable.cancel()
    │
    ├──────────────────────────────────┐
    │                                  │
    ▼                                  ▼
Publisher stops emitting     receiveCompletion called
    │                        with .finished
    ▼                                  │
SDK process killed                     │
    │                                  ▼
    │                        continuation.finish()
    │                                  │
    │                                  ▼
    │                        removeSession() (idempotent)
    │                                  │
    └──────────────────────────────────┘
                    │
                    ▼
        Caller's for-await loop exits
```

**Why removeSession() is idempotent:**

```swift
// cancel() removes session immediately
activeSessions.removeValue(forKey: sessionId)

// Later, receiveCompletion calls it again
Task { await self.removeSession(sessionId) }

// Implementation is safe:
private func removeSession(_ sessionId: String) async {
    activeSessions.removeValue(forKey: sessionId)  // No-op if already removed
}
```

This double-removal is intentional:
1. `cancel()` removes immediately so future cancel calls are no-ops
2. `receiveCompletion` ensures cleanup even if `cancel()` isn't called
3. No crashes or errors from removing non-existent keys

### Complete Streaming Example

Here's a full example showing all components working together:

```swift
// === CALLER (ChatController) ===
let stream = executor.execute(
    prompt: "Implement user login",
    workingDirectory: "/path/to/project",
    options: ExecutionOptions(maxTurns: 5)
)

// Stream returned immediately, start consuming
for try await message in stream {
    switch message {
    case .system(let sys):
        print("System: \(sys.subtype)")
    case .assistant(let asst):
        print("Assistant: \(asst.content)")
    case .result(let res):
        print("Done in \(res.durationMs)ms")
    case .error(let err):
        print("Error: \(err.message)")
    }
}

// === EXECUTOR SERVICE ===

// 1. execute() - Returns stream immediately
nonisolated func execute(...) -> AsyncThrowingStream<StreamMessage, Error> {
    AsyncThrowingStream { continuation in
        Task {
            await self.runWithSDK(..., continuation: continuation)
        }
    }
}

// 2. runWithSDK() - Executes in background on actor
private func runWithSDK(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions,
    continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
) async {
    guard let client = client else {
        continuation.yield(.error(StreamError(code: "CLIENT_ERROR", message: "Client not initialized")))
        continuation.finish()
        return
    }

    do {
        // 3. Call SDK
        let result = try await client.runSinglePrompt(
            prompt: prompt,
            outputFormat: .streamJson,
            options: sdkOptions
        )

        // 4. Handle streaming result
        switch result {
        case .stream(let publisher):
            let sessionId = UUID().uuidString

            // 5. Create Combine sink
            let cancellable = publisher.sink(
                receiveCompletion: { completion in
                    // 8. Stream finished
                    switch completion {
                    case .finished:
                        continuation.finish()
                    case .failure(let error):
                        continuation.yield(.error(StreamError(code: "STREAM_ERROR", message: error.localizedDescription)))
                        continuation.finish()
                    }

                    // 9. Cleanup
                    Task { await self.removeSession(sessionId) }
                },
                receiveValue: { chunk in
                    // 6. Convert and yield each chunk
                    let message = self.convertChunk(chunk)
                    continuation.yield(message)
                    // 7. Caller receives message immediately
                }
            )

            await storeSession(sessionId, cancellable: cancellable)

        case .text(let text):
            // Non-streaming result
            continuation.yield(.assistant(AssistantMessage(content: [.text(TextBlock(text: text))])))
            continuation.finish()

        case .json(let resultMsg):
            // JSON result
            continuation.yield(.result(ResultMessage(...)))
            continuation.finish()
        }

    } catch {
        // Error from SDK
        continuation.yield(.error(StreamError(code: "EXECUTION_ERROR", message: error.localizedDescription)))
        continuation.finish()
    }
}

// 6. convertChunk() - Transform SDK types
nonisolated private func convertChunk(_ chunk: ResponseChunk) -> StreamMessage {
    switch chunk {
    case .initSystem(let msg):
        return .system(SystemMessage(...))
    case .assistant(let msg):
        return .assistant(AssistantMessage(...))
    case .result(let msg):
        return .result(ResultMessage(...))
    case .user:
        return .system(SystemMessage(subtype: "user_echo", data: nil))
    }
}
```

**Message Flow Timeline:**

```
Time  Executor                     SDK                      Caller
────  ─────────────────────────    ──────────────────────   ────────────────────
0ms   execute() called             -                        -
      └─> AsyncThrowingStream      -                        -
           created                 -                        -
1ms   return stream                -                        Receives stream
      Task spawned                 -                        for try await msg
2ms   runWithSDK() starts          -                        (waiting...)
10ms  client.runSinglePrompt()     -                        (waiting...)
50ms  -                            claude CLI starts        (waiting...)
100ms -                            First chunk emitted      -
      receiveValue called          -                        -
      convertChunk()               -                        -
      continuation.yield()         -                        -
101ms -                            -                        Receives .system
200ms -                            Second chunk             -
      continuation.yield()         -                        -
201ms -                            -                        Receives .assistant
...   (chunks continue)            (chunks continue)        (processing...)
5000ms -                           CLI exits                -
       receiveCompletion called    -                        -
       continuation.finish()       -                        -
5001ms -                           -                        Loop exits
       removeSession()             -                        -
```

### Stream Performance Characteristics

**Latency:**

- **First Message**: 50-500ms (depends on Claude CLI startup)
- **Subsequent Messages**: 10-50ms (network + JSON parsing)
- **Backpressure Delay**: 0ms if consumer is fast, unbounded if consumer is slow

**Memory:**

- **Buffer Size**: 1 message (default AsyncThrowingStream buffering)
- **Active Sessions**: O(n) where n = concurrent requests
- **Per-Session Overhead**: ~100 bytes (one `AnyCancellable` reference)

**Throughput:**

- **Max Messages/sec**: Limited by SDK (typically 10-100/sec depending on chunk size)
- **Backpressure**: Automatically throttles producer if consumer is slow
- **No Buffering Issues**: Stream suspends yield() when buffer is full

### Streaming Best Practices

**DO:**

✅ **Use nonisolated for stream creation**
```swift
nonisolated func execute(...) -> AsyncThrowingStream<...> {
    AsyncThrowingStream { continuation in
        Task { await self.actualWork(continuation) }
    }
}
```

✅ **Always call finish() in all code paths**
```swift
receiveCompletion: { completion in
    switch completion {
    case .finished:
        continuation.finish()  // ✅
    case .failure(let error):
        continuation.yield(.error(...))
        continuation.finish()  // ✅ Still finish
    }
}
```

✅ **Make conversion functions nonisolated**
```swift
nonisolated private func convertChunk(...) -> StreamMessage {
    // Pure transformation, no state access
}
```

✅ **Use Task to re-enter actor context from Combine**
```swift
receiveCompletion: { completion in
    Task { await self.actorIsolatedMethod() }
}
```

**DON'T:**

❌ **Don't make execute() actor-isolated**
```swift
// BAD: Requires await, delays stream creation
func execute(...) async -> AsyncThrowingStream<...> { ... }
```

❌ **Don't forget to finish the stream**
```swift
// BAD: Stream never closes, caller hangs
receiveCompletion: { completion in
    // Missing continuation.finish()
}
```

❌ **Don't call yield() after finish()**
```swift
// BAD: These yields are ignored
continuation.finish()
continuation.yield(message)  // No-op, silent failure
```

❌ **Don't access actor-isolated state from Combine closures**
```swift
receiveValue: { chunk in
    // BAD: Not in actor context
    self.activeSessions[id] = ...  // Compile error
}
```

### Summary

The streaming flow in `ClaudeExecutorService` demonstrates sophisticated integration of Swift's modern concurrency primitives:

1. **execute()** creates an `AsyncThrowingStream` immediately (nonisolated)
2. **AsyncThrowingStream** provides pull-based consumption with automatic backpressure
3. **Continuation** bridges push-based Combine publishers to pull-based streams
4. **ClaudeCodeSDK Publisher** emits `ResponseChunk` events from the Claude CLI
5. **sink()** connects publisher to continuation, yielding transformed messages
6. **Caller** consumes stream via `for try await`, receiving real-time messages

This architecture ensures:
- **Real-time delivery**: Messages stream as they're produced
- **Backpressure handling**: Slow consumers don't cause memory buildup
- **Thread safety**: Actor isolation + Sendable types prevent data races
- **Resource management**: Automatic cleanup via Combine completion handlers
- **Cancellation support**: Manual cancellation via stored `AnyCancellable`

## Message Type Conversion

The `convertChunk()` method maps ClaudeCodeSDK's `ResponseChunk` enum to ILSShared's `StreamMessage` enum.

### ResponseChunk Types (from ClaudeCodeSDK)

| Chunk Type | Description |
|------------|-------------|
| `.initSystem(msg)` | Initial system message with session info and tools |
| `.assistant(msg)` | Assistant's response with content blocks |
| `.result(msg)` | Final result with usage stats and duration |
| `.user(msg)` | User message echo (skipped) |

### StreamMessage Types (ILSShared)

| Message Type | Description |
|--------------|-------------|
| `.system(SystemMessage)` | System notifications (init, user_echo) |
| `.assistant(AssistantMessage)` | Assistant responses with content blocks |
| `.result(ResultMessage)` | Final result with metadata |
| `.error(StreamError)` | Error messages |

### Content Block Conversion

The most complex conversion happens for `.assistant` chunks, which contain an array of `Content` types from SwiftAnthropic:

```swift
case .assistant(let msg):
    var contentBlocks: [ContentBlock] = []

    for content in msg.message.content {
        switch content {
        case .text(let text, _):
            contentBlocks.append(.text(TextBlock(text: text)))

        case .toolUse(let toolUse):
            contentBlocks.append(.toolUse(ToolUseBlock(
                id: toolUse.id,
                name: toolUse.name,
                input: AnyCodable(toolUse.input)
            )))

        case .toolResult(let toolResult):
            let resultContent: String
            switch toolResult.content {
            case .string(let text):
                resultContent = text
            case .items(let items):
                resultContent = items.compactMap { $0.text }.joined(separator: "\n")
            }
            contentBlocks.append(.toolResult(ToolResultBlock(
                toolUseId: toolResult.toolUseId ?? "",
                content: resultContent,
                isError: toolResult.isError ?? false
            )))

        case .thinking(let thinking):
            // Map thinking to text with prefix
            contentBlocks.append(.text(TextBlock(text: "[thinking] \(thinking.thinking)")))

        case .serverToolUse(let serverTool):
            contentBlocks.append(.toolUse(ToolUseBlock(
                id: serverTool.id,
                name: serverTool.name,
                input: AnyCodable(serverTool.input)
            )))

        case .webSearchToolResult(let webResult):
            let text = webResult.content.compactMap { $0.text }.joined(separator: "\n")
            contentBlocks.append(.toolResult(ToolResultBlock(
                toolUseId: webResult.toolUseId ?? "",
                content: text,
                isError: false
            )))

        case .codeExecutionToolResult(let codeResult):
            let text: String
            switch codeResult.content {
            case .string(let s): text = s
            default: text = "[code execution result]"
            }
            contentBlocks.append(.toolResult(ToolResultBlock(
                toolUseId: codeResult.toolUseId ?? "",
                content: text,
                isError: false
            )))
        }
    }

    return .assistant(ILSShared.AssistantMessage(content: contentBlocks))
```

**Content Block Types Handled (6 total):**

1. **`.text`** - Plain text assistant responses
2. **`.toolUse`** - Tool invocations (Bash, Read, Edit, etc.)
3. **`.toolResult`** - Results from tool executions
4. **`.thinking`** - Extended thinking blocks (mapped to text with `[thinking]` prefix)
5. **`.serverToolUse`** - Server-side tool usage
6. **`.webSearchToolResult`** - Web search results (if web search enabled)

### Why This Conversion?

The conversion layer exists to:
1. **Decouple Dependencies**: ILS models don't depend on ClaudeCodeSDK types
2. **Simplify iOS Client**: iOS app only needs ILSShared, not ClaudeCodeSDK
3. **Type Safety**: Explicit mapping catches breaking changes in SDK updates
4. **Flexibility**: Can enrich or transform data during conversion

## Session Management

### Active Sessions Dictionary

```swift
private var activeSessions: [String: AnyCancellable] = [:]
```

**Purpose:**
- Maps session IDs to their Combine `AnyCancellable` subscriptions
- Enables cancellation of in-progress Claude executions
- Automatically cleaned up on stream completion

### Session Lifecycle

```
┌────────────────┐
│   New Request  │
└────────┬───────┘
         │
         ▼
┌────────────────────┐
│ Generate sessionId │ (from options or UUID)
└────────┬───────────┘
         │
         ▼
┌──────────────────────┐
│  Create Publisher    │
│  Sink (Cancellable)  │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────────┐
│ storeSession(sessionId,  │ activeSessions[sessionId] = cancellable
│              cancellable) │
└────────┬─────────────────┘
         │
         ├─────────────────────────┐
         │                         │
         ▼                         ▼
┌─────────────────┐       ┌────────────────────┐
│ Stream Chunks   │       │ cancel(sessionId)  │ (User cancels)
└────────┬────────┘       └────────┬───────────┘
         │                         │
         ▼                         │
┌─────────────────┐                │
│ Stream Finishes │◄───────────────┘
└────────┬────────┘
         │
         ▼
┌────────────────────────┐
│ removeSession(sessionId) │ activeSessions.removeValue(forKey: sessionId)
└────────────────────────┘
```

### Cancellation

```swift
func cancel(sessionId: String) async {
    if let cancellable = activeSessions[sessionId] {
        cancellable.cancel()  // Cancel Combine subscription
        activeSessions.removeValue(forKey: sessionId)
    }
    client?.cancel()  // Cancel ClaudeCodeClient PTY process
}
```

**Cancellation Flow:**
1. Controller calls `cancel(sessionId:)`
2. Retrieve cancellable from `activeSessions`
3. Call `cancellable.cancel()` to stop Combine stream
4. Remove from dictionary
5. Call `client?.cancel()` to kill underlying PTY process

## Initialization

```swift
init() {
    do {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true
        self.client = try ClaudeCodeClient(configuration: config)
    } catch {
        print("Failed to initialize ClaudeCodeClient: \(error)")
    }
}
```

**Configuration:**
- Uses `ClaudeCodeConfiguration.default` which auto-detects `claude` CLI path
- Enables debug logging for troubleshooting
- Gracefully handles initialization failure (client will be nil)

**Fallback:**
- If `client` is nil, `execute()` yields an error immediately:
  ```swift
  guard let client = client else {
      continuation.yield(.error(StreamError(code: "CLIENT_ERROR", message: "ClaudeCodeClient not initialized")))
      continuation.finish()
      return
  }
  ```

## Usage Example

### In ChatController

```swift
func send(_ req: Request) async throws -> Response {
    let sendReq = try req.content.decode(ChatSendRequest.self)

    // Get executor service from app
    let executor = req.application.services.claudeExecutor

    // Build execution options
    let options = ExecutionOptions(from: sendReq.options)
    options.sessionId = session.id?.uuidString

    // Execute and get stream
    let stream = executor.execute(
        prompt: sendReq.message,
        workingDirectory: project.directory,
        options: options
    )

    // Create SSE response
    let response = Response()
    response.headers.contentType = .init(type: "text", subType: "event-stream")
    response.headers.cacheControl = .init(noCache: true, noStore: true)
    response.headers.add(name: "X-Accel-Buffering", value: "no")

    response.body = .init(asyncStream: { writer in
        do {
            for try await message in stream {
                let json = try JSONEncoder().encode(message)
                let data = "data: \(String(data: json, encoding: .utf8)!)\n\n"
                try await writer.write(.buffer(ByteBuffer(string: data)))
            }
        } catch {
            // Handle errors
        }
        try await writer.write(.end)
    })

    return response
}
```

## Thread Safety Considerations

> **Note**: For comprehensive concurrency architecture details, see the [Concurrency Model & Best Practices](#concurrency-model--best-practices) section above. This section provides a quick reference for developers.

### Actor Isolation Quick Reference

**Actor-Isolated Methods (Requires `await`):**

| Method | Purpose | Why Isolated |
|--------|---------|--------------|
| `isAvailable()` | Check CLI availability | Accesses `client` property |
| `getVersion()` | Get CLI version | Spawns process (safe to serialize) |
| `runWithSDK()` | Execute SDK calls | Accesses `client`, calls `storeSession()` |
| `storeSession()` | Store cancellable | Mutates `activeSessions` dictionary |
| `removeSession()` | Remove cancellable | Mutates `activeSessions` dictionary |
| `cancel()` | Cancel active session | Reads/mutates `activeSessions`, calls `client.cancel()` |

**Nonisolated Methods (No `await` needed):**

| Method | Purpose | Why Nonisolated |
|--------|---------|-----------------|
| `execute()` | Start execution stream | No state access, returns immediately |
| `convertChunk()` | Transform chunk types | Pure function, called from non-isolated context |

### Concurrency Patterns Summary

**Pattern 1: Nonisolated Stream Creation**

```swift
nonisolated func execute(...) -> AsyncThrowingStream<...> {
    // ✅ Returns immediately, no actor wait
    AsyncThrowingStream { continuation in
        Task { await self.runWithSDK(...) }  // Actor work happens async
    }
}
```

**Pattern 2: Actor Re-Entry from Combine**

```swift
publisher.sink(
    receiveCompletion: { completion in
        Task { await self.removeSession(sessionId) }  // ✅ Hop to actor
    },
    receiveValue: { chunk in
        let message = self.convertChunk(chunk)  // ✅ Nonisolated, no await
        continuation.yield(message)
    }
)
```

**Pattern 3: Atomic Session Management**

```swift
// ✅ Atomic: No suspension between creation and storage
let cancellable = publisher.sink(...)
await storeSession(sessionId, cancellable: cancellable)
```

### Common Concurrency Pitfalls Avoided

**❌ Pitfall 1: Blocking execute() on actor**

```swift
// BAD: Would require await, delaying stream creation
func execute(...) async -> AsyncThrowingStream<...> { ... }

// GOOD: Returns immediately
nonisolated func execute(...) -> AsyncThrowingStream<...> { ... }
```

**❌ Pitfall 2: Accessing actor state from Combine closures**

```swift
publisher.sink(
    receiveCompletion: { completion in
        // BAD: Can't access activeSessions directly
        self.activeSessions.removeValue(forKey: sessionId)  // ❌ Compile error

        // GOOD: Use Task to enter actor context
        Task { await self.removeSession(sessionId) }  // ✅ Works
    }
)
```

**❌ Pitfall 3: Over-isolating pure functions**

```swift
// BAD: Adds unnecessary await to every chunk
private func convertChunk(...) async -> StreamMessage { ... }

// GOOD: No await needed, called from non-isolated context
nonisolated private func convertChunk(...) -> StreamMessage { ... }
```

### Thread Safety Guarantees

See [Thread Safety Guarantees](#thread-safety-guarantees) in the Concurrency Model section for comprehensive details on:
- What mutations are protected
- Sendable conformance requirements
- Data race prevention
- Actor reentrancy handling

## Error Handling

### Error Sources

| Error Type | Code | When |
|------------|------|------|
| `CLIENT_ERROR` | Client not initialized | `client == nil` |
| `STREAM_ERROR` | SDK stream failure | Combine publisher fails |
| `EXECUTION_ERROR` | SDK execution error | `runSinglePrompt()` throws |

### Error Propagation

```swift
do {
    let result = try await client.runSinglePrompt(...)
    // Handle result
} catch {
    continuation.yield(.error(StreamError(
        code: "EXECUTION_ERROR",
        message: error.localizedDescription
    )))
    continuation.finish()
}
```

**Flow:**
1. SDK throws error
2. Catch and convert to `StreamError`
3. Yield error to stream
4. Finish continuation (close stream)

## Performance Characteristics

### Memory

- **Active Sessions**: O(n) where n = concurrent chat sessions
- **Stream Buffering**: Minimal - chunks yielded immediately
- **Cancellable Storage**: Small overhead per session (one reference)

### Concurrency

- **Max Concurrent Sessions**: Limited by system resources (PTY processes)
- **Actor Contention**: Minimal - most work is async/await
- **Thread Pools**: Managed by Swift's cooperative task pool

### Latency

- **First Chunk**: ~200-500ms (Claude CLI startup)
- **Subsequent Chunks**: 10-50ms (network + parsing)
- **Cancellation**: Immediate (kills PTY process)

## Debugging

### Enable Debug Logging

Already enabled in initialization:

```swift
config.enableDebugLogging = true
```

### Common Issues

**1. "claude: command not found"**
- Ensure Claude CLI is installed and in PATH
- ClaudeCodeSDK checks `/usr/local/bin/claude` and `~/.local/bin/claude`

**2. Session not canceling**
- Verify session ID matches
- Check if `activeSessions` contains the session
- Ensure `client?.cancel()` is called

**3. Chunks not streaming**
- Confirm `outputFormat: .streamJson` is set
- Check that `continuation.yield()` is called in `receiveValue`
- Verify SSE response headers in ChatController

## Future Improvements

### Potential Enhancements

1. **Session Persistence**: Save activeSessions to database for crash recovery
2. **Metrics**: Track session duration, chunk counts, error rates
3. **Retry Logic**: Automatic retry for transient SDK errors
4. **Streaming Backpressure**: Handle slow consumers (rate limiting)
5. **Multiple Clients**: Support different Claude CLI versions per session

### Breaking Changes to Watch

**ClaudeCodeSDK Updates:**
- New `ResponseChunk` types → Update `convertChunk()` switch
- Changed `Content` enum cases → Update content block mapping
- New `ClaudeCodeOptions` fields → Update options builder

**SwiftAnthropic Updates:**
- Modified `Content` enum → Update conversion logic
- New tool result types → Add handling

## Related Documentation

- [ClaudeCodeSDK Documentation](https://github.com/krzemienski/ClaudeCodeSDK)
- [Swift Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [AsyncThrowingStream](https://developer.apple.com/documentation/swift/asyncthrowingstream)
- [Combine Framework](https://developer.apple.com/documentation/combine)

## Summary

`ClaudeExecutorService` is the critical bridge between ILS and Claude Code CLI:

- **Actor-based** for thread-safe session management
- **Streaming-first** using AsyncThrowingStream for real-time responses
- **Type conversion** from ClaudeCodeSDK to ILSShared models
- **Cancellation support** for user-initiated stops
- **Error resilient** with graceful fallbacks

Understanding this service is essential for debugging chat issues, adding new content block types, or optimizing streaming performance.
