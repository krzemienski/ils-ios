# ILS Project Overview & Product Development Requirements

**Version:** 1.1.1 | **Status:** Production | **Last Updated:** 2026-03-10

---

## Executive Summary

ILS (Intelligent Local Server) is a native Swift client for Claude Code, enabling developers to:
- Manage and replay Claude Code sessions locally
- Execute workflows with real-time feedback
- Monitor system resources and agent team coordination
- Integrate model context protocol (MCP) servers and plugins
- Customize themes and configure advanced development tools

The project comprises iOS, macOS, and backend components totaling ~152K LOC across 617 Swift files.

---

## Vision & Target Users

### Primary Users
- **Claude Code Power Users** — Developers who run Claude Code CLI and want a GUI for session management
- **Team Leads & Agents** — Users coordinating multi-agent workflows with team features
- **System Developers** — Engineers who need deep monitoring, hooks, and plugin extensibility

### Core Value Proposition
- **Session Replay & Forking** — Explore alternative code paths from checkpoints
- **Real-Time Feedback** — Live metrics on CPU, memory, disk, network
- **Portable Workflows** — Manage agent teams and automation rules across machines
- **Extensible System** — MCP servers, plugins, custom themes, app intents/shortcuts

---

## Feature Matrix

### Core (v1.0 - Complete)

| Feature | iOS | macOS | Status |
|---------|-----|-------|--------|
| Session list & detail | ✅ | ✅ | COMPLETE |
| Real-time chat (SSE) | ✅ | ✅ | COMPLETE |
| New session creation | ✅ | ✅ | COMPLETE |
| Session fork | ✅ | ✅ | COMPLETE |
| Message history search | ✅ | ✅ | COMPLETE |

### Discovery (v1.0 - Complete)

| Feature | iOS | macOS | Status |
|---------|-----|-------|--------|
| Skills browser (GitHub) | ✅ | ✅ | COMPLETE |
| Plugins marketplace | ✅ | ✅ | COMPLETE |
| MCP server catalog | ✅ | ✅ | COMPLETE |
| Quick install | ✅ | ✅ | COMPLETE |

### Configuration (v1.0 - Complete)

| Feature | iOS | macOS | Status |
|---------|-----|-------|--------|
| Settings panel | ✅ | ✅ | COMPLETE |
| Theme customization | ✅ | ✅ | COMPLETE |
| Host profiles | ✅ | ✅ | COMPLETE |
| Cloudflare tunnels | ✅ | ✅ | COMPLETE |

### Advanced (v1.1 - Complete)

| Feature | iOS | macOS | Status |
|---------|-----|-------|--------|
| System Monitor (metrics) | ✅ | ✅ | COMPLETE |
| Agent Teams | ✅ | ✅ | COMPLETE |
| Workflows & scheduling | ✅ | ✅ | COMPLETE |
| Hooks & config editor | ✅ | ✅ | COMPLETE |

### Premium (v1.2 - Planned)

| Feature | iOS | macOS | Status |
|---------|-----|-------|--------|
| Chat export (PDF/JSON) | 🔄 | 🔄 | PLANNED |
| Advanced monitoring (apm) | 🔄 | 🔄 | PLANNED |
| Unlimited sessions | 🔄 | 🔄 | PLANNED |
| Custom MCP dev tools | 🔄 | 🔄 | PLANNED |

---

## Technical Requirements

### Functional Requirements

| ID | Feature | Requirement | Status |
|----|---------|-------------|--------|
| **FR-001** | Backend API | REST endpoints at `/api/v1` with auth middleware | COMPLETE |
| **FR-002** | Real-time Chat | Server-Sent Events (SSE) streaming with token counting | COMPLETE |
| **FR-003** | Session Mgmt | CRUD operations, fork from checkpoint, message search | COMPLETE |
| **FR-004** | System Metrics | CPU, memory, disk, network monitoring via WebSocket | COMPLETE |
| **FR-005** | Theme System | 13 built-in + custom editor with Codable storage | COMPLETE |
| **FR-006** | Offline Mode | LocalDatabase caching, sync on reconnect | COMPLETE |
| **FR-007** | Deep Linking | URL scheme `ils://` for session/plugin navigation | COMPLETE |
| **FR-008** | Plugin System | Install custom plugins, configure via editor | COMPLETE |
| **FR-009** | MCP Servers | Discover and integrate Model Context Protocol servers | COMPLETE |

### Non-Functional Requirements

| ID | Category | Requirement | Status |
|----|----------|-------------|--------|
| **NFR-001** | Performance | App startup < 3s, session list < 500ms (22K items) | COMPLETE |
| **NFR-002** | Battery | ScenePhase animation pausing, timer tolerance | COMPLETE |
| **NFR-003** | Memory | deinit cleanup for WebSocket, tasks, timers | COMPLETE |
| **NFR-004** | Network | Conditional requests (ETags), request deduplication | COMPLETE |
| **NFR-005** | Concurrency | @MainActor ViewModels, actor-based APIClient | COMPLETE |
| **NFR-006** | Accessibility | Dynamic Type support, VoiceOver labels | COMPLETE |
| **NFR-007** | Dark Mode | System-adaptive colors, custom theme support | COMPLETE |
| **NFR-008** | Data Safety | Keychain for credentials, no hardcoded secrets | IN PROGRESS |
| **NFR-009** | Privacy | GDPR data deletion, Privacy Manifest | IN PROGRESS |

---

## Architecture Overview

### Three-Tier System

```
┌─────────────────────────────────────┐
│ iOS App (SwiftUI, 401 Swift files) │
│ macOS App (SwiftUI, 18 Swift files)│
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Shared Models (ILSShared, 26 files) │
│ DTOs, Codable, Sendable             │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Backend (Vapor, 52 Swift files)     │
│ 31 Controllers, 39 Services         │
│ SQLite (ils.sqlite)                 │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Claude Code CLI (Python SDK wrapper)│
│ Agent execution, stream processing  │
└─────────────────────────────────────┘
```

### Key Components

**Frontend (iOS/macOS):**
- `APIClient` — Actor-based REST with caching, ETags, request dedup
- `SSEClient` — Server-Sent Events streaming (2-tier timeouts)
- `ChatViewModel` — Manages messages, permissions, streaming state
- `SessionsViewModel` — 22K sessions with search/filter optimization
- `ThemeSnapshot` — Concrete struct replacing existential containers (82 sites optimized)

**Backend:**
- `SessionsController` — CRUD, fork, checkpoint, search (1,464 LOC)
- `ChatController` — Stream handling with Python SDK wrapper (869 LOC)
- `ClaudeExecutorService` — Python subprocess with env var stripping
- `SystemMetricsService` — CPU, memory, disk, network collection
- `WorkflowExecutionEngine` — Scheduler + executor for automation

---

## Success Metrics

### User Engagement
- **Retention:** 70%+ monthly active users (after 30 days)
- **Feature Adoption:** 40%+ use MCP servers, 25%+ use workflows
- **Session Volume:** Average 5+ sessions per active user

### Performance
- **Startup:** < 3 seconds
- **Session List Load:** < 500ms (22K items)
- **Chat Response:** First token < 1s, full response < 5s
- **Metrics Update:** < 100ms refresh cycle

### Quality
- **Crash-Free:** 99.9% sessions crash-free
- **Test Coverage:** 30% UI coverage, 60% backend coverage (planned)
- **Build Success:** 100% CI/CD pass rate

### Business
- **App Store Rating:** 4.5+
- **Premium Conversion:** 5-10% of active users
- **Revenue:** $12.5K-40K/year (subscription model)

---

## Roadmap (13 Phases, 58 Days)

See `docs/ROADMAP.md` for detailed phase breakdown. Key milestones:

| Phase | Duration | Focus | Status |
|-------|----------|-------|--------|
| **0** | Days 1-3 | Memory, energy, performance fixes | COMPLETE |
| **1** | Days 4-8 | Security hardening (auth, validation, rate limiting) | IN PROGRESS |
| **2** | Days 9-12 | UI polish (accessibility, dark mode, animations) | COMPLETE |
| **3** | Days 13-15 | Infrastructure (Docker, CI/CD, monitoring) | IN PROGRESS |
| **4-13** | Days 16-58 | Advanced features (premium tier, teams, workflows) | PLANNED |

---

## Risk Assessment

### Critical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-----------|
| Backend downtime | Users cannot sync sessions | LOW | Offline mode, local SQLite caching |
| Data loss | User sessions unavailable | LOW | Regular backups, version control |
| Security breach | Credential exposure | MEDIUM | Keychain storage, input validation, rate limiting |
| Performance degradation | 22K sessions → slow search | LOW | Indexing, caching, search optimization |

### Medium Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-----------|
| Plugin incompatibility | Crashes, feature breakage | MEDIUM | Plugin sandbox, version pinning |
| MCP server failures | Incomplete integrations | MEDIUM | Fallback modes, health checks |
| Memory leaks | Battery drain, crashes | LOW | deinit cleanup, scenePhase management |

---

## Dependencies

### External Services
- **Claude Code CLI** — User must have CLI installed
- **Anthropic API** — Backend calls Claude API (user's API key)
- **GitHub API** — Skill discovery and marketplace
- **Cloudflare** — Tunnel integration for remote access

### Internal Dependencies
- **Backend:** Vapor 4, SQLite, Fluent ORM
- **Frontend:** SwiftUI, Observation, TipKit, StoreKit 2
- **Shared:** ILSShared models (DTOs, enums, protocols)

---

## Compliance & Standards

### Regulatory
- **GDPR:** Data deletion endpoint at `/api/v1/data/delete`
- **CCPA:** Privacy policy, data handling transparency
- **App Store:** Privacy Manifest (PrivacyInfo.xcprivacy), app review guidelines

### Code Quality
- **SwiftLint:** Enabled (`.swiftlint.yml`)
- **Build:** Zero errors, zero warnings on all targets
- **Concurrency:** Swift Concurrency (async/await, @MainActor, actors)

### Accessibility
- **WCAG AA:** 4.5:1 contrast ratio (body text), 3:1 (large text)
- **Dynamic Type:** All text scales with user setting
- **VoiceOver:** Labels on interactive elements

---

## Deployment

### Platforms
- **iOS:** 17.0+ via App Store
- **macOS:** 14.0+ via App Store
- **Backend:** Docker, launchd, Homebrew services, or direct Swift

### Release Process
```
Feature Branch → Code Review → Merge to master → TestFlight → App Store
```

See `docs/RUNNING_BACKEND.md` for server deployment options.

---

## Future Considerations (v2.0+)

- **Web Client:** Browser-based dashboard via WebKit
- **Team Analytics:** Aggregate metrics across multiple users
- **AI-Powered Insights:** Anomaly detection, performance recommendations
- **Custom Themes Marketplace:** Share themes with community
- **Mobile Cloud:** Sync sessions across iOS/macOS devices
