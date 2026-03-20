# Chat Advanced Options

**Type:** Feature Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Chat/ChatView.swift`
- `ILSApp/ILSApp/Views/Chat/AdvancedOptionsSheet.swift`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`

## Purpose

Gives users granular control over every aspect of their Claude conversation — model selection, system prompts, permission modes, token budgets, tool allowlists, and streaming behavior — accessible from a single sheet in the chat input bar.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Taps Advanced Options ⚡] --> Sheet[Advanced Options Sheet]
        Sheet --> SystemPrompt[System Prompt Editor 🎯 Custom instructions]
        Sheet --> ModelPicker[Model Selector ⚡ Sonnet / Opus / Haiku]
        Sheet --> Permissions[Permission Mode 🛡️ default / plan / auto]
        Sheet --> Budget[Budget Controls 💾 Max Turns + Max Budget USD]
        Sheet --> ToolControl[Tool Control 🛡️ Allow/Disallow specific tools]
        Sheet --> StreamToggle[Stream Partial Messages ⚡ Token-by-token]
        Sheet --> Debug[Debug Mode 📊 Verbose logging]
        Sheet --> Reset[Reset to Defaults 🔄 One-tap restore]
    end

    subgraph "Back-Stage (Implementation)"
        ModelPicker --> SDKConfig[SDK Wrapper Config 🎯 --model flag]
        Permissions --> CLIFlags[Claude CLI Flags 🛡️ --permission-mode]
        Budget --> TurnCounter[Turn Counter 💾 Enforced per-session]
        ToolControl --> AllowList[Tool Allowlist 🛡️ --allowedTools / --disallowedTools]
        StreamToggle --> SSEMode[SSE Client Mode ⚡ Partial vs complete]
        SystemPrompt --> PromptInjection[Prepend to Session 💾 Persisted per-chat]
    end

    SDKConfig --> ChatStream[POST /api/v1/chat/stream]
    CLIFlags --> ChatStream
    AllowList --> ChatStream
    SSEMode --> ChatStream

    Reset -->|Error| Fallback[Defaults Always Available 🔄]
```

## Key Insights

- **Model Switching**: Users can switch between Sonnet (fast), Opus (deep reasoning), and Haiku (cheap) mid-conversation
- **System Prompt**: Custom instructions prepended to every message — persists per chat session
- **Token-by-Token Streaming**: "Stream Partial Messages" toggle controls whether responses render word-by-word or all at once
- **Tool Safety**: Allow/disallow specific tools (Bash, Write, Edit) for safety-conscious users
- **Budget Guardrails**: Max Turns and Max Budget USD prevent runaway sessions
- **One-Tap Reset**: Restore all defaults if configuration gets confusing

## Change History

- **2026-03-18:** Initial creation from full functional audit
