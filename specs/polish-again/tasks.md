---
spec: polish-again
phase: tasks
total_tasks: 52
created: 2026-02-07T20:30:00Z
---

# Tasks: ILS iOS Front-End Polish & Evidence-Based Validation

## Phase 1: Make It Work (POC) -- Critical Bug Fixes

Focus: Fix the 3 critical bugs and verify the app still builds and runs.

- [x] 1.1 Remove dead code from AppState: `isServerConnected` and `serverConnectionInfo`
  - **Do**:
    1. Open `ILSApp/ILSApp/ILSAppApp.swift`
    2. Delete line 46: `@Published var isServerConnected: Bool = false`
    3. Delete line 47: `@Published var serverConnectionInfo: ConnectionResponse?`
    4. Grep entire ILSApp directory for `isServerConnected` and `serverConnectionInfo` to confirm zero remaining references
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift`
  - **Done when**: Both properties removed, grep returns 0 matches, build succeeds
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -rn 'isServerConnected\|serverConnectionInfo' ILSApp/ILSApp/ | grep -v '\.build/' | wc -l` returns 0
  - **Commit**: `fix(app): remove dead isServerConnected and serverConnectionInfo properties`
  - _Requirements: FR-C1, FR-C2, AC-1.2, AC-1.3_
  - _Design: Phase 1 step 1_

- [x] 1.2 Fix ThemePickerView theme ID mismatches + add UserDefaults migration
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift`
    2. Line 20: change `id: "ghost"` to `id: "ghost-protocol"`
    3. Line 22: change `id: "electric"` to `id: "electric-grid"`
    4. Open `ILSApp/ILSApp/Theme/AppTheme.swift`, find ThemeManager.init()
    5. Add migration code at the start of init: if stored theme ID is "ghost" map to "ghost-protocol", if "electric" map to "electric-grid", persist the corrected value
  - **Files**: `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift`, `ILSApp/ILSApp/Theme/AppTheme.swift`
  - **Done when**: ThemePreview.all uses correct IDs "ghost-protocol" and "electric-grid"; ThemeManager.init() migrates legacy IDs
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -n '"ghost"' ILSApp/ILSApp/Views/Settings/ThemePickerView.swift | grep -v ghost-protocol | wc -l` returns 0 && `grep -n '"electric"' ILSApp/ILSApp/Views/Settings/ThemePickerView.swift | grep -v electric-grid | wc -l` returns 0
  - **Commit**: `fix(theme): correct Ghost Protocol and Electric Grid theme IDs with UserDefaults migration`
  - _Requirements: FR-C3, AC-1.1_
  - _Design: Theme Fix Design, ThemePickerView ID Fix_

- [x] 1.3 [VERIFY] Build checkpoint after critical fixes
  - **Do**: Build the project and verify zero errors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(app): pass build checkpoint after critical fixes` (only if fixes needed)

## Phase 2: High Bug Fixes (P0)

- [x] 2.1 Replace 4 redundant APIClient(baseURL:) with self.apiClient in AppState
  - **Do**:
    1. Open `ILSApp/ILSApp/ILSAppApp.swift`
    2. Line 114 in `checkConnection()`: replace `let client = APIClient(baseURL: serverURL)` with `let client = self.apiClient`, then use `client` as before
    3. Line 150 in `startRetryPolling()`: replace `let client = APIClient(baseURL: currentURL)` with using `self.apiClient`
    4. Line 180 in `startHealthPolling()`: replace `let client = APIClient(baseURL: currentURL)` with using `self.apiClient`
    5. Line 218 in `connectToServer()`: replace `let client = APIClient(baseURL: cleanURL)` -- note this one uses a different URL, so create client with cleanURL BEFORE calling updateServerURL, or call healthCheck on the new apiClient AFTER updateServerURL
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift`
  - **Done when**: Grep for `APIClient(baseURL:` in ILSAppApp.swift shows only lines 79 (init) and 95 (updateServerURL)
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -n 'APIClient(baseURL:' ILSApp/ILSApp/ILSAppApp.swift | wc -l` returns exactly 2 (init + updateServerURL)
  - **Commit**: `fix(app): use self.apiClient instead of creating redundant APIClient instances`
  - _Requirements: FR-H1, AC-2.1_
  - _Design: Phase 2 step 5_

- [x] 2.2 Delete EntityType.color and EntityType.gradient dead code
  - **Do**:
    1. Open `ILSApp/ILSApp/Theme/EntityType.swift`
    2. Delete the `var color: Color` computed property (lines 15-24)
    3. Delete the `var gradient: LinearGradient` computed property (lines 27-42)
    4. Keep `icon`, `displayName`, and `themeColor(from:)` intact
  - **Files**: `ILSApp/ILSApp/Theme/EntityType.swift`
  - **Done when**: EntityType.swift contains only `icon`, `displayName`, `themeColor(from:)`. No callers existed (confirmed via grep)
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -n 'var color:\|var gradient:' ILSApp/ILSApp/Theme/EntityType.swift | wc -l` returns 0
  - **Commit**: `refactor(theme): remove dead EntityType.color and .gradient properties`
  - _Requirements: FR-H4, AC-2.4_
  - _Design: EntityType Color Unification_

- [x] 2.3 Fix StreamingIndicatorView timer leak -- replace Timer with Task
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift`
    2. Add `@State private var animationTask: Task<Void, Never>?` property
    3. Replace `startAnimation()` method: instead of `Timer.scheduledTimer`, create a `Task` that loops with `Task.sleep(for: .milliseconds(400))` and updates `animatingDot`
    4. In `animatedDots`, change `.onAppear { startAnimation() }` to `.onAppear { startAnimation() }.onDisappear { animationTask?.cancel(); animationTask = nil }`
    5. The Task version naturally handles cancellation via `Task.isCancelled` check
  - **Files**: `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift`
  - **Done when**: No `Timer.scheduledTimer` in file; Task cancels on disappear
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -n 'Timer.scheduledTimer' ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift | wc -l` returns 0
  - **Commit**: `fix(chat): replace Timer with Task-based animation in StreamingIndicatorView`
  - _Requirements: FR-H6, AC-2.6_
  - _Design: StreamingIndicatorView Timer Leak Fix_

- [x] 2.4 Fix SystemMonitorView WebSocket recreation + CodeBlockView light theme
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/System/SystemMonitorView.swift`
    2. Line 125: wrap the `MetricsWebSocketClient` creation in a guard -- only create new client if URL changed: `if viewModel.metricsClient == nil || viewModel.metricsBaseURL != appState.serverURL { ... }`
    3. Add a `metricsBaseURL: String` tracking property to SystemMetricsViewModel or use a local check
    4. Open `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift`
    5. Add `@Environment(\.theme) private var theme: any AppTheme` if not present
    6. Change the `.task { await performHighlight() }` to `.task { await performHighlight(isLight: theme.isLight) }`
    7. Update `performHighlight` signature to accept `isLight: Bool` parameter
    8. Line 126: change `.dark(.xcode)` to `isLight ? .light(.xcode) : .dark(.xcode)`
  - **Files**: `ILSApp/ILSApp/Views/System/SystemMonitorView.swift`, `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift`
  - **Done when**: WebSocket client reuses existing connection; CodeBlockView uses light highlighting on light themes
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -n 'isLight' ILSApp/ILSApp/Theme/Components/CodeBlockView.swift | wc -l` returns at least 1 && `grep -c '.dark(.xcode)' ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` returns 0
  - **Commit**: `fix(system,theme): guard WebSocket recreation, fix CodeBlockView light theme highlighting`
  - _Requirements: FR-H7, FR-H8, AC-2.7, AC-2.8_
  - _Design: SystemMonitorView WebSocket Fix, CodeBlockView Light Theme Fix_

- [x] 2.5 Rename APIErrorResponse to APIErrorDetail + add doc comment
  - **Do**:
    1. Open `ILSApp/ILSApp/Services/APIClient.swift`
    2. Find `struct APIErrorResponse: Decodable` (line ~214) and rename to `APIErrorDetail`
    3. Find the reference on line ~211 (`let error: APIErrorResponse?`) and rename to `APIErrorDetail`
    4. Add a doc comment explaining the intentional separation: ILSApp's APIResponse/APIError are for app-side decoding; ILSShared's are for shared encoding. Different requirements (Decodable vs Codable & Sendable).
    5. Grep for any other `APIErrorResponse` references in ILSApp and update them
  - **Files**: `ILSApp/ILSApp/Services/APIClient.swift`
  - **Done when**: No `APIErrorResponse` in codebase; `APIErrorDetail` used instead; doc comment present
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -rn 'APIErrorResponse' ILSApp/ILSApp/ | wc -l` returns 0
  - **Commit**: `refactor(api): rename APIErrorResponse to APIErrorDetail with documentation`
  - _Requirements: FR-H5, AC-2.5_
  - _Design: APIResponse/APIError Unification_

- [x] 2.6 [VERIFY] Build checkpoint after high-priority fixes
  - **Do**: Build the project and verify zero errors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED with zero errors
  - **Commit**: `chore(app): pass build checkpoint after high-priority fixes` (only if fixes needed)

## Phase 3: AppState Decomposition (P0)

- [x] 3.1 Create ConnectionManager.swift -- extract connection state from AppState
  - **Do**:
    1. Create `ILSApp/ILSApp/Services/ConnectionManager.swift`
    2. Move from AppState: `isConnected`, `serverURL`, `showOnboarding`, `apiClient`, `sseClient`, `isInitialized`
    3. Move methods: `updateServerURL(_:)`, `connectToServer(url:)`, `showOnboardingIfNeeded()`
    4. Move init() logic (URL loading from UserDefaults, client creation) into ConnectionManager.init()
    5. ConnectionManager is `@MainActor class: ObservableObject` with `@Published` properties
  - **Files**: `ILSApp/ILSApp/Services/ConnectionManager.swift` (create)
  - **Done when**: ConnectionManager owns connection state, URL persistence, client lifecycle
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/ConnectionManager.swift && echo "EXISTS"`
  - **Commit**: `refactor(app): create ConnectionManager extracted from AppState`
  - _Requirements: FR-H2, AC-2.2_
  - _Design: ConnectionManager component_

- [x] 3.2 Create PollingManager.swift -- extract polling logic from AppState
  - **Do**:
    1. Create `ILSApp/ILSApp/Services/PollingManager.swift`
    2. Move from AppState: `retryTask`, `healthPollTask`
    3. Move methods: `checkConnection()`, `startRetryPolling()`, `stopRetryPolling()`, `startHealthPolling()`, `stopHealthPolling()`, `handleScenePhase(_:)`
    4. PollingManager takes `weak var connectionManager: ConnectionManager?` in init
    5. Uses `connectionManager?.apiClient` for health checks (fixes FR-H1 at this level too)
    6. Updates `connectionManager?.isConnected` on success/failure
  - **Files**: `ILSApp/ILSApp/Services/PollingManager.swift` (create)
  - **Done when**: PollingManager owns all polling tasks and scene phase handling
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/PollingManager.swift && echo "EXISTS"`
  - **Commit**: `refactor(app): create PollingManager extracted from AppState`
  - _Requirements: FR-H2, AC-2.2_
  - _Design: PollingManager component_

- [x] 3.3 Slim AppState to coordinator with forwarding properties
  - **Do**:
    1. Open `ILSApp/ILSApp/ILSAppApp.swift`
    2. Remove all extracted code from AppState
    3. Add `let connectionManager: ConnectionManager` and `let pollingManager: PollingManager` properties
    4. In AppState.init(): create ConnectionManager, then PollingManager(connectionManager:), call pollingManager.checkConnection()
    5. Add forwarding computed properties for backward compatibility:
       - `var isConnected: Bool { connectionManager.isConnected }`
       - `var apiClient: APIClient { connectionManager.apiClient }`
       - `var sseClient: SSEClient { connectionManager.sseClient }`
       - `var serverURL: String { connectionManager.serverURL }`
       - `var showOnboarding: Bool { get { connectionManager.showOnboarding } set { connectionManager.showOnboarding = newValue } }`
    6. Keep: `selectedProject`, `selectedTab`, `navigationIntent`, `lastSessionId`, `isOffline`, `updateLastSessionId(_:)`, `handleURL(_:)`
    7. Forward `handleScenePhase(_:)` to `pollingManager.handleScenePhase(_:)`
    8. Forward `updateServerURL(_:)` to `connectionManager.updateServerURL(_:)`
    9. Forward `connectToServer(url:)` to `connectionManager.connectToServer(url:)`
    10. Forward `checkConnection()` to `pollingManager.checkConnection()`
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift`
  - **Done when**: AppState is <150 lines, delegates to ConnectionManager and PollingManager
  - **Verify**: `wc -l /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ILSAppApp.swift | awk '{print ($1 < 150) ? "PASS" : "FAIL: " $1 " lines"}'`
  - **Commit**: `refactor(app): slim AppState to thin coordinator with forwarding properties`
  - _Requirements: FR-H2, AC-2.2_
  - _Design: AppState Simplified_

- [x] 3.4 [VERIFY] Build + navigation checkpoint after AppState decomposition
  - **Do**:
    1. Build the project
    2. Install on simulator
    3. Launch and verify app opens to home screen
    4. Capture screenshot as evidence
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED, app launches on simulator
  - **Commit**: `chore(app): pass build checkpoint after AppState decomposition` (only if fixes needed)

## Phase 4: SettingsView Split (P0)

- [x] 4.1 Extract ConfigEditorViewModel to separate file
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
    2. Find `ConfigEditorViewModel` class (starts ~line 858, ends ~908)
    3. Cut the entire class
    4. Create `ILSApp/ILSApp/ViewModels/ConfigEditorViewModel.swift`
    5. Paste with `import SwiftUI` and `import ILSShared` at top
    6. Verify SettingsView.swift still compiles (ConfigEditorView references ConfigEditorViewModel)
  - **Files**: `ILSApp/ILSApp/ViewModels/ConfigEditorViewModel.swift` (create), `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (modify)
  - **Done when**: ConfigEditorViewModel in separate file, SettingsView.swift compiles
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/ConfigEditorViewModel.swift && echo "EXISTS"`
  - **Commit**: `refactor(settings): extract ConfigEditorViewModel to separate file`
  - _Requirements: FR-H3, AC-2.3_
  - _Design: SettingsView Split Design_

- [x] 4.2 Extract SettingsViewModel to separate file
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
    2. Find `SettingsViewModel` class (starts ~line 756, ends ~856)
    3. Cut the entire class
    4. Create `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift`
    5. Paste with `import SwiftUI` and `import ILSShared` at top
  - **Files**: `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` (create), `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (modify)
  - **Done when**: SettingsViewModel in separate file
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/SettingsViewModel.swift && echo "EXISTS"`
  - **Commit**: `refactor(settings): extract SettingsViewModel to separate file`
  - _Requirements: FR-H3, AC-2.3_
  - _Design: SettingsView Split Design_

- [x] 4.3 Extract ConfigEditorView to separate file
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
    2. Find `ConfigEditorView` struct (starts ~line 639, ends ~751)
    3. Cut the entire struct
    4. Create `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift`
    5. Paste with `import SwiftUI` and `import ILSShared` at top
    6. ConfigEditorView uses ConfigEditorViewModel (already extracted)
  - **Files**: `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift` (create), `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (modify)
  - **Done when**: ConfigEditorView in separate file, SettingsView.swift is only the SettingsView struct + helper extensions
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift && echo "EXISTS"`
  - **Commit**: `refactor(settings): extract ConfigEditorView to separate file`
  - _Requirements: FR-H3, AC-2.3_
  - _Design: SettingsView Split Design_

- [x] 4.4 [VERIFY] Build + SettingsView line count checkpoint
  - **Do**:
    1. Build the project
    2. Verify SettingsView.swift is now <300 lines
    3. Verify all 4 files exist and build
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5` && `wc -l ILSApp/ILSApp/Views/Settings/SettingsView.swift | awk '{print ($1 < 300) ? "PASS" : "FAIL: " $1}'`
  - **Done when**: BUILD SUCCEEDED, SettingsView.swift <300 lines
  - **Commit**: `chore(settings): pass build checkpoint after SettingsView split` (only if fixes needed)

## Phase 5: Medium Bug Fixes (P1)

- [x] 5.1 Wire or remove SidebarView "Phase X" placeholder comments
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Root/SidebarView.swift`
    2. Line 169: `// Rename -- wired in Phase 3` -- check if rename button action actually works (calls rename endpoint). If yes, remove comment. If no, wire it up or remove the button.
    3. Line 174: `// Export -- wired in Phase 3` -- same check for export functionality
    4. Line 237: `// New session -- wired in Phase 5` -- same check for new session button
    5. Replace comments with actual implementation notes or remove entirely
  - **Files**: `ILSApp/ILSApp/Views/Root/SidebarView.swift`
  - **Done when**: Zero "wired in Phase" comments in SidebarView.swift
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'wired in Phase' ILSApp/ILSApp/Views/Root/SidebarView.swift` returns 0
  - **Commit**: `fix(sidebar): wire or remove Phase placeholder comments`
  - _Requirements: FR-M1, AC-3.1_
  - _Design: Phase 5 step 22_

- [x] 5.2 Extract ShareSheet to shared file + remove duplicates
  - **Do**:
    1. Create directory `ILSApp/ILSApp/Views/Shared/` if it doesn't exist
    2. Create `ILSApp/ILSApp/Views/Shared/ShareSheet.swift`
    3. Move the `ShareSheet: UIViewControllerRepresentable` struct from `SessionInfoView.swift` (line ~178) to the new file
    4. Remove the inline ShareSheet definition from `SessionInfoView.swift`
    5. ChatView.swift already references `ShareSheet` by name without defining it locally -- verify it compiles using the shared definition
    6. Add `import SwiftUI` and `import UIKit` to new file
  - **Files**: `ILSApp/ILSApp/Views/Shared/ShareSheet.swift` (create), `ILSApp/ILSApp/Views/Sessions/SessionInfoView.swift` (modify)
  - **Done when**: Single ShareSheet definition in shared file; both views compile
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -rn 'struct ShareSheet' ILSApp/ILSApp/ | wc -l` returns 1
  - **Commit**: `refactor(views): extract ShareSheet to shared file, remove duplicate`
  - _Requirements: FR-M2, AC-3.2_
  - _Design: Phase 5 step 23_

- [x] 5.3 Delete dead code: BaseListViewModel.swift and ThemeManager.swift
  - **Do**:
    1. Delete `ILSApp/ILSApp/ViewModels/BaseListViewModel.swift` (35 lines, never inherited)
    2. Delete `ILSApp/ILSApp/Theme/ThemeManager.swift` (3-line redirect comment, real ThemeManager is in AppTheme.swift)
    3. Remove both from Xcode project if needed (may auto-detect)
  - **Files**: `ILSApp/ILSApp/ViewModels/BaseListViewModel.swift` (delete), `ILSApp/ILSApp/Theme/ThemeManager.swift` (delete)
  - **Done when**: Both files deleted, build succeeds
  - **Verify**: `test ! -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/BaseListViewModel.swift && test ! -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Theme/ThemeManager.swift && echo "DELETED"`
  - **Commit**: `refactor(app): delete dead BaseListViewModel and empty ThemeManager redirect`
  - _Requirements: FR-M3, FR-M4, AC-3.3, AC-3.4_
  - _Design: Phase 5 steps 24-25_

- [x] 5.4 Consolidate ConnectionBanner struct + modifier duplicate UI
  - **Do**:
    1. Open `ILSApp/ILSApp/Theme/Components/ConnectionBanner.swift`
    2. The file has `ConnectionBanner` struct (lines 5-54) AND `ConnectionBannerModifier` (lines 57+) with duplicated HStack UI
    3. Keep `ConnectionBanner` as the standalone view component with the HStack UI
    4. Refactor `ConnectionBannerModifier` to USE `ConnectionBanner` inside its `safeAreaInset` instead of duplicating the HStack
    5. ConnectionBannerModifier keeps its `@State` management and `.onChange` auto-dismiss logic
  - **Files**: `ILSApp/ILSApp/Theme/Components/ConnectionBanner.swift`
  - **Done when**: Single HStack definition; modifier delegates to ConnectionBanner struct
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'Reconnecting' ILSApp/ILSApp/Theme/Components/ConnectionBanner.swift` returns 1 (was 2)
  - **Commit**: `refactor(ui): consolidate ConnectionBanner duplicate HStack UI`
  - _Requirements: FR-M5, AC-3.5_
  - _Design: ConnectionBanner Consolidation_

- [x] 5.5 [VERIFY] Build checkpoint after medium fixes batch 1
  - **Do**: Build the project
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED
  - **Commit**: `chore(app): pass build checkpoint after medium fixes batch 1` (only if fixes needed)

- [x] 5.6 Share ViewModels between HomeView and SidebarView (SKIPPED - unsafe without parent injection)
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Home/HomeView.swift`
    2. Lines 8-9: change `@StateObject private var dashboardVM = DashboardViewModel()` and `@StateObject private var sessionsVM = SessionsViewModel()` to `@EnvironmentObject var dashboardVM: DashboardViewModel` and `@EnvironmentObject var sessionsVM: SessionsViewModel`
    3. Inject these from the parent (SidebarRootView or wherever HomeView is created)
    4. Verify SidebarView already creates these VMs and they can be shared
  - **Files**: `ILSApp/ILSApp/Views/Home/HomeView.swift`, potentially `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
  - **Done when**: HomeView receives VMs via injection, no duplicate `= SessionsViewModel()` or `= DashboardViewModel()` in HomeView
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'SessionsViewModel()' ILSApp/ILSApp/Views/Home/HomeView.swift` returns 0 && `grep -c 'DashboardViewModel()' ILSApp/ILSApp/Views/Home/HomeView.swift` returns 0
  - **Commit**: `refactor(home): share ViewModels with SidebarView via injection`
  - _Requirements: FR-M6, AC-3.6_
  - _Design: Phase 5 step 27_

- [x] 5.7 Fix ServerSetupSheet to use AppState's APIClient + persist notification preferences
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`
    2. Line 458: replace standalone `let client = APIClient(baseURL: url)` with using `appState.apiClient` or calling `appState.connectToServer(url:)` which already validates and persists
    3. Open `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift`
    4. Replace all `@State` toggles (lines 7-10) with `@AppStorage`:
       - `@AppStorage("notif_mcp_offline") private var mcpOfflineAlerts = true`
       - `@AppStorage("notif_mcp_online") private var mcpOnlineAlerts = false`
       - `@AppStorage("notif_session_complete") private var sessionCompleteAlerts = true`
       - `@AppStorage("notif_quiet_hours") private var quietHoursEnabled = false`
  - **Files**: `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`, `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift`
  - **Done when**: ServerSetupSheet uses AppState's client; notification toggles persist via @AppStorage
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'APIClient(baseURL:' ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` returns 0 && `grep -c '@AppStorage' ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift` returns 4
  - **Commit**: `fix(onboarding,settings): use shared APIClient, persist notification preferences`
  - _Requirements: FR-M7, FR-M8, AC-3.7, AC-3.8_
  - _Design: Phase 5 steps 28-29_

- [x] 5.8 Fix FileBrowserView to use APIClient instead of raw URLSession
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/System/FileBrowserView.swift`
    2. Line 17: remove `private let session = URLSession.shared`
    3. Add `@EnvironmentObject var appState: AppState` if not present
    4. Replace URLSession-based fetch calls (lines ~248-260) with `appState.apiClient.get("/system/files?path=\(encodedPath)")`
    5. Note: APIClient auto-prepends `/api/v1` so use relative path `/system/files?path=...` not full URL
    6. Handle response using existing APIClient pattern
  - **Files**: `ILSApp/ILSApp/Views/System/FileBrowserView.swift`
  - **Done when**: Zero `URLSession.shared` in FileBrowserView; uses APIClient for all requests
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'URLSession.shared' ILSApp/ILSApp/Views/System/FileBrowserView.swift` returns 0
  - **Commit**: `fix(system): use APIClient instead of raw URLSession in FileBrowserView`
  - _Requirements: FR-M10, AC-3.10_
  - _Design: Phase 5 step 30_

- [x] 5.9 [VERIFY] Build checkpoint after medium fixes batch 2
  - **Do**: Build the project
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED
  - **Commit**: `chore(app): pass build checkpoint after medium fixes batch 2` (only if fixes needed)

## Phase 6: Model Unification (P1)

- [ ] 6.1 Replace MCPServerItem with MCPServer from ILSShared
  - **Do**:
    1. First verify backend JSON matches MCPServer enum raw values: `curl -s http://localhost:9090/api/v1/mcp | python3 -m json.tool | head -30`
    2. MCPServer (ILSShared) uses `MCPScope` and `MCPStatus` enums with String raw values ("user","project","local" and "healthy","unhealthy","unknown")
    3. MCPServer does NOT conform to Hashable -- add extension in MCPViewModel.swift: `extension MCPServer: Hashable { func hash(into hasher: inout Hasher) { hasher.combine(id) } static func == (lhs: MCPServer, rhs: MCPServer) -> Bool { lhs.id == rhs.id } }`
    4. Open `ILSApp/ILSApp/ViewModels/MCPViewModel.swift`: replace all `MCPServerItem` with `MCPServer`
    5. Open `ILSApp/ILSApp/Views/Browser/MCPServerDetailView.swift`: change `let server: MCPServerItem` to `let server: MCPServer`
    6. Open `ILSApp/ILSApp/Views/Browser/BrowserView.swift`: update any `MCPServerItem` references
    7. If scope/status are returned as strings that don't match enum raw values, add a custom decoder or fallback
    8. Delete `ILSApp/ILSApp/Models/MCPServerItem.swift`
  - **Files**: `ILSApp/ILSApp/ViewModels/MCPViewModel.swift`, `ILSApp/ILSApp/Views/Browser/MCPServerDetailView.swift`, `ILSApp/ILSApp/Views/Browser/BrowserView.swift`, `ILSApp/ILSApp/Models/MCPServerItem.swift` (delete)
  - **Done when**: MCPServerItem.swift deleted; all views use MCPServer from ILSShared; build succeeds
  - **Verify**: `test ! -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Models/MCPServerItem.swift && echo "DELETED"` && `cd /Users/nick/Desktop/ils-ios && grep -rn 'MCPServerItem' ILSApp/ILSApp/ | wc -l` returns 0
  - **Commit**: `refactor(models): unify MCPServerItem to MCPServer from ILSShared`
  - _Requirements: FR-DM1, AC-4.1_
  - _Design: MCPServerItem -> MCPServer migration_

- [ ] 6.2 Replace PluginItem with Plugin from ILSShared + delete PluginModels.swift
  - **Do**:
    1. Plugin (ILSShared) has superset of fields vs PluginItem -- direct drop-in replacement
    2. Open `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`: replace all `PluginItem` with `Plugin` (from ILSShared, already imported)
    3. Open `ILSApp/ILSApp/Views/Browser/BrowserView.swift` line 350: change `[PluginItem]` to `[Plugin]`
    4. Also delete `MarketplaceInfo` and `MarketplacePlugin` references if any -- ILSShared has `PluginMarketplace` and `PluginInfo`
    5. Delete `ILSApp/ILSApp/Models/PluginModels.swift`
  - **Files**: `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`, `ILSApp/ILSApp/Views/Browser/BrowserView.swift`, `ILSApp/ILSApp/Models/PluginModels.swift` (delete)
  - **Done when**: PluginModels.swift deleted; all views use Plugin from ILSShared; build succeeds
  - **Verify**: `test ! -f /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Models/PluginModels.swift && echo "DELETED"` && `cd /Users/nick/Desktop/ils-ios && grep -rn 'PluginItem\|MarketplaceInfo\|MarketplacePlugin' ILSApp/ILSApp/ | wc -l` returns 0
  - **Commit**: `refactor(models): unify PluginItem to Plugin from ILSShared`
  - _Requirements: FR-DM2, AC-4.2_
  - _Design: PluginItem -> Plugin migration_

- [ ] 6.3 Replace TunnelSettingsView private DTOs with ILSShared types
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
    2. Line 378: change `TunnelStatusDTO` to `TunnelStatusResponse`
    3. Lines 403-404: change `EmptyTunnelRequest()` to `TunnelStartRequest()` (all-nil defaults) and `TunnelStartDTO` to `TunnelStartResponse`
    4. Lines 427-428: change `EmptyTunnelRequest()` to `TunnelStartRequest()` (or an empty Encodable) and `TunnelStopDTO` to `TunnelStopResponse`
    5. Delete private structs at bottom of file (lines 479-496): `TunnelStatusDTO`, `TunnelStartDTO`, `TunnelStopDTO`, `EmptyTunnelRequest`
    6. ILSShared is already imported at top of file
  - **Files**: `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
  - **Done when**: Private DTO structs deleted; ILSShared types used; build succeeds
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'private struct Tunnel\|EmptyTunnelRequest' ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` returns 0
  - **Commit**: `refactor(tunnel): replace private DTOs with ILSShared types`
  - _Requirements: FR-DM4, FR-M9, AC-3.9, AC-4.4_
  - _Design: TunnelSettingsView DTOs migration_

- [ ] 6.4 [VERIFY] Build checkpoint after model unification
  - **Do**: Build the project
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED
  - **Commit**: `chore(app): pass build checkpoint after model unification` (only if fixes needed)

## Phase 7: Low Polish (P2)

- [ ] 7.1 Fix textOnAccent contrast for Ghost Protocol and Electric Grid themes
  - **Do**:
    1. Open `ILSApp/ILSApp/Theme/Themes/GhostProtocolTheme.swift`
    2. Line 24: change `let textOnAccent = Color.white` to `let textOnAccent = Color(hex: "08080C")` (dark bgPrimary for contrast against cyan #7DF9FF accent)
    3. Open `ILSApp/ILSApp/Theme/Themes/ElectricGridTheme.swift`
    4. Line 24: change `let textOnAccent = Color.white` to `let textOnAccent = Color(hex: "050510")` (dark bgPrimary for contrast against green #00FF88 accent)
  - **Files**: `ILSApp/ILSApp/Theme/Themes/GhostProtocolTheme.swift`, `ILSApp/ILSApp/Theme/Themes/ElectricGridTheme.swift`
  - **Done when**: Both themes use dark text on their light accent colors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep 'textOnAccent' ILSApp/ILSApp/Theme/Themes/GhostProtocolTheme.swift ILSApp/ILSApp/Theme/Themes/ElectricGridTheme.swift | grep -c 'Color.white'` returns 0
  - **Commit**: `fix(theme): use dark textOnAccent for Ghost Protocol and Electric Grid`
  - _Requirements: FR-L2, AC-5.1_
  - _Design: textOnAccent Contrast Fix_

- [ ] 7.2 Fix Crimson accent + Ember warning color differentiation
  - **Do**:
    1. Open `ILSApp/ILSApp/Theme/Themes/CrimsonTheme.swift`
    2. Change accent from `#EF4444` to `#DC2626` (Tailwind red-700, deeper red distinct from error)
    3. Open `ILSApp/ILSApp/Theme/Themes/EmberTheme.swift`
    4. Change warning from `#EAB308` to `#FBBF24` (Tailwind amber-400, lighter amber distinct from accent #F59E0B)
  - **Files**: `ILSApp/ILSApp/Theme/Themes/CrimsonTheme.swift`, `ILSApp/ILSApp/Theme/Themes/EmberTheme.swift`
  - **Done when**: Crimson accent != error; Ember warning != accent (visually distinct)
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep 'accent.*=.*Color' ILSApp/ILSApp/Theme/Themes/CrimsonTheme.swift | grep -c 'DC2626'` returns 1 && `grep 'warning.*=.*Color' ILSApp/ILSApp/Theme/Themes/EmberTheme.swift | grep -c 'FBBF24'` returns 1
  - **Commit**: `fix(theme): differentiate Crimson accent from error, Ember warning from accent`
  - _Requirements: FR-L3, FR-L4, AC-5.2, AC-5.3_
  - _Design: Crimson/Ember color fixes_

- [ ] 7.3 Fix ChatInputBar onSubmit + token count label + sparkline label
  - **Do**:
    1. Open `ILSApp/ILSApp/Views/Chat/ChatView.swift`
    2. Line 450: review `.onSubmit` behavior. If it sends on Return key, either remove `.onSubmit` (let only the Send button trigger send) or change to require Cmd+Return. For multiline TextField, `.onSubmit` should probably be removed since Return inserts newline in multiline. If it's a single-line TextField with .onSubmit, that's OK.
    3. Open `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
    4. Line 429: where `streamTokenCount` is set via `currentMessage.text.count / 4`, find the UI label that displays this and prefix with "~" (e.g., "~{count} tokens")
    5. Open `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift`
    6. The sparkline data is synthetic from `generateSparkline(count:seed:)`. Add a comment documenting this is synthetic or add a "Sample Data" label in the StatCard that shows sparklines
  - **Files**: `ILSApp/ILSApp/Views/Chat/ChatView.swift`, `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`, `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift`
  - **Done when**: onSubmit reviewed and fixed; token count shows "~"; sparkline labeled or documented
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'Sample\|approximate\|~.*token' ILSApp/ILSApp/ViewModels/ChatViewModel.swift ILSApp/ILSApp/ViewModels/DashboardViewModel.swift | grep -v ':0$' | wc -l` returns at least 1
  - **Commit**: `fix(chat,dashboard): fix onSubmit, label token count approximate, document sparklines`
  - _Requirements: FR-L5, FR-L6, FR-L1, AC-5.4, AC-5.5, AC-5.7_
  - _Design: Phase 7 steps 41-44_

- [ ] 7.4 Document ILSCodeHighlighter as intentional passthrough
  - **Do**:
    1. Open `ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift`
    2. The struct is 18 lines and intentionally returns unstyled Text (MarkdownUI's CodeSyntaxHighlighter is synchronous, cannot use async Highlight framework)
    3. Expand the existing doc comment to explicitly state: "Inline code uses system monospaced font without syntax coloring. Fenced code blocks are handled by CodeBlockView which provides full async syntax highlighting via the Highlight framework."
    4. This is documentation-only, not a code fix
  - **Files**: `ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift`
  - **Done when**: Doc comment clearly explains the design decision
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -c 'CodeBlockView\|intentional\|Fenced' ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift` returns at least 1
  - **Commit**: `docs(theme): document ILSCodeHighlighter as intentional passthrough to CodeBlockView`
  - _Requirements: FR-L7, AC-5.6_
  - _Design: Phase 7 step 43_

- [ ] 7.5 [VERIFY] Build checkpoint after low polish
  - **Do**: Build the project
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -5`
  - **Done when**: BUILD SUCCEEDED
  - **Commit**: `chore(app): pass build checkpoint after low polish` (only if fixes needed)

## Phase 8: Chat Scenarios 1-4 (P0)

Prerequisites for ALL chat scenarios:
```bash
# Boot simulator
xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null; echo "Booted"
# Start backend
cd /Users/nick/Desktop/ils-ios && PORT=9090 swift run ILSBackend &
# Wait for backend
sleep 15 && curl -s http://localhost:9090/api/v1/health | head -1
# Build + install + launch
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3
xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app
xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app
sleep 3
```

- [ ] 8.1 CS1: Basic Send-Receive-Render
  - **Do**:
    1. Ensure backend running on 9090, app launched
    2. Navigate to an existing session via sidebar (use `idb ui describe-all` to find session row coordinates, then `idb ui tap X Y`)
    3. Type "What is 2+2?" in input bar (use `xcrun simctl io ... type-text` or `idb ui type` if available)
    4. Tap Send button
    5. Wait 15-30 seconds for Claude response
    6. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs1-chat-response.png`
    7. Verify screenshot shows response containing "4"
  - **Files**: Evidence only
  - **Done when**: Screenshot shows completed response with "4" visible; input bar cleared
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs1-chat-response.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS1 basic send-receive-render evidence captured`
  - _Requirements: FR-CS1, AC-6.1 through AC-6.7_
  - _Design: Chat Scenario 1_

- [ ] 8.2 CS2: Streaming Cancellation Mid-Response
  - **Do**:
    1. In the same or new session, type: "Write a detailed 500-word essay about quantum computing"
    2. Tap Send
    3. Wait 3-5 seconds for streaming to start (streaming indicator visible)
    4. Tap the Stop/Cancel button
    5. Wait 2 seconds for cancellation
    6. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs2-partial.png`
    7. Type follow-up: "Never mind, just say hello"
    8. Tap Send, wait for response
    9. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs2-followup.png`
  - **Files**: Evidence only
  - **Done when**: Screenshots show partial response + successful follow-up
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs2-partial.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs2-followup.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS2 streaming cancellation evidence captured`
  - _Requirements: FR-CS2, AC-7.1 through AC-7.7_
  - _Design: Chat Scenario 2_

- [ ] 8.3 CS3: Tool Call Rendering Chain
  - **Do**:
    1. In a session, type: "Read the file Package.swift and tell me what dependencies are used"
    2. Tap Send, wait 30-60 seconds for response with tool calls
    3. Verify ToolCallAccordion renders (expand if needed)
    4. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs3-tool-accordion.png`
    5. Verify screenshot shows accordion header, tool icon, file_path input, output content
  - **Files**: Evidence only
  - **Done when**: Screenshot shows expanded tool call accordion with inputs and output
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs3-tool-accordion.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS3 tool call rendering evidence captured`
  - _Requirements: FR-CS3, AC-8.1 through AC-8.7_
  - _Design: Chat Scenario 3_

- [ ] 8.4 CS4: Error Recovery After Backend Restart
  - **Do**:
    1. With app open and connected to backend
    2. Kill backend: `pkill -f 'ILSBackend' || kill $(lsof -ti:9090) 2>/dev/null`
    3. Wait 10 seconds for ConnectionBanner to appear
    4. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs4-disconnected.png`
    5. Restart backend: `cd /Users/nick/Desktop/ils-ios && PORT=9090 swift run ILSBackend &`
    6. Wait 15 seconds for health check to reconnect
    7. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs4-recovered.png`
    8. Send message "Are you still there?" and wait for response
    9. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs4-post-recovery.png`
  - **Files**: Evidence only
  - **Done when**: Screenshots show disconnected banner, recovery, and successful post-recovery message
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs4-disconnected.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs4-recovered.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS4 error recovery after backend restart evidence captured`
  - _Requirements: FR-CS4, AC-9.1 through AC-9.8_
  - _Design: Chat Scenario 4_

- [ ] 8.5 [VERIFY] Chat scenarios 1-4 evidence checkpoint
  - **Do**: Verify all 6 evidence screenshots exist and are non-empty
  - **Verify**: `cd /Users/nick/Desktop/ils-ios/specs/polish-again/evidence && ls -la cs1-*.png cs2-*.png cs3-*.png cs4-*.png 2>&1 | grep -c '.png'` returns at least 6
  - **Done when**: All P0 chat scenario evidence files present
  - **Commit**: none

## Phase 9: Chat Scenarios 5-10 (P1)

- [ ] 9.1 CS5: Session Fork and Navigate
  - **Do**:
    1. Open a session with 3+ messages
    2. Tap toolbar menu (3 dots) to open menu
    3. Tap "Fork Session"
    4. Capture screenshot of fork alert: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs5-fork-alert.png`
    5. Tap "Open Fork" in the alert
    6. Wait for navigation to forked session
    7. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs5-forked.png`
  - **Files**: Evidence only
  - **Done when**: Screenshots show fork alert and forked session
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs5-fork-alert.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs5-forked.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS5 session fork and navigate evidence captured`
  - _Requirements: FR-CS5, AC-10.1 through AC-10.7_

- [ ] 9.2 CS6: Rapid-Fire Message Sending
  - **Do**:
    1. Open a session
    2. Type "Message 1" and tap Send
    3. Immediately type "Message 2" and tap Send (before first response completes)
    4. Observe behavior: does input bar disable during streaming? Does second send get blocked?
    5. Wait for all responses to complete
    6. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs6-rapid.png`
    7. Document observed behavior in commit message
  - **Files**: Evidence only
  - **Done when**: Screenshot shows message sequence; behavior documented
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs6-rapid.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS6 rapid-fire message sending evidence captured`
  - _Requirements: FR-CS6, AC-11.1 through AC-11.6_

- [ ] 9.3 CS7: Theme Switching During Active Chat
  - **Do**:
    1. Open a chat with messages visible (Obsidian theme, the default)
    2. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs7-obsidian.png`
    3. Navigate to Settings > Theme > select Slate
    4. Return to chat
    5. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs7-slate.png`
    6. Navigate to Settings > Theme > select Paper (light theme)
    7. Return to chat
    8. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs7-paper.png`
    9. Verify code blocks are readable on Paper (light theme fix from task 2.4)
  - **Files**: Evidence only
  - **Done when**: 3 screenshots showing same chat in Obsidian, Slate, Paper themes
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs7-obsidian.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs7-paper.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS7 theme switching during active chat evidence captured`
  - _Requirements: FR-CS7, AC-12.1 through AC-12.7_

- [ ] 9.4 CS8: Long Message with Code Blocks and Thinking
  - **Do**:
    1. In a session, type: "Think step by step about how to implement a binary search tree in Swift, then show me the code"
    2. Tap Send, wait 60+ seconds for full response with thinking + code
    3. Scroll to ThinkingSection if visible, expand it
    4. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs8-thinking.png`
    5. Scroll to code blocks
    6. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs8-code.png`
  - **Files**: Evidence only
  - **Done when**: Screenshots show thinking section and syntax-highlighted code block
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs8-thinking.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs8-code.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS8 long message with code and thinking evidence captured`
  - _Requirements: FR-CS8, AC-13.1 through AC-13.7_

- [ ] 9.5 CS9: External Session Read-Only Browsing
  - **Do**:
    1. Check if backend has external sessions: `curl -s http://localhost:9090/api/v1/sessions | python3 -c "import sys,json; data=json.load(sys.stdin); ext=[s for s in data.get('data',data) if isinstance(s,dict) and s.get('source')=='external']; print(f'{len(ext)} external sessions found')" 2>/dev/null || echo "Check manually"`
    2. If external sessions exist: open sidebar, find one, tap to open
    3. Verify read-only indicator and disabled input
    4. If NO external sessions exist: document this in commit message as "no external sessions in backend data; CS9 requires external session test data"
    5. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs9-external.png`
  - **Files**: Evidence only
  - **Done when**: Screenshot captured or documented that no external sessions exist
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs9-external.png && echo "CAPTURED" || echo "NO_EXTERNAL_SESSIONS"`
  - **Commit**: `test(chat): CS9 external session read-only browsing evidence captured`
  - _Requirements: FR-CS9, AC-14.1 through AC-14.5_

- [ ] 9.6 CS10: Session Rename + Export + Info Sheet
  - **Do**:
    1. Open a session in ChatView
    2. Tap toolbar menu > Rename
    3. Enter "Test Renamed Session", confirm
    4. Capture screenshot of renamed session in sidebar: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs10-renamed.png`
    5. Tap menu > Session Info
    6. Capture screenshot of info sheet: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs10-info.png`
    7. Dismiss info, tap menu > Export
    8. Capture screenshot of share sheet: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs10-export.png`
  - **Files**: Evidence only
  - **Done when**: 3 screenshots showing rename, info sheet, export sheet
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs10-renamed.png && test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/cs10-info.png && echo "CAPTURED"`
  - **Commit**: `test(chat): CS10 session rename, export, info sheet evidence captured`
  - _Requirements: FR-CS10, AC-15.1 through AC-15.6_

- [ ] 9.7 [VERIFY] Chat scenarios 5-10 evidence checkpoint
  - **Do**: Verify all P1 chat scenario evidence screenshots exist
  - **Verify**: `cd /Users/nick/Desktop/ils-ios/specs/polish-again/evidence && ls -la cs5-*.png cs6-*.png cs7-*.png cs8-*.png cs10-*.png 2>&1 | grep -c '.png'` returns at least 10
  - **Done when**: All P1 chat scenario evidence files present
  - **Commit**: none

## Phase 10: Quality Gates

- [ ] 10.1 [VERIFY] Full local CI: clean build with zero warnings
  - **Do**:
    1. Build with full output to check for warnings: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E 'warning:|error:|BUILD' | tail -20`
    2. Fix any warnings found
    3. Capture clean build log: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tee /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/build-log.txt | tail -5`
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3 | grep -c 'BUILD SUCCEEDED'` returns 1
  - **Done when**: BUILD SUCCEEDED with zero warnings, zero errors
  - **Commit**: `fix(build): resolve all compiler warnings for clean build` (if fixes needed)
  - _Requirements: NFR-1, AC-2.9, AC-16.6_

- [ ] 10.2 Grep audit: dead code, duplicates, raw URLSession
  - **Do**:
    1. `grep -rn 'isServerConnected\|serverConnectionInfo' ILSApp/ILSApp/` -- expect 0 matches
    2. `grep -rn 'MCPServerItem\|PluginItem\|MarketplaceInfo\|MarketplacePlugin' ILSApp/ILSApp/` -- expect 0 matches
    3. `grep -rn 'URLSession.shared' ILSApp/ILSApp/Views/` -- expect 0 matches in Views
    4. `grep -rn 'APIErrorResponse' ILSApp/ILSApp/` -- expect 0 matches
    5. `grep -rn 'BaseListViewModel' ILSApp/ILSApp/` -- expect 0 matches
    6. `grep -rn 'wired in Phase' ILSApp/ILSApp/` -- expect 0 matches
    7. `grep -rn 'Timer.scheduledTimer' ILSApp/ILSApp/` -- expect 0 matches
    8. Fix any violations found
  - **Files**: Various (fix any violations)
  - **Done when**: All 7 grep audits return 0 matches
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && grep -rn 'isServerConnected\|MCPServerItem\|PluginItem\|APIErrorResponse\|BaseListViewModel\|wired in Phase\|Timer.scheduledTimer' ILSApp/ILSApp/ | grep -v '\.build/' | wc -l` returns 0
  - **Commit**: `chore(app): pass grep audit for dead code, duplicates, and violations` (if fixes needed)
  - _Requirements: NFR-4, NFR-5, NFR-6_

- [ ] 10.3 File size audit: no file >500 lines
  - **Do**:
    1. `find ILSApp/ILSApp -name '*.swift' -exec wc -l {} + | sort -rn | head -10`
    2. Verify no Swift file exceeds 500 lines
    3. If any exceed 500, they may need further splitting (but SettingsView was already split)
  - **Files**: Various
  - **Done when**: No Swift file in ILSApp/ exceeds 500 lines
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && find ILSApp/ILSApp -name '*.swift' -exec wc -l {} + | awk '$1 > 500 {print "FAIL: " $0}' | wc -l` returns 0
  - **Commit**: `refactor(app): reduce oversized files` (if any found)
  - _Requirements: NFR-2_

- [ ] 10.4 Create evidence index file
  - **Do**:
    1. Create `specs/polish-again/evidence/INDEX.md`
    2. List all screenshots with descriptions:
       - cs1-chat-response.png: Basic send-receive with "What is 2+2?" response
       - cs2-partial.png: Cancelled streaming response (partial)
       - cs2-followup.png: Follow-up message after cancellation
       - cs3-tool-accordion.png: Expanded tool call accordion
       - cs4-disconnected.png: ConnectionBanner showing disconnected state
       - cs4-recovered.png: Reconnected after backend restart
       - cs4-post-recovery.png: Successful message after recovery
       - cs5-fork-alert.png: Session fork alert dialog
       - cs5-forked.png: Forked session with inherited messages
       - cs6-rapid.png: Rapid-fire message sequence
       - cs7-obsidian.png: Chat in Obsidian theme
       - cs7-slate.png: Chat in Slate theme
       - cs7-paper.png: Chat in Paper theme (light)
       - cs8-thinking.png: ThinkingSection expanded
       - cs8-code.png: Syntax-highlighted code block
       - cs9-external.png: External session (or documented N/A)
       - cs10-renamed.png: Renamed session in sidebar
       - cs10-info.png: Session info sheet
       - cs10-export.png: Export share sheet
       - build-log.txt: Clean build output
    3. Include spec name, date, simulator UDID at top
  - **Files**: `specs/polish-again/evidence/INDEX.md` (create)
  - **Done when**: INDEX.md lists all evidence files with descriptions
  - **Verify**: `test -f /Users/nick/Desktop/ils-ios/specs/polish-again/evidence/INDEX.md && echo "EXISTS"`
  - **Commit**: `docs(polish): create evidence index for all screenshots and build logs`
  - _Requirements: AC-16.7_

## Phase 11: PR Lifecycle

- [ ] 11.1 Create PR and verify
  - **Do**:
    1. Verify current branch: `git branch --show-current` -- should be `design/v2-redesign` or a feature branch
    2. If on default branch (main), STOP and alert user
    3. Stage all changes: `git add -A`
    4. Push branch: `git push -u origin $(git branch --show-current)`
    5. Create PR: `gh pr create --title "polish: fix 28 bugs, decompose God Objects, 10 chat scenario evidence" --body "..."`
    6. Monitor CI: `gh pr checks` (if CI configured)
  - **Verify**: `gh pr view --json url -q .url 2>/dev/null || echo "PR creation needed"`
  - **Done when**: PR created and pushed
  - **Commit**: none (PR creation, not a commit)

- [ ] 11.2 [VERIFY] AC checklist: all acceptance criteria met
  - **Do**:
    1. Read requirements.md
    2. For each AC-* criterion, verify via grep/file check/screenshot that it is satisfied
    3. Key checks:
       - AC-1.1: `grep '"ghost-protocol"' ThemePickerView.swift` -- match
       - AC-2.2: `wc -l ILSAppApp.swift` -- <150 lines
       - AC-2.3: 4 files exist (SettingsView, ConfigEditorView, SettingsViewModel, ConfigEditorViewModel)
       - AC-2.9: build succeeds with 0 warnings
       - AC-3.3: BaseListViewModel.swift deleted
       - AC-4.1: MCPServerItem.swift deleted
       - AC-4.2: PluginModels.swift deleted
       - AC-16.5: evidence/ directory has 15+ screenshots
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && test ! -f ILSApp/ILSApp/Models/MCPServerItem.swift && test ! -f ILSApp/ILSApp/Models/PluginModels.swift && test ! -f ILSApp/ILSApp/ViewModels/BaseListViewModel.swift && test -f ILSApp/ILSApp/Services/ConnectionManager.swift && test -f ILSApp/ILSApp/Services/PollingManager.swift && test -f ILSApp/ILSApp/ViewModels/ConfigEditorViewModel.swift && test -f ILSApp/ILSApp/ViewModels/SettingsViewModel.swift && test -f ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift && echo "ALL AC PASS"`
  - **Done when**: All acceptance criteria confirmed met
  - **Commit**: none

## Notes

### POC Shortcuts
- None -- this is a polish spec, not a POC. All changes are production-quality.

### Key Risk Areas
- **AppState decomposition (3.1-3.3)**: Highest risk. Forward properties maintain backward compat. Build after EACH step.
- **MCPServer enum decoding (6.1)**: Verify backend JSON matches enum raw values with curl BEFORE deleting MCPServerItem.
- **SettingsView split (4.1-4.3)**: Extract in order: ConfigEditorViewModel, SettingsViewModel, ConfigEditorView. Build after each.

### Chat Scenario Dependencies
- CS1 (basic) must pass before CS2 (cancel), CS3 (tools), CS4 (recovery)
- CS7 (theme switch) depends on CodeBlockView light theme fix (2.4)
- CS9 (external session) depends on backend having external session data -- may need to document as N/A

### Files Created (New)
- `ILSApp/ILSApp/Services/ConnectionManager.swift`
- `ILSApp/ILSApp/Services/PollingManager.swift`
- `ILSApp/ILSApp/ViewModels/ConfigEditorViewModel.swift`
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift`
- `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift`
- `ILSApp/ILSApp/Views/Shared/ShareSheet.swift`
- `specs/polish-again/evidence/INDEX.md`

### Files Deleted
- `ILSApp/ILSApp/Models/MCPServerItem.swift`
- `ILSApp/ILSApp/Models/PluginModels.swift`
- `ILSApp/ILSApp/ViewModels/BaseListViewModel.swift`
- `ILSApp/ILSApp/Theme/ThemeManager.swift`

### Production TODOs
- CS9 may need backend test data for external sessions
- ConnectionBanner auto-dismiss timing may need UX tuning after decomposition
- MCPServer scope/status enum decoding may need fallback for unknown values
