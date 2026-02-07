---
type: component-spec
source: Sources/ILSBackend/Services/StreamingService.swift
hash: e2a0ea08
category: service
indexed: 2026-02-05T21:40:00Z
---

# StreamingService

## Purpose
Service for handling SSE (Server-Sent Events) streaming responses with automatic heartbeats (15s interval), message persistence to database, and client disconnection handling.

## Exports
- struct StreamingService

## Methods
- static func createSSEResponse(from: AsyncThrowingStream<StreamMessage, Error>, on: Request) -> Response
- static func createSSEResponseWithPersistence(from: AsyncThrowingStream<StreamMessage, Error>, sessionId: UUID, userMessageId: UUID, on: Request) -> Response
- static func createPingEvent() -> String

## Dependencies
- import Vapor
- import Fluent
- import ILSShared

## Keywords
service streamingservice sse server-sent-events streaming heartbeat persistence
