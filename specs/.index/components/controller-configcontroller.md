---
type: component-spec
source: Sources/ILSBackend/Controllers/ConfigController.swift
hash: da18cb46
category: controller
indexed: 2026-02-05T21:40:00Z
---

# ConfigController

## Purpose
Vapor route collection for reading, updating, and validating Claude configuration files.

## Exports
- struct ConfigController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func get(req: Request) async throws -> APIResponse<ConfigInfo>
- func update(req: Request) async throws -> APIResponse<ConfigInfo>
- func validate(req: Request) async throws -> APIResponse<ConfigValidationResult>

## Dependencies
- import Vapor
- import ILSShared

## Keywords
controller configcontroller config validation settings
