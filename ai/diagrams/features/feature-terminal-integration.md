# Terminal Integration

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Terminal/`
- `ILSApp/ILSApp/ViewModels/TerminalViewModel.swift`
- `ILSApp/ILSApp/Services/TerminalWebSocketClient.swift`
- `Sources/ILSBackend/Controllers/TerminalController.swift`

## Purpose

Gives users a native terminal interface within ILS to execute commands on the backend machine via WebSocket, enabling server management without switching to a separate terminal app.

## Diagram

```mermaid
sequenceDiagram
    actor User
    participant UI as Terminal View (Front-Stage)
    participant VM as TerminalViewModel
    participant WS as TerminalWebSocketClient
    participant API as Vapor Backend
    participant Shell as Host Shell

    User->>UI: Navigate to Terminal
    Note over UI: Shows terminal prompt ⚡

    UI->>VM: onAppear
    VM->>WS: connect()
    WS->>API: ws://host:9999/api/v1/terminal
    Note over API: WebSocket upgrade 🛡️ Authenticated

    API->>Shell: Spawn PTY session
    Note over Shell: Pseudo-terminal 🎯 Full shell access

    User->>UI: Types command
    UI->>VM: Input text
    VM->>WS: Send command bytes
    WS->>API: WebSocket frame
    API->>Shell: Write to PTY stdin

    Shell-->>API: stdout + stderr
    API-->>WS: Output frame ⚡ Real-time
    WS-->>VM: Parse output
    VM-->>UI: Render terminal text ⚡ ANSI color support
    UI-->>User: Sees command output

    alt Connection Drop
        WS-->>VM: Disconnected
        Note over VM: Auto-reconnect 🔄 Resume session
        VM-->>UI: Show reconnecting indicator ⏱️
        WS->>API: Reconnect
        API-->>WS: Session restored
        WS-->>VM: Connected
        VM-->>UI: Terminal restored ✅
    end

    alt Session Timeout
        Note over Shell: Idle timeout 🛡️ Prevents orphan shells
        Shell-->>API: PTY closed
        API-->>WS: Session ended
        WS-->>VM: Notify
        VM-->>UI: Show "Session ended" 🔄 Tap to restart
    end
```

## Key Insights

- **Native Terminal**: Full PTY session via WebSocket — not a command runner, a real shell
- **ANSI Support**: Terminal renders colors, cursor movement, and formatting natively
- **Session Persistence**: Reconnect restores the same shell session after network blips
- **Idle Timeout**: Orphan shells automatically cleaned up to prevent resource leaks
- **Authenticated**: WebSocket connection requires valid backend auth

## Change History

- **2026-03-18:** Initial creation
