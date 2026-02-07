---
type: component-spec
source: Sources/ILSBackend/Controllers/SessionsController.swift
hash: ab0f9c21
category: controller
indexed: 2026-02-05T21:40:00Z
---

# SessionsController

## Purpose
Vapor route collection managing chat sessions - CRUD operations, scanning external sessions, forking, and reading message transcripts from JSONL files.

## Exports
- struct SessionsController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func list(req: Request) async throws -> APIResponse<ListResponse<ChatSession>>
- func create(req: Request) async throws -> APIResponse<ChatSession>
- func scan(req: Request) async throws -> APIResponse<SessionScanResponse>
- func get(req: Request) async throws -> APIResponse<ChatSession>
- func delete(req: Request) async throws -> APIResponse<DeletedResponse>
- func fork(req: Request) async throws -> APIResponse<ChatSession>
- func messages(req: Request) async throws -> APIResponse<ListResponse<Message>>
- func transcript(req: Request) async throws -> APIResponse<ListResponse<Message>>

## Dependencies
- import Vapor
- import Fluent
- import ILSShared

## Keywords
controller sessionscontroller sessions chat messages transcript
