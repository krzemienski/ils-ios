---
phase: quick-4
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ILSApp/ILSApp/Views/Sessions/NewSessionView.swift
  - ILSApp/ILSApp/Views/Root/SidebarView.swift
  - ILSApp/ILSApp/Views/Home/HomeView.swift
  - ILSApp/ILSApp/ViewModels/ProjectsViewModel.swift
autonomous: true
requirements: [NEW-SESSION-UX]

must_haves:
  truths:
    - "User sees a project/directory picker when tapping New Session"
    - "User can search and select from existing projects (~373 discovered from ~/.claude/projects/)"
    - "User can create a new project inline (name + path) and start a session within it"
    - "User can fork from an existing session as a starting point"
    - "Selected project context flows through to ChatStreamRequest.projectId and correct workingDirectory"
    - "Model, permissions, and advanced options remain configurable before session creation"
  artifacts:
    - path: "ILSApp/ILSApp/Views/Sessions/NewSessionView.swift"
      provides: "Redesigned multi-step new session flow with project picker, fork option, and create-project inline"
      min_lines: 200
    - path: "ILSApp/ILSApp/Views/Root/SidebarView.swift"
      provides: "Updated bottom action to present NewSessionView sheet instead of instant navigation"
    - path: "ILSApp/ILSApp/Views/Home/HomeView.swift"
      provides: "Updated quick action to present NewSessionView sheet instead of instant navigation"
  key_links:
    - from: "SidebarView.bottomActions"
      to: "NewSessionView"
      via: "sheet presentation"
      pattern: "sheet.*NewSessionView"
    - from: "HomeView.quickActionsGrid"
      to: "NewSessionView"
      via: "sheet presentation"
      pattern: "sheet.*NewSessionView"
    - from: "NewSessionView.createSession()"
      to: "POST /sessions"
      via: "apiClient.post with CreateSessionRequest containing projectId"
      pattern: "apiClient\\.post.*sessions.*projectId"
    - from: "NewSessionView fork flow"
      to: "POST /sessions/:id/fork"
      via: "apiClient.post for fork endpoint"
      pattern: "apiClient\\.post.*fork"
---

<objective>
Redesign the "New Session" UX to be a context-aware, multi-step flow instead of an instant blank session.

Purpose: Currently tapping "New Session" creates a blank session with no project context -- the user lands on "How can I help you today?" with no directory/project association. This redesign makes project selection the primary first step, ensures Claude CLI runs in the correct working directory, and adds the ability to fork from existing sessions or create new projects inline.

Output: A redesigned NewSessionView.swift with three entry modes (pick project, fork session, create project), wired into both SidebarView and HomeView, with full parameter flow to the backend.
</objective>

<execution_context>
@/Users/nick/.claude/get-shit-done/workflows/execute-plan.md
@/Users/nick/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ILSApp/ILSApp/Views/Sessions/NewSessionView.swift (current form -- to be redesigned)
@ILSApp/ILSApp/Views/Root/SidebarView.swift (bottom "New Session" button)
@ILSApp/ILSApp/Views/Home/HomeView.swift (quick action "New Session" card)
@ILSApp/ILSApp/ViewModels/ProjectsViewModel.swift (existing project loading)
@ILSApp/ILSApp/ViewModels/ChatViewModel.swift (sendMessage flow with projectId)
@Sources/ILSShared/Models/Session.swift (ChatSession model with projectId, forkedFrom)
@Sources/ILSShared/Models/Project.swift (Project model with path, encodedPath)
@Sources/ILSShared/DTOs/Requests.swift (CreateSessionRequest, ChatStreamRequest, ChatOptions, CreateProjectRequest)
@Sources/ILSBackend/Controllers/SessionsController.swift (POST /sessions, POST /sessions/:id/fork)
@Sources/ILSBackend/Controllers/ProjectsController.swift (GET /projects, POST /projects)
@Sources/ILSBackend/Controllers/ChatController.swift (stream endpoint -- uses projectId to resolve workingDirectory)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Redesign NewSessionView with project-first flow and three entry modes</name>
  <files>
    ILSApp/ILSApp/Views/Sessions/NewSessionView.swift
    ILSApp/ILSApp/ViewModels/ProjectsViewModel.swift
  </files>
  <action>
Completely redesign NewSessionView.swift to be a multi-step, context-aware session creation flow. The view should present as a sheet (.large detent) with three distinct modes accessible via a segmented control or tab-like selector at the top:

**Mode 1: "Project" (default)** -- Directory/Project Picker
- Show a searchable list of projects loaded from ProjectsViewModel (GET /projects endpoint, ~373 projects discovered from ~/.claude/projects/)
- Each project row shows: project name, path (truncated), session count, last accessed date
- Search bar at top filters projects by name (use existing projectsViewModel.searchText if available, or add local filtering)
- Selecting a project highlights it and reveals the configuration section below
- A "No Project (Home Directory)" option at the top for starting without project context
- After project selection, show collapsed configuration panel: Model picker (Sonnet/Opus/Haiku segmented control), Permission mode picker, System prompt (expandable), Limits (expandable)
- "Start Session" button at bottom creates session via POST /sessions with selected project's ID, then calls onCreated callback

**Mode 2: "Fork" -- Fork from Existing Session**
- Show recent sessions list (reuse SessionsViewModel pattern -- load from GET /sessions?limit=20)
- Each row shows: session name (cleaned), project name, model, message count, last active relative time
- Search bar to filter sessions
- Selecting a session shows a preview: session name, message count, project context
- "Fork & Start" button calls POST /sessions/{id}/fork, then navigates to the forked session via onCreated
- Show a brief explanation: "Creates a copy of this session's conversation history as a new starting point"

**Mode 3: "New Project" -- Create Project then Start Session**
- Simple form: Project Name (required TextField), Directory Path (required TextField with folder icon hint)
- "Browse" concept: since this is iOS, the path must be typed or pasted (no native file picker for server paths). Add helper text: "Enter the full path to your project directory on the server"
- Optional: Default Model picker for the project
- "Create Project & Start" button: first POST /projects with {name, path}, then POST /sessions with the new project's ID, then calls onCreated

**Implementation details:**
- Use an enum `NewSessionMode: String, CaseIterable` with cases `.project`, `.fork`, `.newProject` with display names "Project", "Fork", "New Project"
- Use @State private var selectedMode: NewSessionMode = .project
- Keep the existing model/permission/systemPrompt/limits configuration as a collapsible section (DisclosureGroup) that appears after project/session selection in modes 1 and 2
- For the sessions list in Fork mode, create a minimal @State private var recentSessions: [ChatSession] = [] and load via apiClient.get("/sessions?limit=20") in .task
- Preserve existing createSession() logic for the API call but ensure projectId is set from the selected project
- Use theme tokens throughout (theme.fontBody, theme.bgSecondary, theme.spacingMD, etc.) -- follow existing patterns in the file
- Add .accessibilityIdentifier to key elements: "mode-picker", "project-list", "session-list", "create-project-form", "start-session-button"
- The onCreated callback signature stays: `(ChatSession) -> Void`

**ProjectsViewModel update:**
- If not already present, add a `searchText` @Published/@Observable property for filtering
- Add a computed `filteredProjects` that filters by searchText (case-insensitive on name)
- This is a minor addition -- the VM already loads projects via GET /projects

**Key data flow:**
1. User selects project -> selectedProject is set -> projectId flows into CreateSessionRequest
2. Backend creates session with projectId foreign key
3. When user sends first message, ChatStreamRequest includes projectId
4. ChatController.stream() resolves projectId -> ProjectModel.path -> passes as workingDirectory to executor.execute()
5. Claude CLI runs with --cwd pointing to the project directory

This flow already works end-to-end (ChatController lines 100-106 resolve projectPath from projectId). The redesign ensures users actually SELECT a project instead of skipping it.
  </action>
  <verify>
Build iOS target to verify no compile errors:
```
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -20
```
Verify NewSessionView has three modes, project list renders, fork list renders, create project form renders.
  </verify>
  <done>
NewSessionView presents a three-mode interface (Project/Fork/New Project). Project mode shows searchable project list. Fork mode shows recent sessions with fork action. New Project mode has name+path form. All modes flow to session creation via the existing backend API. Builds without errors on iOS.
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire SidebarView and HomeView to present NewSessionView sheet</name>
  <files>
    ILSApp/ILSApp/Views/Root/SidebarView.swift
    ILSApp/ILSApp/Views/Home/HomeView.swift
  </files>
  <action>
Update both entry points that currently create instant blank sessions to instead present the redesigned NewSessionView as a sheet.

**SidebarView.swift -- bottomActions section (line ~282-303):**
- Add @State private var showNewSessionSheet = false to SidebarView
- Change the "New Session" button action from:
  ```swift
  let newSession = ChatSession(name: "New Session", model: AppConstants.defaultModel)
  onSessionSelected(newSession)
  isSidebarOpen = false
  ```
  To:
  ```swift
  showNewSessionSheet = true
  ```
- Add .sheet(isPresented: $showNewSessionSheet) modifier to the VStack body (or the bottomActions view) presenting:
  ```swift
  NewSessionView { session in
      showNewSessionSheet = false
      onSessionSelected(session)
      isSidebarOpen = false
  }
  .environment(appState)
  .environment(\.theme, theme)
  ```
- Keep the button styling exactly as-is (plus.circle.fill icon, accent background, full-width)

**HomeView.swift -- quickActionsGrid section (line ~331-338):**
- Add @State private var showNewSessionSheet = false to HomeView
- Change the "New Session" quick action card action from:
  ```swift
  let newSession = ChatSession(name: "New Session", model: AppConstants.defaultModel)
  onSessionSelected?(newSession)
  ```
  To:
  ```swift
  showNewSessionSheet = true
  ```
- Add .sheet(isPresented: $showNewSessionSheet) modifier to the appropriate parent view:
  ```swift
  NewSessionView { session in
      showNewSessionSheet = false
      onSessionSelected?(session)
  }
  .environment(appState)
  .environment(\.theme, theme)
  ```

**Important:** Do NOT change the onSessionSelected callback signature or the navigation flow after session creation. The sheet creates the session, dismisses itself, and passes the ChatSession to the existing navigation machinery (activeScreen = .chat(session) in SidebarRootView).

**Cross-platform:** Check if there are macOS equivalents (ILSMacApp) that also have "New Session" buttons. If so, apply the same pattern. Search for `"New Session"` or `newSession` in ILSMacApp/ views. The macOS app may have its own sidebar -- update it consistently.
  </action>
  <verify>
Build both iOS and macOS targets:
```
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -10
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -10
```
Verify: tapping "New Session" in sidebar or home now presents a sheet instead of creating an instant blank session.
  </verify>
  <done>
Both SidebarView "New Session" button and HomeView "New Session" quick action present NewSessionView as a sheet. User must choose a project/context before starting a session. The navigation flow after creation (sheet dismisses, navigates to ChatView) works identically to before. Both iOS and macOS targets build clean.
  </done>
</task>

<task type="auto">
  <name>Task 3: Build verification and macOS parity check</name>
  <files>
    ILSApp/ILSMacApp/Views/MacSidebarView.swift
    ILSApp/ILSMacApp/Views/MacContentView.swift
  </files>
  <action>
Final verification pass and macOS parity:

1. Search ILSMacApp/ for any "New Session" creation patterns that bypass project selection:
   ```
   grep -rn "New Session\|newSession\|ChatSession(name:" ILSApp/ILSMacApp/ --include='*.swift'
   ```
   If found, update them to present NewSessionView sheet with the same pattern as iOS.

2. Run full iOS build to confirm zero errors and zero warnings related to the changed files.

3. Run full macOS build to confirm zero errors.

4. Verify the data flow is correct by tracing:
   - NewSessionView selects project -> CreateSessionRequest.projectId is set
   - onCreated returns ChatSession with projectId populated
   - ChatView receives session with projectId
   - sendMessage() passes projectId to ChatStreamRequest
   - ChatController resolves projectId to ProjectModel.path
   - executor.execute() receives correct workingDirectory

5. If any macOS views need NewSessionView but it uses iOS-only APIs (e.g., .presentationDetents), add `#if os(iOS)` guards or use macOS-appropriate presentation. NewSessionView already has `#if os(iOS)` for .inlineNavigationBarTitle() so this pattern exists.

6. Verify that the fork flow works by checking: NewSessionView calls apiClient.post("/sessions/{id}/fork") which hits SessionsController.fork() which creates a new session with forkedFrom set and copies all messages. The returned ChatSession is passed to onCreated, navigating to the forked session's ChatView.
  </action>
  <verify>
```
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5
swift build 2>&1 | tail -5
```
All three targets build clean (0 errors). macOS "New Session" also presents project picker.
  </verify>
  <done>
All three build targets (iOS, macOS, backend) compile with zero errors. macOS parity confirmed -- New Session flow presents project picker on both platforms. Fork flow verified against backend fork endpoint. Project context flows correctly from selection through to Claude CLI workingDirectory parameter.
  </done>
</task>

</tasks>

<verification>
1. iOS build succeeds with zero errors on changed files
2. macOS build succeeds with zero errors
3. NewSessionView presents three modes: Project (default), Fork, New Project
4. Project mode shows searchable list of ~373 discovered projects
5. Fork mode shows recent sessions with fork action
6. New Project mode has name+path creation form
7. SidebarView "New Session" button presents sheet instead of instant navigation
8. HomeView "New Session" quick action presents sheet instead of instant navigation
9. Created session has correct projectId flowing through to ChatStreamRequest
10. Backend resolves projectId to project path for Claude CLI workingDirectory
</verification>

<success_criteria>
- Tapping "New Session" anywhere in the app presents a project/context picker instead of a blank session
- User can select from existing projects, fork an existing session, or create a new project
- Selected project context flows end-to-end: UI selection -> CreateSessionRequest.projectId -> ChatStreamRequest.projectId -> ChatController -> executor.execute(workingDirectory:)
- All three build targets (iOS, macOS, backend) compile clean
- No regression to existing chat functionality -- sessions created through the new flow work identically once in ChatView
</success_criteria>

<output>
After completion, create `.planning/quick/4-redesign-new-session-ux-with-directory-p/4-01-SUMMARY.md`
</output>
