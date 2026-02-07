---
type: component-spec
source: ILSApp/ILSApp/ViewModels/MCPViewModel.swift
hash: 80f20508
category: service
indexed: 2026-02-05T21:40:00Z
---

# MCPViewModel

## Purpose
SwiftUI ObservableObject managing MCP servers with client-side search filtering and cache refresh support.

## Exports
- class MCPViewModel: ObservableObject

## Methods
- init()
- func configure(client: APIClient)
- func loadServers(refresh: Bool) async
- func refreshServers() async
- func retryLoadServers() async
- func addServer(name: String, command: String, args: [String], scope: String) async -> MCPServerItem?
- func deleteServer(_ server: MCPServerItem) async

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service mcpviewmodel mcp servers search viewmodel
