# ILS System Architecture Overview

**Type:** Architecture Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/` — iOS SwiftUI app
- `ILSApp/ILSMacApp/` — macOS SwiftUI app
- `Sources/ILSBackend/` — Vapor 4 backend
- `Sources/ILSShared/` — Shared DTOs
- `scripts/sdk-wrapper.py` — Python Claude Agent SDK wrapper

## Purpose

Shows how ILS delivers a native Claude Code experience across iOS and macOS by connecting SwiftUI clients to a local Vapor backend that orchestrates Claude CLI execution.

## Diagram

```mermaid
graph TB
    subgraph "Front-Stage (User Experience)"
        iOS[iOS App]
        macOS[macOS App]
        Sidebar[Sidebar Navigation 🎯 Quick access to all features]
        Chat[Chat View 🎯 Real-time Claude conversations]
        Browser[Browser 🎯 Browse sessions, skills, MCP, plugins]
        Settings[Settings ✅ Configure backend connection]
    end

    subgraph "Back-Stage (Implementation)"
        subgraph "Vapor Backend (Port 9999)"
            API[API Gateway 🛡️ /api/v1 prefix, validates requests]
            Controllers[25 Controllers 🎯 Full REST surface]
            SSE[SSE Streaming ⚡ Real-time chat delivery]
            Fluent[Fluent ORM 💾 SQLite persistence]
        end

        subgraph "Claude Integration"
            SDK[Python SDK Wrapper ⏱️ Subprocess isolation]
            CLI[Claude CLI 🎯 OAuth-authenticated AI execution]
            Anthropic[Anthropic API 🛡️ Secure cloud inference]
        end

        DB[(SQLite 💾 Local data store)]
    end

    iOS --> API
    macOS --> API
    API --> Controllers
    Controllers --> Fluent
    Controllers --> SSE
    Fluent --> DB
    SSE --> SDK
    SDK --> CLI
    CLI --> Anthropic

    Sidebar --> Chat
    Sidebar --> Browser
    Sidebar --> Settings

    Anthropic -->|Stream| CLI
    CLI -->|NDJSON| SDK
    SDK -->|SSE| iOS
    SDK -->|SSE| macOS

    Controllers -->|Error| ErrorResponse[API Error Response 🔄 Typed error envelopes]
    ErrorResponse --> iOS
```

## Key Insights

- **Native Performance**: SwiftUI on both platforms — no web views, no Electron
- **Local-First**: Vapor backend + SQLite runs on user's machine, data never leaves device
- **Real-Time Chat**: SSE streaming delivers Claude responses token-by-token
- **OAuth Auth**: Claude CLI handles auth — no API keys stored in app
- **Error Isolation**: Python subprocess prevents Claude CLI hangs from crashing backend

## Change History

- **2026-03-10:** Initial creation
