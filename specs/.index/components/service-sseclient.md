---
type: component-spec
source: ILSApp/ILSApp/Services/SSEClient.swift
hash: 06defe76
category: service
indexed: 2026-02-05T21:40:00Z
---

# SSEClient

## Purpose
SwiftUI ObservableObject for Server-Sent Events streaming with 60s connection timeout, automatic reconnection (max 3 attempts with exponential backoff), and connection state management.

## Exports
- class SSEClient: ObservableObject
- enum ConnectionState

## Methods
- init(baseURL: String)
- func startStream(request: ChatStreamRequest)
- func cancel()

## Dependencies
- import Foundation
- import Combine
- import ILSShared

## Keywords
service sseclient sse streaming observable reconnection timeout
