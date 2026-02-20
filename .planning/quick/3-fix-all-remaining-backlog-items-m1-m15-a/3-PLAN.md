---
phase: quick-3
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
  - ILSApp/ILSApp/Views/Settings/LogViewerView.swift
  - ILSApp/ILSApp/Views/Home/HomeView.swift
  - ILSApp/ILSApp/Views/Browser/BrowserView.swift
  - ILSApp/ILSApp/Views/Chat/ChatView.swift
  - ILSApp/ILSApp/Views/Premium/PremiumView.swift
  - ILSApp/ILSApp/Views/System/SystemMonitorView.swift
  - ILSApp/ILSApp/ViewModels/DashboardViewModel.swift
  - ILSApp/ILSMacApp/Views/SessionWindowView.swift
  - ILSApp/ILSMacApp/Managers/NotificationManager.swift
autonomous: true
requirements: [M1, M4, M6, M7, M12, M13, L1, L2]

must_haves:
  truths:
    - "SSH setup log console adapts to available space instead of fixed 300pt"
    - "Log viewers use stable identifiers instead of offset-based ForEach"
    - "All sheets have presentationDetents for proper sizing"
    - "SessionWindowView uses .task instead of unstructured Task in onAppear"
    - "DashboardViewModel cache Task is stored for deduplication"
    - "SSH log terminal uses theme colors instead of raw Color values"
  artifacts:
    - path: "ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift"
      provides: "Flexible log console height, theme-colored terminal output"
    - path: "ILSApp/ILSApp/Views/Settings/LogViewerView.swift"
      provides: "Stable ForEach identifiers"
    - path: "ILSApp/ILSApp/Views/Browser/BrowserView.swift"
      provides: "presentationDetents on AddMCPServer sheet"
    - path: "ILSApp/ILSApp/Views/Chat/ChatView.swift"
      provides: "presentationDetents on CommandPalette and PermissionRequest sheets"
    - path: "ILSApp/ILSMacApp/Views/SessionWindowView.swift"
      provides: ".task modifier instead of onAppear+Task"
    - path: "ILSApp/ILSApp/ViewModels/DashboardViewModel.swift"
      provides: "Stored cache Task handle"
  key_links: []
---

<objective>
Fix 8 remaining MEDIUM/LOW audit backlog items from the ILS iOS/macOS comprehensive audit.

Purpose: Complete the audit remediation backlog — all CRITICAL and HIGH items are done, now finishing MEDIUM and LOW items that have real impact.
Output: Clean, polished codebase with all actionable audit findings resolved.

**Items already fixed (skip):** M2 (LazyVStack in Fleet — done), M5 (SSEClient @Observable — done), M9 (8pt font in Hooks — done), M11 (.task in SystemMonitor — done), M15 (ThemeMarketplace file I/O — done).

**Items deferred (skip):** M3 (sidebar width — risk to gesture thresholds), M8 (BrowserView .searchable — UX change risk), M14 (109 VStack/HStack spacing — too many changes, high regression risk).

**Not a runtime issue (skip):** M10 (PremiumView CyberpunkTheme only in #Preview, not runtime code).
</objective>

<execution_context>
@/Users/nick/.claude/get-shit-done/workflows/execute-plan.md
@/Users/nick/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
@ILSApp/ILSApp/Views/Settings/LogViewerView.swift
@ILSApp/ILSApp/Views/Home/HomeView.swift
@ILSApp/ILSApp/Views/Browser/BrowserView.swift
@ILSApp/ILSApp/Views/Chat/ChatView.swift
@ILSApp/ILSApp/Views/Premium/PremiumView.swift
@ILSApp/ILSMacApp/Views/SessionWindowView.swift
@ILSApp/ILSApp/ViewModels/DashboardViewModel.swift
@ILSApp/ILSMacApp/Managers/NotificationManager.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix layout, lifecycle, and data handling issues (M1, M4, M6, M12, M13)</name>
  <files>
    ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
    ILSApp/ILSApp/Views/Settings/LogViewerView.swift
    ILSApp/ILSApp/Views/Home/HomeView.swift
    ILSApp/ILSMacApp/Views/SessionWindowView.swift
    ILSApp/ILSApp/ViewModels/DashboardViewModel.swift
  </files>
  <action>
    **M1 — SSHSetupView.swift line 228:** Replace `.frame(height: 300)` on the log console ScrollView with `.frame(minHeight: 150, maxHeight: 400)` to allow the console to adapt to available space while staying bounded.

    **M4 — LogViewerView.swift line 14:** Replace `ForEach(Array(logs.enumerated()), id: \.offset)` with a stable identifier approach. Since log lines are plain strings that may repeat, create a lightweight wrapper struct:
    ```swift
    private struct LogLine: Identifiable {
        let id: Int  // use index at time of creation, stable across renders
        let text: String
    }
    ```
    Change `@State private var logs: [String] = []` to `@State private var logs: [LogLine] = []`. Update the `.task` and refresh button to map: `logs = rawLogs.enumerated().map { LogLine(id: $0.offset, text: $0.element) }`. Update ForEach to `ForEach(logs) { line in Text(line.text) ... }`.

    **M4 — SSHSetupView.swift line 214:** Same pattern — `ForEach(Array(viewModel.logLines.enumerated()), id: \.offset)`. Since `viewModel.logLines` is a `[String]` that grows incrementally (append-only during setup), the offset IS stable here because lines are never removed/reordered. Add a comment `// Log lines are append-only; offset is stable as an identifier` to document the intentional choice. No structural change needed.

    **M6 — HomeView.swift line 18:** Change `VStack(alignment: .leading, spacing: theme.spacingLG)` to `LazyVStack(alignment: .leading, spacing: theme.spacingLG)` inside the ScrollView. This is safe because all child views are independent sections.

    **M12 — SessionWindowView.swift lines 58-60:** Replace:
    ```swift
    .onAppear {
        loadSession()
    }
    ```
    with:
    ```swift
    .task {
        await loadSessionAsync()
    }
    ```
    And refactor `loadSession()` to be an async method `loadSessionAsync()` that does the work directly without spawning an inner `Task { }`. The inner `await MainActor.run { }` blocks are unnecessary since the view is already `@MainActor` — just set properties directly after the `try await` call. Keep the `do/catch` error handling.

    **M13 — DashboardViewModel.swift lines 63-66:** The fire-and-forget `Task { }` for caching sessions should be stored. Add a property:
    ```swift
    @ObservationIgnored private var cacheTask: Task<Void, Never>?
    ```
    Replace the bare `Task { ... }` at line 64 with:
    ```swift
    cacheTask?.cancel()
    cacheTask = Task { [sessions = self.recentSessions] in
        await CacheService.shared.cacheSessions(sessions)
    }
    ```
    This deduplicates concurrent cache writes and allows cancellation.
  </action>
  <verify>
    Run iOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5`
    Run macOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5`
    Both must succeed with 0 errors.
  </verify>
  <done>
    - SSHSetupView log console uses flexible height constraints instead of fixed 300pt
    - LogViewerView uses stable LogLine identifiers instead of offset-based ForEach
    - HomeView uses LazyVStack inside ScrollView
    - SessionWindowView uses .task modifier instead of onAppear+Task
    - DashboardViewModel stores cache Task handle with cancellation
    - iOS and macOS builds pass
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix sheet detents, theme colors, and documentation (M7, L1, L2)</name>
  <files>
    ILSApp/ILSApp/Views/Browser/BrowserView.swift
    ILSApp/ILSApp/Views/Chat/ChatView.swift
    ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
    ILSApp/ILSMacApp/Managers/NotificationManager.swift
  </files>
  <action>
    **M7 — Missing presentationDetents on 3 sheets:**

    1. BrowserView.swift line 81-83: Add `.presentationDetents([.large])` after the `AddMCPServerView(mcpVM: mcpVM)` sheet:
    ```swift
    .sheet(isPresented: $showingAddMCPServer) {
        AddMCPServerView(mcpVM: mcpVM)
            .presentationDetents([.large])
    }
    ```

    2. ChatView.swift line 56-63: The CommandPaletteView sheet is missing detents. Add `.presentationDetents([.medium, .large])` after the closing brace of the CommandPaletteView content (before the closing `}`). Read ChatView.swift first to find exact insertion point.

    3. ChatView.swift line 135-138: The PermissionRequestModal sheet is missing detents. Add `.presentationDetents([.medium])` after the PermissionRequestModal closing brace.

    **L2 — SSHSetupView.swift lines 239-254:** Replace raw Color values in `logLineColor()` with theme colors. The function currently returns `.green`, `.red`, `.cyan`, `.yellow`, `.white`. Since this function is inside the struct (has access to `theme`), replace:
    - `.green` -> `theme.success`
    - `.red` -> `theme.error`
    - `.cyan` -> `theme.info`
    - `.yellow` -> `theme.warning`
    - `.white.opacity(0.8)` -> `theme.textSecondary`

    **L1 — NotificationManager.swift line 22:** Add a documentation comment above `center.delegate = self` explaining the intentional design:
    ```swift
    // Intentional: UNUserNotificationCenter.delegate is weak, and NotificationManager
    // is a singleton (static let shared) — so the delegate reference is always valid
    // for the lifetime of the app. No retain cycle risk.
    center.delegate = self
    ```
    No code change needed — documentation only.
  </action>
  <verify>
    Run iOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5`
    Run macOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5`
    Both must succeed with 0 errors.
  </verify>
  <done>
    - All 3 sheets (AddMCPServer, CommandPalette, PermissionRequest) have presentationDetents
    - SSH log terminal uses theme colors instead of raw Color values
    - NotificationManager delegate assignment documented as intentional
    - iOS and macOS builds pass
  </done>
</task>

</tasks>

<verification>
After both tasks complete:
1. iOS build succeeds: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet`
2. macOS build succeeds: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet`
3. Backend build succeeds: `swift build`
4. Grep confirms no remaining `size: 8` font sizes
5. Grep confirms no remaining `id: \.offset` in LogViewerView
6. Grep confirms all sheets have presentationDetents
</verification>

<success_criteria>
- 8 audit items resolved (M1, M4, M6, M7, M12, M13, L1, L2)
- 5 items confirmed already fixed (M2, M5, M9, M11, M15)
- 3 items deferred with rationale (M3, M8, M14)
- 1 item confirmed not a runtime issue (M10)
- All 3 build targets pass (iOS, macOS, backend)
- Zero regressions introduced
</success_criteria>

<output>
After completion, create `.planning/quick/3-fix-all-remaining-backlog-items-m1-m15-a/3-01-SUMMARY.md`
</output>
