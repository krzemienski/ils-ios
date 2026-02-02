# ILS Implementation Plan - Gap Analysis

## Executive Summary

**Original Specifications:** ~175KB (5,231 lines)
- `ils.md`: 4,452 lines - Complete orchestration spec with ALL Swift code
- `ils-spec.md`: 779 lines - Complete UI/API/data model specifications

**Current Output:** ~100KB (2,830 lines)
- `plan.md`: 1,720 lines
- `detailed-design.md`: 1,110 lines

**Gap:** ~75KB (~2,400 lines) of missing content

---

## Critical Missing Elements

### 1. Complete Swift Code (Missing ~3,500 lines)

The original `ils.md` contains complete, copy-paste-ready Swift code for EVERY file:

| File | Lines | Status |
|------|-------|--------|
| ServerConnection.swift | ~50 | ❌ Missing |
| MCPServer.swift | ~80 | ❌ Missing |
| Skill.swift + SkillParser | ~100 | ❌ Missing |
| Plugin.swift + Marketplace | ~150 | ❌ Missing |
| ClaudeConfig.swift | ~100 | ❌ Missing |
| APIResponse.swift | ~100 | ❌ Missing |
| SearchResult.swift | ~100 | ❌ Missing |
| entrypoint.swift | ~30 | ❌ Missing |
| configure.swift | ~40 | ❌ Missing |
| routes.swift | ~40 | ❌ Missing |
| StatsController.swift | ~50 | ❌ Missing |
| SkillsController.swift | ~100 | ❌ Missing |
| MCPController.swift | ~100 | ❌ Missing |
| PluginsController.swift | ~150 | ❌ Missing |
| ConfigController.swift | ~100 | ❌ Missing |
| ILSTheme.swift | ~200 | ❌ Missing |
| ThemePreview.swift | ~150 | ❌ Missing |
| ServerConnectionView.swift | ~250 | ❌ Missing |
| DashboardView.swift | ~200 | ❌ Missing |
| SkillsListView.swift | ~200 | ❌ Missing |
| SkillDetailView.swift | ~150 | ❌ Missing |
| MCPServerListView.swift | ~250 | ❌ Missing |
| PluginMarketplaceView.swift | ~200 | ❌ Missing |
| SettingsEditorView.swift | ~200 | ❌ Missing |
| ILSApp.swift | ~100 | ❌ Missing |
| APIClient.swift | ~150 | ❌ Missing |

### 2. Sub-Agent Orchestration Prompts

Original has explicit sub-agent prompt blocks:

```
<sub_agent_alpha>
You are SUB-AGENT ALPHA responsible for building the Vapor backend.

CRITICAL CONSTRAINTS:
- You may ONLY work on files in Sources/ILSBackend/
- You MUST import and use models from ILSShared - NO duplicating models
- Every file you create MUST compile before you proceed
- You validate via cURL - backend must respond correctly
- Do NOT proceed if compilation fails
- Report evidence for EVERY task

Your tasks are SEQUENTIAL - complete each fully before starting next.
</sub_agent_alpha>
```

**Status:** ❌ Missing from current plan

### 3. Evidence Template Format

Original has exact templates for each task:

```
EVIDENCE_0.1:
- Type: Terminal Output
- Command: `tree ILSApp -d`
- Expected: Directory tree matching specification
- Actual: [PASTE OUTPUT HERE]
- Status: PASS/FAIL
```

**Status:** ❌ Missing from current plan (20+ templates needed)

### 4. Validation Gate Checklists

Original has explicit gate checks with pass/fail matrices:

```
GATE_CHECK_2A:
- Build Status: PASS/FAIL
- Health Endpoint: PASS/FAIL
- Stats Endpoint: PASS/FAIL
- Skills Endpoint: PASS/FAIL
- MCP Endpoint: PASS/FAIL
- Plugins Endpoint: PASS/FAIL
- Config Endpoint: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

**Status:** ⚠️ Partially present, needs expansion for chat/session functionality

### 5. Orchestration Flow Diagram

Original has ASCII art diagram showing:
- Phase dependencies
- Parallel execution tracks
- Gate check sync points
- Sub-agent assignments

**Status:** ❌ Missing from current plan

### 6. Blocking Dependencies

Original explicitly states after each task:

```
**BLOCKING:** Cannot proceed to 3.2 until screenshot evidence shows PASS
```

**Status:** ❌ Not explicit in current plan

### 7. Failure Recovery Protocol

Original has 6-step protocol:

1. STOP - Do not proceed to next task
2. DIAGNOSE - Read error messages completely
3. FIX - Make targeted corrections
4. RE-VALIDATE - Run the same validation again
5. DOCUMENT - Record what was fixed
6. PROCEED - Only after PASS status confirmed

**Status:** ❌ Missing from current plan

### 8. Complete Evidence Manifest

Original has 20+ item checklist at end:

```
COMPLETE EVIDENCE MANIFEST:

Phase 0 - Environment Setup:
□ evidence_0.1 - Directory tree output
□ evidence_0.2 - Package resolve output
□ evidence_0.3 - Xcode setup screenshot
...
```

**Status:** ❌ Missing from current plan

---

## User's Additional Requirements (New)

The user emphasized validation gates for chat/session functionality:

1. **Chat/session screen gate:** Typing and using slash commands displays expected results
2. **Session management gate:** Creating new session with new project shows all existing system data
3. **Session interaction gate:** Multiple back-and-forth exchanges work correctly

These require NEW validation gates beyond what's in the original spec:

| Gate | Description | Evidence Type |
|------|-------------|---------------|
| GATE_CHAT_1 | Slash command execution | Screenshot + backend log |
| GATE_CHAT_2 | Streaming response display | Screenshot series |
| GATE_CHAT_3 | Tool call/result rendering | Screenshot |
| GATE_SESSION_1 | New session creation | Screenshot + API response |
| GATE_SESSION_2 | Project association | Screenshot showing project data |
| GATE_SESSION_3 | Session resume | Screenshot of history loaded |
| GATE_MULTI_1 | 3+ turn conversation | Screenshot series |
| GATE_MULTI_2 | Context preservation | Verification of continuity |

---

## Design Document Gaps

### Missing UI Screen Specifications

`ils-spec.md` has 7 detailed screen specs with element tables:

| Screen | Elements Defined | Status |
|--------|------------------|--------|
| Server Connection | 8 elements | ❌ Missing |
| Dashboard | 12 elements | ❌ Missing |
| Skills Explorer | 10 elements | ❌ Missing |
| Skill Detail | 8 elements | ❌ Missing |
| MCP Management | 9 elements | ❌ Missing |
| Plugin Marketplace | 11 elements | ❌ Missing |
| Settings Editor | 10 elements | ❌ Missing |

### Missing API Endpoint Details

Need complete request/response JSON examples for all 18+ endpoints.

### Missing Design System Tokens

Need complete tables for:
- 15 color tokens with hex values
- Typography scale (10 levels)
- Spacing scale (6 levels)
- Corner radius specs (4 levels)
- Shadow definitions (3 levels)

### Missing Integration Details

- SSH via Citadel patterns
- GitHub API search patterns
- Claude Code file locations (8 paths)
- File format references (4 formats)

---

## Remediation Plan

### Phase 1: Expand plan.md (~50KB addition)

1. Add system directive and orchestration diagram
2. Add complete Swift code for all 26 files
3. Add sub-agent prompts (Alpha, Beta)
4. Add evidence templates for all 25+ tasks
5. Add gate check matrices for all 5 gates
6. Add blocking dependency statements
7. Add failure recovery protocol
8. Add complete evidence manifest
9. Add new chat/session validation gates

### Phase 2: Expand detailed-design.md (~35KB addition)

1. Add complete UI screen specifications (7 screens)
2. Add complete data model definitions
3. Add API request/response examples (18+ endpoints)
4. Add design system token tables
5. Add integration code patterns
6. Add file format references
7. Add mermaid diagrams (4 types)

---

## Success Criteria

- [ ] Combined plan.md + detailed-design.md exceeds 150KB
- [ ] All Swift code from ils.md included
- [ ] All UI specs from ils-spec.md included
- [ ] Sub-agent orchestration defined
- [ ] 30+ validation gates defined
- [ ] Evidence templates for every task
- [ ] Chat/session-specific gates added per user requirement
