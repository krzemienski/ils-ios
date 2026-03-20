# System Monitoring

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/System/SystemMetricsView.swift`
- `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift`
- `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift`
- `Sources/ILSBackend/Controllers/SystemController.swift`

## Purpose

Gives users a live dashboard of their machine's health (CPU, memory, disk, network, process count) with real-time WebSocket streaming and automatic fallback to REST polling when WebSocket fails.

## Diagram

```mermaid
sequenceDiagram
    actor User
    participant UI as System Monitor (Front-Stage)
    participant VM as SystemMetricsViewModel
    participant WS as MetricsWebSocketClient
    participant API as Vapor Backend
    participant OS as macOS System APIs

    User->>UI: Navigate to System Monitor
    Note over UI: Shows loading state ⏱️

    UI->>VM: onAppear
    VM->>WS: connect()

    WS->>API: ws://host:9999/api/v1/system/metrics/live
    Note over API: WebSocket upgrade 🎯 Enables real-time

    API->>OS: Poll system metrics
    Note over OS: CPU, Memory, Disk, Network, Processes

    loop Live Streaming (every 2s)
        OS-->>API: Raw metrics
        API-->>WS: JSON payload ⚡ Sub-second delivery
        WS-->>VM: Parse metrics
        VM-->>UI: Update gauges ⚡ Live animation
        UI-->>User: CPU 5%, RAM 8GB, 1324 processes
    end

    alt WebSocket Fails 3x
        WS-->>VM: Fallback triggered
        Note over VM: Switch to REST polling 🔄 Automatic recovery

        loop REST Polling (every 5s)
            VM->>API: GET /api/v1/system/metrics
            API->>OS: Snapshot metrics
            OS-->>API: Metrics
            API-->>VM: JSON response
            VM-->>UI: Update gauges ⏱️ Slightly delayed
        end
    end

    alt 10min Recovery Window
        Note over WS: Retry WebSocket 🔄
        WS->>API: Reconnect ws://
        API-->>WS: Connected
        Note over WS: Resume live streaming ⚡
    end
```

## Key Insights

- **Real-Time by Default**: WebSocket streams metrics every 2s for live gauges and graphs
- **Automatic Fallback**: After 3 WebSocket failures, transparently switches to REST polling at 5s intervals
- **Self-Healing**: After 10 minutes in fallback mode, retries WebSocket to restore real-time
- **Native Gauges**: CPU/memory/disk rendered as SwiftUI gauge animations, not static text
- **Process Count**: Shows total running processes as a health indicator

## Change History

- **2026-03-18:** Initial creation
