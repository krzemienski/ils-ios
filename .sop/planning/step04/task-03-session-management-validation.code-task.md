# Task: Validation Gate - Session Management

## Description
Validate session management functionality including creating new sessions, listing sessions, resuming sessions, and session-project association.

## Background
Sessions are the primary organizational unit in ILS. Users need to create, list, resume, and manage sessions associated with projects.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Test creating a new session (no project)
2. Test creating a session associated with a project
3. Test listing all sessions
4. Test resuming an existing session
5. Test session appears in recent activity
6. Test session metadata (model, permission mode) is preserved
7. Capture screenshots as evidence

## Dependencies
- ChatView and session creation flow
- Dashboard for session list
- Running backend

## Implementation Approach
1. Create new session from dashboard
2. Verify session appears in list
3. Send a message in session
4. Leave and return to session
5. Verify message history is preserved
6. Create project-associated session
7. Verify session shows project name
8. Test session filtering by project
9. Document all results with screenshots

## Acceptance Criteria

1. **Create Session**
   - Given the new session button
   - When creating session
   - Then session is created and chat opens

2. **Session Listing**
   - Given created sessions
   - When viewing sessions list
   - Then all sessions are displayed with metadata

3. **Session Resume**
   - Given an existing session with messages
   - When reopening
   - Then previous messages are displayed

4. **Project Association**
   - Given a project
   - When creating session for project
   - Then session shows project name and context

5. **Session Metadata**
   - Given session with specific model/permissions
   - When viewing session
   - Then correct model and permission mode are shown

6. **Evidence Collection**
   - Given all session tests
   - When completed
   - Then screenshots document each functionality

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, Validation, Sessions, Testing
- **Required Skills**: iOS testing, Session management, Screenshot capture
