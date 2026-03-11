# ILS iOS — Unified Impact Diagrams Index

Diagrams following Diagram Driven Development (DDD) methodology — connecting user experience to technical implementation.

**Last Updated:** 2026-03-10

## Quick Links

- [System Architecture](#architecture)
- [User Journeys](#user-journeys)
- [Features](#features)

## Architecture

- [System Overview](architecture/arch-system-overview.md) - Three-tier monorepo: SwiftUI iOS/macOS + Vapor backend + Claude CLI integration
- [Chat Streaming Pipeline](architecture/arch-chat-streaming-pipeline.md) - Real-time SSE chat from user input to Claude response

## User Journeys

- [Chat Session Lifecycle](journeys/journey-chat-session-lifecycle.md) - Creating, chatting, and managing Claude Code sessions
- [Server Connection](journeys/journey-server-connection.md) - Connecting iOS app to local/remote backend

## Features

- [Theme System](features/feature-theme-system.md) - 13 built-in themes with premium gating and Dynamic Type
- [Feature Gating](features/feature-premium-gating.md) - Free vs premium tier access control

## Test Coverage

_No diagrams yet._

## Refactoring Plans

_No diagrams yet._

## Recent Changes

- **2026-03-10:** Bootstrap — created directory structure and initial diagrams
