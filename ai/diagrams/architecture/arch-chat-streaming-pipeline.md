# Chat Streaming Pipeline

**Type:** Architecture Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/Views/Chat/ChatView.swift`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- `ILSApp/ILSApp/Services/SSEClient.swift`
- `Sources/ILSBackend/Controllers/ChatController.swift`
- `scripts/sdk-wrapper.py`

## Purpose

Shows how a user's chat message flows from SwiftUI input through the Vapor backend to Claude and back as a real-time streaming response, including timeout handling and error recovery.

## Diagram

```mermaid
sequenceDiagram
    actor User
    participant Chat as ChatView (Front-Stage)
    participant VM as ChatViewModel
    participant SSE as SSEClient
    participant API as Vapor Backend
    participant SDK as sdk-wrapper.py
    participant Claude as Claude CLI

    User->>Chat: Types message & sends
    Note over Chat: Optimistic UI ⚡ Message appears instantly

    Chat->>VM: sendMessage()
    VM->>SSE: POST /api/v1/chat/stream
    Note over SSE: 30s initial timeout ⏱️ Prevents hung connections

    SSE->>API: HTTP POST with session context
    Note over API: Validates session 🛡️ Prevents invalid requests

    API->>SDK: Spawn subprocess
    Note over SDK: Env var stripping 🛡️ Blocks nesting detection

    SDK->>Claude: claude_agent_sdk.query()
    Note over Claude: OAuth auth 🛡️ No API keys in app

    loop Token Streaming
        Claude-->>SDK: Partial message (NDJSON)
        SDK-->>API: Stream chunk
        API-->>SSE: SSE event
        SSE-->>VM: Parse & append
        VM-->>Chat: Update UI ⚡ Token-by-token rendering
        Chat-->>User: Sees response building
    end

    Claude-->>SDK: Final message + cost
    SDK-->>API: Complete event
    API-->>SSE: SSE done
    SSE-->>VM: Mark complete
    VM-->>Chat: Show cost badge 💾 Track API spend

    alt Connection Timeout
        SSE-->>VM: connectingTooLong timer fires
        Note over VM: 60s watchdog ⏱️ Detects stale connections
        VM-->>Chat: Show timeout error 🔄
        Chat-->>User: Retry button available
    end

    alt Claude CLI Hangs
        Note over SDK: 5min total timeout ⏱️ Kills stuck processes
        SDK-->>API: Process terminated
        API-->>SSE: Error event
        SSE-->>VM: Show error
        VM-->>Chat: Error with retry 🔄
    end
```

## Key Insights

- **Instant Feedback**: Optimistic UI shows user message before backend confirms
- **Token Streaming**: Response renders word-by-word via SSE, not waiting for full completion
- **Two-Tier Timeouts**: 30s initial connect + 5min total prevents both slow starts and infinite hangs
- **Env Var Stripping**: Removes `CLAUDECODE=1` vars so Claude CLI doesn't detect nesting and refuse to run
- **Cost Tracking**: Final event includes API cost so users can monitor spend

## Change History

- **2026-03-10:** Initial creation
