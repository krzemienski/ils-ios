---
type: component-spec
source: Sources/ILSBackend/Services/FileSystemService.swift
hash: c60a8c70
category: service
indexed: 2026-02-05T21:40:00Z
---

# FileSystemService

## Purpose
Service for Claude Code filesystem operations - skills scanning, MCP server configuration, settings management, and session transcript reading. Implements actor-based caching with 30s TTL for performance.

## Exports
- struct FileSystemService
- struct SessionsIndex
- struct SessionEntry
- actor FileSystemCache (private)

## Methods
- func listSkills(bypassCache: Bool) async throws -> [Skill]
- func scanSkills() throws -> [Skill]
- func getSkill(name: String) throws -> Skill?
- func createSkill(name: String, content: String) throws -> Skill
- func updateSkill(name: String, content: String) throws -> Skill
- func deleteSkill(name: String) throws
- func readMCPServers(scope: MCPScope?, bypassCache: Bool) async throws -> [MCPServer]
- func scanMCPServers(scope: MCPScope?) throws -> [MCPServer]
- func addMCPServer(_ server: MCPServer) throws
- func removeMCPServer(name: String, scope: MCPScope) throws
- func readConfig(scope: String) throws -> ConfigInfo
- func writeConfig(scope: String, content: ClaudeConfig) throws -> ConfigInfo
- func scanExternalSessions() throws -> [ExternalSession]
- func readTranscriptMessages(encodedProjectPath: String, sessionId: String, limit: Int, offset: Int) throws -> [Message]

## Dependencies
- import Foundation
- import Vapor
- import ILSShared
- import Yams

## Keywords
service filesystemservice filesystem skills mcp config sessions cache
