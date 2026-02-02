# Task: Create StreamingService

## Description
Create the service that bridges ClaudeExecutorService output to HTTP SSE (Server-Sent Events) responses. This enables real-time streaming of Claude responses to the iOS app.

## Background
SSE is a simple protocol for server-to-client streaming over HTTP. Each message is formatted as "data: {json}\n\n". The iOS app uses URLSession's bytes(for:) to consume this stream.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create StreamingService that wraps ClaudeExecutorService
2. Implement startStream() returning Vapor Response with SSE content type
3. Format each StreamMessage as SSE event (data: {json}\n\n)
4. Handle stream completion with result message
5. Handle errors gracefully with error events
6. Support connection keep-alive
7. Integrate with Vapor's async response body streaming

## Dependencies
- ClaudeExecutorService from Task 2A.3
- ILSShared StreamMessage models
- Vapor framework

## Implementation Approach
1. Create Sources/ILSBackend/Services/StreamingService.swift
2. Create SSE helper that formats messages correctly
3. Implement stream method that takes Request and returns Response
4. Set Content-Type to text/event-stream
5. Set Cache-Control to no-cache
6. Use Response.Body.init(asyncStream:) for streaming
7. Consume ClaudeExecutorService output and format as SSE
8. Send final event on completion or error
9. Verify compilation

## Acceptance Criteria

1. **SSE Content Type**
   - Given a streaming response
   - When inspecting headers
   - Then Content-Type is "text/event-stream"

2. **Message Formatting**
   - Given a StreamMessage
   - When formatted for SSE
   - Then output is "data: {json}\n\n" format

3. **Stream Completion**
   - Given a completed claude execution
   - When stream ends
   - Then final result event is sent before closing

4. **Error Handling**
   - Given an error during execution
   - When error occurs
   - Then error event is sent and stream closes gracefully

5. **Compilation Success**
   - Given the StreamingService
   - When running `swift build --target ILSBackend`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Backend, Vapor, Services, SSE, Streaming
- **Required Skills**: Vapor, SSE protocol, Async streaming, HTTP
