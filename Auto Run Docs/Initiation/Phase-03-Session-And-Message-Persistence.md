# Phase 03: Session and Message Persistence

This phase ensures chat history survives app restarts and backend reboots. Users expect their conversations to persist—losing context mid-conversation breaks the experience. By the end, sessions store their full message history in SQLite, and the iOS app reloads conversations seamlessly.

## Tasks

- [x] Create Message database model and migration:
  - Create `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Models/MessageModel.swift`:
    - id (UUID), sessionId (UUID), role (String: user/assistant/system), content (String)
    - toolCalls (JSON optional), toolResults (JSON optional)
    - createdAt (Date), updatedAt (Date)
  - Create `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Migrations/CreateMessages.swift`
  - Register migration in configure.swift
  - Run migration to create messages table

- [x] Add Message model to ILSShared:
  - Create or update `/Users/nick/Desktop/ils-ios/Sources/ILSShared/Models/Message.swift`
  - Include all fields: id, sessionId, role, content, toolCalls, toolResults, timestamps
  - Ensure Codable and Sendable conformance
  - Add to ILSShared target in Package.swift if needed
  - **Completed**: Message.swift already exists with all required fields (id, sessionId, role, content, toolCalls, toolResults, createdAt, updatedAt), MessageRole enum (user/assistant/system), and Codable+Sendable+Identifiable conformance. Build verified successful.

- [x] Implement message persistence in ChatController:
  - After receiving user message, save to database with role "user"
  - As Claude responds, accumulate full response
  - On stream completion, save assistant message to database
  - Include tool calls and results if present
  - Return message IDs in SSE events for client correlation
  - **Completed**: ChatController.swift saves user messages (lines 46-52) with session creation/update. StreamingService.swift accumulates assistant content (lines 110-169), saves on completion (lines 182-208), includes tool calls/results (lines 148-156, 187-188), and returns message IDs via SSE headers (X-User-Message-ID, X-Session-ID) and messageId event (lines 205-207). Build verified.

- [ ] Add messages endpoint to SessionsController:
  - Add GET `/api/v1/sessions/:id/messages` endpoint
  - Return all messages for session ordered by createdAt
  - Support pagination with `limit` and `offset` query params
  - Include full message content and metadata

- [ ] Update iOS ChatViewModel to load message history:
  - On session selection, fetch existing messages from backend
  - Populate messages array before enabling chat input
  - Show loading indicator while fetching history
  - Handle empty sessions gracefully (welcome message)

- [ ] Update ChatView to display loaded history:
  - Render historical messages with correct styling (user vs assistant)
  - Maintain scroll position when loading older messages
  - Distinguish between loaded history and new messages
  - Show timestamps for historical messages

- [ ] Test message persistence end-to-end:
  - Send several messages in a session
  - Force quit iOS app and relaunch
  - Navigate back to same session
  - Verify all previous messages appear
  - Send new message and verify it appends correctly
