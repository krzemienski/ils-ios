# Task: Create StreamMessage Models for SSE/Chat

## Description
Create the comprehensive message models for parsing Claude Code's SSE (Server-Sent Events) streaming output. These models handle system messages, assistant messages with content blocks, user messages, and result messages.

## Background
Claude Code outputs stream-json format with different message types. The iOS app needs to parse these in real-time for the chat UI. Content blocks include text, tool_use, tool_result, and thinking blocks.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for stream-json format details)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create StreamMessage enum with cases: system, assistant, user, result
2. Implement custom Codable for type-based decoding
3. Create SystemMessage with subtype and data (sessionId, plugins, slashCommands)
4. Create AssistantMessage with content blocks array, costUSD, durationMs
5. Create ContentBlock enum with cases: text, toolUse, toolResult, thinking
6. Create individual block structs (TextBlock, ToolUseBlock, ToolResultBlock, ThinkingBlock)
7. Create UserMessage with content string
8. Create ResultMessage with session stats (durationMs, isError, numTurns, totalCostUSD, usage)
9. Create AnyCodable helper for dynamic JSON in tool inputs

## Dependencies
- Session.swift from Task 1.1
- Foundation framework

## Implementation Approach
1. Create Sources/ILSShared/Models/StreamMessage.swift
2. Define StreamMessage enum with custom decoder based on "type" field
3. Define each message type struct with appropriate fields
4. Define ContentBlock enum with custom decoder based on "type" field
5. Define block structs with Identifiable conformance (using id field or UUID)
6. Create AnyCodable for handling arbitrary JSON in tool inputs
7. Verify all types compile and are Sendable

## Acceptance Criteria

1. **StreamMessage Decoding**
   - Given a JSON string with type "assistant"
   - When decoding as StreamMessage
   - Then it correctly produces .assistant(AssistantMessage)

2. **ContentBlock Variety**
   - Given assistant message JSON with mixed content blocks
   - When decoding content array
   - Then text, toolUse, toolResult, and thinking blocks are correctly parsed

3. **AnyCodable Flexibility**
   - Given a ToolUseBlock with complex nested input JSON
   - When encoding and decoding
   - Then the input structure is preserved

4. **Compilation Success**
   - Given all StreamMessage models
   - When running `swift build --target ILSShared`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Models, Swift, Shared, Streaming, SSE, Chat
- **Required Skills**: Swift, Codable, Custom decoders, Enums with associated values
