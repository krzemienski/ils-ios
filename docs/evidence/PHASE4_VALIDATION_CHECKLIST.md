# Phase 4 Validation Checklist

**Phase:** Chat/Session Integration
**Lines in Plan:** 5968-7200
**Status:** PENDING
**Last Updated:** 2026-02-01

---

## Overview

Phase 4 contains **3 USER-SPECIFIED CRITICAL GATES** that are BLOCKING requirements for project completion:

1. **GATE_CHAT_1**: Slash command functionality
2. **GATE_SESSION_1**: Session management with system data
3. **GATE_MULTI_1**: Multi-turn conversation

**All three gates must PASS before Phase 4 can be marked complete.**

---

## Task 4.1: ChatView Implementation

### Validation Criteria
- [ ] File compiles without errors
- [ ] Chat view renders with input bar
- [ ] Session selection works
- [ ] Message bubbles display correctly

### Evidence Required: EVIDENCE_4.1
**Type:** iOS Simulator Screenshot
**Filename:** `evidence_4.1_chat_view.png`

**Must Verify:**
- [ ] Session header visible at top
- [ ] Message input bar at bottom
- [ ] User/assistant message bubbles styled differently
- [ ] Send button visible and orange colored
- [ ] Dark theme applied correctly

**Status:** NOT_TESTED

**Blocking:** Cannot proceed to Task 4.2 until PASS

---

## GATE_CHAT_1: Slash Command Validation

**USER-SPECIFIED CRITICAL GATE**

### Requirement
Typing and using slash commands displays expected results.

### Test Procedure
1. Launch app and navigate to Chat tab
2. Create or select a session
3. Type "/" in the input field
4. Verify slash command suggestions appear
5. Select "/help" command
6. Verify message is sent to backend
7. Verify response is received and displayed

### Evidence Required: EVIDENCE_4.2_GATE_CHAT_1

#### Screenshot 1: Slash Trigger
**Filename:** `evidence_4.2a_slash_trigger.png`

**Must Verify:**
- [ ] Chat input shows "/" typed
- [ ] Slash command suggestions visible above input
- [ ] Commands displayed: /help, /skills, /mcp, /config, /clear
- [ ] Suggestions styled correctly (dark theme, proper spacing)

#### Screenshot 2: Command Selected
**Filename:** `evidence_4.2b_command_selected.png`

**Must Verify:**
- [ ] Full "/help" command visible in input field
- [ ] Send button enabled (orange color)
- [ ] Input field accepts the command

#### Screenshot 3: Response Received
**Filename:** `evidence_4.2c_help_response.png`

**Must Verify:**
- [ ] User message bubble displays "/help"
- [ ] Assistant response bubble displays help text
- [ ] Correct styling (dark theme, orange accents)
- [ ] Message bubbles aligned correctly (user right, assistant left)
- [ ] Timestamps visible

### Backend Log Verification

**Command:**
```bash
curl -X POST http://localhost:8080/api/v1/sessions/{id}/chat \
  -H "Content-Type: application/json" \
  -d '{"content":"/help"}'
```

**Expected:** SSE stream with help content
**Actual:** [PASTE OUTPUT]

**Status:** NOT_TESTED

**Blocking:** This is a user-specified critical gate. Project CANNOT be marked complete without PASS.

---

## GATE_SESSION_1: New Session with System Data

**USER-SPECIFIED CRITICAL GATE**

### Requirement
Creating a new session with a new project shows all existing system data.

### Test Procedure
1. Ensure backend has data (skills, MCP servers, plugins installed)
2. Navigate to Chat tab
3. Tap "New Session" button
4. Enter project path: `~/test-project`
5. Create session
6. Verify session is created and selected
7. Send message asking about available skills
8. Verify response includes actual system data (not mocked)

### Evidence Required: EVIDENCE_4.3_GATE_SESSION_1

#### Screenshot 1: New Session Sheet
**Filename:** `evidence_4.3a_new_session.png`

**Must Verify:**
- [ ] New Session creation form displays
- [ ] Project path input field visible
- [ ] Create button present
- [ ] Create button enabled when path entered
- [ ] Cancel button present

#### Screenshot 2: Session Created
**Filename:** `evidence_4.3b_session_created.png`

**Must Verify:**
- [ ] Session header shows project name (derived from path)
- [ ] Empty chat (new session, no history)
- [ ] Input field enabled
- [ ] Send button visible

#### Screenshot 3: System Data Response
**Filename:** `evidence_4.3c_system_data.png`

**Must Verify:**
- [ ] Response to "What skills are available?" displays
- [ ] Response lists actual installed skills from backend
- [ ] Data matches what's shown in Skills tab
- [ ] Not showing mock/placeholder data

### API Verification

#### Test 1: Session Creation
**Command:**
```bash
curl http://localhost:8080/api/v1/sessions | jq
```

**Expected:** New session with project path visible
**Actual:** [PASTE OUTPUT]

**Verify:**
- [ ] New session in list
- [ ] Project path matches input
- [ ] Session ID is valid UUID

#### Test 2: Cross-Reference with Skills
**Command:**
```bash
curl http://localhost:8080/api/v1/skills | jq
```

**Match Requirement:** Skills in API response must match chat response
**Status:** MATCH / MISMATCH

**Actual:** [PASTE OUTPUT]

**Status:** NOT_TESTED

**Blocking:** This is a user-specified critical gate. Project CANNOT be marked complete without PASS.

---

## GATE_MULTI_1: Multi-Turn Conversation

**USER-SPECIFIED CRITICAL GATE**

### Requirement
Multiple back-and-forth exchanges within a session work correctly.

### Test Procedure
1. Use existing session from GATE_SESSION_1 test
2. Send message 1: "List the MCP servers"
3. Wait for response, verify correctness
4. Send message 2: "Tell me about the first one in detail"
5. Wait for response, verify it references previous context
6. Send message 3: "How do I add a new one?"
7. Wait for response, verify coherent multi-turn conversation

### Evidence Required: EVIDENCE_4.4_GATE_MULTI_1

#### Screenshot 1: Message 1 Exchange
**Filename:** `evidence_4.4a_turn1.png`

**Must Verify:**
- [ ] User message "List the MCP servers" visible
- [ ] Assistant response lists MCP servers
- [ ] Data matches MCP tab in app
- [ ] Message bubbles styled correctly

#### Screenshot 2: Message 2 Exchange
**Filename:** `evidence_4.4b_turn2.png`

**Must Verify:**
- [ ] Previous messages (turn 1) still visible
- [ ] User message "Tell me about the first one" visible
- [ ] Response references specific server from turn 1
- [ ] Context maintained (proves conversation memory)

#### Screenshot 3: Message 3 Exchange
**Filename:** `evidence_4.4c_turn3.png`

**Must Verify:**
- [ ] All 3 user messages visible
- [ ] All 3 assistant responses visible
- [ ] Response to "How do I add a new one?" provides relevant instructions
- [ ] Conversation remains coherent across turns

#### Screenshot 4: Full Conversation
**Filename:** `evidence_4.4d_full_conversation.png`

**Must Verify:**
- [ ] Scrolled view showing entire conversation
- [ ] 3 user messages present
- [ ] 3 assistant responses present
- [ ] All messages properly styled (user right/orange, assistant left/gray)
- [ ] Timestamps visible on all messages
- [ ] No visual glitches or layout issues

**Status:** NOT_TESTED

**Blocking:** This is a user-specified critical gate. Project CANNOT be marked complete without PASS.

---

## Task 4.5: Backend Session Persistence

### Validation Criteria
- [ ] File compiles without errors
- [ ] All endpoints respond correctly
- [ ] SSE streaming works
- [ ] Messages persisted to database

### Evidence Required: EVIDENCE_4.5

#### Test 1: Create Session
**Command:**
```bash
curl -X POST http://localhost:8080/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"projectPath":"~/test-project"}'
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "id": "...",
    "project": {...},
    "createdAt": "...",
    "updatedAt": "...",
    "messageCount": 0
  }
}
```

**Actual:** [PASTE OUTPUT]

**Verify:**
- [ ] success = true
- [ ] Valid UUID in id field
- [ ] project object contains name and path
- [ ] messageCount = 0 for new session

#### Test 2: List Sessions
**Command:**
```bash
curl http://localhost:8080/api/v1/sessions | jq
```

**Expected:** Array of sessions, sorted by updatedAt descending

**Actual:** [PASTE OUTPUT]

**Verify:**
- [ ] Returns array
- [ ] Contains created session
- [ ] Sorted by most recent first

#### Test 3: Get Session with Messages
**Command:**
```bash
curl http://localhost:8080/api/v1/sessions/{id} | jq
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "id": "...",
    "project": {...},
    "createdAt": "...",
    "updatedAt": "...",
    "messages": [...]
  }
}
```

**Actual:** [PASTE OUTPUT]

**Verify:**
- [ ] success = true
- [ ] messages array present
- [ ] Messages sorted by createdAt
- [ ] Each message has: id, role, content, timestamp

#### Test 4: Chat Streaming
**Command:**
```bash
curl -X POST http://localhost:8080/api/v1/sessions/{id}/chat \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"content":"Hello"}'
```

**Expected:** SSE events stream
```
event: text
data: {"content":"Hello"}

event: done
data: {}
```

**Actual:** [PASTE OUTPUT]

**Verify:**
- [ ] Content-Type: text/event-stream header
- [ ] Receives text events
- [ ] Receives done event
- [ ] Message persisted to database after stream completes

**Status:** NOT_TESTED

**Blocking:** Cannot proceed to Gate Check 4 until PASS

---

## GATE CHECK 4: Overall Phase Status

**OVERALL STATUS:** PENDING

| Gate ID | Requirement | Evidence Files | Status |
|---------|-------------|----------------|--------|
| 4.1 | ChatView renders | evidence_4.1_chat_view.png | NOT_TESTED |
| **GATE_CHAT_1** | Slash commands work | evidence_4.2a/b/c_*.png + curl log | NOT_TESTED |
| **GATE_SESSION_1** | New session shows system data | evidence_4.3a/b/c_*.png + API logs | NOT_TESTED |
| **GATE_MULTI_1** | Multi-turn conversation works | evidence_4.4a/b/c/d_*.png | NOT_TESTED |
| 4.5 | Backend session persistence | curl test outputs | NOT_TESTED |

### Complete Validation Checklist

#### Chat View Implementation
- [ ] ChatView compiles without errors
- [ ] Chat view renders correctly
- [ ] Session header displays project info
- [ ] Message bubbles styled correctly
- [ ] Input bar present and functional
- [ ] Send button enabled when appropriate

#### Slash Command Functionality (GATE_CHAT_1)
- [ ] Typing "/" triggers suggestions
- [ ] All commands displayed: /help, /skills, /mcp, /config, /clear
- [ ] Command selection works
- [ ] Commands sent to backend
- [ ] Backend responses received
- [ ] Responses displayed correctly

#### Session Management (GATE_SESSION_1)
- [ ] New session sheet displays
- [ ] Project path input works
- [ ] Session creation successful
- [ ] Session appears in session list
- [ ] New session shows in chat view
- [ ] System data query returns real data
- [ ] Data matches Skills/MCP tabs

#### Multi-turn Conversation (GATE_MULTI_1)
- [ ] First message sent and response received
- [ ] Second message maintains context from first
- [ ] Third message maintains context from both
- [ ] All messages visible in chat history
- [ ] Conversation coherent across turns
- [ ] No loss of context

#### Backend Endpoints
- [ ] POST /api/v1/sessions creates session
- [ ] GET /api/v1/sessions lists sessions
- [ ] GET /api/v1/sessions/:id returns session detail
- [ ] POST /api/v1/sessions/:id/chat streams SSE
- [ ] SSE events properly formatted
- [ ] Messages persisted to database

---

## Blocking Conditions

### Phase 4 CANNOT be marked complete if:

1. **Any Critical Gate FAILS:**
   - GATE_CHAT_1: Slash commands don't work
   - GATE_SESSION_1: New session doesn't show system data
   - GATE_MULTI_1: Multi-turn conversation breaks

2. **Evidence Missing:**
   - Required screenshots not captured
   - Backend API logs not verified
   - Cross-reference with other tabs not performed

3. **Functional Issues:**
   - ChatView doesn't compile
   - Session creation fails
   - SSE streaming broken
   - Database persistence fails
   - UI rendering issues

4. **Data Integrity Issues:**
   - System data is mocked/placeholder
   - Skills list doesn't match backend
   - MCP servers list doesn't match backend
   - Context not maintained across turns

---

## Success Criteria Summary

**Phase 4 is COMPLETE when:**

✅ All 13 screenshots captured and verified
✅ All 4 backend API tests pass
✅ All 3 user-specified critical gates PASS
✅ ChatView compiles and renders correctly
✅ Session management fully functional
✅ Multi-turn conversations work with context
✅ Real system data displayed (not mocked)

**Total Evidence Required:**
- 13 screenshots
- 4 curl test outputs
- 2 cross-reference verifications

---

## Notes

- **User Priority:** The user explicitly specified these gates in the original requirements
- **No Shortcuts:** Cannot mark complete without ALL evidence
- **Real Data Only:** Mock/placeholder data is NOT acceptable
- **Context Preservation:** Multi-turn must demonstrate actual conversation memory
- **Cross-Tab Consistency:** Data must match across Chat, Skills, and MCP tabs

---

## Status Legend

- **NOT_TESTED**: Validation not yet attempted
- **FAIL**: Validation attempted but failed criteria
- **PASS**: All criteria met with evidence captured
- **PENDING**: Overall status awaiting component completion
