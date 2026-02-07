---
type: component-spec
source: Sources/ILSBackend/Controllers/ProjectsController.swift
hash: a503299a
category: controller
indexed: 2026-02-05T21:40:00Z
---

# ProjectsController

## Purpose
Vapor route collection managing Claude Code projects from ~/.claude/projects/ - CRUD operations, session listing, and filesystem scanning.

## Exports
- struct ProjectsController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func index(req: Request) async throws -> APIResponse<ListResponse<Project>>
- func create(req: Request) async throws -> APIResponse<Project>
- func show(req: Request) async throws -> APIResponse<Project>
- func update(req: Request) async throws -> APIResponse<Project>
- func delete(req: Request) async throws -> APIResponse<DeletedResponse>
- func getSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>>

## Dependencies
- import Vapor
- import Fluent
- import ILSShared
- import Foundation

## Keywords
controller projectscontroller projects filesystem sessions
