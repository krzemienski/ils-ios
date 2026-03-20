# Server Connection Journey

**Type:** Sequence Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/Services/APIClient.swift`
- `ILSApp/ILSApp/Views/Settings/ServerSetupSheet.swift`
- `ILSApp/ILSApp/ViewModels/AppState.swift`
- `Sources/ILSBackend/Controllers/SystemController.swift`

## Purpose

Shows how users connect the iOS/macOS app to their local or remote ILS backend, including first-launch setup, health checks, and reconnection after network changes.

## Diagram

```mermaid
sequenceDiagram
    actor User
    participant App as ILS App (Front-Stage)
    participant Setup as ServerSetupSheet
    participant Client as APIClient
    participant Backend as Vapor Backend
    participant Health as /health endpoint

    User->>App: Launch app
    Note over App: Check saved server URL 💾

    alt First Launch (No URL saved)
        App->>Setup: Show setup sheet
        Note over Setup: Default localhost:9999 ⚡ Zero-config local
        User->>Setup: Enter server URL
        Setup->>Client: Save URL to UserDefaults 💾
    end

    Client->>Health: GET /health
    Note over Health: Validates backend running ✅

    alt Backend Running
        Health-->>Client: 200 OK
        Client-->>App: Connected state
        App-->>User: Green status indicator ✅
        App->>Backend: Load initial data
        Note over Backend: Sessions, projects, stats ⚡
        Backend-->>App: Dashboard populated
    end

    alt Backend Not Running
        Health-->>Client: Connection refused
        Client-->>App: Disconnected state
        App-->>User: Red indicator + instructions 🔄
        Note over App: Shows "Run backend" command
        User->>App: Starts backend manually
        App->>Health: Auto-retry health check ⏱️
        Health-->>Client: 200 OK
        Client-->>App: Connected
    end

    alt Network Change (Wi-Fi switch, tunnel)
        Note over Client: Connection drops
        Client-->>App: Disconnected
        App-->>User: Yellow reconnecting indicator ⏱️
        Client->>Health: Auto-retry with backoff
        Health-->>Client: 200 OK
        Client-->>App: Reconnected ✅
        App-->>User: Green indicator restored
    end
```

## Key Insights

- **Zero-Config Local**: Default `localhost:9999` works out of the box for local dev
- **Visual Status**: Color-coded connection indicator — green/yellow/red
- **Auto-Recovery**: Network changes trigger automatic reconnection with backoff
- **Clear Instructions**: Disconnected state shows exact command to start backend

## Change History

- **2026-03-10:** Initial creation
