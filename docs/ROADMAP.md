# ILS iOS/macOS — Master Roadmap (20+ Days)

> Generated 2026-02-15 from 18 parallel research agents covering every dimension of the project.
> Total findings: **400+ actionable items** across security, performance, UX, architecture, and business.

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total estimated work | **58 engineering days** |
| Critical blockers | 4 areas (security, memory, energy, performance) |
| High-impact quick wins | 12 items (< 2 hours each) |
| Revenue opportunity | $12.5K-40K/year (subscription model) |
| Swift 6 readiness | 95% (6 minor issues) |
| Test coverage | ~0% unit, ~30% UI |

---

## Phase 0: Critical Fixes (Days 1-3)
*Ship-blocking issues that affect stability, security, and battery life*

### Day 1: Memory & Energy Fixes (8 items, ~4 hours)

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| 0.1 | Add `deinit` to MetricsWebSocketClient (cancel tasks + WebSocket) | `MetricsWebSocketClient.swift` | 15 min | HIGH - prevents connection accumulation |
| 0.2 | Add `deinit` to TeamsViewModel (invalidate timer) | `TeamsViewModel.swift` | 5 min | HIGH - prevents timer leak |
| 0.3 | Add `deinit` to FleetViewModel (invalidate timer) | `FleetViewModel.swift` | 5 min | HIGH - prevents timer leak |
| 0.4 | Add `deinit` to PollingManager (cancel tasks) | `PollingManager.swift` | 5 min | MEDIUM - cleanup |
| 0.5 | Add `deinit` to SSEClient (cancel stream + invalidate session) | `SSEClient.swift` | 10 min | MEDIUM - cleanup |
| 0.6 | Fix animation leak in StreamingIndicatorView (add scenePhase) | `StreamingIndicatorView.swift` | 10 min | HIGH - 2-3% battery |
| 0.7 | Fix animation leak in ThinkingSection (add scenePhase) | `ThinkingSection.swift` | 10 min | HIGH - 1-2% battery |
| 0.8 | Fix animation leak in SystemMonitorView (add scenePhase) | `SystemMonitorView.swift` | 10 min | HIGH - 1-2% battery |

### Day 2: Performance Quick Wins (6 items, ~3 hours)

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| 0.9 | Add database indexes (sessions, projects, skills) | Backend migrations | 1 hr | CRITICAL - 50-100x query speedup |
| 0.10 | Add search cache to SessionsViewModel (22K sessions) | `SessionsViewModel.swift` | 45 min | HIGH - O(n) → O(1) on re-render |
| 0.11 | Add search cache to MCPViewModel | `MCPViewModel.swift` | 30 min | MEDIUM |
| 0.12 | Cache grouped sessions computation | `SessionsViewModel.swift` | 30 min | MEDIUM |
| 0.13 | Move MessageView formatters to DateFormatters.swift | `MessageView.swift`, `DateFormatters.swift` | 15 min | MEDIUM |
| 0.14 | Add response compression (gzip) to backend | Backend middleware | 30 min | HIGH - 6-10x payload reduction |

### Day 3: Concurrency & Network Hardening (6 items, ~2 hours)

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| 0.15 | Replace 3x DispatchQueue.main.asyncAfter with Task.sleep | `ToastModifier`, `MessageView`, `CodeBlockView` | 20 min | LOW |
| 0.16 | Add timer tolerance to TeamsViewModel (33%) | `TeamsViewModel.swift` | 5 min | MEDIUM - battery |
| 0.17 | Add URLSession cellular constraints (allowsConstrainedNetworkAccess) | `APIClient.swift`, `SSEClient.swift` | 10 min | MEDIUM - Low Data Mode |
| 0.18 | Increase polling interval (PollingManager retry: 5s→exponential backoff) | `PollingManager.swift` | 15 min | MEDIUM - battery |
| 0.19 | Add `defer` cleanup for Process/Pipe in ClaudeExecutorService | `ClaudeExecutorService.swift` | 30 min | HIGH - fd leak prevention |
| 0.20 | Increase MetricsWebSocket fallback polling (5s→15s) | `MetricsWebSocketClient.swift` | 5 min | MEDIUM - battery |

**Phase 0 Deliverable:** Stable, leak-free, battery-efficient app.

---

## Phase 1: Security Hardening (Days 4-8)
*Backend security from zero to production-ready*

### Day 4-5: Authentication & Authorization

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1.1 | Implement API key authentication middleware | 1 day | CRITICAL - currently zero auth |
| 1.2 | Add per-route authorization (admin vs user) | 0.5 day | HIGH |
| 1.3 | Migrate sensitive data from UserDefaults to Keychain | 0.5 day | HIGH - credentials in plaintext |

### Day 6: Input Validation & Injection Prevention

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1.4 | Fix path traversal in SessionFileService (sanitize file paths) | 2 hrs | CRITICAL |
| 1.5 | Add input validation to all controller endpoints | 4 hrs | HIGH |
| 1.6 | Restrict CORS to specific origins | 1 hr | HIGH |

### Day 7: Rate Limiting & Protection

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1.7 | Add rate limiting middleware (per-IP, per-route) | 4 hrs | HIGH |
| 1.8 | Add request size limits | 1 hr | MEDIUM |
| 1.9 | Add certificate pinning for production | 2 hrs | MEDIUM |

### Day 8: Privacy & Compliance

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1.10 | Populate Privacy Manifest (PrivacyInfo.xcprivacy) | 2 hrs | HIGH - App Store requirement |
| 1.11 | Add data deletion capability (GDPR/CCPA) | 4 hrs | HIGH |
| 1.12 | Add screenshot protection for sensitive screens | 1 hr | MEDIUM |

**Phase 1 Deliverable:** Secure API with auth, validation, rate limiting, and privacy compliance.

---

## Phase 2: @Observable Migration & SwiftUI Modernization (Days 9-12)
*iOS 17+ architecture upgrade for 15-30% performance improvement*

### Day 9-10: ViewModel Migration

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 2.1 | Migrate ChatViewModel to @Observable | 2 hrs | HIGH - most complex VM |
| 2.2 | Migrate SessionsViewModel to @Observable | 1 hr | HIGH |
| 2.3 | Migrate remaining 13 ViewModels | 4 hrs | HIGH - batch migration |
| 2.4 | Update all @StateObject → @State references | 2 hrs | Required by migration |
| 2.5 | Update all @EnvironmentObject → @Environment | 2 hrs | Required by migration |
| 2.6 | Update all @ObservedObject → @Bindable (or remove) | 1 hr | Required by migration |

### Day 11: SwiftUI Layout Modernization

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 2.7 | Add `.equatable()` to complex views (ChatView, BrowserView) | 2 hrs | MEDIUM - reduce re-renders |
| 2.8 | Fix ForEach identity (TextSegment enum, SSHSetupView) | 1 hr | MEDIUM |
| 2.9 | Add `drawingGroup()` to shadow-heavy views | 1 hr | MEDIUM - GPU optimization |
| 2.10 | Async file import in ThemesListView | 20 min | LOW |

### Day 12: TipKit Onboarding

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 2.11 | Add TipKit framework and configure | 1 hr | Setup |
| 2.12 | Create tips: Server Setup, Create Session, Command Palette | 3 hrs | HIGH - user onboarding |
| 2.13 | Create tips: Theme selection, MCP servers, Teams | 2 hrs | MEDIUM |
| 2.14 | Add tip rules (show after N app opens, sequential tips) | 1 hr | Polish |

**Phase 2 Deliverable:** Modern SwiftUI architecture with @Observable, better performance, guided onboarding.

---

## Phase 3: Backend API Completion (Days 13-17)
*Fill the 40+ endpoint gaps and add missing CRUD operations*

### Day 13-14: Missing Endpoints

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 3.1 | Sessions: PATCH rename, DELETE, bulk operations | 4 hrs | HIGH |
| 3.2 | Projects: Full CRUD (currently read-only from filesystem) | 4 hrs | HIGH |
| 3.3 | Skills: Search, filter by category, CRUD | 4 hrs | MEDIUM |
| 3.4 | MCP: Server health checks, restart, logs | 4 hrs | HIGH |

### Day 15: Chat Enhancements

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 3.5 | Message search across sessions | 4 hrs | HIGH |
| 3.6 | Session forking (duplicate with history) | 2 hrs | MEDIUM |
| 3.7 | Chat export (JSON, Markdown, PDF) | 4 hrs | HIGH - monetizable |

### Day 16: System & Monitoring

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 3.8 | Structured logging with log levels | 4 hrs | HIGH |
| 3.9 | Request/response logging middleware | 2 hrs | MEDIUM |
| 3.10 | Health check detail (DB, filesystem, Claude CLI) | 2 hrs | MEDIUM |

### Day 17: API Polish

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 3.11 | Pagination for all list endpoints | 4 hrs | HIGH - 22K sessions |
| 3.12 | Consistent error response format | 2 hrs | MEDIUM |
| 3.13 | API versioning strategy (v1 → v2 path) | 2 hrs | MEDIUM |

**Phase 3 Deliverable:** Complete, well-documented API with all CRUD operations, search, export, and pagination.

---

## Phase 4: Offline & Caching (Days 18-21)
*Make the app useful without constant network connectivity*

### Day 18-19: Local Database Layer

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4.1 | Add GRDB/SQLite local database | 4 hrs | Foundation |
| 4.2 | Cache sessions on successful load | 2 hrs | HIGH |
| 4.3 | Cache last 50 messages per session | 2 hrs | HIGH |
| 4.4 | Cache projects, skills, MCP servers, plugins | 3 hrs | MEDIUM |
| 4.5 | Implement cache-first loading pattern | 3 hrs | HIGH - instant UI |

### Day 20: Offline UX

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4.6 | Activate `AppState.isOffline` flag properly | 1 hr | Foundation |
| 4.7 | Show cached data with "Last updated X ago" indicator | 2 hrs | HIGH |
| 4.8 | Implement message draft queue (compose offline) | 4 hrs | HIGH |
| 4.9 | Add offline indicators throughout the app | 2 hrs | MEDIUM |

### Day 21: Sync Coordinator

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4.10 | Build SyncCoordinator service | 4 hrs | Foundation |
| 4.11 | Queue management (exponential backoff, max retries) | 2 hrs | MEDIUM |
| 4.12 | Auto-drain queue on reconnection | 2 hrs | HIGH |

**Phase 4 Deliverable:** App works offline with cached data, queued messages, and automatic sync on reconnect.

---

## Phase 5: Testing Infrastructure (Days 22-26)
*From 0% to 70% unit test coverage*

### Day 22-23: Model & API Client Tests

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5.1 | Replace placeholder tests in ILSSharedTests | 2 hrs | Foundation |
| 5.2 | Add Codable conformance tests for all 14 models | 4 hrs | HIGH |
| 5.3 | Add APIClient unit tests (mock URLSession) | 6 hrs | CRITICAL |
| 5.4 | Add edge case tests (empty arrays, null fields, timestamps) | 2 hrs | MEDIUM |

### Day 24: ViewModel Tests

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5.5 | ChatViewModel logic tests (batching, state transitions) | 6 hrs | CRITICAL |
| 5.6 | SessionsViewModel tests (filtering, grouping) | 3 hrs | HIGH |
| 5.7 | SSEClient connection tests (reconnection, timeout) | 4 hrs | HIGH |

### Day 25-26: Backend Integration Tests

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5.8 | Setup XCTVapor test harness | 2 hrs | Foundation |
| 5.9 | Sessions controller integration tests | 4 hrs | HIGH |
| 5.10 | Chat controller integration tests | 4 hrs | HIGH |
| 5.11 | Add GitHub Actions CI (build + test on push) | 4 hrs | HIGH |
| 5.12 | Error scenario tests (network failures, malformed data) | 3 hrs | MEDIUM |

**Phase 5 Deliverable:** 70% unit coverage, backend integration tests, CI pipeline.

---

## Phase 6: iOS 18+ Features (Days 27-32)
*Modern platform features for competitive advantage*

### Day 27-28: Interactive Widgets

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6.1 | Create ILSWidgetExtension target | 2 hrs | Foundation |
| 6.2 | Session Quick-Access widget (recent sessions) | 4 hrs | HIGH |
| 6.3 | Server Status widget (connection, counts) | 3 hrs | MEDIUM |
| 6.4 | Widget configuration and intents | 3 hrs | Required |

### Day 29-30: Live Activities

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6.5 | Create ILSLiveActivity attributes | 2 hrs | Foundation |
| 6.6 | Lock screen widget (streaming status, token count) | 4 hrs | HIGH |
| 6.7 | Dynamic Island compact/expanded views | 4 hrs | HIGH |
| 6.8 | Integrate with ChatViewModel SSE streaming | 3 hrs | Required |

### Day 31-32: App Intents & Shortcuts

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6.9 | SendMessageIntent (send to session via Shortcuts) | 3 hrs | MEDIUM |
| 6.10 | CreateSessionIntent (create via Siri) | 2 hrs | MEDIUM |
| 6.11 | GetSessionInfoIntent (query session status) | 2 hrs | LOW |
| 6.12 | SessionOptionsProvider for discoverable sessions | 2 hrs | Required |

**Phase 6 Deliverable:** Home screen widgets, lock screen Live Activities, Siri/Shortcuts integration.

---

## Phase 7: Accessibility & Localization (Days 33-36)
*App Store readiness and global reach*

### Day 33: Accessibility Fixes

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7.1 | Replace 412 hard-coded font sizes with Dynamic Type | 6 hrs | HIGH - App Store |
| 7.2 | Add reduceMotion checks to 18 animations | 2 hrs | MEDIUM |
| 7.3 | Fix touch targets (minimum 44x44 points) | 1 hr | MEDIUM |
| 7.4 | Add VoiceOver hints to interactive elements | 2 hrs | MEDIUM |

### Day 34-36: Localization

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7.5 | Extract 880+ hardcoded strings to Localizable.strings | 8 hrs | HIGH |
| 7.6 | Add String Catalog (.xcstrings) support | 2 hrs | Foundation |
| 7.7 | Localize to Spanish, German, Japanese (top markets) | 6 hrs | MEDIUM |
| 7.8 | RTL layout support (Arabic) | 4 hrs | LOW |

**Phase 7 Deliverable:** Dynamic Type, full VoiceOver, 4 languages.

---

## Phase 8: macOS Feature Parity (Days 37-41)
*Make the Mac app a first-class citizen*

### Day 37-38: Core Mac Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 8.1 | Spotlight integration (index sessions, projects) | 4 hrs | HIGH |
| 8.2 | Drag-and-drop (files into chat, sessions reorder) | 4 hrs | HIGH |
| 8.3 | Menu bar commands (File, Edit, View, Session menus) | 4 hrs | HIGH |
| 8.4 | Inspector panel (session details in sidebar) | 4 hrs | MEDIUM |

### Day 39-40: Mac-Specific Polish

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 8.5 | Handoff support (continue session iOS ↔ Mac) | 6 hrs | HIGH |
| 8.6 | AppleScript/Automator support | 4 hrs | MEDIUM |
| 8.7 | Share Extension (share text/code to ILS) | 4 hrs | MEDIUM |

### Day 41: Mac UX Polish

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 8.8 | Keyboard shortcuts for all actions (beyond existing 16) | 3 hrs | HIGH |
| 8.9 | Context menus throughout | 2 hrs | MEDIUM |
| 8.10 | Stage Manager / window management optimization | 2 hrs | LOW |

**Phase 8 Deliverable:** Mac app with Spotlight, drag-drop, Handoff, menus, and keyboard shortcuts.

---

## Phase 9: CI/CD & DevOps (Days 42-44)
*Automated quality gates and deployment pipeline*

### Day 42: Build Pipeline

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9.1 | GitHub Actions: iOS build + test on PR | 4 hrs | HIGH |
| 9.2 | GitHub Actions: macOS build + test on PR | 2 hrs | HIGH |
| 9.3 | GitHub Actions: Backend build + test on PR | 2 hrs | HIGH |

### Day 43: Quality Gates

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9.4 | SwiftLint enforcement (lint on PR) | 2 hrs | MEDIUM |
| 9.5 | Security scanning (dependency audit) | 2 hrs | HIGH |
| 9.6 | Code coverage reporting | 2 hrs | MEDIUM |

### Day 44: Deployment

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9.7 | Fastlane setup (iOS code signing, TestFlight upload) | 4 hrs | HIGH |
| 9.8 | Automated App Store screenshot generation | 3 hrs | MEDIUM |
| 9.9 | Backend container registry (Docker) | 2 hrs | MEDIUM |

**Phase 9 Deliverable:** Fully automated CI/CD with build, test, lint, security scan, and TestFlight deployment.

---

## Phase 10: Monetization (Days 45-50)
*Revenue generation through premium features*

### Day 45-46: StoreKit Integration

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10.1 | App Store Connect product setup (subscription) | 2 hrs | Foundation |
| 10.2 | StoreKit 2 configuration file (.storekit) | 2 hrs | Foundation |
| 10.3 | SubscriptionManager class (purchase, restore, verify) | 6 hrs | CRITICAL |
| 10.4 | Feature gating system (free vs premium checks) | 4 hrs | CRITICAL |

### Day 47-48: Premium Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10.5 | Chat export (JSON, Markdown, PDF) — premium gate | 6 hrs | HIGH |
| 10.6 | Custom theme creator — premium gate | 6 hrs | HIGH |
| 10.7 | Advanced system monitoring (graphs, alerts) — premium gate | 4 hrs | MEDIUM |

### Day 49-50: Subscription UX

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10.8 | PremiumView / paywall screen | 4 hrs | HIGH |
| 10.9 | Settings integration (manage subscription) | 2 hrs | Required |
| 10.10 | 7-day free trial flow | 2 hrs | HIGH - conversion |
| 10.11 | Restore purchases flow | 1 hr | Required - App Store |
| 10.12 | Receipt validation | 3 hrs | Required - fraud prevention |

**Phase 10 Deliverable:** $4.99/month or $49.99/year subscription with premium features.

---

## Phase 11: Plugin & Theme Ecosystem (Days 51-54)
*Community-driven extensibility*

### Day 51-52: Plugin Management

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11.1 | Plugin configuration UI (enable/disable, settings) | 4 hrs | HIGH |
| 11.2 | Plugin versioning and update checks | 4 hrs | MEDIUM |
| 11.3 | Plugin dependency management | 4 hrs | MEDIUM |

### Day 53-54: Theme Marketplace

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11.4 | Theme import/export (JSON format standardized) | 3 hrs | HIGH |
| 11.5 | Community theme browser (curated list or API) | 4 hrs | MEDIUM |
| 11.6 | Theme preview before install | 2 hrs | MEDIUM |
| 11.7 | MeshGradient themes (iOS 18+ visual upgrade) | 3 hrs | LOW - polish |

**Phase 11 Deliverable:** Plugin management UI and theme marketplace.

---

## Phase 12: Shared Models & Architecture (Days 55-56)
*Technical debt reduction*

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 12.1 | Add Hashable conformance to 7 models | 1 hr | MEDIUM |
| 12.2 | Fix port defaults 9090→9999 in shared package | 30 min | LOW |
| 12.3 | Convert 5 String fields to proper enums | 2 hrs | MEDIUM |
| 12.4 | Add computed properties for common derivations | 1 hr | LOW |
| 12.5 | Add input validation to model initializers | 2 hrs | MEDIUM |
| 12.6 | Document all public APIs in ILSShared | 2 hrs | LOW |

**Phase 12 Deliverable:** Clean, well-documented shared models.

---

## Phase 13: UX Polish (Days 57-58)
*Final touches for App Store quality*

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 13.1 | Empty states for all list views (sessions, projects, skills) | 3 hrs | HIGH |
| 13.2 | Skeleton loading screens (shimmer effect) | 3 hrs | MEDIUM |
| 13.3 | Pull-to-refresh on all list views | 2 hrs | MEDIUM |
| 13.4 | Deep link handling in code (ils:// URL scheme) | 3 hrs | MEDIUM |
| 13.5 | iPad adaptive layouts (sidebar + detail) | 4 hrs | MEDIUM |
| 13.6 | Haptic feedback on key interactions | 1 hr | LOW |

**Phase 13 Deliverable:** Polished, delightful user experience.

---

## Summary: 58 Days, 13 Phases

| Phase | Days | Theme | Key Deliverable |
|-------|------|-------|-----------------|
| **0** | 1-3 | Critical Fixes | Stable, leak-free, battery-efficient |
| **1** | 4-8 | Security | Auth, validation, rate limiting, privacy |
| **2** | 9-12 | Modernization | @Observable, TipKit, SwiftUI upgrades |
| **3** | 13-17 | Backend API | Complete CRUD, search, export, pagination |
| **4** | 18-21 | Offline/Caching | Local DB, cache-first, draft queue, sync |
| **5** | 22-26 | Testing | 70% coverage, integration tests, CI |
| **6** | 27-32 | iOS 18+ Features | Widgets, Live Activities, App Intents |
| **7** | 33-36 | Accessibility/i18n | Dynamic Type, VoiceOver, 4 languages |
| **8** | 37-41 | macOS Parity | Spotlight, drag-drop, Handoff, menus |
| **9** | 42-44 | CI/CD | Automated build, test, deploy pipeline |
| **10** | 45-50 | Monetization | StoreKit 2 subscription, premium features |
| **11** | 51-54 | Plugin Ecosystem | Plugin mgmt, theme marketplace |
| **12** | 55-56 | Architecture | Shared model cleanup, tech debt |
| **13** | 57-58 | UX Polish | Empty states, loading, deep links, iPad |

---

## Quick Win Leaderboard (Do These First)

These items provide the highest impact for the least effort:

| Rank | Item | Effort | Impact | Phase |
|------|------|--------|--------|-------|
| 1 | Add DB indexes | 1 hr | 50-100x query speed | 0 |
| 2 | Add deinit to 5 classes | 30 min | Fix all memory leaks | 0 |
| 3 | Fix 3 animation leaks (scenePhase) | 30 min | 4-7% battery savings | 0 |
| 4 | Add response compression | 30 min | 6-10x payload reduction | 0 |
| 5 | Fix path traversal | 2 hrs | Eliminate security vuln | 1 |
| 6 | Add search caches (Sessions/MCP) | 1.5 hrs | Smooth scrolling | 0 |
| 7 | Restrict CORS | 1 hr | Security hardening | 1 |
| 8 | Add timer tolerance | 5 min | Battery optimization | 0 |
| 9 | Add URLSession constraints | 10 min | Low Data Mode support | 0 |
| 10 | Replace DispatchQueue.main → Task.sleep | 20 min | Swift 6 ready | 0 |
| 11 | Populate Privacy Manifest | 2 hrs | App Store requirement | 1 |
| 12 | Fix port defaults 9090→9999 | 5 min | Correctness | 12 |

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| @Observable migration breaks views | Medium | HIGH | Incremental migration, build after each VM |
| Security fixes introduce regressions | Low | HIGH | Integration tests before/after |
| StoreKit 2 App Store review rejection | Low | MEDIUM | Follow Apple guidelines strictly |
| Offline cache grows unbounded | Medium | MEDIUM | TTL + LRU eviction |
| CI/CD pipeline flaky on macOS runners | Medium | LOW | Use self-hosted runner |
| Localization string extraction errors | Low | LOW | Use Xcode String Catalog |

---

## Research Areas Not Yet Covered

These were from agents that didn't complete in the previous session. They are lower priority but could add additional work items:

- **Competitive Landscape**: How do other Claude/AI coding apps position themselves?
- **Claude Code API Evolution**: What new Claude CLI features are coming?
- **App Store Requirements**: Latest App Store Review Guidelines changes
- **Team/Collaboration Features**: Multi-user collaboration patterns

---

## Recommended Execution Order

**For a solo developer (1 engineer):**
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 5 → Phase 4 → Phase 7 → Phase 9 → Phase 6 → Phase 10

**For a 2-person team:**
- Engineer A: Phase 0 → Phase 1 → Phase 3 → Phase 5 → Phase 9
- Engineer B: Phase 2 → Phase 4 → Phase 6 → Phase 7 → Phase 10

**For rapid MVP iteration:**
Phase 0 → Phase 2 (skip TipKit) → Phase 3 (core endpoints only) → Phase 10 → Ship to TestFlight

---

*This roadmap was generated from 18 parallel research agents analyzing: iOS UX, Backend API, macOS parity, shared models, security/privacy, performance, CI/CD, plugin ecosystem, accessibility, modernization, test coverage, iOS 18/19 APIs, offline/sync, monetization, SwiftUI performance, concurrency, energy efficiency, and memory leaks.*
