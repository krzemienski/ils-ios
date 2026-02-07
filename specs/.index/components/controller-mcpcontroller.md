---
type: component-spec
source: Sources/ILSBackend/Controllers/MCPController.swift
hash: dbe3ddd5
category: controller
indexed: 2026-02-05T21:40:00Z
---

# MCPController

## Purpose
Vapor route collection managing MCP (Model Context Protocol) servers - list, show, create, and delete operations with scope support.

## Exports
- struct MCPController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func show(req: Request) async throws -> APIResponse<MCPServer>
- func list(req: Request) async throws -> APIResponse<ListResponse<MCPServer>>
- func create(req: Request) async throws -> APIResponse<MCPServer>
- func delete(req: Request) async throws -> APIResponse<DeletedResponse>

## Dependencies
- import Vapor
- import ILSShared

## Keywords
controller mcpcontroller mcp servers model context protocol
