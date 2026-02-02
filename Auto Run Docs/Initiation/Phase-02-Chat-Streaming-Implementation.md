# Phase 02: Chat Streaming Implementation

This phase wires up the core chat functionality—the heart of the Claude Code iOS experience. By the end, you'll be able to send a message from the iOS app, have it processed by the backend, and see streaming responses appear in real-time. This transforms the app from a static CRUD interface into an interactive AI assistant.

## Tasks

- [x] Complete the ChatController backend implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ChatController.swift`
  - Implement `sendMessage()` endpoint that accepts message text and sessionId
  - Wire up to ClaudeExecutorService to execute Claude CLI commands
  - Return Server-Sent Events (SSE) stream for response chunks
  - Handle errors gracefully and return appropriate HTTP status codes

  **Verified Complete (2026-02-02):** Implementation already exists and builds successfully:
  - `stream()` endpoint at POST `/chat/stream` accepts `ChatStreamRequest` (prompt, sessionId, projectId, options)
  - Wired to `ClaudeExecutorService.execute()` using ClaudeCodeSDK for CLI execution
  - Returns SSE via `StreamingService.createSSEResponse()` with proper `event:`/`data:` format
  - Error handling: `.serviceUnavailable` when Claude CLI unavailable, `.badRequest` for invalid params

- [x] Implement ClaudeExecutorService CLI execution:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/ClaudeExecutorService.swift`
  - Implement `execute()` method that spawns Claude CLI process
  - Capture stdout/stderr streams from the process
  - Parse Claude's streaming JSON output format
  - Yield StreamMessage objects as Claude responds
  - Handle process termination and cleanup

  **Verified Complete (2026-02-02):** Implementation uses ClaudeCodeSDK instead of raw Process spawning:
  - `execute()` returns `AsyncThrowingStream<StreamMessage, Error>` for async streaming
  - `runWithSDK()` integrates with ClaudeCodeSDK, handling both new and resumed sessions
  - `convertChunk()` maps all SDK `ResponseChunk` types (initSystem, assistant, result, user) to ILSShared `StreamMessage`
  - Content blocks fully mapped: text, toolUse, toolResult, thinking, serverToolUse, webSearchToolResult, codeExecutionToolResult
  - Session lifecycle managed via `storeSession()`/`removeSession()` with Combine cancellables
  - Build verification: `swift build` completes successfully

- [x] Complete StreamingService SSE implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/StreamingService.swift`
  - Implement SSE response format: `data: {json}\n\n`
  - Stream chunks as they arrive from ClaudeExecutorService
  - Send heartbeat events to keep connection alive
  - Handle client disconnection gracefully

  **Verified Complete (2026-02-02):** Enhanced implementation with full SSE support:
  - SSE format: `event: {type}\ndata: {json}\n\n` with proper Content-Type and headers
  - Added `X-Accel-Buffering: no` header to disable nginx proxy buffering
  - Heartbeat task sends ping comments (`: ping\n\n`) every 15 seconds to keep connection alive
  - Client disconnection detection via write failure tracking (`isConnected` flag)
  - Graceful cleanup: cancels heartbeat task on stream end, sends `event: done` on completion
  - Error handling: catches CancellationError separately, logs disconnects, sends error events
  - Build verification: `swift build` completes successfully

- [ ] Wire SSEClient to ChatView in iOS app:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/SSEClient.swift`
  - Implement `connect()` method that opens URLSession stream
  - Parse incoming SSE events and decode JSON to StreamMessage
  - Publish messages to ChatViewModel via Combine or async stream
  - Handle reconnection on network errors

- [ ] Update ChatViewModel to handle streaming messages:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
  - Implement `sendMessage()` that posts to backend and opens SSE stream
  - Accumulate streaming text chunks into assistant message
  - Update UI state as chunks arrive (isStreaming, currentMessage)
  - Handle stream completion and errors

- [ ] Update ChatView UI for streaming experience:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Chat/ChatView.swift`
  - Show typing indicator while waiting for first chunk
  - Display message text as it streams in (character by character feel)
  - Disable send button during active stream
  - Auto-scroll to bottom as new content appears
  - Handle stream errors with user-friendly alert

- [ ] Test end-to-end chat flow:
  - Start backend server
  - Run iOS app in simulator
  - Create or select a session
  - Send a test message like "Hello, what can you help me with?"
  - Verify streaming response appears progressively
  - Verify message history persists in session
