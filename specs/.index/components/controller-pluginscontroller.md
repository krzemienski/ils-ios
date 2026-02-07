---
type: component-spec
source: Sources/ILSBackend/Controllers/PluginsController.swift
hash: 937396d1
category: controller
indexed: 2026-02-05T21:40:00Z
---

# PluginsController

## Purpose
Vapor route collection for managing Claude Code plugins - list installed, browse marketplace, install, enable/disable, and uninstall.

## Exports
- struct PluginsController: RouteCollection

## Methods
- func boot(routes: RoutesBuilder) throws
- func list(req: Request) async throws -> APIResponse<ListResponse<Plugin>>
- func marketplace(req: Request) async throws -> APIResponse<[PluginMarketplace]>
- func install(req: Request) async throws -> APIResponse<Plugin>
- func enable(req: Request) async throws -> APIResponse<EnabledResponse>
- func disable(req: Request) async throws -> APIResponse<EnabledResponse>
- func uninstall(req: Request) async throws -> APIResponse<DeletedResponse>

## Dependencies
- import Vapor
- import ILSShared

## Keywords
controller pluginscontroller plugins marketplace install
