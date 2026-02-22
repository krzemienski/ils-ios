---
phase: "05"
plan: "05"
subsystem: "system-monitor"
tags: [backend, websocket, swift, swiftui, process-list, metrics]
dependency_graph:
  requires: ["04-skills-plugins-hooks-themes"]
  provides: ["system-monitor-backend-fix", "websocket-hardening", "process-list-ui"]
  affects: ["SystemMetricsService", "MetricsWebSocketClient", "SystemMetricsViewModel", "ProcessListView"]
tech_stack:
  patterns:
    - DispatchQueue.global() + withCheckedContinuation for subprocess execution off NIO event loop
    - URLSessionWebSocketTask sendPing(pongReceiveHandler:) for heartbeat detection
    - Task-based auto-refresh timer with 5s interval, started/stopped with view lifecycle
key_files:
  modified:
    - Sources/ILSBackend/Services/SystemMetricsService.swift
    - ILSApp/ILSApp/Services/MetricsWebSocketClient.swift
    - ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift
    - ILSApp/ILSApp/Views/System/ProcessListView.swift
    - ILSApp/ILSApp.xcodeproj/project.pbxproj
decisions:
  - "Use DispatchQueue.global() + withCheckedContinuation rather than structured concurrency for subprocess to avoid holding actor"
  - "Parse ps aux output as static method so closure capture does not require actor isolation"
  - "Heartbeat ping every 15s using callback-based sendPing(pongReceiveHandler:) since no async overload available"
  - "disconnect() resets wsFailureCount and reconnectAttempts to fix stale state bug from MEMORY.md"
  - "Process count shows N-of-total badge when list truncated at 50, plain N when under limit"
metrics:
  duration: "19 minutes"
  completed_date: "2026-02-22"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 5
---

# Phase 5 Plan 5: System Monitor + Host Profiles Summary

**One-liner**: Fixed NIO/DispatchQueue deadlock in process endpoint, hardened WebSocket with heartbeat + disconnect state reset, improved process list UI with auto-refresh, count badge, and dual-threshold CPU color coding.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 5.1 | Fix /system/processes Endpoint Deadlock | c802a8c | `SystemMetricsService.swift` |
| 5.2 | Harden WebSocket Metrics Stream | a4c4591 | `MetricsWebSocketClient.swift`, `project.pbxproj` |
| 5.3 | Improve Process List UI | 884b6a0 | `ProcessListView.swift`, `SystemMetricsViewModel.swift` |

## What Was Built

### Task 5.1 — Backend Process Endpoint Fix (c802a8c)

The `getProcesses()` method in `SystemMetricsService` was running `ps aux` directly on the actor's executor. While the pipe-buffer read ordering was correct (read before waitUntilExit), running a blocking subprocess on the NIO event loop (via actor isolation) was the real issue — it blocked all other actor calls during process collection.

**Fix**: Moved the entire subprocess execution to `DispatchQueue.global(qos: .userInitiated)` using `withCheckedContinuation`. This yields the actor back to NIO while the subprocess runs on a separate thread. Also added a 5-second `DispatchWorkItem` timeout to prevent permanent hangs. `parseProcessOutput` was extracted as a `static` method so the closure doesn't need to capture `self` (actor isolation requirement).

### Task 5.2 — WebSocket Hardening (a4c4591)

Fixed the documented MEMORY.md bug where `disconnect()` failed to reset `wsFailureCount` and `reconnectAttempts`, causing subsequent `connect()` calls to immediately enter fallback polling mode.

**Fixes**:
- `disconnect()` now resets `wsFailureCount = 0`, `reconnectAttempts = 0`, `useFallbackPolling = false`
- Added `heartbeatTask` that sends a ping every 15 seconds via `sendPing(pongReceiveHandler:)` (callback API — no async overload exists on `URLSessionWebSocketTask`)
- Heartbeat is started in `connectWebSocket()`, cancelled in `handleWSDisconnect()`, `disconnect()`, and `deinit`
- Registered parallel agent's new HostProfiles files in Xcode project (pbxproj patch)

Existing features confirmed present: bounded history (60 points), exponential backoff reconnect (1s→2s→4s→max 30s, max 10 attempts), fallback REST polling after 3 WS failures.

### Task 5.3 — Process List UI (884b6a0)

**Auto-refresh**: Added `processRefreshTask` (5-second interval) in `SystemMetricsViewModel`. `startProcessAutoRefresh()` performs an immediate initial load then loops. Called from `connect()`/`disconnect()` for lifecycle alignment.

**Process count badge**: Header shows a capsule badge with process count. Displays "N" when under the 50-process limit, "N of total" when truncated.

**CPU color coding**: Dual threshold implemented:
- `> 80%` → `theme.error` (red) + `.semibold` weight
- `> 50%` → `theme.warning` (orange) + `.semibold` weight
- Otherwise → `theme.textSecondary`

Existing features confirmed: sort toggle (CPU/Memory), search filter wired to `processSearchText`, `.prefix(50)` limit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Parallel agent HostProfiles files not registered in Xcode project**
- **Found during**: Task 5.2 build verification
- **Issue**: The concurrent Task 5.4 (Fleet rename) agent created `HostProfilesView.swift`, `HostProfileDetailView.swift`, `HostProfilesViewModel.swift` on disk and updated `SidebarRootView.swift` to reference `HostProfilesView`, but the files were not registered in `project.pbxproj`, causing a "cannot find HostProfilesView in scope" build error
- **Fix**: Python script patched `project.pbxproj` to add PBXFileReference, PBXBuildFile, group membership, and Sources build phase entries for all three new files for both iOS and macOS targets
- **Files modified**: `ILSApp/ILSApp.xcodeproj/project.pbxproj`
- **Commit**: a4c4591
- **Note**: Resulted in duplicate build file warnings (harmless) because the parallel agent had already added the files in a different part of the build phases

## Build Verification

| Target | Result |
|--------|--------|
| iOS (ILSApp) | BUILD SUCCEEDED — warnings only (duplicate file entries from parallel agent) |
| Backend (ILSBackend) | Build complete — 0 errors, 0 warnings |

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| SystemMetricsService.swift exists | FOUND |
| MetricsWebSocketClient.swift exists | FOUND |
| SystemMetricsViewModel.swift exists | FOUND |
| ProcessListView.swift exists | FOUND |
| Commit c802a8c (Task 5.1) | FOUND |
| Commit a4c4591 (Task 5.2) | FOUND |
| Commit 884b6a0 (Task 5.3) | FOUND |
