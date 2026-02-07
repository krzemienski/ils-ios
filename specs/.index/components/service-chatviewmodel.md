---
type: component-spec
source: ILSApp/ILSApp/ViewModels/ChatViewModel.swift
hash: ca2de599
category: service
indexed: 2026-02-05T21:40:00Z
---

# ChatViewModel

## Purpose
SwiftUI ObservableObject managing chat UI state with SSE streaming integration, message batching (75ms intervals), dual-mode session support (ILS DB + external JSONL transcripts), and connection state tracking with 5s timeout warning.

## Exports
- class ChatViewModel: ObservableObject

## Methods
- init()
- func configure(client: APIClient, sseClient: SSEClient)
- func loadMessageHistory() async
- func addUserMessage(_ text: String)
- func sendMessage(prompt: String, projectId: UUID?, options: ChatOptions?)
- func cancel()
- func forkSession() async -> ChatSession?

## Dependencies
- import Foundation
- import Combine
- import ILSShared

## Keywords
service chatviewmodel chat streaming sse batching viewmodel
