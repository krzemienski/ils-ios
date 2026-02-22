# Task 9.7: VoiceOver Navigation Audit — Verdict

**Date:** 2026-02-22
**Auditor:** Phase 9 Accessibility Auditor
**Method:** Source code analysis of all 65 view files + idb_describe accessibility tree dumps

---

## Summary

The ILS iOS app has **above-average VoiceOver support** for a custom-themed app. A systematic audit found **114 `.accessibilityLabel()` calls**, **34 `.accessibilityIdentifier()` calls**, **20 `.accessibilityHint()` calls**, **19 `.accessibilityElement()` calls**, and **4 `.accessibilityAddTraits()` calls** across the codebase.

**Overall: CONDITIONAL PASS** — Core navigation and chat flows are well-labeled. Several secondary screens and components have gaps.

---

## Screen-by-Screen Analysis

### Home Screen (HomeView.swift) — PASS
- Session rows: `.accessibilityLabel("\(session.name), \(session.model), \(session.messageCount) messages")` + `.accessibilityHint` + `.isButton` trait
- Quick action cards: `StatCard` has `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(title), \(count)")`
- Start a Chat banner: has descriptive labels
- Refresh indicator: `.accessibilityLabel("Refreshing content")` + `.updatesFrequently` trait
- Setup button: `.accessibilityLabel("Setup server connection")` + `.accessibilityHint`
- **Minor gap:** Dismiss "X" button on the Start a Chat banner — no explicit label (relies on system default)

### Sidebar (SidebarView.swift) — PASS
- Navigation items: `.accessibilityLabel(label)` + `.accessibilityHint("Navigate to \(label)")`
- Session rows (SidebarSessionRow): `.accessibilityLabel("\(sessionDisplayName), \(relativeTime)")` + `.accessibilityHint` + `.isButton` trait
- New Session button: `.accessibilityLabel("Create new chat session")` + `.accessibilityHint`
- Search field: `.accessibilityLabel("Search sessions")`
- Clear search: `.accessibilityLabel("Clear search")`
- Hamburger button: `.accessibilityLabel("Open sidebar")` + `.accessibilityHint("Opens navigation sidebar")`

### Chat View (ChatView.swift, ChatInputBar.swift, MessageView.swift) — PASS
- Menu button: `.accessibilityLabel("Chat options menu")` + `.accessibilityIdentifier` + `.accessibilityHint`
- Input bar: 5 labeled elements (command palette, advanced options, message field, stop streaming, send message)
- All buttons have both labels and hints
- User messages: `.accessibilityLabel("You said: \(message.text)")`
- Assistant messages: `.accessibilityLabel("Assistant said: \(message.text.prefix(100))")`
- System messages: `.accessibilityLabel("System message: \(message)")`
- Error messages: `.accessibilityElement(children: .combine)` + contextual label with retry hint
- Code blocks: 5 labeled elements (language, expand/collapse, copy, share, content)
- Streaming indicator: `.accessibilityLabel("AI is responding")`
- Jump to bottom: `.accessibilityLabel("Jump to bottom")` + `.accessibilityHint`
- Thinking section: `.accessibilityElement(children: .contain)` + label + hint
- Tool call accordion: `.accessibilityElement(children: .contain)` + label + hint

### Browser View (BrowserView.swift) — PASS
- Segmented control: `.accessibilityLabel("\(seg.rawValue), \(countFor(seg)) items")`
- Search clear: `.accessibilityLabel("Clear search")`
- Scope filter: `.accessibilityLabel("\(scope.capitalized) scope filter")`
- Plugin rows: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")`
- MCP server rows: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(name), \(status)")`
- **Minor gap:** Skill list rows in BrowserView are not explicitly labeled (relies on Text content)

### System Monitor (SystemMonitorView.swift) — PARTIAL PASS
- Network chart: `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("Network usage chart, ...")`
- CPU chart: Uses `MetricChart` component which has `.accessibilityElement(children: .ignore)` + `.accessibilityLabel`
- Memory/Disk rings: `ProgressRing` has `.accessibilityElement(children: .ignore)` + `.accessibilityLabel` + `.accessibilityValue("\(Int(progress * 100)) percent")`
- **BUG-9.70: Process list rows lack accessibility labels** — `processRow()` in `ProcessListView.swift` renders name, PID, CPU%, and MEM but has NO `.accessibilityLabel` or `.accessibilityElement(children: .combine)` on the row
- **BUG-9.71: Process classification badge (colored circle) has no label** — The colored dot indicating Claude/ILS/Swift/Node classification is purely visual
- **BUG-9.72: Sort option buttons in process list lack labels** — The ForEach over `ProcessSortOption.allCases` creates buttons with only text content, no explicit role/state announcement
- **BUG-9.73: Live indicator in toolbar lacks accessibility label** — The HStack with pulsing circle + "Live"/"Offline" text has no combined label
- Load average cards: No `.accessibilityElement(children: .combine)` or label (individual "2.85" and "1m" texts are separate)

### Settings (SettingsView.swift, SettingsConnectionSection, SettingsConfigSection) — PASS
- Server URL: `.accessibilityLabel("Server URL")`
- Connection status: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("Connection status: ...")`
- Test connection: `.accessibilityLabel("Test connection to backend server")`
- Config pickers: `.accessibilityLabel("Default Claude model")`, `.accessibilityLabel("Color scheme preference")`
- Toggles: `.accessibilityLabel("Enable extended thinking mode")`, `.accessibilityLabel("Include co-authored-by attribution")`
- Analytics toggle: `.accessibilityLabel("Enable analytics")`

### Theme Picker (ThemePickerView.swift) — PASS
- Theme cards: `.accessibilityLabel("\(appTheme.name) theme\(isActive ? ", active" : "")")`
- Custom theme cards: Same pattern

### Theme Editor (ThemeEditorView.swift) — CONDITIONAL PASS
- Form uses native SwiftUI Form elements (TextField, ColorPicker, Picker, Slider) which inherit accessibility
- **BUG-9.74: Sliders in spacing/corner radius sections lack explicit accessibilityLabel** — While the VStack has a descriptive Text, the Slider itself has no `.accessibilityLabel`. VoiceOver users hear just "Slider" without context about which spacing token they're adjusting
- **BUG-9.75: Shadow section has duplicate "Color" labels** — Three ColorPickers all labeled just "Color" for light/medium/heavy shadows. VoiceOver can't distinguish them.

### Host Profiles (HostProfilesView.swift, FleetManagementView.swift) — PASS
- Host rows: `.accessibilityLabel("\(host.name), \(host.healthStatus.rawValue)")`
- Detail view header: `.accessibilityLabel("\(title) backend on \(host.name)")`

### Agent Teams (AgentTeamsListView.swift) — FAIL
- **BUG-9.76: Team cards have NO accessibility labels** — `teamCard()` is a NavigationLink with text content but no `.accessibilityLabel` or `.accessibilityElement(children: .combine)`. VoiceOver reads individual child texts instead of a combined description.
- **BUG-9.77: Team member count icon "person.2" has no alt text** — The Image is decorative but not hidden from VoiceOver
- **BUG-9.78: Empty state icon "person.3" at size 64 has no label** — Just a decorative image not marked `.accessibilityHidden(true)`
- **BUG-9.79: "+" button in toolbar has no label** — Bare `Image(systemName: "plus")` without `.accessibilityLabel("Create new team")`

### Hooks Management (HooksManagementView.swift) — FAIL
- **BUG-9.80: Hook event sections have no accessibility labels** — The section headers (Session Start, Pre Tool Use, etc.) are just visual text with no semantic grouping
- **BUG-9.81: Hook definition rows lack labels** — `hookDefinitionRow()` shows command text but has no `.accessibilityElement` or `.accessibilityLabel`
- **BUG-9.82: Empty state icon "arrow.triangle.branch" at size 40 not hidden from VoiceOver**
- **BUG-9.83: Hook count badges are not announced** — The capsule showing hook count is standalone text with no context

### File Browser (FileBrowserView.swift) — PARTIAL PASS
- **BUG-9.84: File/directory rows have NO accessibility labels** — `fileRow()` renders icon, name, size, chevron but has no `.accessibilityLabel` or `.accessibilityElement(children: .combine)`. VoiceOver would read each child element separately.
- **BUG-9.85: Breadcrumb path components have no combined label** — Each breadcrumb is a separate button but there's no VoiceOver grouping or ".accessibilityLabel("Current path: ~/Documents/project")"
- **BUG-9.86: Folder/file icons read as "folder.fill" / "doc.text" without context** — Missing `.accessibilityHidden(true)` since the file name provides context

### Session Info (SessionInfoView.swift) — PARTIAL PASS
- Uses native `LabeledContent` which provides good VoiceOver support automatically
- **BUG-9.87: Export button (square.and.arrow.up) has no accessibility label**
- **BUG-9.88: Copy session ID button (doc.on.doc) has no accessibility label**

### Command Palette (CommandPaletteView.swift) — PASS
- Uses native SwiftUI List with Label elements
- Button text provides implicit label
- Model switching items use `Label(model, systemImage: "cpu")`

### New Session (NewSessionView.swift) — PASS
- Project rows: `.accessibilityLabel("\(project.name), \(project.path)")`
- Session rows: `.accessibilityLabel("\(session.name), \(session.model), \(session.messageCount) messages")`
- Model picker: `.accessibilityLabel("Claude model selection")`
- Various form fields have identifiers

### Onboarding / QuickConnect — PASS
- 11 accessibility labels covering all interactive elements
- Connection mode picker, server URL, remote host, port, tunnel URL, connect button

### Shared Components — PASS
- `EmptyEntityState`: `.accessibilityElement(children: .combine)` + `.accessibilityLabel`
- `OfflineIndicator`: `.accessibilityLabel("Offline mode. Showing cached data.")`
- `AccentButton`: `.accessibilityLabel(title)`
- `SkeletonRow`: `.accessibilityLabel("Loading content")`
- `ConnectionBanner`: `.accessibilityElement(children: .ignore)` + `.accessibilityLabel` + `.updatesFrequently`
- `SparklineChart`: `.accessibilityElement(children: .ignore)` + `.accessibilityLabel`
- `ThinkingSection`: `.accessibilityElement(children: .contain)` + label + hint
- `ToolCallAccordion`: `.accessibilityElement(children: .contain)` + label + hint
- `ThemedCodeBlockView`: `.accessibilityElement(children: .contain)` + label
- `MetricChart`: `.accessibilityElement(children: .ignore)` + label
- `ProgressRing`: `.accessibilityElement(children: .ignore)` + label + value
- `ConnectionSteps`: `.accessibilityElement(children: .ignore)` + label
- `EntityBadge`: `.accessibilityLabel("\(entityType.displayName) entity")`
- `StatCard`: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(title), \(count)")`
- `CacheStatusView`: `.accessibilityLabel("Last updated \(relativeTime)")`

---

## Bug Summary

| Bug ID | Severity | Screen | Issue |
|--------|----------|--------|-------|
| BUG-9.70 | P2 | ProcessListView | Process rows lack accessibility labels |
| BUG-9.71 | P3 | ProcessListView | Classification badge (colored dot) has no label |
| BUG-9.72 | P3 | ProcessListView | Sort option buttons lack state announcement |
| BUG-9.73 | P3 | SystemMonitorView | Live indicator lacks combined label |
| BUG-9.74 | P3 | ThemeEditorView | Spacing/radius sliders lack explicit labels |
| BUG-9.75 | P3 | ThemeEditorView | Shadow section has 3 duplicate "Color" labels |
| BUG-9.76 | P2 | AgentTeamsListView | Team cards have no accessibility labels |
| BUG-9.77 | P3 | AgentTeamsListView | Member count icon has no alt text |
| BUG-9.78 | P3 | AgentTeamsListView | Empty state icon not hidden from VoiceOver |
| BUG-9.79 | P2 | AgentTeamsListView | "+" toolbar button has no label |
| BUG-9.80 | P2 | HooksManagementView | Event sections lack accessibility grouping |
| BUG-9.81 | P2 | HooksManagementView | Hook definition rows lack labels |
| BUG-9.82 | P3 | HooksManagementView | Empty state icon not hidden from VoiceOver |
| BUG-9.83 | P3 | HooksManagementView | Count badges lack context |
| BUG-9.84 | P2 | FileBrowserView | File/directory rows lack accessibility labels |
| BUG-9.85 | P3 | FileBrowserView | Breadcrumb components lack combined label |
| BUG-9.86 | P3 | FileBrowserView | Folder/file icons should be hidden from VoiceOver |
| BUG-9.87 | P2 | SessionInfoView | Export button lacks accessibility label |
| BUG-9.88 | P2 | SessionInfoView | Copy ID button lacks accessibility label |

**P2 bugs (unlabeled interactive elements): 8**
**P3 bugs (minor label improvements): 11**
**Total: 19 bugs**

---

## PASS Criteria Assessment

| Criterion | Status | Notes |
|-----------|--------|-------|
| P1: Every tappable element has label | CONDITIONAL PASS | Core flows pass. 8 P2 bugs in secondary screens (Agent Teams, Hooks, File Browser, Process List, Session Info) |
| P2: Custom controls announce role/state | PARTIAL PASS | Most custom controls are well-labeled. Process sort buttons and theme editor sliders lack state |
| P3: Navigation items properly labeled | PASS | All sidebar nav items, toolbar buttons in primary screens labeled |

---

## Strengths

1. **Chat flow is excellent** — 50+ accessibility annotations across chat views
2. **Onboarding is fully accessible** — 11 labels in QuickConnectView alone
3. **Shared components set a high bar** — StatCard, EmptyEntityState, ProgressRing, MetricChart all properly annotated
4. **Sidebar navigation** is comprehensively labeled with both labels and hints
5. **Browser view** has combined element labels for rows
6. **Theme preview cards** include active/available state

## Weaknesses

1. **Newer screens lack accessibility** — HooksManagementView, AgentTeamsListView, FileBrowserView were added later and don't follow the pattern
2. **Process list** in System Monitor has zero accessibility annotations
3. **Session Info toolbar buttons** are bare SF Symbol images
4. **Theme Editor** has duplicate labels in shadow section and unlabeled sliders
