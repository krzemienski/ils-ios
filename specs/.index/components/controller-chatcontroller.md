---
type: component-spec
source: Sources/ILSBackend/Controllers/ChatController.swift
hash: 350e000a
category: controller
indexed: 2026-02-05T21:40:00Z
---

# ChatController

## Purpose
Vapor route collection handling chat streaming via SSE and WebSocket, permission decisions, and session cancellation.

## Exports
- struct ChatController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func stream(req: Request) async throws -> Response
- func handleWebSocket(req: Request, ws: WebSocket) async
- func permission(req: Request) async throws -> APIResponse<AcknowledgedResponse>
- func cancel(req: Request) async throws -> APIResponse<CancelledResponse>

## Dependencies
- import Vapor
- import Fluent
- import ILSShared

## Keywords
controller chatcontroller chat streaming sse websocket
