# Task: Validation Gate - Slash Commands

## Description
Validate that slash commands work correctly through the chat interface. Test command invocation, parameter passing, and response handling.

## Background
Claude Code supports slash commands (e.g., /help, /compact, /clear) that trigger specific behaviors. The chat interface must properly send these commands and display their results.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for slash command list)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Test /help command returns available commands
2. Test /status command shows session status
3. Test /clear command clears conversation
4. Test /compact command triggers compaction
5. Verify command parameters are passed correctly
6. Verify command responses render properly
7. Capture screenshots as evidence for each command

## Dependencies
- ChatView from Task 4.1
- Running backend with Claude CLI

## Implementation Approach
1. Launch app connected to backend
2. Start new session
3. Send /help command
4. Capture screenshot of response
5. Send /status command
6. Capture screenshot
7. Test other commands
8. Document each result
9. Verify all responses render correctly

## Acceptance Criteria

1. **Help Command**
   - Given an active chat session
   - When sending "/help"
   - Then list of available commands is displayed

2. **Status Command**
   - Given an active session
   - When sending "/status"
   - Then session information is displayed

3. **Clear Command**
   - Given messages in chat
   - When sending "/clear"
   - Then conversation is cleared

4. **Command Parameters**
   - Given a command with parameters
   - When sent
   - Then parameters are correctly passed to backend

5. **Evidence Collection**
   - Given all command tests
   - When completed
   - Then screenshots exist for each command test

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, Validation, Chat, Commands, Testing
- **Required Skills**: iOS testing, Screenshot capture, Command validation
