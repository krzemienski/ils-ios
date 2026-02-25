# Phase 36: Browse, Skills & Plugins - Research

**Researched:** 2026-02-25
**Domain:** SwiftUI Browse UI, GitHub API integration, per-item state management
**Confidence:** HIGH

## Summary

Phase 36 addresses eight requirements (BRW-01 through BRW-08) that improve the Browse tab's GitHub skill search, add GitHub browse for plugins, implement per-item install/uninstall progress, add installed/enabled state badges, fix branch detection in `fetchRawContent`, and surface actionable rate limit errors.

The existing codebase already has substantial infrastructure: `GitHubService` (backend) handles GitHub Code Search API calls with caching, `SkillsViewModel` has GitHub search with debouncing, and `BrowserView` renders a `githubBrowseSection` for skills. The plugin side (`PluginsViewModel`) already has `installingPlugins: Set<String>` for per-item progress -- skills need the same pattern. The primary gaps are: (1) skills use global `isLoading` for install progress instead of per-item tracking, (2) no GitHub browse section exists for plugins, (3) `fetchRawContent` hardcodes the `main` branch, (4) rate limit 429 errors lack actionable messaging, (5) no installed badges on search results, (6) no enable/disable toggles on browse rows, (7) no context menu uninstall, and (8) skill enable/disable backend routes are missing.

**Primary recommendation:** Address these in three waves: backend fixes (branch detection, rate limit messaging, skill enable/disable endpoints), ViewModel state changes (per-item install tracking, installed state cross-referencing), and View layer updates (badges, toggles, context menus, plugin GitHub browse section).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BRW-01 | GitHub skill search returns results with name, description, stars, repo path | Already implemented in `SkillsViewModel.searchGitHub()` + `githubBrowseSection` in BrowserView. Results display name, description, stars, and repository path. Verify current rendering is correct. |
| BRW-02 | Per-item install progress indicator (not global isLoading blocking entire list) | Skills currently use `skillsVM.isLoading` globally (line 455-460 of BrowserView.swift). Must add `installingSkills: Set<String>` to SkillsViewModel (matching PluginsViewModel pattern with `installingPlugins`). |
| BRW-03 | Installed state badge on GitHub search result rows | No badge exists. Must cross-reference `gitHubResults` against `skills` array (match on repository name) and show "Installed" capsule badge on matching rows. |
| BRW-04 | Plugin GitHub browse UI in Plugins tab (symmetry with skills tab) | No GitHub browse section exists in plugins content. Must add `pluginGitHubBrowseSection` mirroring `githubBrowseSection`, with GitHub search for plugins. Backend `PluginsController` already has install endpoint. Need new GitHub search endpoint or reuse existing search with plugin-specific query. |
| BRW-05 | Enable/disable toggle inline on installed skill and plugin rows | Plugins already have enable/disable in PluginConfigView (detail view) but not inline on browse rows. Skills have `toggleSkillActive()` in ViewModel that calls non-existent backend endpoints. Must: (1) add enable/disable routes to SkillsController, (2) add inline toggles on both skill and plugin browse rows. |
| BRW-06 | GitHub fetchRawContent branch detection -- not hardcoded to main | `GitHubService.fetchRawContent()` hardcodes `/main/` in the URL (line 115). Must query GitHub Repos API for `default_branch` first, then use that branch in the raw content URL. |
| BRW-07 | Rate limit 429 shows actionable error | Backend throws `Abort(.tooManyRequests, reason: "GitHub API rate limit exceeded")` but the iOS client retries 429s automatically (APIClient.isRetriable). Must: (1) change backend error reason to include "Set GITHUB_TOKEN on host" message, (2) surface the specific error in SkillsViewModel/PluginsViewModel instead of generic error, (3) display in the GitHub browse section UI. |
| BRW-08 | Uninstall from browse tab via context menu on installed items | No `.contextMenu` exists on any BrowserView rows. Must add `.contextMenu { Button("Remove") }` on skill and plugin rows where item is installed/local. Skills use `deleteSkill()`, plugins use `uninstallPlugin()`. |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ / macOS 14+ | View layer | Project standard; all views use SwiftUI |
| `@Observable` | Swift 5.10+ | ViewModel state | Project pattern for all ViewModels |
| Vapor 4 | Latest | Backend API | Backend framework; GitHubService uses Vapor.Client |
| ILSShared | Local package | Shared models/DTOs | All models defined here, used by both targets |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GitHub REST API v3 | Current | Code search, repo metadata | Search for skills/plugins, fetch default branch |
| GitHub raw.githubusercontent.com | N/A | Raw file fetch | Download SKILL.md content for install |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GitHub Code Search API | GitHub Search Repositories API | Code Search finds SKILL.md files directly; Repos API would need content tree traversal |
| Per-item Set<String> tracking | AsyncStream per install | Set<String> is simpler, already proven in PluginsViewModel |

## Architecture Patterns

### Recommended File Changes
```
Sources/ILSBackend/
├── Services/GitHubService.swift        # Add getDefaultBranch(), update fetchRawContent()
├── Controllers/SkillsController.swift  # Add enable/disable routes
└── Controllers/PluginsController.swift # Add GitHub search endpoint for plugins

Sources/ILSShared/
├── DTOs/SearchResult.swift             # Add PluginGitHubSearchResult if needed (or reuse GitHubSearchResult)
└── DTOs/ResponseDTOs.swift             # Already has DeletedResponse, EnabledResponse

ILSApp/ILSApp/
├── ViewModels/SkillsViewModel.swift    # Add installingSkills: Set<String>, gitHubError, isInstalled()
├── ViewModels/PluginsViewModel.swift   # Add gitHubSearchText, gitHubResults, searchGitHub()
└── Views/Browser/BrowserView.swift     # Per-item spinners, badges, toggles, context menus, plugin browse
```

### Pattern 1: Per-Item Install Progress (Set<String>)
**What:** Track installing items by identifier in a Set, not a global boolean.
**When to use:** Any list where individual items can be independently installed/uninstalled.
**Example (already exists in PluginsViewModel):**
```swift
// PluginsViewModel.swift -- existing pattern to replicate for skills
var installingPlugins: Set<String> = []

func installPlugin(name: String, marketplace: String) async {
    installingPlugins.insert(name)
    defer { installingPlugins.remove(name) }
    // ... perform install
}
```

**For skills (to add):**
```swift
// SkillsViewModel.swift -- new pattern
var installingSkills: Set<String> = []

func installFromGitHub(result: GitHubSearchResult) async -> Bool {
    installingSkills.insert(result.repository)
    defer { installingSkills.remove(result.repository) }
    // ... existing install logic
}
```

### Pattern 2: Installed State Cross-Reference
**What:** Check if a GitHub search result is already installed by matching repository name against local skills list.
**When to use:** When showing install/installed state on search results.
**Example:**
```swift
// SkillsViewModel
func isInstalled(result: GitHubSearchResult) -> Bool {
    let repoName = result.repository.split(separator: "/").last.map(String.init) ?? result.repository
    return skills.contains { $0.name == repoName || $0.path.contains(repoName) }
}
```

### Pattern 3: Context Menu Uninstall
**What:** SwiftUI `.contextMenu` on browse rows for destructive actions.
**When to use:** Secondary actions that don't warrant a dedicated button.
**Example:**
```swift
browserRow(...)
    .contextMenu {
        if skill.source == .local || skill.source == .github {
            Button(role: .destructive) {
                Task { await skillsVM.deleteSkill(skill) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
```

### Pattern 4: GitHub Default Branch Detection
**What:** Query GitHub Repos API before fetching raw content to get the actual default branch.
**When to use:** Any raw.githubusercontent.com fetch where branch is unknown.
**Example:**
```swift
// GitHubService.swift
func getDefaultBranch(owner: String, repo: String) async throws -> String {
    let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)")
    var headers = HTTPHeaders()
    headers.add(name: .accept, value: "application/vnd.github.v3+json")
    headers.add(name: .userAgent, value: "ILS-Backend/1.0")
    if let token = token {
        headers.add(name: .authorization, value: "Bearer \(token)")
    }
    let response = try await client.get(uri, headers: headers)
    guard response.status == .ok else {
        return "main" // fallback
    }
    struct RepoInfo: Codable {
        let defaultBranch: String
        enum CodingKeys: String, CodingKey {
            case defaultBranch = "default_branch"
        }
    }
    let info = try response.content.decode(RepoInfo.self)
    return info.defaultBranch
}
```

### Anti-Patterns to Avoid
- **Global isLoading for per-item operations:** Blocks entire list during one item's install. Use `Set<String>` keyed by item identifier.
- **Hardcoded branch names:** Not all repos use `main` -- some use `master`, custom names, etc. Always query first.
- **Silent error swallowing for rate limits:** 429 errors need user-facing messaging, not just logging + retry.
- **Duplicating GitHub browse UI:** Skills and plugins GitHub browse sections should share as much view code as possible (helper functions, row builders).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Debounced search | Manual Timer/DispatchWorkItem | Existing `debouncedGitHubSearch()` pattern in SkillsViewModel | Already handles cancellation, 300ms delay, empty query clearing |
| Per-item progress | Custom progress tracking objects | `Set<String>` with insert/remove around async call | Proven pattern in PluginsViewModel, O(1) contains check |
| GitHub API auth | Custom OAuth flow | `GITHUB_TOKEN` env var on host (already in GitHubService) | Standard for server-side GitHub API access |
| Rate limit backoff | Exponential retry logic | Surface error to user with actionable message | User needs to set token, not wait for automatic retry |

**Key insight:** The codebase already has working patterns for most of what's needed. BRW-02 is literally copying the `installingPlugins` pattern to skills. BRW-04 is copying the skills GitHub browse section to plugins. The real work is in the details: branch detection, error surfacing, and cross-referencing installed state.

## Common Pitfalls

### Pitfall 1: GitHub API Rate Limiting Without Token
**What goes wrong:** Unauthenticated GitHub Code Search API allows only 10 requests/minute. Users hit 429 quickly during browsing.
**Why it happens:** `GITHUB_TOKEN` env var is not set on the host by default.
**How to avoid:** Surface the error clearly: "GitHub search limit reached. Set GITHUB_TOKEN on host to increase limits." Don't auto-retry 429s for GitHub search (the client's `isRetriable` logic retries 429s, which wastes quota).
**Warning signs:** Search stops returning results after a few queries.

### Pitfall 2: Branch Detection Adding Latency
**What goes wrong:** Extra API call to get default branch adds ~200-500ms per install.
**Why it happens:** GitHub Repos API call before raw content fetch.
**How to avoid:** Cache the default branch per repo (already have `IndexingService` caching). Or try the raw fetch with `main` first, fall back to querying branch on 404.
**Warning signs:** Install feels sluggish compared to before.

### Pitfall 3: Installed State Check Race Condition
**What goes wrong:** GitHub search results show "Install" button for skills that were just installed because the local skills list hasn't refreshed.
**Why it happens:** `installFromGitHub` reloads skills list, but the GitHub results aren't re-evaluated.
**How to avoid:** After successful install, re-evaluate installed state on the existing `gitHubResults` array rather than relying on full reload timing.
**Warning signs:** "Install" button remains visible after successful install.

### Pitfall 4: Skill Enable/Disable Backend Missing
**What goes wrong:** `SkillsViewModel.toggleSkillActive()` calls POST `/skills/{name}/enable` and `/skills/{name}/disable` but these routes don't exist in `SkillsController`.
**Why it happens:** Routes were planned but never added.
**How to avoid:** Must add these routes to `SkillsController.boot()` and implement handlers. Skill enable/disable could work by renaming the file (adding `.disabled` suffix) or by updating a config file.
**Warning signs:** Toggle calls silently fail with 404.

### Pitfall 5: macOS Regression
**What goes wrong:** BrowserView changes break macOS because macOS uses the same BrowserView.
**Why it happens:** All Browse changes affect both platforms.
**How to avoid:** Use `#if os(iOS)` only for platform-specific APIs (haptics, text input capitalization). The main view logic should work identically on both platforms. Build both schemes after changes.
**Warning signs:** macOS build fails after iOS-focused changes.

## Code Examples

### Current GitHub Result Row (BrowserView.swift lines 405-476)
The existing `gitHubResultRow` function shows name, description, stars, and repository path. It uses `skillsVM.isLoading` globally for the install button spinner. This needs three changes:
1. Replace `skillsVM.isLoading` with `skillsVM.installingSkills.contains(result.repository)`
2. Add "Installed" badge when `skillsVM.isInstalled(result:)` returns true
3. Disable install button when already installed

### Skill Enable/Disable Endpoint Pattern (from PluginsController)
```swift
// SkillsController -- pattern to add, based on PluginsController.enable/disable
@Sendable
func enableSkill(req: Request) async throws -> APIResponse<Skill> {
    guard let name = req.parameters.get("name") else {
        throw Abort(.badRequest, reason: "Invalid skill name")
    }
    try PathSanitizer.validateComponent(name)
    // Implementation: rename {name}.disabled.md → {name}/SKILL.md
    // or: update a skills config tracking enabled state
    let skill = try fileSystem.enableSkill(name: name)
    return APIResponse(success: true, data: skill)
}
```

### Rate Limit Error Surface Pattern
```swift
// GitHubService.swift -- improved error with actionable message
guard response.status == .ok else {
    if response.status == .forbidden || response.status == .tooManyRequests {
        throw Abort(.tooManyRequests, reason: "GitHub search limit reached. Set GITHUB_TOKEN on host to increase limits.")
    }
    throw Abort(.badGateway, reason: "GitHub API returned \(response.status)")
}

// SkillsViewModel.swift -- surface specific error in UI
var gitHubError: String?

func searchGitHub(query: String) async {
    // ...
    do {
        // ... search
        gitHubError = nil
    } catch {
        if let apiError = error as? APIClientError,
           case .serverError(let code, let reason) = apiError,
           code == "RATE_LIMITED" {
            gitHubError = reason // "GitHub search limit reached..."
        } else {
            self.error = error
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global `isLoading` for installs | Per-item `Set<String>` tracking | Already in PluginsViewModel | List stays browsable during install |
| Hardcoded `main` branch | Query GitHub Repos API for `default_branch` | This phase | Supports repos using `master`, custom branches |
| Silent 429 retry | Actionable error message | This phase | User knows to set GITHUB_TOKEN |

**Deprecated/outdated:**
- None identified -- patterns are current SwiftUI/Vapor best practices.

## Open Questions

1. **Skill enable/disable mechanism**
   - What we know: Backend has no routes for this. ViewModel already has `toggleSkillActive()` calling non-existent endpoints.
   - What's unclear: How should skill enable/disable actually work on the filesystem? Options: (a) rename file with `.disabled` suffix, (b) maintain a skills config JSON tracking enabled state, (c) leverage Claude Code's own skill enable/disable if it has one.
   - Recommendation: Use option (b) -- a simple JSON file at `~/.claude/skills/.skills-config.json` tracking `{ "disabledSkills": ["name1", "name2"] }`. This avoids renaming files and is consistent with how plugin enable/disable works via config.

2. **Plugin GitHub search endpoint**
   - What we know: Plugins currently only have a local search endpoint (`/plugins/search`). Skills have `/skills/search` that calls GitHub Code Search API.
   - What's unclear: Should plugins have their own GitHub search, or should we search GitHub for `plugin.json` files similar to how skills search for `SKILL.md`?
   - Recommendation: Add a parallel `/plugins/github-search` endpoint in PluginsController that searches GitHub for `plugin.json` or `.claude-plugin` files. Reuse `GitHubService` with different filename query.

3. **Branch detection caching**
   - What we know: `IndexingService` has caching for search results.
   - What's unclear: How long to cache default branch info?
   - Recommendation: Cache for 24 hours (branches rarely change). Use `IndexingService.cacheSearchResults` with key prefix `branch:owner/repo`.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- Direct reading of all relevant Swift files (BrowserView.swift, SkillsViewModel.swift, PluginsViewModel.swift, GitHubService.swift, SkillsController.swift, PluginsController.swift, Skill.swift, Plugin.swift, SearchResult.swift, Requests.swift, PluginConfigView.swift, APIClient.swift)
- **GitHub REST API v3** -- Code Search endpoint (`/search/code`), Repos endpoint (`/repos/{owner}/{repo}` for `default_branch` field), raw content (`raw.githubusercontent.com`)

### Secondary (MEDIUM confidence)
- **GitHub rate limits** -- Unauthenticated: 10 requests/minute for Code Search, 60/hour for REST. Authenticated with token: 30/minute for Code Search, 5000/hour for REST.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries/patterns already in project
- Architecture: HIGH -- extending existing proven patterns (Set<String>, GitHub browse section)
- Pitfalls: HIGH -- identified from direct code analysis of current gaps
- Open questions: MEDIUM -- skill enable/disable mechanism needs a decision

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable domain, no external dependency changes expected)
