# Session Management

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Services/SessionExportService.swift`
- `ILSApp/ILSApp/Services/SessionBackupService.swift`
- `ILSApp/ILSApp/Services/SessionBookmarksManager.swift`
- `ILSApp/ILSApp/ViewModels/SessionForkTreeViewModel.swift`
- `ILSApp/ILSApp/ViewModels/CrossSessionSearchViewModel.swift`
- `Sources/ILSBackend/Controllers/SessionBackupController.swift`

## Purpose

Empowers users to manage their Claude Code conversations beyond basic chat — exporting for sharing, forking to branch ideas, bookmarking for quick access, backing up for safety, and searching across all sessions.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User in Chat Session] --> Actions{Session Actions}
        Actions -->|Export| ExportSheet[Export Options 💾 Markdown / JSON]
        Actions -->|Fork| ForkUI[Fork Tree View 🎯 Visual branch map]
        Actions -->|Bookmark| BookmarkToggle[Bookmark ⚡ Instant save]
        Actions -->|Backup| BackupUI[Backup Status 💾 Auto + manual]
        Actions -->|Search| CrossSearch[Cross-Session Search 🎯 Find anything]
    end

    subgraph "Back-Stage (Implementation)"
        ExportSheet --> ExportService[SessionExportService 💾 Format + download]
        ExportService --> ShareSheet[iOS Share Sheet 🎯 AirDrop, Files, clipboard]

        ForkUI --> ForkAPI[POST /sessions/fork 💾 Clone + branch]
        ForkAPI --> NewSession[New Session Created ⚡]
        NewSession --> ForkTree[Fork Tree Visualization 📊 Parent-child map]

        BookmarkToggle --> BookmarkStore[SessionBookmarksManager 💾 UserDefaults]

        BackupUI --> BackupService[SessionBackupService 💾 Periodic snapshots]
        BackupService --> BackupAPI[POST /sessions/backup 🛡️ Encrypted]

        CrossSearch --> SearchAPI[GET /sessions/search 🎯 Full-text across all]
        SearchAPI --> Results[Ranked Results ⚡ With message preview]
    end

    ExportService -->|Premium gate| Gate{FeatureGate 🛡️}
    Gate -->|Free| Block[Premium Required Overlay]
    Gate -->|Premium| ShareSheet

    BackupService -->|Error| RetryBackup[Retry on Next Interval 🔄]
    SearchAPI -->|No results| EmptySearch[Suggest Broader Query 🔄]
```

## Key Insights

- **Export Gated**: Chat export is a premium feature — clear upgrade path for free users
- **Fork Trees**: Visual graph shows conversation branch history — great for exploring alternatives
- **Cross-Session Search**: Search message content across all 22K+ sessions with previews
- **Auto-Backup**: Periodic session snapshots protect against data loss
- **Bookmarks**: One-tap bookmark for quick access to important conversations

## Change History

- **2026-03-18:** Initial creation
