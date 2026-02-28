# Milestone Context: v5.0

## Name
v5.0 — Cross-Platform Feature Completion & 30-Gate Audit

## Scope Decision
**Features + Full Audit** — Implement all new features AND run full 30-gate validation framework.
**v4.1 merged** — macOS feature parity scope (from cancelled v4.1) folded into v5.0.

## Goals

### Implementation Streams (5 parallel)

**Stream 1: Navigation & Layout**
- Home screen sidebar (hamburger on iPhone, persistent on iPad)
- Session detail navigation (back button iPhone, sidebar iPad)
- Quick actions above recent sessions on home screen
- Home recent sessions match dedicated Sessions screen data

**Stream 2: Settings & Configuration Inheritance**
- Config flow traceability: CLI → backend → mobile
- "Inherited from host" vs "Custom override" visual distinction
- System prompt inherited from host CLI
- Model defaults to host CLI value (not hardcoded Sonic)
- Tool controls with info tooltips (≥20 words)
- Permissions show inherited defaults + override capability
- Info explanations for: Continue Previous Session, Stable Section Persistence, Debug Mode
- Descriptions for: Agent, Data Flags, Input Format

**Stream 3: Skills, Plugins, Hooks & Theming**
- MCP server backend returns proper data
- Skills screen excludes node_modules entries (KNOWN OPEN ISSUE)
- Active/inactive status indicators for skills/plugins
- GitHub browsing for skills with install capability (NEW FEATURE)
- GitHub browsing for plugins with install capability (NEW FEATURE)
- Hooks management screen (NEW FEATURE)
- Default themes available and functional

**Stream 4: System Monitor + Profiles**
- System monitor shows real-time metrics over SSH
- "Fleet" → "Host/Backend Profiles" throughout codebase (KNOWN OPEN ISSUE, 6 files)
- Profile switching changes settings context

**Stream 5: Backend API Audit**
- All API endpoints return expected structures
- Config endpoint exposes CLI host defaults
- MCP servers registered in backend
- Error handling returns proper HTTP codes (not 200-with-error)

### macOS Feature Parity (from v4.1)
- All iOS features accessible on macOS
- NavigationSplitView correct on Mac
- Keyboard shortcuts, menu bar, window resizing
- macOS-specific UX patterns

### Validation Stages (3 sequential after implementation)

**Platform Validation**
- iPhone 16 Pro Max visual audit (~50 screens)
- iPad Pro 13" visual audit (sidebar, split view, orientations)
- Mac visual audit (window, menu, keyboard)
- Cross-platform regression report

**Functional Audit**
- All functional areas verified end-to-end across all platforms
- Before/after evidence for every fix

**Bug Hunt**
- Edge cases: empty states, long text, special characters, offline
- Accessibility: VoiceOver navigation, Dynamic Type scaling
- Memory pressure, background/foreground cycling
- ≥20 edge case scenarios tested

## 30-Gate Framework
The full 30-gate validation framework is defined in the orchestration prompt.
Gates: VG-01 through VG-30-FINAL
Stages: Discovery → Research → Implementation (5 streams) → Platform Validation → Functional → Bug Hunt → Final

## Known Open Issues (carry forward)
1. "Fleet" terminology in 6 Swift files (API endpoints, type names, routing)
2. node_modules scanning in SkillsFileService.swift
3. 3 LOW-priority bugs from v4.0 deferred list

## Process Constraints
- Model enforcement: All sub-agents use claude-opus-4-6
- No mocks/tests: Functional validation only (Iron Rule)
- iOS Validation Runner: SETUP→RECORD→ACT→COLLECT→VERIFY for every iOS gate
- FIX_PROTOCOL: Every fix through skill invocation → implement → evidence
- Skills must be inventoried (VG-01) before any implementation
- Evidence directory: evidence/ (organized by phase/stream)

## Phase Numbering
Continues from Phase 48 (v4.0 final phase). v5.0 starts at Phase 49.

---
*Captured: 2026-02-27 from user's orchestration prompt + scope decisions*
