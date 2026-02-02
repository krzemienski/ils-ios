# ILS iOS Application - Claude Code Full Feature Parity

## Original Request

We want to expand the ILS application functionality to encompass all aspects of Claude Code and its SDK. Currently, our specs show that only the settings are being modified and utilize the RR API. We need to expand this to cover every part of Claude Code's functionality on the host machine.

## Requirements for Both Backend and Frontend

### Core Features
- Plugins
- Sessions
- Real-time streaming of chat responses
- Settings (skills and custom commands)

### API/CLI Integration
- Execute CLI commands on the user's behalf in non-interactive mode
- Detect previous sessions
- Support custom commands from user settings

### User Workflow
- Users can add new plugins and use them in sessions
- All features should integrate seamlessly

### Chat Interface & Map Flow
- Projects and sessions need meticulous, detailed implementation
- Stream JSON responses directly
- Provide concise output by default, with option to dive deeper into details
- Allow users to choose:
  - Model
  - MCP servers
  - Enabled plugins

## Goal

Achieve complete feature parity with how Claude Code currently functions.

## Existing Specification Context

The existing specs (`ils-spec.md` and `ils.md`) define:
- SSH-based remote configuration management
- Skills, MCP servers, and plugins CRUD operations
- Dark mode UI with hot orange accent
- Vapor backend with SwiftUI iOS frontend
- Shared models package architecture

The gap: Current specs focus on **configuration management** but not on **actual Claude Code execution and chat functionality**.
