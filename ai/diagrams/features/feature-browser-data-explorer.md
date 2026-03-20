# Browser & Data Explorer

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Browser/`
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`
- `ILSApp/ILSApp/ViewModels/MCPViewModel.swift`
- `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`
- `Sources/ILSBackend/Controllers/SkillsController.swift`
- `Sources/ILSBackend/Controllers/MCPController.swift`
- `Sources/ILSBackend/Controllers/PluginsController.swift`

## Purpose

Lets users browse, search, and inspect their entire Claude Code ecosystem — 22K+ sessions, 3K+ skills, 15 MCP servers, and 84 plugins — with paginated lists, detail views, and health status indicators.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Opens Browser] --> Tabs{Pick Category}
        Tabs -->|Sessions| Sessions[Sessions List ⚡ 22K+ searchable]
        Tabs -->|Skills| Skills[Skills Grid 🎯 3K+ with favorites]
        Tabs -->|MCP| MCP[MCP Servers ✅ Health indicators]
        Tabs -->|Plugins| Plugins[Plugins List 🎯 84 installed]

        Sessions --> SessionDetail[Session Detail 💾 Full conversation]
        Skills --> SkillDetail[Skill Detail 📊 Usage stats]
        MCP --> MCPDetail[Server Detail ✅ Tool inventory]
        Plugins --> PluginDetail[Plugin Config 🎯 Enable/disable]
    end

    subgraph "Back-Stage (Implementation)"
        Sessions --> PaginatedAPI[Paginated GET ⚡ 50 per page]
        Skills --> SearchAPI[Full-text Search 🎯 Name + description]
        MCP --> HealthCheck[Health Polling ✅ Every 30s]
        Plugins --> PluginState[Plugin State 💾 Enabled/disabled tracking]

        PaginatedAPI --> Backend[Vapor Controllers]
        SearchAPI --> Backend
        HealthCheck --> Backend
        PluginState --> Backend

        Backend --> DB[(SQLite 💾 Local data)]
        Backend --> ClaudeCLI[Claude CLI 🎯 Live skill/MCP data]
    end

    PaginatedAPI -->|Error| EmptyState[Empty State 🔄 Pull to refresh]
    HealthCheck -->|Server down| Unhealthy[Red Status Badge 🔄 Shows last-seen time]
```

## Key Insights

- **Massive Scale**: Handles 22K+ sessions with paginated loading — no memory blowup
- **Live Health**: MCP servers show green/red health badges with auto-polling
- **Skill Favorites**: Users can pin frequently-used skills for quick access
- **Plugin Toggle**: Enable/disable plugins without leaving the browser
- **Unified Search**: Search across sessions, skills, and plugins from one interface

## Change History

- **2026-03-18:** Initial creation
