# Chat Session Lifecycle

**Type:** Sequence Diagram
**Last Updated:** 2026-03-10
**Related Files:**
- `ILSApp/ILSApp/Views/Sessions/SessionsView.swift`
- `ILSApp/ILSApp/Views/Chat/ChatView.swift`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- `Sources/ILSBackend/Controllers/SessionsController.swift`

## Purpose

Maps the complete user journey from browsing sessions to having a conversation with Claude, including session creation, message exchange, and session management actions like export and fork.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        Home[Home Screen 🎯 22K+ sessions at a glance]
        Sessions[Sessions List ⚡ Search & filter]
        NewSession[New Session Sheet ✅ Pick project context]
        ChatView[Chat View 🎯 Full conversation UI]
        Export[Export Chat 💾 Share conversations]
    end

    subgraph "Back-Stage (Implementation)"
        API[Sessions API ⚡ Paginated with search]
        Create[POST /sessions 💾 Creates session record]
        Stream[SSE /chat/stream ⚡ Real-time Claude response]
        Fork[POST /sessions/fork 💾 Branch conversation]
        ExportAPI[GET /sessions/export 📊 Markdown/JSON output]
    end

    Home -->|Tap Sessions| Sessions
    Sessions -->|Tap +| NewSession
    Sessions -->|Tap Session| ChatView
    NewSession -->|Create| Create
    Create -->|Success| ChatView
    ChatView -->|Send Message| Stream
    Stream -->|Token Stream| ChatView
    ChatView -->|Fork| Fork
    Fork -->|New Session| ChatView
    ChatView -->|Export| ExportAPI
    ExportAPI --> Export

    Sessions --> API
    API -->|Error| EmptyState[Empty State 🔄 Pull to refresh]

    Create -->|Error| CreateError[Creation Failed 🔄 User can retry]
    Stream -->|Error| StreamError[Connection Lost 🔄 Auto-reconnect]
```

## Key Insights

- **Massive Scale**: Home screen aggregates 22K+ sessions with instant search
- **Context Preservation**: Forking lets users branch conversations without losing history
- **Export Freedom**: Users own their data — export as Markdown or JSON anytime
- **Error Recovery**: Every failure point has a user-actionable recovery path

## Change History

- **2026-03-10:** Initial creation
