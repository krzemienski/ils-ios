# Task: Add Session Persistence to Backend

## Description
Implement session persistence in the backend to maintain conversation history across app restarts. Store messages in SQLite and sync with Claude Code's session storage.

## Background
For a production-quality experience, sessions must persist beyond memory. The backend stores session data in SQLite while optionally syncing with Claude Code's ~/.claude/projects/ storage.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create Message database model for storing messages
2. Add migration for messages table
3. Store each StreamMessage as conversation progresses
4. Load message history when resuming session
5. Implement message pagination for long conversations
6. Sync session metadata with Claude Code storage (optional scan)
7. Handle session discovery from ~/.claude/projects/

## Dependencies
- Fluent models from Phase 2A
- StreamMessage parsing

## Implementation Approach
1. Create Sources/ILSBackend/Models/MessageModel.swift
2. Define fields: id, sessionId, type, content (JSON), timestamp
3. Create CreateMessage migration
4. Modify StreamingService to save messages as they stream
5. Add getSessionMessages() endpoint
6. Implement pagination with offset/limit
7. Add optional Claude storage scanning service
8. Test persistence across server restarts
9. Verify with cURL and iOS app

## Acceptance Criteria

1. **Message Storage**
   - Given a streaming chat response
   - When messages are received
   - Then they are persisted to SQLite

2. **History Retrieval**
   - Given a session with previous messages
   - When calling getSessionMessages()
   - Then all messages are returned in order

3. **Pagination**
   - Given 100+ messages in session
   - When requesting with limit=20
   - Then only 20 messages are returned with pagination info

4. **Persistence Across Restarts**
   - Given stored messages
   - When server restarts
   - Then messages are still retrievable

5. **iOS App Integration**
   - Given the iOS app resuming a session
   - When loading
   - Then previous messages display correctly

6. **Compilation Success**
   - Given all persistence code
   - When building backend
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Backend, Vapor, Persistence, Sessions, Messages
- **Required Skills**: Fluent ORM, Database design, JSON storage, Pagination
