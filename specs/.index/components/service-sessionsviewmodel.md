---
type: component-spec
source: ILSApp/ILSApp/ViewModels/SessionsViewModel.swift
hash: 1dcfc182
category: service
indexed: 2026-02-05T21:40:00Z
---

# SessionsViewModel

## Purpose
SwiftUI ObservableObject managing chat sessions with dual-source loading (ILS DB + external Claude Code sessions), deduplication, and fork support.

## Exports
- class SessionsViewModel: ObservableObject
- struct CreateSessionRequest
- struct DeletedResponse
- struct EmptyBody

## Methods
- init()
- func configure(client: APIClient)
- func loadSessions() async
- func retryLoadSessions() async
- func createSession(projectId: UUID?, name: String?, model: String) async -> ChatSession?
- func deleteSession(_ session: ChatSession) async
- func forkSession(_ session: ChatSession) async -> ChatSession?

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service sessionsviewmodel sessions external fork viewmodel
