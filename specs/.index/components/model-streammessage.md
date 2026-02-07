---
type: component-spec
source: Sources/ILSShared/Models/StreamMessage.swift
hash: 689e870e
category: model
indexed: 2026-02-05T21:40:00Z
---

# StreamMessage

## Purpose
Comprehensive SSE streaming message types from Claude Code CLI with system/assistant/result/permission/error variants, content blocks (text/toolUse/toolResult/thinking), and AnyCodable helper for dynamic JSON.

## Exports
- enum StreamMessage
- struct SystemMessage
- struct SystemData
- struct AssistantMessage
- enum ContentBlock
- struct TextBlock
- struct ToolUseBlock
- struct ToolResultBlock
- struct ThinkingBlock
- struct ResultMessage
- struct UsageInfo
- struct PermissionRequest
- struct StreamError
- struct AnyCodable

## Methods
None (data structures with Codable conformance)

## Dependencies
- import Foundation

## Keywords
model streammessage sse streaming content blocks tools codable
