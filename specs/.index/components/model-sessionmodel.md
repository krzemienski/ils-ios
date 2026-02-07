---
type: component-spec
source: Sources/ILSBackend/Models/SessionModel.swift
hash: 6b7a374b
category: model
indexed: 2026-02-05T21:40:00Z
---

# SessionModel

## Purpose
Fluent ORM model for session persistence with optional project relationship, permission modes, status tracking, and fork relationships.

## Exports
- class SessionModel: Model

## Methods
- init()
- init(id: UUID?, claudeSessionId: String?, name: String?, projectId: UUID?, model: String, permissionMode: PermissionMode, status: SessionStatus, messageCount: Int, totalCostUSD: Double?, source: SessionSource, forkedFrom: UUID?)
- func toShared(projectName: String?) -> ChatSession
- static func from(_ session: ChatSession) -> SessionModel

## Dependencies
- import Fluent
- import Vapor
- import ILSShared

## Keywords
model sessionmodel fluent database orm persistence project fork
