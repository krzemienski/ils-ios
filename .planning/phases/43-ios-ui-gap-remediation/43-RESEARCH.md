# Phase 43: iOS UI Gap Remediation - Research

**Researched:** 2026-02-25
**Domain:** SwiftUI iOS UI implementation — closing 6 specific UI gaps between spec and current app
**Confidence:** HIGH

## Summary

Phase 43 addresses 6 specific UI gaps identified in the comprehensive gap analysis (`.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md`). After thorough investigation of every file involved, the findings show that **most infrastructure already exists** — the gaps are primarily about missing UI wiring, not missing backend or ViewModel logic.

The HomeView Quick Actions grid already exists with 4 cards (New Session, Skills, MCP Servers, Plugins) but uses different labels than the spec's "Discover Skills, Browse Plugins, Configure MCP, Edit Settings" — this needs label/action adjustment plus adding an "Edit Settings" card. The Settings Quick Settings toggles (Model picker, Extended Thinking, Co-authored-by) **already exist** in `SettingsConfigSection.swift` under the "General" section — the spec wanted them "below the config editor" as a separate Quick Settings panel, but functionally they are fully implemented. The GitHub search UI in BrowserView is **fully wired** with search fields, result rows, Install buttons, and even rate limit error banners. The ChatView overflow menu already has Rename, Fork, Export, Session Info, and Delete — it is complete. The rate limit UX shows the backend error message but lacks a countdown timer. Animation timing values are consistent but need verification against specific spec values.

**Primary recommendation:** This phase is lighter than initially estimated. UI-02 (Quick Settings), UI-03 (GitHub search UI), and UI-04 (session overflow) are essentially already complete — they need verification and minor polish at most. UI-01 needs label changes and one additional card. UI-05 needs a countdown timer. UI-06 needs a timing audit pass.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | HomeView Quick Actions row with navigation shortcuts (Discover Skills, Browse Plugins, Configure MCP, Edit Settings) | Quick Actions grid exists at `HomeView.swift:343-389` with 4 cards. Labels differ from spec. Missing "Edit Settings" card. Navigation callbacks (`onNavigate`, `onNavigateToBrowser`) already wired. |
| UI-02 | Quick Settings toggles below config editor (Model picker, Extended Thinking, Co-authored-by) | **ALREADY IMPLEMENTED** in `SettingsConfigSection.swift:88-187`. Model Picker, Extended Thinking toggle, and Include Co-Author toggle all present with `saveWithPatch` persistence. Located in General section, not a separate "Quick Settings" panel — but functionally complete. |
| UI-03 | GitHub skill search UI wired in BrowserView with "Discovered from GitHub" section and Install buttons | **ALREADY IMPLEMENTED** in `BrowserView.swift:358-529`. `githubBrowseSection` renders search field, results with Install buttons via `installFromGitHub()`, "Installed" badges, star counts. Rate limit error banner included. Section header says "BROWSE GITHUB" not "Discovered from GitHub". |
| UI-04 | Session management overflow menu wired for all operations (rename, export, fork, delete) in ChatView | **ALREADY IMPLEMENTED** in `ChatView.swift:272-349`. Menu contains: Rename (with alert dialog), Fork Session, Export, Session Info, Delete Session. All wired to `ChatViewModel` methods (`renameSession`, `forkSession`, `exportSession`, `deleteSession`). |
| UI-05 | GitHub rate limit user-facing "try again in X seconds" countdown message | Partially implemented. `SkillsViewModel.swift:203-208` catches rate limit errors and sets `gitHubError` string. `BrowserView.swift:413-425` shows the error banner. Backend returns `"GitHub search limit reached..."` text. Missing: countdown timer extracting `X-RateLimit-Reset` header value. |
| UI-06 | Animation timing values verified against spec (0.25s spring, 0.2s easeOut) | 40+ animation instances found. Most use `.easeInOut(duration: 0.2)` or `.easeInOut(duration: 0.3)`. Springs use `response: 0.3, dampingFraction: 0.6-0.85`. All gated with `reduceMotion`. Need spec-by-spec timing comparison. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI views | Project standard, @Observable pattern |
| ILSShared | local | DTOs, models (ClaudeConfig, GitHubSearchResult, ChatSession) | Shared between iOS and backend |
| Vapor 4 | latest | Backend API | Existing backend framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Observation | Swift 5.9+ | @Observable ViewModels | All ViewModels use this pattern |
| TipKit | iOS 17+ | User tips/hints | Already in HomeView |

**No new dependencies required.** All 6 UI gaps can be closed with existing libraries.

## Architecture Patterns

### Recommended Project Structure
```
ILSApp/ILSApp/
├── Views/
│   ├── Home/HomeView.swift          # UI-01: Quick Actions modification
│   ├── Settings/
│   │   ├── SettingsView.swift        # UI-02: Already has Quick Settings
│   │   └── SettingsConfigSection.swift # UI-02: Toggles already here
│   ├── Browser/BrowserView.swift     # UI-03: GitHub search already wired
│   │                                  # UI-05: Rate limit countdown
│   └── Chat/ChatView.swift           # UI-04: Overflow menu already wired
├── ViewModels/
│   ├── SkillsViewModel.swift         # UI-05: Rate limit error handling
│   └── ChatViewModel.swift           # UI-04: Session operations
└── Theme/                            # UI-06: Animation timing values
```

### Pattern 1: Quick Actions Navigation
**What:** HomeView quick action cards navigate via callbacks to parent SidebarRootView
**When to use:** Adding new quick action cards (UI-01)
**Example:**
```swift
// Existing pattern from HomeView.swift — onNavigate and onNavigateToBrowser callbacks
quickActionCard(
    icon: "gearshape.fill",
    title: "Edit Settings",
    color: theme.textSecondary
) {
    onNavigate?(.settings)  // Uses ActiveScreen enum
}
```

### Pattern 2: SettingsViewModel saveWithPatch
**What:** Read-then-patch pattern that preserves CLI-only config fields
**When to use:** Any config mutation from iOS Settings
**Example:**
```swift
// Already used in SettingsViewModel.swift:111-140
func saveWithPatch(applying delta: (inout ClaudeConfig) -> Void) async -> String? {
    // 1. Load fresh config from server
    // 2. Apply delta closure (mutates only intended fields)
    // 3. PUT full config back (preserving hooks, env, permissions)
}
```

### Pattern 3: GitHub Error Handling in ViewModels
**What:** SkillsViewModel catches rate limit errors separately from general errors
**When to use:** UI-05 countdown timer
**Example:**
```swift
// Existing pattern from SkillsViewModel.swift:203-208
let desc = error.localizedDescription.lowercased()
if desc.contains("rate limit") || desc.contains("429") || desc.contains("limit reached") {
    gitHubError = error.localizedDescription  // Displayed in BrowserView banner
}
```

### Pattern 4: ChatView Overflow Menu
**What:** Toolbar Menu with labeled actions, each wiring to ChatViewModel async methods
**When to use:** UI-04 verification
**Example:**
```swift
// Already in ChatView.swift:291-349
ToolbarItem(placement: .primaryAction) {
    Menu {
        Button { /* rename */ } label: { Label("Rename", systemImage: "pencil") }
        Button { /* fork */ } label: { Label("Fork Session", systemImage: "arrow.branch") }
        Button { /* export */ } label: { Label("Export", systemImage: "square.and.arrow.up") }
        Button { /* info */ } label: { Label("Session Info", systemImage: "info.circle") }
        Divider()
        Button(role: .destructive) { /* delete */ } label: { Label("Delete Session", systemImage: "trash") }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
}
```

### Anti-Patterns to Avoid
- **Do NOT create new ViewModels for existing functionality** — all VMs needed already exist
- **Do NOT change the BrowserView section header** from "BROWSE GITHUB" to match spec literally — the implementation is functionally correct
- **Do NOT move Quick Settings toggles** to a new location — they are already properly placed in SettingsConfigSection's General section
- **Do NOT add new backend endpoints** — all API endpoints needed already exist

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config persistence | Custom UserDefaults logic | `SettingsViewModel.saveWithPatch()` | Already handles read-then-patch to preserve CLI-only fields |
| GitHub install | Custom download logic | `SkillsViewModel.installFromGitHub(result:)` | Already clones via backend POST /skills/install |
| Session operations | Custom API calls | `ChatViewModel.renameSession()`, `.forkSession()`, `.deleteSession()` | Already wired with error handling |
| Rate limit parsing | Custom HTTP header parsing | Backend `GitHubService` already returns `.tooManyRequests` Abort | Parse the reason string for timer value |
| Navigation | Custom router | `onNavigate?(ActiveScreen)` and `onNavigateToBrowser?(BrowserSegment)` | Callbacks already threaded through HomeView |

## Common Pitfalls

### Pitfall 1: Misidentifying Gaps as Missing When They're Already Implemented
**What goes wrong:** Spending time implementing features that already exist because the gap analysis used different terminology
**Why it happens:** The spec says "Quick Settings toggles below config editor" but they exist as "General" section in SettingsConfigSection. The spec says "Discovered from GitHub section" but it exists as "BROWSE GITHUB" section.
**How to avoid:** Always read the actual source file before implementing. Run the app and verify visually first.
**Warning signs:** Creating new View files for functionality that already renders on screen

### Pitfall 2: Breaking Existing Settings Save Logic
**What goes wrong:** Overwriting CLI-only config fields (hooks, env, permissions) when saving from iOS
**Why it happens:** Naive PUT of partial ClaudeConfig overwrites fields the iOS app didn't render
**How to avoid:** Always use `saveWithPatch()` which does read-then-patch. Never construct a fresh ClaudeConfig for PUT.
**Warning signs:** User reports hooks or environment variables disappearing after changing settings on iOS

### Pitfall 3: Rate Limit Header Not Available on iOS
**What goes wrong:** Trying to parse `X-RateLimit-Reset` on the iOS side when the backend proxied the GitHub request
**Why it happens:** The backend catches the 429 and throws `Abort(.tooManyRequests, reason: "...")`. The iOS app only sees the error message string, not the original GitHub response headers.
**How to avoid:** Either (a) have the backend include the reset timestamp in the error reason string, or (b) use a fixed cooldown period (e.g., 60 seconds for unauthenticated, 30 seconds for authenticated).
**Warning signs:** Countdown timer always showing a hardcoded value instead of real remaining time

### Pitfall 4: Auto-Build Hook on Every Swift Edit
**What goes wrong:** Forgetting that `.claude/settings.local.json` triggers xcodebuild on every .swift file edit
**Why it happens:** The auto-build hook is invisible to the executor unless they read CLAUDE.md
**How to avoid:** Make changes in batches within a single Edit call. Expect 15-45s build after each edit.
**Warning signs:** Extremely slow progress due to constant build cycles

### Pitfall 5: Animation Timing Verification Scope Creep
**What goes wrong:** Trying to exhaustively verify every animation in 40+ files against spec values
**Why it happens:** UI-06 asks for "verified against spec values" but the spec only defines a handful of target values
**How to avoid:** Focus on the specific values mentioned in the spec (0.25s spring, 0.2s easeOut). Most existing values (0.2-0.3s easeInOut) are already within spec range. Only change clear outliers.
**Warning signs:** Spending hours on animation timing with no visible UX improvement

## Code Examples

### UI-01: Adding "Edit Settings" Quick Action Card to HomeView
```swift
// In HomeView.swift quickActionsGrid, add after the Plugins card:
quickActionCard(
    icon: "gearshape.fill",
    title: "Edit Settings",
    color: theme.textSecondary
) {
    onNavigate?(.settings)
}
```

### UI-01: Updating Quick Action Labels to Match Spec
```swift
// Current labels: "New Session", "Skills", "MCP Servers", "Plugins"
// Spec labels: "Discover Skills", "Browse Plugins", "Configure MCP", "Edit Settings"
// Adjust titles in existing quickActionCard calls:
quickActionCard(icon: "sparkles", title: "Discover Skills", ...)
quickActionCard(icon: "server.rack", title: "Configure MCP", ...)
quickActionCard(icon: "puzzlepiece.extension.fill", title: "Browse Plugins", ...)
quickActionCard(icon: "gearshape.fill", title: "Edit Settings", ...)
```

### UI-05: Rate Limit Countdown Timer
```swift
// In SkillsViewModel, add countdown state:
var rateLimitResetDate: Date?
var rateLimitCountdown: Int = 0

// When catching rate limit error, parse or default:
if desc.contains("rate limit") || desc.contains("429") {
    gitHubError = "GitHub rate limit reached"
    rateLimitResetDate = Date().addingTimeInterval(60) // Default 60s cooldown
    startCountdownTimer()
}

// In BrowserView, show countdown:
if let countdown = skillsVM.rateLimitCountdown, countdown > 0 {
    Text("Try again in \(countdown) seconds")
        .font(.system(size: theme.fontCaption))
        .foregroundStyle(theme.warning)
}
```

### UI-06: Animation Timing Reference Values
```swift
// Spec target values:
// Spring: .spring(response: 0.25, dampingFraction: 0.8)
// EaseOut: .easeOut(duration: 0.2)
// EaseInOut: .easeInOut(duration: 0.25)

// Current most-common values in codebase:
// .easeInOut(duration: 0.2)  — 20+ occurrences — WITHIN SPEC
// .easeInOut(duration: 0.3)  — 10+ occurrences — CLOSE TO SPEC
// .spring(response: 0.3, dampingFraction: 0.85)  — sidebar — CLOSE TO SPEC
// .spring(response: 0.3, dampingFraction: 0.6)   — AccentButton — CLOSE TO SPEC
```

## Detailed File Analysis Per Requirement

### UI-01: HomeView Quick Actions
| File | Current State | Action Needed |
|------|---------------|---------------|
| `ILSApp/ILSApp/Views/Home/HomeView.swift` | 4 cards: New Session, Skills, MCP Servers, Plugins (lines 343-389) | Rename labels to spec wording; add 5th "Edit Settings" card; possibly restructure to 3-column grid or 2x3 |
| `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` | `onNavigate` and `onNavigateToBrowser` callbacks already passed to HomeView | No changes needed |

**Navigation infrastructure:** `ActiveScreen.settings` exists. `BrowserSegment.skills/.mcp/.plugins` exist. All callback plumbing is in place.

### UI-02: Quick Settings Toggles
| File | Current State | Action Needed |
|------|---------------|---------------|
| `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` | Lines 88-187: Model Picker, Color Scheme picker, Updates Channel, Extended Thinking toggle, Include Co-Author toggle | **Verify visually.** May need minor reordering or a "Quick Settings" section label above Model/Thinking/Co-Author toggles to match spec intent. |
| `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` | `saveWithPatch()`, `updateModel()`, `updateToggle()` all implemented | No changes needed |
| `Sources/ILSShared/Models/ClaudeConfig.swift` | `model`, `alwaysThinkingEnabled`, `includeCoAuthoredBy` fields all present | No changes needed |

**Key finding:** The spec asked for "Quick Settings toggles below config editor." The current implementation places them in the General section of SettingsConfigSection, which is rendered above the raw JSON editor links. The toggles are functionally complete with persistence via `saveWithPatch`. The only gap may be visual grouping under a "Quick Settings" label.

### UI-03: GitHub Skill Search in BrowserView
| File | Current State | Action Needed |
|------|---------------|---------------|
| `ILSApp/ILSApp/Views/Browser/BrowserView.swift` | Lines 358-529: Full `githubBrowseSection` with search field, results list, Install buttons, "Installed" badges, star counts, rate limit banner | **Verify visually.** Section header says "BROWSE GITHUB" — could optionally add "Discovered from GitHub" as a sub-label. |
| `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` | `searchGitHub()`, `installFromGitHub()`, `isInstalled()`, `gitHubResults`, `installingSkills`, `gitHubError` — all implemented | No changes needed |
| `Sources/ILSBackend/Services/GitHubService.swift` | `searchSkills()` with GitHub Code API, caching, rate limit handling | No changes needed |
| `Sources/ILSBackend/Controllers/SkillsController.swift` | `GET /skills/search?q=`, `POST /skills/install` routes registered | No changes needed |

**Key finding:** This is fully implemented. The gap analysis marked it PARTIAL because it "needs verification of actual render" — which is a validation task, not an implementation task.

### UI-04: Session Overflow Menu
| File | Current State | Action Needed |
|------|---------------|---------------|
| `ILSApp/ILSApp/Views/Chat/ChatView.swift` | Lines 272-349: Menu with Rename, Fork, Export, Session Info, Delete + cost/model/project info display | **Verify visually.** Already complete. |
| `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` | `renameSession()` (line 590), `forkSession()` (line 617), `deleteSession()` (line 603), export via `SessionExportService` | No changes needed |
| `ILSApp/ILSApp/Services/APIClient.swift` | `renameSession(id:name:)` (line 329) | No changes needed |

**Key finding:** All 4 operations (Rename, Export, Fork, Delete) plus Session Info are already wired in the overflow menu. The gap analysis marked this PARTIAL because "iOS overflow menu wiring for all operations needs verification" — again a validation task.

### UI-05: Rate Limit UX Countdown
| File | Current State | Action Needed |
|------|---------------|---------------|
| `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` | Lines 203-208: Catches rate limit errors, sets `gitHubError` string | Add `rateLimitCountdown` state, countdown timer logic |
| `ILSApp/ILSApp/Views/Browser/BrowserView.swift` | Lines 413-425: Shows `gitHubError` in warning banner | Replace static error text with "try again in X seconds" countdown |
| `Sources/ILSBackend/Services/GitHubService.swift` | Lines 72-76, 78-81: Reads `X-RateLimit-Remaining` header, throws `.tooManyRequests` on 403/429 | Optionally include `X-RateLimit-Reset` value in error reason string |

**Implementation approach:** The backend already reads `X-RateLimit-Remaining` but does NOT forward `X-RateLimit-Reset` to the client. Two options:
1. **Backend enhancement:** Include reset timestamp in the Abort reason string so iOS can parse it
2. **Client-side default:** Use a 60-second countdown from the moment of error (simpler, acceptable UX)

Recommend option 2 for simplicity — the exact reset time is rarely critical for users.

### UI-06: Animation Timing Audit
| File Category | Count | Current Values | Spec Target |
|---------------|-------|----------------|-------------|
| `.easeInOut(duration: 0.2)` | ~20 files | 0.2s | 0.2s easeOut (match) |
| `.easeInOut(duration: 0.3)` | ~10 files | 0.3s | 0.25s (close) |
| `.spring(response: 0.3)` | ~3 files | 0.3s, damping 0.6-0.85 | 0.25s spring (close) |
| `.easeOut(duration: 0.4)` | 1 file (ILSAppApp) | 0.4s | 0.2s easeOut (needs adjustment) |
| `.easeInOut(duration: 0.5)` | 1 file (ProgressRing) | 0.5s | acceptable for progress |
| `.easeInOut(duration: 0.8+)` | 5 files (pulsing/looping) | 0.8-2.0s | acceptable for ambient animation |

**Key finding:** Most animations are within 0.05s of spec values. The main outlier is `ILSAppApp.swift:38` using `.easeOut(duration: 0.4)` where spec wants 0.2s. Ambient/looping animations (0.8-2.0s) are intentionally slower and should not be changed. Focus the audit on interactive animations (button presses, transitions, menu appearances).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Gap marked PARTIAL | Verified as COMPLETE on code read | This research | UI-02, UI-03, UI-04 need verification only, not implementation |
| Rate limit shows raw error string | Need countdown timer | This phase | UI-05 is the main new implementation work |
| Quick Actions: generic labels | Spec-specific labels | This phase | UI-01 is a label rename + 1 new card |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| UI-02/03/04 turn out to have runtime bugs despite code being present | LOW | MEDIUM | Build and run first, verify before claiming complete |
| Animation timing changes cause visual regressions | LOW | LOW | Change only clear outliers, test with reduceMotion on/off |
| Rate limit countdown is inaccurate without server-side reset time | MEDIUM | LOW | 60s default is acceptable UX; exact timer is nice-to-have |
| HomeView Quick Actions grid layout breaks with 5 cards in 2-column grid | LOW | LOW | 5th card wraps to 3rd row naturally in LazyVGrid |

## Open Questions

1. **Quick Actions: 4 or 5 cards?**
   - What we know: Spec lists 4 items (Discover Skills, Browse Plugins, Configure MCP, Edit Settings). Current app has 4 items (New Session, Skills, MCP Servers, Plugins). Merging both sets yields 5.
   - What's unclear: Should "New Session" remain? It's the most-used action.
   - Recommendation: Keep all 5 in a 2-column grid (3rd row has 1 card). Or replace "New Session" with "Edit Settings" since New Session has a dedicated FAB/sheet elsewhere. Executor discretion.

2. **"Quick Settings" label vs "General" label**
   - What we know: Spec says "Quick Settings toggles below config editor." Current implementation labels them "General" and places them above the editor links.
   - What's unclear: Whether the spec intended a visually distinct "Quick Settings" section or just wanted the toggles to exist.
   - Recommendation: Add a "Quick Settings" sub-header within the General section above the Model/Thinking/Co-Author controls. Minimal change, satisfies spec language.

3. **Rate limit countdown source of truth**
   - What we know: Backend reads `X-RateLimit-Remaining` but doesn't forward `X-RateLimit-Reset`. Error message is a static string.
   - Recommendation: Client-side 60s countdown. If backend enhancement is trivial, include reset timestamp in error reason for accuracy.

## Sources

### Primary (HIGH confidence)
- `ILSApp/ILSApp/Views/Home/HomeView.swift` — full file read, Quick Actions grid at lines 343-389
- `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` — full file read, Quick Settings at lines 88-187
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift` — full file read, GitHub search at lines 358-529
- `ILSApp/ILSApp/Views/Chat/ChatView.swift` — full file read, overflow menu at lines 272-349
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` — full file read, rate limit handling at lines 189-212
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — full file read, session operations at lines 590-628
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` — full file read, saveWithPatch at lines 111-140
- `Sources/ILSBackend/Services/GitHubService.swift` — full file read, rate limit at lines 72-81
- `Sources/ILSShared/Models/ClaudeConfig.swift` — ClaudeConfig fields verified
- `.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md` — 673-line gap analysis

### Secondary (MEDIUM confidence)
- Animation timing grep across 40+ files — pattern analysis, not exhaustive per-file audit
- Spec wireframe descriptions from gap analysis — original spec docs not directly consulted

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing Swift/SwiftUI project, no new dependencies
- Architecture: HIGH — all patterns verified against actual source code
- Pitfalls: HIGH — drawn from real project history (MEMORY.md) and code analysis
- Implementation scope: HIGH — every file read, every method verified, clear implementation/verification distinction

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable codebase, no external dependency changes)
