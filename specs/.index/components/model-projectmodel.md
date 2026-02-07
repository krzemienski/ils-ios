---
type: component-spec
source: Sources/ILSBackend/Models/ProjectModel.swift
hash: a320d647
category: model
indexed: 2026-02-05T21:40:00Z
---

# ProjectModel

## Purpose
Fluent ORM model for project persistence with sessions relationship and automatic timestamp tracking.

## Exports
- class ProjectModel: Model

## Methods
- init()
- init(id: UUID?, name: String, path: String, defaultModel: String, description: String?)
- func toShared(sessionCount: Int?) -> Project
- static func from(_ project: Project) -> ProjectModel

## Dependencies
- import Fluent
- import Vapor
- import ILSShared

## Keywords
model projectmodel fluent database orm persistence sessions
