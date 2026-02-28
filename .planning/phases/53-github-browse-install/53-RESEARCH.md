# Phase 53: GitHub Browse & Install - Research

**Researched:** 2026-02-28
**Domain:** GitHub API integration, SwiftUI browse/search/install UX, backend proxy services
**Confidence:** HIGH

## Summary

Phase 53 adds a "Discover" tab to the BrowserView where users can search GitHub for skills and plugins, preview them (README content + file listing), and install with one tap. The critical finding is that **90% of the infrastructure already exists** -- the backend has `GitHubService` with `searchSkills()`, `searchPlugins()`, and `fetchRawContent()` endpoints, the iOS ViewModels (`SkillsViewModel`, `PluginsViewModel`) already have debounced GitHub search, install-from-GitHub, rate limit handling, and "installed" detection, and the `BrowserView` already renders inline GitHub search sections with result rows and install buttons at the bottom of both Skills and Plugins tabs.

What is **missing** and required by the success criteria:
1. A dedicated "Discover" tab (not just inline sections at the bottom of Skills/Plugins)
2. A preview/detail view for search results showing README content and file listing
3. A backend endpoint to fetch README content and repository file tree
4. Retry capability on network errors during install
5. Ensuring the plugin GitHub install flow is truly symmetric with skills

**Primary recommendation:** Refactor the existing inline GitHub browse sections into a proper "Discover" segment in the `BrowserSegment` enum, add a `GitHubPreviewView` detail screen, add two new backend endpoints (`/skills/preview` and `/plugins/preview` returning README + file tree), and add retry UI on install failure. Most code is reuse/refactor, not greenfield.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SKILL-01 | User can browse GitHub for skills with search, category filtering, and preview | Existing: `SkillsViewModel.searchGitHub()`, `GitHubService.searchSkills()`, inline browse section in BrowserView. Missing: dedicated Discover tab, preview view with README, category filtering in search UI |
| SKILL-02 | User can install skills from GitHub with progress indication and error handling | Existing: `SkillsViewModel.installFromGitHub()`, `SkillsController.install()`, progress spinner, `installingSkills` set. Missing: retry button on failure, error banner with retry option |
| SKILL-03 | User can browse GitHub for plugins with search, category filtering, and preview | Existing: `PluginsViewModel.searchGitHub()`, `GitHubService.searchPlugins()`, inline browse section. Missing: dedicated Discover tab, preview view, category filtering |
| SKILL-04 | User can install plugins from GitHub with progress indication and error handling | Existing: `PluginsViewModel.installFromGitHub()`, `PluginsController.install()`, progress spinner. Missing: retry button on failure, error banner |
</phase_requirements>

## Standard Stack

### Core (Already in Project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ / macOS 14+ | UI framework | Project standard, all views use SwiftUI |
| Vapor 4 | 4.x | Backend HTTP framework | Project backend, GitHubService already uses Vapor's `Client` |
| MarkdownUI | latest | Markdown rendering | Already used in `SkillDetailView` for rendering skill content |
| ILSShared | local | Shared DTOs | `GitHubSearchResult`, `SkillInstallRequest`, `Skill`, `Plugin` already defined |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TipKit | iOS 17+ | Contextual tips | Already imported in BrowserView, can add Discover tab tip |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GitHub REST API (via backend proxy) | GitHub GraphQL API | GraphQL would allow fetching README + file tree in one call, but adds complexity and the REST API is already working |
| Backend proxy for all GitHub calls | Direct GitHub API from iOS | Backend proxy is correct -- handles GITHUB_TOKEN, rate limit management, and caching via IndexingService |

## Architecture Patterns

### Recommended Project Structure

No new directories needed. Files slot into existing structure:

```
ILSApp/ILSApp/
├── Views/Browser/
│   ├── BrowserView.swift          # ADD: "Discover" segment case
│   ├── GitHubPreviewView.swift    # NEW: README + file tree + install button
│   └── SkillDetailView.swift      # EXISTING (pattern reference)
├── ViewModels/
│   ├── SkillsViewModel.swift      # ADD: fetchPreview() method
│   └── PluginsViewModel.swift     # ADD: fetchPreview() method
Sources/ILSBackend/
├── Controllers/
│   ├── SkillsController.swift     # ADD: preview route
│   └── PluginsController.swift    # ADD: preview route
├── Services/
│   └── GitHubService.swift        # ADD: fetchRepoContents(), fetchReadme()
Sources/ILSShared/
├── DTOs/
│   └── SearchResult.swift         # ADD: GitHubRepoPreview DTO
```

### Pattern 1: BrowserSegment Extension

**What:** Add a `.discover` case to the existing `BrowserSegment` enum, making it a 4-tab control (MCP / Skills / Plugins / Discover).

**When to use:** Success Criteria #1 requires a dedicated Discover tab.

**Example:**
```swift
enum BrowserSegment: String, CaseIterable {
    case mcp = "MCP"
    case skills = "Skills"
    case plugins = "Plugins"
    case discover = "Discover"  // NEW
}
```

**Alternative approach considered:** A sub-tab within Skills and Plugins (toggle between "Installed" and "Discover"). This would be more granular but adds navigation complexity. The success criteria says "Browser view includes a 'Discover' tab" -- a top-level segment is the most direct interpretation.

### Pattern 2: Shared GitHub Result Row (DRY)

**What:** The existing `gitHubResultRow(_:)` and `pluginGitHubResultRow(_:)` in BrowserView are nearly identical (same layout, different entity color). Extract a shared `GitHubResultRowView` component.

**When to use:** Both skills and plugins use the same row layout in the Discover tab.

**Example:**
```swift
struct GitHubResultRowView: View {
    let result: GitHubSearchResult
    let entityColor: Color
    let isInstalled: Bool
    let isInstalling: Bool
    let onInstall: () -> Void
    // ... shared layout
}
```

### Pattern 3: Preview View with Markdown Rendering

**What:** A detail view (pushed via NavigationLink) showing the full README rendered via MarkdownUI, a file listing, and an Install button.

**When to use:** Success Criteria #2 requires tapping a result to see "README content, file listing, and an Install button."

**Example:**
```swift
struct GitHubPreviewView: View {
    let result: GitHubSearchResult
    let entityType: EntityType  // .skill or .plugin

    @State private var readmeContent: String?
    @State private var files: [GitHubFile] = []
    @State private var isLoadingPreview = true
    @State private var installState: InstallState = .idle

    enum InstallState {
        case idle, installing, installed, failed(Error)
    }
}
```

### Pattern 4: Backend Preview Endpoint

**What:** A new endpoint that fetches README + file tree from GitHub in one backend call (two GitHub API calls, but one client request).

**When to use:** The iOS app should not call GitHub directly -- the backend proxies all GitHub API calls (handles GITHUB_TOKEN, caching, rate limits).

**Example backend route:**
```swift
// GET /skills/preview?repo=owner/repo
// Returns: { readme: String, files: [{ name, path, type, size }], stars: Int, description: String }
skills.get("preview", use: preview)
```

### Anti-Patterns to Avoid

- **Direct GitHub API calls from iOS:** All GitHub API calls go through the Vapor backend. The backend manages GITHUB_TOKEN, rate limit headers, and caching via IndexingService. Never call `api.github.com` from the iOS app directly.
- **Separate Discover screen outside BrowserView:** The success criteria says "Browser view includes a Discover tab." Keep it within BrowserView's segment control, not a separate navigation destination.
- **Fetching README on every search result render:** Only fetch README when the user taps a result to open the preview. Search results should only show name, description, stars (already available from the search response).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown rendering | Custom markdown parser | `MarkdownUI` library | Already used in SkillDetailView with themed rendering (ILSCodeHighlighter, custom blockquote, code block styles) |
| Debounced search | Custom debounce timer | Existing pattern in ViewModels | Both SkillsViewModel and PluginsViewModel already have `debouncedGitHubSearch()` with 300ms delay and task cancellation |
| Rate limit handling | Custom rate limit tracker | Existing countdown pattern | Both ViewModels already detect 429/rate limit errors, show countdown timer, and auto-clear after 60s |
| Search result caching | In-memory cache | `IndexingService` (SQLite cache) | Backend already caches GitHub search results with 1-hour TTL via Fluent/SQLite |
| Install progress tracking | Custom state machine | Existing `installingSkills`/`installingPlugins` Set pattern | ViewModels already track in-flight installs by repository name |

**Key insight:** The existing codebase has solved most of the hard problems (debouncing, rate limits, caching, install tracking). The phase is primarily UI refactoring and adding a preview layer, not building infrastructure.

## Common Pitfalls

### Pitfall 1: GitHub Search API Rate Limits (10 req/min for code search)

**What goes wrong:** GitHub Code Search API allows only 10 requests per minute for both authenticated and unauthenticated requests. Users rapidly typing in the search field can exhaust this quickly even with 300ms debounce.
**Why it happens:** The code search endpoint (`/search/code`) has stricter limits than other search endpoints (30/min). Unauthenticated requests get 10/min total across all search types.
**How to avoid:** The existing 300ms debounce is correct. Additionally: (1) the backend already caches results via IndexingService with 1-hour TTL, (2) the backend checks `X-RateLimit-Remaining` headers and logs warnings at <10 remaining, (3) both ViewModels detect 429 responses and show countdown. Add a minimum query length (3+ chars) to avoid wasting requests on single-character searches.
**Warning signs:** `rateLimitCountdown` appearing in UI, backend logs showing "GitHub API rate limit low."

### Pitfall 2: Confusing Discover Tab with Existing Inline GitHub Sections

**What goes wrong:** BrowserView already has GitHub browse sections at the bottom of Skills and Plugins tabs. Adding a Discover tab creates two places to search GitHub, confusing users.
**Why it happens:** The inline sections were built before the Discover tab was planned.
**How to avoid:** Remove the inline `githubBrowseSection` and `pluginGitHubBrowseSection` from skillsContent/pluginsContent and consolidate all GitHub browsing into the Discover tab. The Discover tab should have a sub-segment or toggle for "Skills" vs "Plugins" search.
**Warning signs:** Users seeing duplicate search results in two places.

### Pitfall 3: README Fetch Failure on Private/Missing READMEs

**What goes wrong:** Not all GitHub repos have a README.md at the root. Some use README.rst, some have no README, some are private.
**Why it happens:** `fetchRawContent()` currently hardcodes the path. READMEs can be at various paths.
**How to avoid:** The backend preview endpoint should try multiple README paths (`README.md`, `readme.md`, `README`, `README.rst`) and return an empty string if none found. Use GitHub's Repository Contents API (`/repos/{owner}/{repo}/readme`) which automatically finds the README regardless of name/case.
**Warning signs:** Preview views showing empty content area instead of graceful "No README" message.

### Pitfall 4: Large README Content Overwhelming Mobile UI

**What goes wrong:** Some READMEs are extremely long (10K+ lines). Loading and rendering the full content in MarkdownUI can cause UI jank or memory issues.
**Why it happens:** No truncation or lazy loading of markdown content.
**How to avoid:** Truncate README content to first 5000 characters on the backend preview endpoint. Show a "View on GitHub" link for the full version. MarkdownUI's rendering is already wrapped in ScrollView (see SkillDetailView pattern).
**Warning signs:** Preview view taking >2s to render, memory spikes on large READMEs.

### Pitfall 5: macOS Parity

**What goes wrong:** BrowserView is shared between iOS and macOS (imported in MacContentView). Changes must compile and look correct on both platforms.
**Why it happens:** The `#if os(iOS)` conditionals are already used for `.textInputAutocapitalization` and `.inlineNavigationBarTitle()`. Missing platform conditionals causes build failures.
**How to avoid:** Keep using the existing pattern of `#if os(iOS)` for iOS-only modifiers. Test builds on both schemes: `ILSApp` (iOS) and `ILSMacApp` (macOS).
**Warning signs:** macOS build failures after editing BrowserView.swift.

### Pitfall 6: Skill vs Plugin Install Asymmetry

**What goes wrong:** Skills install by fetching `SKILL.md` content and writing to `~/.claude/skills/{name}/SKILL.md`. Plugins install by `git clone --depth 1` to `~/.claude/plugins/{name}`. These are fundamentally different mechanisms but the UX should feel identical.
**Why it happens:** Skills are single-file markdown; plugins are multi-file repositories with manifests.
**How to avoid:** Both install flows already exist and work (`SkillsController.install()` and `PluginsController.install()`). The Discover tab should use the same visual pattern (Install button -> spinner -> "Installed" badge) for both. The backend handles the different mechanisms transparently.
**Warning signs:** Different error messages, different progress indicators, or different post-install behaviors between skills and plugins.

## Code Examples

### Existing GitHub Search Flow (Skills - verified from codebase)

```swift
// SkillsViewModel.swift (lines 209-233)
func searchGitHub(query: String) async {
    guard let client, !query.isEmpty else {
        gitHubResults = []
        return
    }
    isSearchingGitHub = true
    gitHubError = nil
    do {
        let response: APIResponse<ListResponse<GitHubSearchResult>> = try await client.get(
            "/skills/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        )
        if let data = response.data {
            gitHubResults = data.items
        }
    } catch {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("rate limit") || desc.contains("429") || desc.contains("limit reached") {
            gitHubError = "GitHub rate limit reached"
            startCountdown()
        } else {
            self.error = error
        }
    }
    isSearchingGitHub = false
}
```

### Existing Install Flow (Skills - verified from codebase)

```swift
// SkillsViewModel.swift (lines 235-250)
func installFromGitHub(result: GitHubSearchResult) async -> Bool {
    guard let client else { return false }
    installingSkills.insert(result.repository)
    defer { installingSkills.remove(result.repository) }
    do {
        let request = SkillInstallRequest(repository: result.repository, skillPath: result.skillPath)
        let _: APIResponse<Skill> = try await client.post("/skills/install", body: request)
        await loadSkills(refresh: true)
        return true
    } catch {
        self.error = error
        return false
    }
}
```

### Existing Backend GitHub Search (verified from codebase)

```swift
// GitHubService.swift (lines 43-111)
func searchSkills(query: String, page: Int = 1, perPage: Int = 20) async throws -> [GitHubSearchResult] {
    // Check cache first (IndexingService, 1-hour TTL)
    let cacheKey = "skills:\(query):p\(page):pp\(perPage)"
    if let cached = try await indexingService.getCachedResults(query: cacheKey) { ... }

    // GitHub Code Search: query + "filename:SKILL.md"
    let encodedQuery = "\(query)+filename:SKILL.md"
    let uri = URI(string: "https://api.github.com/search/code?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)")

    // Headers: Accept, UserAgent, optional Bearer token
    // Rate limit header checking
    // 429/403 -> throw Abort(.tooManyRequests)
    // Map GitHubCodeItem -> GitHubSearchResult
    // Cache results via IndexingService
}
```

### New: Preview DTO (to be added to ILSShared)

```swift
// Sources/ILSShared/DTOs/SearchResult.swift
public struct GitHubRepoPreview: Codable, Sendable {
    public let repository: String        // "owner/repo"
    public let name: String              // repo name
    public let description: String?
    public let stars: Int
    public let readme: String?           // markdown content (truncated to 5000 chars)
    public let files: [GitHubFileEntry]  // file tree
    public let lastUpdated: String?

    public init(repository: String, name: String, description: String? = nil,
                stars: Int = 0, readme: String? = nil, files: [GitHubFileEntry] = [],
                lastUpdated: String? = nil) {
        self.repository = repository
        self.name = name
        self.description = description
        self.stars = stars
        self.readme = readme
        self.files = files
        self.lastUpdated = lastUpdated
    }
}

public struct GitHubFileEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let type: String  // "file" or "dir"
    public let size: Int?

    public init(id: UUID = UUID(), name: String, path: String, type: String, size: Int? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.size = size
    }
}
```

### New: Backend Preview Endpoint Pattern

```swift
// GitHubService.swift - new methods
func fetchReadme(owner: String, repo: String) async throws -> String? {
    // Use GitHub's README API: GET /repos/{owner}/{repo}/readme
    // Returns base64-encoded content, decode to string
    // Truncate to 5000 chars for mobile
    let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)/readme")
    // ... headers, response handling
}

func fetchRepoContents(owner: String, repo: String, path: String = "") async throws -> [GitHubFileEntry] {
    // Use GitHub Contents API: GET /repos/{owner}/{repo}/contents/{path}
    // Returns array of { name, path, type, size }
    let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)")
    // ... headers, response handling
}
```

### New: Themed Markdown in Preview (reuse existing pattern)

```swift
// GitHubPreviewView.swift - reuse SkillDetailView's markdown theme
Markdown(readmeContent)
    .markdownTheme(buildSkillMarkdownTheme(from: theme))
    .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
    .textSelection(.enabled)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline GitHub search at bottom of tabs | Dedicated Discover tab (this phase) | Phase 53 | Consolidates search, adds preview |
| No preview before install | Preview with README + file tree | Phase 53 | Users can evaluate before installing |
| Install with no retry | Install with retry on failure | Phase 53 | Better error recovery |

**Deprecated/outdated:**
- The inline `githubBrowseSection` and `pluginGitHubBrowseSection` in BrowserView will be replaced by the Discover tab. These sections should be removed to avoid duplicate search surfaces.

## Open Questions

1. **Discover tab sub-navigation: toggle or picker?**
   - What we know: The Discover tab needs to search both skills and plugins. Skills search uses `filename:SKILL.md`, plugins use `filename:plugin.json`.
   - What's unclear: Should it be a single search that shows both types, or a sub-toggle (Skills/Plugins) within the Discover tab?
   - Recommendation: Use a sub-toggle (two-segment `Picker`) within the Discover tab -- "Skills" and "Plugins." This matches the existing pattern of `mcpScope` picker within the MCP tab. A single unified search would require merging results from two different GitHub Code Search queries with different filename filters, adding complexity with no UX benefit.

2. **GITHUB_TOKEN availability**
   - What we know: `GitHubService` reads `GITHUB_TOKEN` from environment. Without it, rate limits are 10 req/min (search) and 60 req/hour (general API).
   - What's unclear: Whether the typical user's host will have GITHUB_TOKEN set.
   - Recommendation: The backend already handles both cases. The countdown timer UI handles rate limit gracefully. No action needed -- just ensure the "Set GITHUB_TOKEN on host to increase limits" error message surfaces in the UI.

3. **Category filtering for GitHub search**
   - What we know: SKILL-01 and SKILL-03 mention "category filtering." GitHub Code Search does not support categories natively -- results come with repo description and topics/tags.
   - What's unclear: What "categories" means for GitHub search results vs local skills.
   - Recommendation: For local skills, categories = tags (already filterable). For GitHub search, add optional topic/language filter chips (e.g., "swift", "python", "testing") that append to the search query. This is lightweight and maps naturally to GitHub search qualifiers like `topic:testing`.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `BrowserView.swift`, `SkillsViewModel.swift`, `PluginsViewModel.swift`, `SkillDetailView.swift`, `PluginConfigView.swift`, `GitHubService.swift`, `SkillsController.swift`, `PluginsController.swift`, `APIClient.swift`
- Codebase analysis: `Sources/ILSShared/DTOs/SearchResult.swift`, `Sources/ILSShared/Models/Skill.swift`, `Sources/ILSShared/Models/Plugin.swift`
- [GitHub REST API Rate Limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) - Rate limit documentation
- [GitHub Search API](https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28) - Search endpoint limits: 10 req/min code search, 30 req/min other search

### Secondary (MEDIUM confidence)
- [GitHub Changelog - Updated rate limits for unauthenticated requests (May 2025)](https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/) - Recent rate limit policy changes

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, no new dependencies needed
- Architecture: HIGH - Extending existing BrowserView/ViewModel/Controller pattern, not creating new patterns
- Pitfalls: HIGH - Rate limit handling already implemented, cross-platform pattern established, install asymmetry understood from codebase analysis

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (stable -- GitHub API and existing codebase patterns unlikely to change)
