# Command Palette

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/CommandPalette/`
- `ILSApp/ILSApp/Services/CommandRegistry.swift`
- `ILSApp/ILSApp/Services/KeyboardShortcutStore.swift`

## Purpose

Provides a keyboard-driven quick-action overlay (Cmd+K style) that lets power users jump to any screen, search across data, and execute common actions without touching the sidebar.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Invokes Palette] --> Overlay[Command Palette Overlay ⚡ Instant open]
        Overlay --> Type[Type Query ⚡ Fuzzy search]
        Type --> Results[Matched Commands + Screens]
        Results --> Pick[Select Action]
        Pick --> Execute[Action Executed ⚡ Navigate or run]
    end

    subgraph "Back-Stage (Implementation)"
        Type --> Registry[CommandRegistry 🎯 All registered actions]
        Registry --> FuzzyMatch[Fuzzy Matcher ⚡ Ranked by relevance]

        FuzzyMatch --> NavCommands[Navigation Commands 🎯 Go to any screen]
        FuzzyMatch --> ActionCommands[Quick Actions 🎯 New session, export, etc.]
        FuzzyMatch --> SearchResults[Data Search 🎯 Sessions, skills, MCP]

        Pick --> ActiveScreen[Set ActiveScreen 💾 Navigate]
        Pick --> ActionHandler[Execute Action ⚡]

        Overlay --> Shortcuts[KeyboardShortcutStore 💾 Custom bindings]
    end

    FuzzyMatch -->|No match| Empty[No Results 🔄 Suggest alternatives]
    ActionHandler -->|Error| Toast[Error Toast 🔄 Actionable message]
```

## Key Insights

- **Keyboard-First**: Power users navigate entire app without touching sidebar
- **Fuzzy Search**: Typo-tolerant matching across commands, screens, and data
- **Extensible Registry**: New commands registered declaratively via `CommandRegistry`
- **Custom Shortcuts**: Users can rebind keyboard shortcuts via `KeyboardShortcutStore`
- **Cross-Concern**: Searches sessions, skills, and MCP servers from one input

## Change History

- **2026-03-18:** Initial creation
