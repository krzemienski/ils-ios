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

## Streaming Flow

### 1. Request Initiation

The `execute()` method is **nonisolated** to allow immediate stream creation:

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

**Key Design:**
- Returns immediately with an `AsyncThrowingStream`
- Spawns a `Task` to handle actor-isolated work
- Caller can start consuming stream before SDK finishes

### 2. SDK Execution

The `runWithSDK()` method is actor-isolated and handles:

```swift
private func runWithSDK(
    prompt: String,
    workingDirectory: String?,
    options: ExecutionOptions,
    continuation: AsyncThrowingStream<StreamMessage, Error>.Continuation
) async {
    // 1. Configure working directory
    if let dir = workingDirectory {
        var config = client.configuration
        config.workingDirectory = dir
        client.configuration = config
    }

    // 2. Build SDK options
    var sdkOptions = ClaudeCodeOptions()
    sdkOptions.maxTurns = options.maxTurns ?? 1
    sdkOptions.model = options.model
    sdkOptions.allowedTools = options.allowedTools
    sdkOptions.disallowedTools = options.disallowedTools

    // 3. Execute (new or resumed session)
    let result: ClaudeCodeResult
    if let resume = options.resume {
        result = try await client.resumeConversation(
            sessionId: resume,
            prompt: prompt,
            outputFormat: .streamJson,
            options: sdkOptions
        )
    } else {
        result = try await client.runSinglePrompt(
            prompt: prompt,
            outputFormat: .streamJson,
            options: sdkOptions
        )
    }

    // 4. Handle result type (stream, text, or json)
    // ...
}
```

### 3. Result Handling

ClaudeCodeSDK returns one of three result types:

| Result Type | Description | When Used |
|-------------|-------------|-----------|
| `.stream(Publisher)` | Combine publisher of `ResponseChunk` | `outputFormat: .streamJson` (default) |
| `.text(String)` | Raw text output | `outputFormat: .text` |
| `.json(ResultMessage)` | Final result object | `outputFormat: .json` |

**Stream Result Processing:**

```swift
case .stream(let publisher):
    let sessionId = options.sessionId ?? UUID().uuidString

    let cancellable = publisher.sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                continuation.finish()
            case .failure(let error):
                continuation.yield(.error(StreamError(...)))
                continuation.finish()
            }
            Task { await self.removeSession(sessionId) }
        },
        receiveValue: { chunk in
            let message = self.convertChunk(chunk)
            continuation.yield(message)
        }
    )

    await storeSession(sessionId, cancellable: cancellable)
```

**Key Flow:**
1. Create a Combine sink on the publisher
2. For each `ResponseChunk`, call `convertChunk()` to map to `StreamMessage`
3. Yield the converted message to the `AsyncThrowingStream` continuation
4. Store the cancellable for potential cancellation
5. Clean up session on completion

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
