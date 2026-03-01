---
phase: 6-comprehensive-ils-audit
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md
autonomous: true
requirements: [GAP-ANALYSIS]

must_haves:
  truths:
    - "Every requirement from all 3 spec documents is accounted for with a status (PASS/PARTIAL/MISSING/EXCEEDED)"
    - "Every iOS view file is classified and mapped to its spec origin"
    - "Every backend controller and endpoint is verified against spec requirements"
    - "Gap severity is assigned (CRITICAL/HIGH/MEDIUM/LOW) with rationale"
    - "Existing validation evidence is cross-referenced to support pass/fail verdicts"
  artifacts:
    - path: ".planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md"
      provides: "Complete gap analysis matrix with screen registry, backend registry, and gap summary"
      min_lines: 400
  key_links:
    - from: "GAP-ANALYSIS.md"
      to: "specs/ils-complete-rebuild/requirements.md"
      via: "FR-1..FR-42 requirement IDs mapped to codebase files"
      pattern: "FR-\\d+"
    - from: "GAP-ANALYSIS.md"
      to: "specs/rebuild-ground-up/requirements.md"
      via: "US-1..US-19 user story IDs mapped to implementation status"
      pattern: "US-\\d+"
    - from: "GAP-ANALYSIS.md"
      to: ".claude/plan/MASTER_ROADMAP.md"
      via: "Phase 0-13 items mapped to completion status"
      pattern: "Phase \\d+"
---

<objective>
Produce a comprehensive gap analysis document comparing the ILS iOS/macOS codebase against ALL three original build specifications.

Purpose: The project has gone through 41+ phases across 6 milestones. Multiple spec documents exist with overlapping and sometimes contradictory requirements. No single document currently maps every spec requirement to its implementation status. This gap analysis will be the definitive reference for prioritizing future remediation work.

Output: A single `GAP-ANALYSIS.md` document containing:
- Executive summary with pass/fail/partial/exceeded counts
- Screen-by-screen evidence registry (iOS views mapped to spec screens)
- Backend endpoint evidence registry (controllers mapped to spec FR IDs)
- Functional requirement matrix (FR-1..FR-42 from ils-complete-rebuild)
- User story matrix (US-1..US-19 from rebuild-ground-up)
- Master Roadmap item matrix (Phase 0-13, 130+ items)
- Gap summary table sorted by severity
- Recommendations for remediation prioritization
</objective>

<execution_context>
@/Users/nick/.claude/get-shit-done/workflows/execute-plan.md
@/Users/nick/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md

Spec documents (the 3 original build specifications to audit against):
@specs/ils-complete-rebuild/requirements.md
@specs/ils-complete-rebuild/design.md
@specs/rebuild-ground-up/requirements.md
@specs/rebuild-ground-up/design.md
@.claude/plan/MASTER_ROADMAP.md

Prior audit reports (reference, not authoritative — they are dated):
@specs/full-audit/report-2026-02-13.md
@.claude/plan/gap-analysis-remediation.md

<interfaces>
<!-- Key codebase file inventory for the executor to audit against -->

iOS Views (70 files across 24 directories):
  Views/Browser/: BrowserView, MCPServerDetailView, SkillDetailView
  Views/Chat/: ChatView, AssistantCard, ChatInputBar, ChatMessageList, CodeBlockView, CommandPaletteView, ErrorMessageView, MarkdownTextView, MessageView, PermissionRequestModal, StreamingIndicatorView, SystemMessageView, TypingIndicatorBubble, UserMessageCard, AdvancedOptionsSheet
  Views/Components/: CacheStatusView, OfflineIndicator
  Views/Fleet/: HostProfileDetailView, HostProfilesView
  Views/Home/: HomeView
  Views/Hooks/: HooksManagementView
  Views/Onboarding/: ConnectionMode, OnboardingView, QuickConnectView, ServerSetupSheet, SSHSetupView
  Views/Plugins/: PluginConfigView
  Views/Premium/: FeatureGateView, PremiumView
  Views/Root/: SidebarRootView, SidebarSessionRow, SidebarView
  Views/Sessions/: NewSessionView, SessionInfoView
  Views/Settings/: ConfigEditorView, LogViewerView, NotificationPreferencesView, SettingsAboutSection, SettingsAppearanceSection, SettingsConfigSection, SettingsConnectionSection, SettingsView, ThemePickerView, TunnelSettingsView
  Views/Shared/: ShareSheet
  Views/System/: FileBrowserView, ProcessListView, SystemMonitorView
  Views/Teams/: AgentTeamDetailView, AgentTeamsListView, CreateTeamView, SpawnTeammateView, TeamMessagesView, TeamTaskListView
  Views/Themes/: ThemeEditorView, ThemeMarketplaceView, ThemePreviewCard, ThemePreviewView, ThemesListView, Editor/* (7 files)
  Views/Tips/: AppTips
  Views/: AppIconGenerator, LaunchScreenView

ViewModels (18 files):
  ChatViewModel, ConfigEditorViewModel, DashboardViewModel, HooksViewModel, HostProfilesViewModel, MCPViewModel, NewSessionViewModel, PluginsViewModel, ProjectsViewModel, QuickConnectViewModel, SessionsViewModel, SettingsViewModel, SetupViewModel, SkillsViewModel, SSHViewModel, SystemMetricsViewModel, TeamsViewModel, ThemesViewModel

Services (17 files):
  APIClient, AppLogger, CacheService, CitadelSSHService, ConnectionManager, FeatureGate, KeychainService, LocalDatabase, LowPowerModeMonitor, MetricsWebSocketClient, NetworkMonitor, PerformanceMonitor, PollingManager, SessionExportService, SSEClient, SubscriptionManager, SyncCoordinator

Backend Controllers (13):
  Chat, Config, Fleet, Health, MCP, Plugins, Projects, Sessions, Skills, Stats, System, Teams, Themes, Tunnel

Backend Services (17):
  ClaudeExecutorService, CLIMessageConverter, ConfigFileService, ExecutionOptions, FileSystemService, GitHubService, IndexingService, MCPFileService, PaginationParams, PathSanitizer, SessionFileService, SkillsFileService, StreamingService, SystemMetricsService, TeamsExecutorService, TeamsFileService, TunnelService, WebSocketService

ILSShared Models (14):
  ClaudeConfig, CLIMessage, ContentBlocks, CustomTheme, FleetHost, MCPServer, Message, Plugin, Project, ServerConnection, Session, SetupProgress, Skill, StreamMessage

ILSShared DTOs (12):
  ConnectionResponse, FleetDTOs, PaginatedResponse, RemoteMetricsDTOs, Requests, ResponseDTOs, SearchResult, SetupDTOs, SSHDTOs, SystemDTOs, TeamDTOs, TunnelDTOs

Existing validation evidence at /tmp/v3.5-evidence/iphone/:
  00-setup-verification.png, 01-home.png, 02-sessions.png, 03-chat.png, 04-browser-mcp.png, 05-browser-skills.png, 06-browser-plugins.png, 07-system-monitor.png, 08-settings-top.png, 08b-settings-scrolled.png, 09-host-profiles.png, 10-agent-teams.png, 11-themes.png, 12-hooks.png, 13-sidebar.png
  + deeplinks/, logs/, fixes/ subdirectories
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Systematic Codebase Inventory and Spec Cross-Reference</name>
  <files>.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md</files>
  <action>
Produce a comprehensive gap analysis document by systematically auditing the current codebase against ALL THREE original build specifications. This is a read-and-analyze task — NO code changes.

**Step 1: Read all three spec documents in full**
- `specs/ils-complete-rebuild/requirements.md` — 42 Functional Requirements (FR-1..FR-42), 18 User Stories (US-1..US-18), 15 NFRs
- `specs/rebuild-ground-up/requirements.md` — 19 User Stories (US-1..US-19), 24 FRs (FR-1..FR-24), 15 NFRs
- `.claude/plan/MASTER_ROADMAP.md` — 13 Phases (0-13), 130+ task items with item numbers (0.1, 0.2, ... 13.6)

**Step 2: Read the prior audit reports for context (but do NOT treat as authoritative — they are dated)**
- `specs/full-audit/report-2026-02-13.md` — from 2026-02-13, many issues since resolved
- `.claude/plan/gap-analysis-remediation.md` — from 2026-02-18, partial analysis

**Step 3: For EACH spec requirement, grep/read the actual codebase files to determine status**

For each FR/US from ils-complete-rebuild/requirements.md:
- FR-1 (POST /auth/connect SSH): grep for SSH/auth connect in backend controllers
- FR-2 (GET /server/status): grep for server status endpoint
- FR-3 (GET /skills/search): grep SkillsController for search endpoint
- FR-4 (POST /skills/install): grep SkillsController for install endpoint
- FR-5 (PUT /mcp/{name}): grep MCPController for update endpoint
- FR-6 (GET /plugins/search): grep PluginsController for search endpoint
- FR-7 (POST /marketplaces): grep PluginsController for marketplace registration
- FR-8 (GET /skills/{id}): grep SkillsController for single skill endpoint
- FR-9 (PUT /skills/{id}): grep SkillsController for update endpoint
- FR-10 (Preserve existing endpoints): verify all listed endpoints exist
- FR-11..FR-14 (Backend services): verify GitHubService, IndexingService, SSH, preserved services
- FR-15..FR-22 (iOS views): verify each view file exists and matches spec layout requirements
- FR-23..FR-25 (iOS services): verify SSHService, ConfigurationManager, APIClient, SSEClient
- FR-26..FR-33 (Data models): verify each model in ILSShared
- FR-34..FR-38 (Design system): verify theme token implementation
- FR-39..FR-42 (GitHub API): verify GitHub integration

For each US from rebuild-ground-up/requirements.md:
- US-1 (Theme System): verify AppTheme protocol, ThemeManager, 30+ tokens
- US-2 (Sidebar Navigation): verify SidebarRootView, SidebarView with all AC items
- US-3 (iPad Sidebar): verify iPad layout adaptation
- US-4..US-8 (Chat View): verify ChatView, streaming, code blocks, tool calls, thinking
- US-9 (Home Dashboard): verify HomeView with spec requirements
- US-10 (New Session): verify NewSessionView
- US-11 (System Monitor): verify SystemMonitorView
- US-12 (Settings): verify SettingsView sections
- US-13 (Theme Picker): verify ThemePickerView
- US-14 (All 12 Themes): verify all theme implementations
- US-15 (Browser): verify BrowserView
- US-16 (Onboarding): verify OnboardingView
- US-17 (Animation Polish): check animation implementations
- US-18 (Session Management): verify session CRUD
- US-19 (Deep Linking): verify URL scheme handling

For MASTER_ROADMAP Phases 0-13 (sample key items from each):
- Phase 0 (Critical Fixes): deinit cleanup, animation leaks, DB indexes, compression
- Phase 1 (Security): API key auth, input validation, CORS, rate limiting, privacy manifest
- Phase 2 (@Observable): ViewModel migration, TipKit, SwiftUI modernization
- Phase 3 (Backend API): Missing endpoints, chat enhancements, pagination
- Phase 4 (Offline): Local DB, cache-first, offline UX
- Phase 5 (Testing): Unit tests, integration tests, CI
- Phase 6 (iOS 18+): Widgets, Live Activities, App Intents
- Phase 7 (Accessibility): Dynamic Type, VoiceOver, localization
- Phase 8 (macOS Parity): Spotlight, drag-drop, Handoff, menus
- Phase 9 (CI/CD): GitHub Actions, SwiftLint, Fastlane
- Phase 10 (Monetization): StoreKit, FeatureGate, premium features
- Phase 11 (Plugin Ecosystem): Plugin management, theme marketplace
- Phase 12 (Shared Models): Hashable, enums, documentation
- Phase 13 (UX Polish): Empty states, skeleton loading, pull-to-refresh, deep links, iPad

**Step 4: Cross-reference existing validation evidence**
Read screenshot filenames from /tmp/v3.5-evidence/iphone/ to note which screens have recent visual verification.

**Step 5: Determine status for each item**
Assign one of:
- PASS: Requirement fully implemented and verified
- EXCEEDED: Implementation goes beyond spec requirement
- PARTIAL: Some aspects implemented, others missing
- MISSING: Not implemented at all
- EVOLVED: Requirement superseded by different (often better) architecture
- N/A: Requirement no longer applicable (e.g., spec was for tab nav, we use sidebar)
- DEFERRED: Explicitly deferred per project decisions

**Step 6: Assign severity to each gap**
For items that are PARTIAL or MISSING:
- CRITICAL: Blocks App Store submission or core functionality
- HIGH: Significant feature gap visible to users
- MEDIUM: Missing polish or secondary feature
- LOW: Cosmetic difference or minor enhancement

**Step 7: Write the GAP-ANALYSIS.md document**
Structure it with these sections:
1. Executive Summary (counts, overall compliance %)
2. Methodology (which specs, how audited)
3. Spec A: ils-complete-rebuild Requirements Matrix (FR-1..FR-42 table)
4. Spec A: ils-complete-rebuild User Stories Matrix (US-1..US-18 table)
5. Spec B: rebuild-ground-up User Stories Matrix (US-1..US-19 table)
6. Spec B: rebuild-ground-up Functional Requirements Matrix (FR-1..FR-24 table)
7. Spec C: MASTER_ROADMAP Phase Completion Matrix (Phases 0-13)
8. Screen Evidence Registry (each iOS screen mapped to spec + screenshot evidence)
9. Backend Evidence Registry (each endpoint mapped to spec + curl verification status)
10. Gap Summary (all PARTIAL/MISSING items sorted by severity)
11. Beyond-Spec Features (things implemented that no spec required)
12. Recommendations (prioritized remediation list)

Each matrix row MUST have columns: ID | Requirement | Status | Evidence/File | Notes
  </action>
  <verify>
Verify the GAP-ANALYSIS.md file:
1. File exists at .planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md
2. File has 400+ lines (comprehensive coverage)
3. Contains all 3 spec matrices (grep for "FR-1", "US-1", "Phase 0")
4. Contains Screen Evidence Registry section
5. Contains Backend Evidence Registry section
6. Contains Gap Summary section with severity levels
7. Every FR-ID from ils-complete-rebuild accounted for (FR-1 through FR-42)
8. Every US-ID from rebuild-ground-up accounted for (US-1 through US-19)
  </verify>
  <done>
GAP-ANALYSIS.md is a comprehensive 400+ line document that:
- Maps every requirement from all 3 spec documents to a PASS/PARTIAL/MISSING/EXCEEDED/EVOLVED status
- Each status is backed by a specific codebase file path or evidence screenshot
- Gaps are severity-rated (CRITICAL/HIGH/MEDIUM/LOW)
- A prioritized remediation list is included at the end
- Executive summary provides at-a-glance compliance percentages per spec document
  </done>
</task>

<task type="auto">
  <name>Task 2: Validate Gap Analysis Completeness</name>
  <files>.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md</files>
  <action>
After Task 1 produces the GAP-ANALYSIS.md, perform a completeness self-check:

1. Count the number of FR-IDs from ils-complete-rebuild/requirements.md (should be 42) and verify all appear in the matrix
2. Count the number of US-IDs from rebuild-ground-up/requirements.md (should be 19) and verify all appear in the matrix
3. Count the number of Master Roadmap phases (should be 14: Phase 0-13) and verify all appear
4. Verify the Executive Summary percentages match the actual counts in the matrices
5. Verify every PARTIAL/MISSING item has a severity rating
6. Verify every PASS/EXCEEDED item has a file path or evidence reference
7. If any gaps found in the document, update it to fix them

Also verify that the Gap Summary section contains a deduplicated, prioritized list — since the 3 specs overlap heavily, the same gap may appear under multiple spec IDs. The summary should consolidate these into unique remediation items.
  </action>
  <verify>
Run a final check:
- grep -c "FR-" GAP-ANALYSIS.md should show 42+ occurrences (all FR IDs covered)
- grep -c "US-" GAP-ANALYSIS.md should show 19+ occurrences (all US IDs covered)
- grep -c "CRITICAL\|HIGH\|MEDIUM\|LOW" GAP-ANALYSIS.md should show gap severity assignments
- grep -c "Phase" GAP-ANALYSIS.md should show 14+ occurrences (all phases covered)
- wc -l GAP-ANALYSIS.md should show 400+ lines
  </verify>
  <done>
GAP-ANALYSIS.md passes all completeness checks:
- All 42 FR-IDs from Spec A accounted for
- All 19 US-IDs from Spec B accounted for
- All 14 phases from Spec C accounted for
- Executive summary percentages are accurate
- Every gap has a severity rating
- Gap summary is deduplicated across overlapping specs
- Document is 400+ lines with comprehensive coverage
  </done>
</task>

</tasks>

<verification>
Overall plan verification:
1. GAP-ANALYSIS.md exists and is 400+ lines
2. All 3 spec documents fully covered (FR-1..FR-42, US-1..US-19, Phases 0-13)
3. Every item has a status assignment with evidence
4. Gap summary is severity-rated and deduplicated
5. Recommendations section provides actionable prioritization
</verification>

<success_criteria>
- A single comprehensive GAP-ANALYSIS.md document exists
- It covers 100% of requirements from all 3 spec documents
- Each requirement maps to PASS/PARTIAL/MISSING/EXCEEDED/EVOLVED with file evidence
- Gaps are severity-rated and consolidated into a prioritized remediation list
- The document can be handed to a future executor as the definitive reference for what to fix
</success_criteria>

<output>
After completion, create `.planning/quick/6-comprehensive-ils-audit-and-remediation-/6-SUMMARY.md`
</output>
