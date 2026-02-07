---
type: component-spec
source: Sources/ILSBackend/Controllers/StatsController.swift
hash: 8569d1ac
category: controller
indexed: 2026-02-05T21:40:00Z
---

# StatsController

## Purpose
Vapor route collection providing dashboard statistics - aggregates counts for projects, sessions, skills, MCP servers, and plugins from filesystem and database sources.

## Exports
- struct StatsController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func stats(req: Request) async throws -> APIResponse<StatsResponse>
- func settings(req: Request) async throws -> APIResponse<ClaudeConfig>
- func recentSessions(req: Request) async throws -> APIResponse<RecentSessionsResponse>

## Dependencies
- import Vapor
- import Fluent
- import ILSShared

## Keywords
controller statscontroller stats dashboard statistics
