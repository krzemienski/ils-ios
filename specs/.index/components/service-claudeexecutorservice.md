---
type: component-spec
source: Sources/ILSBackend/Services/ClaudeExecutorService.swift
hash: 46f7eee7
category: service
indexed: 2026-02-05T21:40:00Z
---

# ClaudeExecutorService

## Purpose
Actor service for executing Claude Code CLI commands directly via Process with streaming output. Bypasses ClaudeCodeSDK due to RunLoop/Combine issues in Vapor's NIO event loops. Implements two-tier timeout mechanism (30s initial + 5min total) and process cancellation support.

## Exports
- actor ClaudeExecutorService
- struct ExecutionOptions

## Methods
- func isAvailable() async -> Bool
- func getVersion() async throws -> String
- func execute(prompt: String, workingDirectory: String?, options: ExecutionOptions) -> AsyncThrowingStream<StreamMessage, Error>
- func cancel(sessionId: String) async

## Dependencies
- import Foundation
- import Vapor
- import ILSShared

## Keywords
service claudeexecutorservice claude cli streaming process timeout
