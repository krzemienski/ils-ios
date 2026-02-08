# Alpha Spec — Research Phase

**Date:** 2026-02-07
**Branch:** `design/v2-redesign`
**Methodology:** 5 parallel research agents via agent team (`alpha-research`)
**Research artifacts:** gap-analysis.md, tools-inventory.md, claude-sdk-research.md, workspace-unification-research.md, codebase-audit.md

---

## Executive Summary

The ILS iOS project has undergone massive development (~80 commits, ~21,728 LOC across 3 modules) but suffers from **spec proliferation** (10 specs, significant overlap) and **validation debt** (no end-to-end chat flow ever validated against live backend with new rendering). The codebase architecture is sound — Vapor backend with Claude CLI subprocess streaming, SwiftUI iOS app with SSE client, shared models via SPM. The workspace is 90% unified already. The ClaudeCodeSDK is correctly removed; our direct Process+DispatchQueue approach works in NIO contexts.

### Key Findings

1. **10 specs exist, 4 are complete, 3 are partially done, 3 are abandoned/empty**
2. **Critical gap: 10 chat scenarios never validated E2E** (the most important unfinished work)
3. **160+ MCP tools available** across 16 servers (XClaude, Codex, Gemini, Context7, Firecrawl, etc.)
4. **Swift 6.2.4 + Xcode 26.3 installed** — swift-subprocess migration is now feasible
5. **XcodeGen AND Tuist installed** — but workspace unification only needs manual scheme setup
6. **Backend is live and healthy** — 40+ endpoints, 15+ confirmed working via curl
7. **ClaudeCodeSDK stays removed** — RunLoop/NIO incompatibility is fundamental; our workaround is production-proven

---

## 1. Gap Analysis (from gap-analysis.md)

### Spec Status Overview

| Spec | Phase | % Complete | Key Outcome |
|------|-------|-----------|-------------|
| rebuild-ground-up | COMPLETE | 100% | 46/46 tasks, 12 themes, sidebar nav, full UI rebuild |
| app-enhancements | NEAR-COMPLETE | 97% | Chat rendering (MarkdownUI+HighlightSwift), SSE hardening, backend DI |
| remaining-audit-fixes | MOSTLY DONE | 79% | 43 audit issues fixed across 6 domains |
| ios-app-polish | COMPLETE | 100% | 13 scenarios validated with 42 screenshots |
| ios-app-polish2 | PARTIALLY DONE | 57% (effective ~85%) | System monitoring, tunnel, chat rendering — most unchecked tasks done by later specs |
| polish-again | IN PROGRESS | 66% | Architecture refactoring done; 10 chat scenarios UNVALIDATED |
| agent-teams | NOT STARTED | 0% | 38 tasks planned, 0 executed — entire new feature |
| ils-complete-rebuild | SUPERSEDED | 7% | Most work done by other specs |
| app-improvements | ABANDONED | 0% | Research only |
| finish-app | EMPTY | 0% | No files |

### Critical Gaps (Priority Order)

| Priority | Gap | Source | Impact |
|----------|-----|--------|--------|
| **P0** | 10 chat scenarios never validated E2E | polish-again | No proof chat works end-to-end with new rendering |
| **P0** | Visual evidence for MarkdownUI/HighlightSwift | app-enhancements | Rendering not screenshot-validated |
| **P1** | Agent Teams feature (38 tasks) | agent-teams | Entire new feature not built |
| **P1** | 14 stub fixes (SSH, Fleet, Config, Toggles) | agent-teams | User-facing buttons that do nothing |
| **P2** | Dead code/file size audit | polish-again | Possible residual dead code |
| **P2** | GitHub skill/plugin discovery improvements | ils-complete-rebuild | Install reliability unverified |
| **P3** | SSH remote management | ils-complete-rebuild | Backend exists, iOS never calls it |
| **P3** | App Store preparation | ils-complete-rebuild | Privacy Manifest, metadata |

---

## 2. Codebase Architecture (from codebase-audit.md)

### Module Sizes

| Module | Files | Lines | Role |
|--------|-------|-------|------|
| ILSBackend | 36 | 8,178 | Vapor server (port 9090) |
| ILSApp | 78 | 11,627 | SwiftUI iOS app |
| ILSShared | 15 | 1,923 | Shared models & DTOs |
| **Total** | **129** | **21,728** | |

### Data Flow (Chat Streaming)

```
Claude CLI (-p --stream-json) → stdout pipes
    → ClaudeExecutorService (Process + DispatchQueue, NOT RunLoop)
    → AsyncThrowingStream<StreamMessage>
    → ChatController (SSE response)
    → SSEClient (URLSession.bytes)
    → ChatViewModel (75ms batching)
    → ChatView (SwiftUI)
```

### Backend API: 40+ Endpoints

- **Sessions**: CRUD, fork, scan external (32 sessions, LIVE)
- **Projects**: index from filesystem (373 projects, LIVE)
- **Skills**: parse YAML files (1,481 skills, LIVE)
- **MCP**: read config files (20 servers, LIVE)
- **Plugins**: list, install via git clone (82 plugins, LIVE)
- **Chat**: SSE streaming, cancel (LIVE)
- **System**: metrics, processes, file browser (LIVE with caveats)
- **Config**: read/write/validate Claude config
- **Tunnel**: Cloudflare tunnel start/stop/status
- **Auth**: stub only (no real auth)
- **Stats**: aggregated dashboard metrics (LIVE)

### Technical Debt

| Issue | Severity | Location |
|-------|----------|----------|
| No authentication | HIGH | AuthController is a stub |
| CORS allows all origins | MEDIUM | configure.swift |
| No rate limiting | MEDIUM | All endpoints |
| Large view files (4 files >480 lines) | LOW | ChatView, ServerSetupSheet, SettingsViewSections, TunnelSettingsView |
| AnyCodable @unchecked Sendable | LOW | StreamMessage.swift |
| SQLite in repo root | LOW | ils.sqlite |
| Manual JSON parsing in executor | LOW | ClaudeExecutorService |
| Duplicate APIResponse types | LOW | ILSShared + APIClient |

---

## 3. ClaudeCodeSDK & Streaming (from claude-sdk-research.md)

### SDK Status: REMOVED (Correct Decision)

The ClaudeCodeSDK (jamesrochabrun fork at krzemienski/ClaudeCodeSDK) is **fundamentally broken in Vapor/NIO** due to `FileHandle.readabilityHandler` requiring RunLoop that NIO doesn't pump. Our direct `Process` + `DispatchQueue` approach is the correct solution.

### Streaming Architecture: SOUND

Current implementation is production-proven:
- Backend: `Process` with blocking reads on dedicated `DispatchQueue` → `AsyncThrowingStream`
- Transport: SSE over HTTP (event IDs, reconnection with exponential backoff)
- Client: `URLSession.bytes` → 75ms batched updates → SwiftUI

### Recommended Improvements (Prioritized)

| Priority | Improvement | Effort | Benefit |
|----------|-------------|--------|---------|
| P1 | Clean up SDK remnants from Package.resolved | Low | Remove dead references |
| P2 | Add heartbeat/keepalive to SSE | Low | Detect stale connections |
| P2 | Structured error types in StreamMessage | Low | Better error handling |
| P3 | Migrate to swift-subprocess (Swift 6.1+) | Medium | Native AsyncSequence, structured cancellation |
| P4 | WebSocket upgrade for bidirectional chat | Medium | Cancel without separate HTTP endpoint |

### Alternative SDKs Evaluated

| SDK | Verdict | Reason |
|-----|---------|--------|
| ClaudeCodeSDK (jamesrochabrun) | **Do not use** | RunLoop/NIO incompatible |
| ClaudeCodeSwiftSDK (AruneshSingh) | **Evaluate only** | Uses AsyncThrowingStream but untested in NIO |
| swift-subprocess (swiftlang) | **Future migration** | Official, requires Swift 6.1+ (we have 6.2.4!) |
| PythonKit bridging | **Do not pursue** | GIL + NIO = performance disaster |

---

## 4. Workspace Unification (from workspace-unification-research.md)

### Current State: 90% Done

- `ILSFullStack.xcworkspace` already exists with iOS project + backend source references
- `ILSShared` already shared correctly via local SPM reference (Apple WWDC22 pattern)
- Backend builds via `swift run` or auto-generated Xcode scheme
- iOS app builds via `xcodebuild -project ILSApp/ILSApp.xcodeproj`

### What's Missing (Minimal)

1. **Workspace-level shared schemes** (3 schemes: iOS, Backend, Full Stack)
2. **Custom working directory** in backend scheme (so Vapor finds DB, .env)
3. **Environment variable** (`PORT=9090`) in backend scheme
4. **Better workspace navigator organization** (Backend, Shared, Tests groups)

### Recommended Approach: Enhanced Manual Workspace (NOT XcodeGen/Tuist)

| Approach | Effort | Risk | Recommendation |
|----------|--------|------|----------------|
| Enhanced Manual Workspace | Low (1-2hr) | None | **RECOMMENDED** |
| XcodeGen | Medium (4-6hr) | Medium | Overkill for 2 targets |
| Tuist | High (8-12hr) | High | Way overkill |
| Pure SPM | Not feasible | — | SPM can't produce .app bundles |

### Scheme Strategy

| Scheme | Builds | Destination | Use |
|--------|--------|-------------|-----|
| ILSApp | iOS app + ILSShared | Simulator | Frontend dev |
| ILSBackend | Server + ILSShared | My Mac | Backend dev |
| ILSFullStack | Both (pre-action) | Simulator | Integration |

---

## 5. Tools & Skills Inventory (from tools-inventory.md)

### Available MCP Servers: 16

| Server | Tools | Key Capability |
|--------|-------|---------------|
| XClaude | 17 | Xcode build, simulator, IDB UI automation |
| OMC Tools | 22 | LSP, AST grep, Python REPL, state/notepad/memory |
| Codex | 5 | OpenAI GPT-5.2 for architecture/planning/review |
| Gemini | 5 | Google Gemini 3 Pro for design/writing (1M context) |
| Claude Memory | 3 | 3-layer memory search |
| Context7 | 2 | Up-to-date library documentation |
| DeepWiki | 3 | AI-powered GitHub repo docs |
| Firecrawl | 8 | Web scraping/crawling/extraction |
| Tavily | 5 | Web search/research |
| Repomix | 8 | Codebase packaging for AI analysis |
| Sequential Thinking | 1 | Dynamic problem-solving |
| Stitch | 6 | UI design generation |
| Vercel | 12 | Deployment/hosting |
| Cloudflare | 20 | Edge infrastructure |
| Mermaid Chart | 4 | Diagram rendering |
| GoDaddy | 2 | Domain management |
| **Total** | **~160+** | |

### Key CLI Tools Installed

- **XcodeGen** (2.44.1), **Tuist** (4.134.0) — workspace generation
- **Periphery** — dead code detection (should use in audit)
- **SwiftFormat**, **SwiftLint** — code formatting/linting
- **fb-idb** (1.1.7) — iOS simulator automation
- **gh** (2.86.0) — GitHub CLI
- **Swift 6.2.4**, **Xcode 26.3** — latest toolchain
- **cloudflared** — Cloudflare tunnel CLI

### Key Axiom Skills Available

- `ios-build` — Build diagnostics and fixes
- `ios-ui` — SwiftUI patterns and iOS 26 Liquid Glass
- `ios-concurrency` — Swift 6 concurrency auditing
- `ios-performance` — Performance profiling
- Plus 30+ specialized auditors (accessibility, memory, energy, networking, etc.)

---

## 6. Recommendations for Alpha Spec

### What Alpha Should Deliver

Based on all research, the alpha spec should focus on three workstreams:

#### Workstream 1: Workspace Unification & Cleanup (P0, 1-2 hours)
- Set up workspace-level shared schemes (ILSApp, ILSBackend, ILSFullStack)
- Configure backend scheme with custom working directory + PORT=9090
- Clean up workspace navigator (Backend/Shared/Tests groups)
- Remove ClaudeCodeSDK from Package.resolved
- Add ils.sqlite to .gitignore

#### Workstream 2: E2E Chat Validation (P0, 4-6 hours)
- Validate all 10 chat scenarios from polish-again spec (CS1-CS10):
  - Basic send/receive, streaming cancellation, tool call rendering
  - Error recovery, fork+navigate, rapid-fire, theme switching during chat
  - Long message with code blocks, external session browsing, session rename+export
- Screenshot evidence for every scenario
- Fix any bugs found during validation

#### Workstream 3: Streaming Improvements (P1, 2-4 hours)
- Add SSE heartbeat/keepalive
- Evaluate swift-subprocess migration (we have Swift 6.2.4!)
- Clean up SDK remnants
- Structured error types in streaming pipeline

#### Workstream 4: Stub Cleanup (P1, 2-3 hours)
- Fix top 3 critical stubs: Extended Thinking toggle, Co-Author toggle, Config History restore
- Mark unimplemented features as "Coming Soon" with clear UI indicators
- Remove or hide non-functional SSH/Fleet/Config views

#### Workstream 5: Code Quality (P2, 1-2 hours)
- Run Periphery for dead code detection
- Split large files (ChatView 555L, ServerSetupSheet 518L, SettingsViewSections 594L)
- Fix duplicate APIResponse types
- Run SwiftLint pass

### What Alpha Should NOT Include

- Agent Teams feature (separate spec, 38 tasks)
- App Store preparation (future spec)
- SSH remote management (low priority)
- iCloud sync (not designed yet)
- Full Tuist/XcodeGen migration (overkill)

---

## Appendix: Research Artifacts

| File | Lines | Content |
|------|-------|---------|
| `gap-analysis.md` | 330 | Detailed per-spec status, gaps, recommendations |
| `tools-inventory.md` | 573 | Complete MCP/skills/tools/packages inventory |
| `claude-sdk-research.md` | 539 | SDK analysis, streaming architecture, alternatives |
| `workspace-unification-research.md` | 493 | Workspace approaches, recommended plan, examples |
| `codebase-audit.md` | 418 | Architecture, file inventory, API catalog, tech debt |
