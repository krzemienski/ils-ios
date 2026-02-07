---
type: component-spec
source: Sources/ILSBackend/Controllers/SkillsController.swift
hash: 5336eb5a
category: controller
indexed: 2026-02-05T21:40:00Z
---

# SkillsController

## Purpose
Vapor route collection managing Claude Code skills - list, create, get, update, and delete with search filtering and cache bypass support.

## Exports
- struct SkillsController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func list(req: Request) async throws -> APIResponse<ListResponse<Skill>>
- func create(req: Request) async throws -> APIResponse<Skill>
- func get(req: Request) async throws -> APIResponse<Skill>
- func update(req: Request) async throws -> APIResponse<Skill>
- func delete(req: Request) async throws -> APIResponse<DeletedResponse>

## Dependencies
- import Vapor
- import ILSShared

## Keywords
controller skillscontroller skills search cache
