# ILS iOS — Unified Impact Diagrams Index

Diagrams following Diagram Driven Development (DDD) methodology — connecting user experience to technical implementation.

**Last Updated:** 2026-03-18

## Quick Links

- [System Architecture](#architecture)
- [User Journeys](#user-journeys)
- [Features](#features)

## Architecture

- [System Overview](architecture/arch-system-overview.md) - Three-tier monorepo: SwiftUI iOS/macOS + Vapor backend + Claude CLI integration
- [Chat Streaming Pipeline](architecture/arch-chat-streaming-pipeline.md) - Real-time SSE chat from user input to Claude response with timeout recovery
- [Navigation & Deep Links](architecture/arch-navigation-deep-links.md) - 20+ screen routing via ActiveScreen enum, ils:// URL scheme, sidebar navigation

## User Journeys

- [Chat Session Lifecycle](journeys/journey-chat-session-lifecycle.md) - Creating, chatting, forking, and exporting Claude Code sessions
- [Server Connection](journeys/journey-server-connection.md) - Connecting iOS app to local/remote backend with auto-reconnect
- [Onboarding & First Launch](journeys/journey-onboarding-setup.md) - First launch to connected dashboard in 60 seconds

## Features

- [Theme System](features/feature-theme-system.md) - 13 built-in themes with premium gating and Dynamic Type
- [Feature Gating](features/feature-premium-gating.md) - Free vs premium tier access control via StoreKit 2
- [System Monitoring](features/feature-system-monitoring.md) - Live CPU/memory/disk/network via WebSocket with REST polling fallback
- [Browser & Data Explorer](features/feature-browser-data-explorer.md) - Browse 22K+ sessions, 3K+ skills, MCP servers, and plugins
- [Session Management](features/feature-session-management.md) - Export, fork trees, bookmarks, backup, cross-session search
- [Command Palette](features/feature-command-palette.md) - Keyboard-driven quick actions and fuzzy navigation
- [Terminal Integration](features/feature-terminal-integration.md) - Native WebSocket terminal with PTY session and ANSI support
- [Chat Advanced Options](features/feature-chat-advanced-options.md) - Model selector, system prompt, permissions, tool control, streaming toggle
- [Agent Teams](features/feature-agent-teams.md) - View and manage coordinated AI agent teams with task boards

## Test Coverage

_No diagrams yet._

## Refactoring Plans

_No diagrams yet._

## Recent Changes

- **2026-03-18:** Full functional audit — added Chat Advanced Options diagram, updated Navigation with verified 20-item sidebar + ChatView bug, confirmed all existing diagrams accurate
- **2026-03-18:** Bootstrap complete — 8 new diagrams (navigation, system monitoring, browser, sessions, command palette, terminal, teams, onboarding)
- **2026-03-10:** Initial bootstrap — 6 seed diagrams (system overview, chat pipeline, session lifecycle, server connection, themes, premium gating)
