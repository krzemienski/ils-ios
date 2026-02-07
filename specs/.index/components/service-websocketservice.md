---
type: component-spec
source: Sources/ILSBackend/Services/WebSocketService.swift
hash: 01b13c41
category: service
indexed: 2026-02-05T21:40:00Z
---

# WebSocketService

## Purpose
Actor service for managing WebSocket connections with message handling, permission decisions, and session cancellation support.

## Exports
- actor WebSocketService

## Methods
- init(executor: ClaudeExecutorService)
- func handleConnection(_ ws: WebSocket, sessionId: String, projectPath: String?, on: Request) async
- func connectionCount() -> Int

## Dependencies
- import Vapor
- import ILSShared

## Keywords
service websocketservice websocket connections realtime
