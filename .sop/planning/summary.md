# ILS Application - PDD Summary

**Date**: 2026-02-01
**Status**: Design Complete, Ready for Implementation

---

## Artifacts Created

| Artifact | Path | Description |
|----------|------|-------------|
| Rough Idea | `.sop/planning/rough-idea.md` | Original requirements for Claude Code feature parity |
| Requirements | `.sop/planning/idea-honing.md` | 13 clarified requirements with answers |
| Research | `.sop/planning/research/claude-code-features.md` | Complete Claude Code feature research |
| Design | `.sop/planning/design/detailed-design.md` | Comprehensive design document |
| Implementation | `.sop/planning/implementation/plan.md` | 42-step implementation plan |

---

## Design Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      HOST MACHINE                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 VAPOR BACKEND                        │   │
│  │     REST API + SSE + WebSocket                       │   │
│  │           ↓                                          │   │
│  │   ClaudeExecutorService (Swift Process)             │   │
│  │           ↓                                          │   │
│  │   Claude Code CLI (--output-format stream-json)     │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTP/SSE/WebSocket
┌───────────────────────────┴─────────────────────────────────┐
│                      iOS APP                                 │
│  SessionsListView → ChatView → Streaming Messages           │
│  + Projects, Plugins, MCP, Skills, Settings                 │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

| Feature | Implementation |
|---------|----------------|
| **Chat Streaming** | SSE for simple, WebSocket for interactive |
| **Session Management** | Hybrid: ILS DB + Claude Code storage scan |
| **Project Management** | Full CRUD, session scoping, model defaults |
| **Plugins** | Full CRUD, marketplace browsing |
| **MCP Servers** | Full CRUD for all scopes |
| **Skills** | View, create, edit, invoke |
| **Settings** | Full config editing, JSON validation |
| **Permissions** | Configurable per-session |

### UI Navigation

- **Session-centric** (like Messages app)
- Main screen: Sessions list
- Tap session → Chat view with streaming
- Sidebar: Projects, Plugins, MCP, Skills, Settings
- Command palette in chat for quick access

---

## Implementation Approach

### Phases

| Phase | Tasks | Validation Gates |
|-------|-------|------------------|
| -1 | API Contract | 1 gate (contract review) |
| 0 | 3 tasks | 3 gates |
| 1 | 5 tasks | 5 gates |
| 2A | 5 tasks | 6 gates |
| 2B | 8 tasks | 25+ gates (per endpoint) |
| 3A | 5 tasks | 5 gates |
| 3B | 12 tasks | 30+ gates (per interaction) |
| 4 | 4 tasks | 10+ gates (per flow) |

**Total: 42 implementation steps, 85+ validation gates**

### Validation Methodology

**3D Shift Validation with Granular Gates**:

| Gate Type | What It Validates | How |
|-----------|-------------------|-----|
| API Gate | Endpoint returns contract JSON | `curl` against real backend |
| UI Gate | Screen displays expected state | Simulator screenshot |
| Interaction Gate | User action produces result | Screenshot + backend log |
| Flow Gate | Multi-step workflow completes | Multiple screenshots + logs |

**CRITICAL RULES**:
1. **API Contract First**: Complete spec BEFORE any implementation
2. **Component Gates**: Each component has its own gate - NO batch validation
3. **Stop on Failure**: If any gate fails, STOP and fix before proceeding
4. **Evidence Required**: Every gate produces an artifact

**PROHIBITED**: Unit tests, mocks, pytest, functional tests, stubbed data

**REQUIRED**: Real compiled binaries, real Claude Code, real screenshots, evidence artifacts

### Parallel Execution

```
Track A (Backend)      Track B (iOS Core)      Track C (iOS Views)
     │                      │                       │
     ├─ Phase 2A            ├─ Phase 3A             │
     │    ↓                 │    ↓                  │
     ├─ Phase 2B ─────────────────────────────→ Phase 3B
     │                                              │
     └──────────────────────────────────────────────┴─→ Phase 4
```

---

## Next Steps

1. **Add project files to context**: `/context add .sop/planning/**/*.md`
2. **Start Phase 0**: Create directory structure
3. **Proceed through gates**: Each gate must PASS before continuing
4. **Collect evidence**: Every task requires evidence artifact

---

## Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Vapor on host + iOS client | Backend has direct Claude Code access |
| Streaming | SSE + WebSocket | SSE for simple, WS for interactive |
| Session storage | Hybrid | ILS DB + Claude storage scan |
| Execution | Swift Process primary | Native, no dependencies; Python sidecar optional |
| Permissions | Configurable per-session | Flexibility for different use cases |
| UI navigation | Session-centric | Chat is primary use case |
| Auth | None (local network) | MVP simplicity |
| Validation | 3D Shift | Real systems, no mocks |

---

## Research Sources

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Session Management](https://platform.claude.com/docs/en/agent-sdk/sessions)
- [ClaudeCodeSDK (Swift)](https://github.com/jamesrochabrun/ClaudeCodeSDK)
- [Plugin Development](https://code.claude.com/docs/en/plugins)

---

**Ready to begin implementation. All planning artifacts complete.**
