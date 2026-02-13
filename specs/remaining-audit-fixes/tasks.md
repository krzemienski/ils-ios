# Tasks: Remaining Audit Fixes (MEDIUM + LOW)

## Phase 1: Make It Work (POC) — MEDIUM + LOW Fixes by File

Focus: Fix all 21 audit issues grouped by file. Core services first, then ViewModels, then Views.

---

- [x] 1.1 Fix APIClient: scoped cache invalidation, skip final retry sleep, nonisolated coders
  - **Do**:
    1. Open `APIClient.swift`
    2. **M-NET-1**: Replace broad cache invalidation in `post`, `put`, `delete` methods. Current: `cache.removeValue(forKey: "/\(basePath)")`. New: add `invalidateCacheForMutation(path:)` method that removes exact path + list endpoint only
    3. **M-NET-2**: In `performWithRetry`, the throw on `attempt == maxAttempts` already exits before the sleep below it — verify the sleep only runs when `attempt < maxAttempts`. If the sleep runs unconditionally after the throw guard, wrap it in `if attempt < maxAttempts { ... }`
    4. **L-CONC-1**: Add `nonisolated` keyword to `decoder` and `encoder` property declarations (line 7-8)
  - **Files**: `ILSApp/ILSApp/Services/APIClient.swift`
  - **Done when**: Cache invalidation scoped to specific resource + list, no sleep on final retry, coders marked nonisolated
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(api): scope cache invalidation, skip final retry sleep, nonisolated coders`
  - _Requirements: FR-3, FR-12, FR-13 | AC-1.3, AC-5.1, AC-5.2_
  - _Design: APIClient.swift section_

- [x] 1.2 Fix SSEClient: exponential backoff, nonisolated coders, print to AppLogger
  - **Do**:
    1. Open `SSEClient.swift`
    2. **L-NET-1**: Line 162 — change `reconnectDelay * UInt64(reconnectAttempts)` to `reconnectDelay * UInt64(1 << (reconnectAttempts - 1))` for true exponential backoff (2s, 4s, 8s, 16s)
    3. **L-CONC-1**: Add `nonisolated` to `jsonEncoder` (line 27) and `jsonDecoder` (line 28)
    4. **L-CONC-2**: Replace all 16 `print()` calls with `AppLogger.shared.info/warning/error()` with category `"sse"`. Use `.error` for error conditions, `.warning` for reconnection, `.info` for lifecycle events
  - **Files**: `ILSApp/ILSApp/Services/SSEClient.swift`
  - **Done when**: Backoff is exponential, coders nonisolated, zero print() calls remain
  - **Verify**: `grep -c 'print(' ILSApp/ILSApp/Services/SSEClient.swift` returns 0 && `grep 'reconnectDelay.*<<' ILSApp/ILSApp/Services/SSEClient.swift` matches
  - **Commit**: `fix(sse): exponential backoff, nonisolated coders, structured logging`
  - _Requirements: FR-3, FR-4, FR-14 | AC-1.3, AC-1.4, AC-5.3_
  - _Design: SSEClient.swift section_

- [x] 1.3 Fix ILSAppApp: weak capture, didSet to method, remove objectWillChange, nonisolated coders
  - **Do**:
    1. Open `ILSAppApp.swift`
    2. **M-ARCH-1**: Remove `didSet` from `serverURL` (line 44) and `selectedTab` (line 61 if applicable). Create explicit `updateServerURL(_ url: String)` method containing the didSet logic. Update all callers to use the method
    3. **M-CONC-2**: In Task closures for polling (lines ~145, ~175), ensure `[weak self]` with `guard let self else { break }` pattern. Capture local copies of properties before async operations
    4. **L-PERF-2**: Remove `objectWillChange.send()` at line 119 — @Published handles this automatically
    5. **L-CONC-1**: Add `nonisolated` to any encoder/decoder properties
    6. **L-CONC-2**: Replace all 12 `print()` calls with `AppLogger.shared` using category `"app"`
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift`
  - **Done when**: No didSet on @Published, no objectWillChange.send(), no print(), weak captures correct
  - **Verify**: `grep -c 'print(' ILSApp/ILSApp/ILSAppApp.swift` returns 0 && `grep 'didSet' ILSApp/ILSApp/ILSAppApp.swift | grep -v '//'` returns only comments && `grep 'objectWillChange' ILSApp/ILSApp/ILSAppApp.swift` returns empty
  - **Commit**: `fix(app): refactor didSet to methods, remove objectWillChange, structured logging`
  - _Requirements: FR-2, FR-3, FR-4, FR-8, FR-19 | AC-1.2, AC-1.3, AC-1.4, AC-3.1_
  - _Design: ILSAppApp.swift section_

- [x] 1.4 [VERIFY] Quality checkpoint: build succeeds after core service fixes
  - **Do**: Build the project to catch any compilation errors from tasks 1.1-1.3
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:)'`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(audit): pass quality checkpoint after core service fixes` (only if fixes needed)

- [x] 1.5 Fix ChatViewModel: Timer to Task, cancellables cleanup, nonisolated decoder, print to AppLogger
  - **Do**:
    1. Open `ChatViewModel.swift`
    2. **M-MEM-1**: Replace `Timer.scheduledTimer` (line 130) with Task-based timer. Change `private var batchTimer: Timer?` to `private var batchTask: Task<Void, Never>?`. In `startBatchTimer()`: create Task with `[weak self]` that loops with `Task.sleep`. In `stopBatchTimer()`: cancel task and nil it
    3. **L-MEM-1**: In deinit (line 67), add `cancellables.removeAll()` after existing cleanup. Also update deinit to cancel `batchTask` instead of `batchTimer?.invalidate()`
    4. **L-CONC-1**: Add `nonisolated` to `jsonDecoder` (line 51)
    5. **L-CONC-2**: Replace the 1 `print()` call with `AppLogger.shared.info()` category `"chat"`
  - **Files**: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
  - **Done when**: No Timer, no print(), cancellables cleared in deinit, decoder nonisolated
  - **Verify**: `grep 'Timer.scheduledTimer' ILSApp/ILSApp/ViewModels/ChatViewModel.swift` returns empty && `grep 'cancellables.removeAll' ILSApp/ILSApp/ViewModels/ChatViewModel.swift` matches
  - **Commit**: `fix(chat-vm): Task-based timer, cancellables cleanup, nonisolated decoder`
  - _Requirements: FR-3, FR-4, FR-5, FR-7 | AC-1.3, AC-1.4, AC-2.1, AC-2.3_
  - _Design: ChatViewModel.swift section_

- [x] 1.6 Fix SystemMetricsViewModel: dedicated URLSession, nonisolated decoder
  - **Do**:
    1. Open `SystemMetricsViewModel.swift`
    2. **M-CONC-1**: Replace `private let session = URLSession.shared` (line 22) with dedicated instance: `private let session: URLSession` initialized in `init` with `URLSessionConfiguration.default` + 10s timeout
    3. **L-CONC-1**: Add `nonisolated` to `decoder` (line 23)
  - **Files**: `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift`
  - **Done when**: Dedicated URLSession instance, nonisolated decoder
  - **Verify**: `grep 'URLSession.shared' ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` returns empty
  - **Commit**: `fix(system-vm): dedicated URLSession, nonisolated decoder`
  - _Requirements: FR-1, FR-3 | AC-1.1, AC-1.3_
  - _Design: SystemMetricsViewModel.swift section_

- [x] 1.7 Fix TunnelSettingsView: DispatchQueue to Task, accessibility labels
  - **Do**:
    1. Open `TunnelSettingsView.swift`
    2. **M-MEM-2**: Replace `DispatchQueue.main.asyncAfter` (line 143) with `@State private var toastTask: Task<Void, Never>?` pattern. Cancel previous, create new Task with `Task.sleep(for: .seconds(2))`, guard `!Task.isCancelled`. Add `.onDisappear { toastTask?.cancel() }`
    3. **M-A11Y-1**: Add `.accessibilityLabel("Enable quick tunnel")` to the Toggle that uses `.labelsHidden()`. Add labels to any other unlabeled interactive elements (TextFields, Buttons)
  - **Files**: `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
  - **Done when**: No DispatchQueue.asyncAfter for toast, all interactive elements have accessibility labels
  - **Verify**: `grep 'DispatchQueue.main.asyncAfter' ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` returns empty && `grep 'accessibilityLabel' ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` has 1+ matches
  - **Commit**: `fix(tunnel): Task-based toast, accessibility labels`
  - _Requirements: FR-6, FR-16 | AC-2.2, AC-6.1_
  - _Design: TunnelSettingsView.swift section_

- [x] 1.8 [VERIFY] Quality checkpoint: build succeeds after ViewModel fixes
  - **Do**: Build the project to catch any compilation errors from tasks 1.5-1.7
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:)'`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(audit): pass quality checkpoint after ViewModel fixes` (only if fixes needed)

- [x] 1.9 Fix SessionsListView: static formatters namespace, computed to method, font theme, color indicators
  - **Do**:
    1. Open `SessionsListView.swift`
    2. **M-ARCH-2**: Extract `relativeDateFormatter` (line 197) to a top-level `enum SessionFormatters` with `nonisolated(unsafe) static let relative = RelativeDateTimeFormatter()`. Also add `nonisolated(unsafe) static let date: DateFormatter` if one exists. Update all references from `Self.relativeDateFormatter` to `SessionFormatters.relative`
    3. **L-ARCH-1**: If complex computed properties exist (e.g. `filteredSessions`), extract to methods
    4. **L-PERF-1**: Replace any `.font(.system(size:))` with ILSTheme equivalents
    5. **L-A11Y-1**: If Circle-based color-only status indicators exist, augment with icon+text using `Image(systemName:)` + `Text()` in HStack with `.accessibilityElement(children: .combine)`
  - **Files**: `ILSApp/ILSApp/Views/Sessions/SessionsListView.swift`
  - **Done when**: Formatters in namespace, no hardcoded fonts, status indicators include text/icon
  - **Verify**: `grep 'SessionFormatters' ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` matches && `grep '.font(.system(size:' ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` returns empty
  - **Commit**: `fix(sessions): formatter namespace, theme fonts, accessible status indicators`
  - _Requirements: FR-9, FR-10, FR-11, FR-18 | AC-3.2, AC-3.3, AC-4.1, AC-6.3_
  - _Design: SessionsListView.swift section_

- [x] 1.10 Fix SkillsViewModel: didSet to method
  - **Do**:
    1. Open `SkillsViewModel.swift`
    2. **M-ARCH-1**: Remove `didSet` from `gitHubSearchText` (line 13). Create `func updateGitHubSearchText(_ text: String)` that sets the property and calls `searchGitHubSkills()`. Find all callers that assign `gitHubSearchText` directly and update them to call the new method instead
  - **Files**: `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`
  - **Done when**: No didSet on gitHubSearchText, explicit update method exists, callers updated
  - **Verify**: `grep 'didSet' ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` returns empty
  - **Commit**: `fix(skills-vm): replace didSet with explicit update method`
  - _Requirements: FR-8 | AC-3.1_
  - _Design: SkillsViewModel.swift section_

- [x] 1.11 Fix ChatView: DispatchQueue to Task, computed to method
  - **Do**:
    1. Open `ChatView.swift`
    2. **M-MEM-2**: Replace `DispatchQueue.main.asyncAfter` (line 322) with `@State private var scrollTask: Task<Void, Never>?` pattern. Cancel previous, create Task with `Task.sleep(for: .milliseconds(300))`, guard `!Task.isCancelled`, then perform scroll. Add `.onDisappear { scrollTask?.cancel() }`
    3. **L-ARCH-1**: Extract complex computed properties (e.g. `shouldShowTypingIndicator`) to methods if they exist
  - **Files**: `ILSApp/ILSApp/Views/Chat/ChatView.swift`
  - **Done when**: No DispatchQueue.asyncAfter, complex computations extracted to methods
  - **Verify**: `grep 'DispatchQueue.main.asyncAfter' ILSApp/ILSApp/Views/Chat/ChatView.swift` returns empty
  - **Commit**: `fix(chat): Task-based scroll delay, extract computed properties`
  - _Requirements: FR-6, FR-10 | AC-2.2, AC-3.3_
  - _Design: ChatView.swift section_

- [x] 1.12 Fix MetricsWebSocketClient: WebSocket fallback reset timer
  - **Do**:
    1. Open `MetricsWebSocketClient.swift`
    2. **L-NET-2**: Add `private var lastWSResetTime: Date?` and `private let wsResetInterval: TimeInterval = 600` properties. In `connect()`, before checking `useFallbackPolling`, add reset logic: if `useFallbackPolling == true` AND `Date().timeIntervalSince(lastWSResetTime) > wsResetInterval`, reset `useFallbackPolling = false` and `wsFailureCount = 0`. When setting `useFallbackPolling = true` (line 138), also set `lastWSResetTime = Date()`
  - **Files**: `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift`
  - **Done when**: WebSocket fallback resets after 10 minutes, allowing retry
  - **Verify**: `grep 'wsResetInterval' ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` matches && `grep 'lastWSResetTime' ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` matches
  - **Commit**: `fix(websocket): reset fallback polling after 10min recovery window`
  - _Requirements: FR-15 | AC-5.4_
  - _Design: MetricsWebSocketClient.swift section_

- [x] 1.13 [VERIFY] Quality checkpoint: build succeeds after all View/ViewModel fixes
  - **Do**: Build the project to catch any compilation errors from tasks 1.9-1.12
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:)'`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(audit): pass quality checkpoint after View fixes` (only if fixes needed)

- [x] 1.14 Fix remaining hardcoded fonts across 6 files
  - **Do**:
    1. Replace all `.font(.system(size:))` with ILSTheme references in these files:
       - `ServerSetupSheet.swift:107` — `.font(.system(size: 44))` to `.font(.system(.largeTitle, weight: .bold))` or `ILSTheme.titleFont` (large icon, may need custom)
       - `ServerSetupSheet.swift:267` — `.font(.system(size: 36))` similar treatment
       - `MCPServerListView.swift:230` — `.font(.system(size: 9))` to `ILSTheme.captionFont` (tiny badge)
       - `EmptyEntityState.swift:29` — `.font(.system(size: 48))` to `.font(.system(.largeTitle))` (decorative icon)
       - `ConnectionSteps.swift:66,70` — `.font(.system(size: 20))` to `ILSTheme.headlineFont` or `.font(.title3)`
    2. Use Dynamic Type-compatible alternatives: `.font(.largeTitle)`, `.font(.title3)`, `ILSTheme.captionFont`
    3. For decorative/icon sizes that must stay fixed, use `.font(.system(size: N))` but document why
  - **Files**: `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`, `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`, `ILSApp/ILSApp/Theme/Components/EmptyEntityState.swift`, `ILSApp/ILSApp/Theme/Components/ConnectionSteps.swift`
  - **Done when**: All practical hardcoded font sizes replaced with theme/system text style references
  - **Verify**: `grep -r '.font(.system(size:' ILSApp/ILSApp/ | grep -v '//' | wc -l` returns 0 or only documented exceptions
  - **Commit**: `fix(theme): replace hardcoded font sizes with Dynamic Type references`
  - _Requirements: FR-11, FR-17 | AC-4.1, AC-6.2_
  - _Design: Low-Impact Files font fixes section_

- [x] 1.15 Fix StatusBadge: augment color-only indicators with icon
  - **Do**:
    1. Open `ILSTheme.swift`, find `StatusBadge` (line 305)
    2. Modify StatusBadge to include an SF Symbol icon alongside the colored circle. Add `let icon: String` parameter with a default. Change body to `HStack(spacing: 4) { Image(systemName: icon).font(.caption2).foregroundColor(color); Text(text).font(.caption2).foregroundColor(color) }`. Add `.accessibilityElement(children: .combine)` and `.accessibilityLabel("\(text) status")`
    3. Remove the `Circle()` — the icon replaces it as the visual indicator
    4. Update `MCPServerListView.swift` (only current caller) to pass appropriate icon names
    5. Status icon mappings: active/running → "checkmark.circle.fill", inactive/stopped → "circle", error → "exclamationmark.triangle.fill"
  - **Files**: `ILSApp/ILSApp/Theme/ILSTheme.swift`, `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`
  - **Done when**: StatusBadge shows icon+text (not color-only circle), accessibility labels present
  - **Verify**: `grep 'accessibilityLabel' ILSApp/ILSApp/Theme/ILSTheme.swift | grep -i status` matches && `grep 'Image(systemName' ILSApp/ILSApp/Theme/ILSTheme.swift | grep -i StatusBadge -A5` finds icon usage
  - **Commit**: `fix(a11y): StatusBadge with icon+text indicators for WCAG compliance`
  - _Requirements: FR-18 | AC-6.3_
  - _Design: Accessibility Color Indicators section_

- [x] 1.16 Fix remaining print() in CommandPaletteView
  - **Do**:
    1. Open `CommandPaletteView.swift`
    2. Replace the 1 `print()` call with `AppLogger.shared.info()` category `"ui"`
  - **Files**: `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift`
  - **Done when**: Zero print() calls remain in file
  - **Verify**: `grep -rn 'print(' ILSApp/ILSApp/ --include='*.swift' | grep -v AppLogger | grep -v '// ' | wc -l` returns 0
  - **Commit**: `fix(ui): replace print with AppLogger in CommandPaletteView`
  - _Requirements: FR-4 | AC-1.4_
  - _Design: L-CONC-2 print cleanup_

- [x] 1.17 POC Checkpoint: full build + app launch verification
  - **Do**:
    1. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*`
    2. Build with strict warnings: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' clean build`
    3. Verify zero `print()` across all Swift files: `grep -rn 'print(' ILSApp/ILSApp/ --include='*.swift' | grep -v AppLogger | grep -v '//'`
    4. Verify zero `DispatchQueue.main.asyncAfter` in modified files (TunnelSettingsView, ChatView)
    5. Verify zero `Timer.scheduledTimer` calls
    6. Verify zero `URLSession.shared` in ViewModels
    7. Verify zero `objectWillChange.send()`
    8. Verify zero `didSet` on @Published properties in modified files
  - **Done when**: All 21 audit issues resolved, clean build, all grep checks pass
  - **Verify**: All commands above exit 0
  - **Commit**: `feat(audit): complete all 21 MEDIUM+LOW audit fixes`

## Phase 2: Refactoring

After POC validated, clean up any rough edges.

- [x] 2.1 Review and normalize AppLogger categories across all modified files
  - **Do**:
    1. Grep all `AppLogger.shared` calls across the codebase
    2. Ensure consistent category naming: `"api"` for APIClient, `"sse"` for SSEClient, `"app"` for ILSAppApp, `"chat"` for ChatViewModel, `"ui"` for Views
    3. Ensure log levels are appropriate: `.error` for failures, `.warning` for recoverable issues, `.info` for lifecycle
  - **Files**: All files modified in Phase 1
  - **Done when**: Consistent logging categories, appropriate log levels
  - **Verify**: `grep -rn 'AppLogger.shared' ILSApp/ILSApp/ --include='*.swift' | grep -oP 'category: "\K[^"]+' | sort -u` shows clean category list
  - **Commit**: `refactor(logging): normalize AppLogger categories`
  - _Design: Technical Decisions table_

- [x] 2.2 Verify all Task cancellation paths are complete
  - **Do**:
    1. Check every `Task<Void, Never>?` property has matching cancel in deinit/onDisappear
    2. Verify ChatViewModel.deinit cancels `batchTask` + clears `cancellables`
    3. Verify TunnelSettingsView.onDisappear cancels `toastTask`
    4. Verify ChatView.onDisappear cancels `scrollTask`
    5. Ensure all Task loops check `Task.isCancelled` before mutations
  - **Files**: `ChatViewModel.swift`, `TunnelSettingsView.swift`, `ChatView.swift`
  - **Done when**: Every Task property has matching cleanup
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E '(BUILD SUCCEEDED|error:)'`
  - **Commit**: `refactor(memory): verify Task cancellation paths`
  - _Requirements: FR-5, FR-6 | AC-2.1, AC-2.2_

- [x] 2.3 [VERIFY] Quality checkpoint: clean build after refactoring
  - **Do**: Full clean build to verify refactoring introduced no issues
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:)'`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(audit): pass quality checkpoint after refactoring` (only if fixes needed)

## Phase 3: Testing (Functional Validation)

Per FUNCTIONAL VALIDATION MANDATE: no mocks, no test files — real app, real simulator, real evidence.

- [x] 3.1 Build and install on simulator
  - **Do**:
    1. Boot simulator: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14` (if not booted)
    2. Clean build and install: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build`
    3. Install: `xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app`
    4. Launch: `xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app`
  - **Done when**: App launches successfully on simulator
  - **Verify**: `xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app` exits 0
  - **Commit**: None (validation only)

- [x] 3.2 Capture evidence screenshots (6 key screens)
  - **Do**:
    1. Start backend: `cd <project-root> && PORT=9090 swift run ILSBackend &`
    2. Wait for backend health: `curl -s http://localhost:9090/api/v1/health | head -1`
    3. Navigate to each screen and capture via `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot`:
       - `specs/remaining-audit-fixes/evidence/audit-fix-01-dashboard.png` — Dashboard
       - `specs/remaining-audit-fixes/evidence/audit-fix-02-sessions.png` — Sessions list (verify status indicators have icons)
       - `specs/remaining-audit-fixes/evidence/audit-fix-03-chat.png` — Chat view
       - `specs/remaining-audit-fixes/evidence/audit-fix-04-system.png` — System monitor
       - `specs/remaining-audit-fixes/evidence/audit-fix-05-settings.png` — Settings
       - `specs/remaining-audit-fixes/evidence/audit-fix-06-tunnel.png` — Tunnel settings (verify toggle labels)
    4. Read each screenshot to verify content matches expectations
  - **Files**: `specs/remaining-audit-fixes/evidence/` (6 new screenshots)
  - **Done when**: 6 screenshots captured and verified, no visual regressions
  - **Verify**: `ls specs/remaining-audit-fixes/evidence/audit-fix-*.png | wc -l` returns 6
  - **Commit**: `chore(audit): capture validation evidence screenshots`
  - _Requirements: NFR-4 | Success Criteria: visual evidence_

- [x] 3.3 [VERIFY] Functional spot-checks via automated verification
  - **Do**:
    1. Verify no `print()` output in Console: `grep -rn 'print(' ILSApp/ILSApp/ --include='*.swift' | grep -v AppLogger | grep -v '//' | grep -v 'debugPrint'`
    2. Verify all `nonisolated` markers: `grep -rn 'nonisolated' ILSApp/ILSApp/ --include='*.swift' | wc -l` (expect 5+)
    3. Verify SessionFormatters exists: `grep -rn 'SessionFormatters' ILSApp/ILSApp/ --include='*.swift'`
    4. Verify exponential backoff: `grep '1 <<' ILSApp/ILSApp/Services/SSEClient.swift`
    5. Verify WebSocket reset: `grep 'wsResetInterval' ILSApp/ILSApp/Services/MetricsWebSocketClient.swift`
    6. Verify StatusBadge has icon: `grep -A5 'struct StatusBadge' ILSApp/ILSApp/Theme/ILSTheme.swift | grep 'Image'`
    7. Verify zero Timer.scheduledTimer: `grep -rn 'Timer.scheduledTimer' ILSApp/ILSApp/ --include='*.swift' | wc -l` returns 0
    8. Verify zero URLSession.shared in ViewModels: `grep -rn 'URLSession.shared' ILSApp/ILSApp/ViewModels/ --include='*.swift' | wc -l` returns 0
  - **Done when**: All automated checks pass
  - **Verify**: All grep commands above return expected results
  - **Commit**: None (validation only)

## Phase 4: Quality Gates

- [ ] 4.1 [VERIFY] Full local CI: clean build with strict warnings
  - **Do**:
    1. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*`
    2. Build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' clean build 2>&1 | tail -20`
    3. Check for warnings: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep 'warning:' | grep -v 'deprecated' | head -20`
  - **Verify**: BUILD SUCCEEDED, zero new warnings (pre-existing deprecation warnings OK)
  - **Done when**: Build succeeds, no new warnings introduced
  - **Commit**: `fix(audit): address any remaining warnings` (only if fixes needed)

- [ ] 4.2 Create PR and verify CI
  - **Do**:
    1. Verify on feature branch: `git branch --show-current` (should be `design/v2-redesign`)
    2. Stage all modified files: `git add ILSApp/ILSApp/`
    3. Push: `git push -u origin design/v2-redesign`
    4. Create PR: `gh pr create --title "fix(audit): resolve 21 MEDIUM+LOW severity audit issues" --body "..."`
  - **Verify**: `gh pr checks --watch` — all checks green
  - **Done when**: PR created, CI passes
  - **If CI fails**: Read failure details, fix locally, push, re-verify

- [ ] 4.3 [VERIFY] AC checklist: all acceptance criteria met
  - **Do**: Verify each acceptance criterion programmatically:
    1. AC-1.1 (URLSession per VM): `grep -rn 'URLSession.shared' ILSApp/ILSApp/ViewModels/ | wc -l` = 0
    2. AC-1.3 (nonisolated coders): `grep -rn 'nonisolated' ILSApp/ILSApp/ --include='*.swift' | wc -l` >= 5
    3. AC-1.4 (no print): `grep -rn 'print(' ILSApp/ILSApp/ --include='*.swift' | grep -v AppLogger | grep -v '//' | wc -l` = 0
    4. AC-2.1 (Task timer): `grep -rn 'Timer.scheduledTimer' ILSApp/ILSApp/ --include='*.swift' | wc -l` = 0
    5. AC-2.3 (cancellables): `grep 'cancellables.removeAll' ILSApp/ILSApp/ViewModels/ChatViewModel.swift` matches
    6. AC-3.1 (no didSet): `grep -n 'didSet' ILSApp/ILSApp/ILSAppApp.swift ILSApp/ILSApp/ViewModels/SkillsViewModel.swift | grep -v '//' | wc -l` = 0
    7. AC-3.2 (formatters): `grep 'SessionFormatters' ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` matches
    8. AC-4.1 (theme fonts): `grep -rn '.font(.system(size:' ILSApp/ILSApp/ --include='*.swift' | wc -l` <= 2 (documented exceptions only)
    9. AC-5.1 (scoped cache): `grep 'invalidateCacheForMutation' ILSApp/ILSApp/Services/APIClient.swift` matches
    10. AC-5.3 (exp backoff): `grep '1 <<' ILSApp/ILSApp/Services/SSEClient.swift` matches
    11. AC-5.4 (WS reset): `grep 'wsResetInterval' ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` matches
    12. AC-6.1 (a11y labels): `grep 'accessibilityLabel' ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` matches
    13. AC-6.3 (status icons): `grep -A3 'StatusBadge' ILSApp/ILSApp/Theme/ILSTheme.swift | grep 'icon'` matches
  - **Verify**: All grep commands return expected values
  - **Done when**: All 13 AC checks confirmed met via automated verification
  - **Commit**: None

## Phase 5: PR Lifecycle

- [ ] 5.1 Monitor CI and fix failures
  - **Do**:
    1. Check PR status: `gh pr checks`
    2. If failures: read logs, fix, push
    3. Re-check: `gh pr checks --watch`
  - **Done when**: All CI checks green
  - **Verify**: `gh pr checks` shows all passing

- [ ] 5.2 Address review comments
  - **Do**:
    1. Check for review comments: `gh pr view --comments`
    2. Address any requested changes
    3. Push fixes
  - **Done when**: No outstanding review comments
  - **Verify**: `gh pr view --json reviewDecision -q .reviewDecision` shows APPROVED or empty

- [ ] 5.3 [VERIFY] Final validation: zero regressions, all ACs met
  - **Do**:
    1. Re-run full AC checklist from 4.3
    2. Verify evidence screenshots still valid
    3. Confirm clean build
  - **Verify**: All Phase 4.3 checks still pass
  - **Done when**: PR ready for merge with all criteria met
  - **Commit**: None

## Notes

- **POC shortcuts**: Phase 1 applies all fixes directly without separate MEDIUM/LOW phases since all are safe incremental refactors with low regression risk
- **Actual font count**: Only 6 hardcoded `.font(.system(size:))` found (not 10 as audited) — many were fixed in ios-app-polish2
- **DashboardViewModel URLSession**: Design listed M-CONC-1 for DashboardViewModel but grep shows it does NOT use URLSession.shared (uses APIClient). Skipped from tasks
- **DispatchQueue.asyncAfter**: Found in 9 locations across 8 files, but design only scoped TunnelSettingsView and ChatView. Others (SkillsListView, SessionInfoView, ProjectDetailView, MessageView, CodeBlockView, ILSTheme.showToast) are toast patterns — same fix pattern but out of original scope. Can be addressed in follow-up
- **FileBrowserView**: Uses `URLSession.shared` (line 15) but was not in audit scope. Follow-up candidate
- **StatusBadge**: Only used by MCPServerListView currently; SessionsListView and DashboardView use inline patterns. L-A11Y-1 fix focuses on StatusBadge component + any inline color-only circles in scoped files
- **Production TODOs**: Address remaining DispatchQueue.asyncAfter in 6 additional files, FileBrowserView URLSession.shared, Swift 6 strict concurrency mode enablement
