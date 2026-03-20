# Agent Teams

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Teams/`
- `ILSApp/ILSApp/ViewModels/TeamsViewModel.swift`
- `Sources/ILSBackend/Controllers/TeamsController.swift`

## Purpose

Lets users view and manage Claude Code agent teams — coordinated groups of AI agents working on shared task lists — with real-time status, task progress, and member activity monitoring.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Opens Teams] --> TeamList[Teams List 🎯 All active teams]
        TeamList --> TeamDetail[Team Detail View]
        TeamDetail --> Members[Member Status ⚡ Active/idle/completed]
        TeamDetail --> Tasks[Task Board 📊 Pending/in-progress/done]
        TeamDetail --> Messages[Team Messages 🎯 Agent communication log]
    end

    subgraph "Back-Stage (Implementation)"
        TeamList --> TeamsAPI[GET /api/v1/teams ⚡ List all teams]
        TeamDetail --> TeamDetailAPI[GET /api/v1/teams/:id 💾 Full team state]

        TeamDetailAPI --> ConfigFile[~/.claude/teams/ 💾 Team config JSON]
        TeamDetailAPI --> TaskDir[~/.claude/tasks/ 📊 Shared task list]

        Members --> AgentStatus[Agent Status Polling ⏱️ Every 10s]
        Tasks --> TaskStatus[Task State Machine ✅ pending → in_progress → completed]
        Messages --> MessageLog[Message History 💾 DMs + broadcasts]
    end

    AgentStatus -->|Agent offline| Stale[Show Last Seen 🔄]
    TaskStatus -->|Blocked| BlockedBadge[Blocked Badge 🔄 Shows blocking task]
    TeamsAPI -->|No teams| EmptyTeams[Empty State 🔄 Instructions to create team]
```

## Key Insights

- **Live Status**: Agent member status polled regularly — active, idle, or completed
- **Task Visualization**: Kanban-style board showing task flow through states
- **Communication Log**: View agent-to-agent messages for debugging team coordination
- **Blocked Detection**: Tasks with unresolved dependencies show blocking task reference
- **File-Based State**: Teams and tasks stored in `~/.claude/` directories — portable and inspectable

## Change History

- **2026-03-18:** Initial creation
