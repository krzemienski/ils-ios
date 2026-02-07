---
type: component-spec
source: Sources/ILSBackend/Models/MessageModel.swift
hash: 04f024bb
category: model
indexed: 2026-02-05T21:40:00Z
---

# MessageModel

## Purpose
Fluent ORM model for message persistence with session relationship, role, content, tool calls/results, and timestamps.

## Exports
- class MessageModel: Model

## Methods
- init()
- init(id: UUID?, sessionId: UUID, role: MessageRole, content: String, toolCalls: String?, toolResults: String?)
- func toShared() -> Message
- static func from(_ message: Message) -> MessageModel

## Dependencies
- import Fluent
- import Vapor
- import ILSShared

## Keywords
model messagemodel fluent database orm persistence
