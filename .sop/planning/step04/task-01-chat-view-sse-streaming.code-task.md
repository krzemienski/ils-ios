# Task: Create ChatView with SSE Streaming

## Description
Create the main chat interface with real-time SSE streaming support. Display conversation messages, handle user input, and render Claude's responses including text, tool use, and thinking blocks.

## Background
The chat view is the core feature of ILS. It connects to the backend's SSE endpoint to stream Claude's responses in real-time. Messages include various content block types that need specialized rendering.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for message format details)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ChatView with message list and input field
2. Display messages in conversation format (user/assistant)
3. Render ContentBlock types: text, toolUse, toolResult, thinking
4. Support real-time streaming (text appears as it arrives)
5. Show typing indicator during streaming
6. Add send button with orange accent
7. Support multi-line text input
8. Auto-scroll to bottom on new messages
9. Show cost and duration after response completes
10. Handle session context (resume existing or start new)

## Dependencies
- APIClient with streamChat()
- ILSShared StreamMessage models
- ILSTheme styling

## Implementation Approach
1. Create ILSApp/ILSApp/Views/Chat/ChatView.swift
2. Create ChatViewModel with @Published messages array
3. Create MessageBubbleView for user/assistant messages
4. Create ContentBlockView with switch for block types
5. Create TextBlockView with markdown rendering
6. Create ToolUseBlockView showing tool name and input
7. Create ToolResultBlockView showing result or error
8. Create ThinkingBlockView with collapsed/expanded state
9. Implement SSE consumption with text aggregation
10. Add input field with send action
11. Verify compilation and streaming functionality

## Acceptance Criteria

1. **Message Display**
   - Given conversation history
   - When ChatView renders
   - Then user and assistant messages are displayed in bubbles

2. **Real-time Streaming**
   - Given an active SSE stream
   - When assistant responds
   - Then text appears incrementally as it streams

3. **Content Block Rendering**
   - Given a message with tool_use block
   - When rendered
   - Then tool name and formatted input are shown

4. **Thinking Block Collapse**
   - Given a thinking block
   - When rendered
   - Then it shows collapsed by default with expand option

5. **Send Message**
   - Given text in input field
   - When tapping send
   - Then message is sent and input clears

6. **Auto-scroll**
   - Given new message arrives
   - When list updates
   - Then view scrolls to show latest message

7. **Session Stats**
   - Given completed response
   - When result message received
   - Then cost and duration are displayed

8. **Compilation Success**
   - Given all chat views
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: High
- **Labels**: iOS, SwiftUI, Views, Chat, SSE, Streaming, Messages
- **Required Skills**: SwiftUI, AsyncSequence, SSE, Complex layouts, Real-time updates
