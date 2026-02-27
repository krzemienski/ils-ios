# Phase 47: Ecosystem Polish - Research

**Researched:** 2026-02-27
**Domain:** Plugin versioning, dependency management, MeshGradient themes, String Catalog migration
**Confidence:** HIGH

## Summary

Phase 47 addresses four ecosystem gaps (ECO-01 through ECO-04) identified in the comprehensive gap analysis. The work spans three distinct domains: plugin ecosystem (versioning + dependency management), theme system (MeshGradient support), and localization infrastructure (String Catalog migration).

The plugin versioning (ECO-01) and dependency management (ECO-02) requirements are the most implementation-heavy. The current `PluginConfigView` already has a "Check for Updates" button with a TODO stub and the `Plugin` model already has a `version` field. The work is wiring these to real data -- reading `plugin.json` manifests for version/dependency info and comparing against the GitHub API for latest releases. MeshGradient (ECO-03) is straightforward since iOS 18+ is the deployment target and the API is well-documented. String Catalog migration (ECO-04) is a mechanical Xcode operation with 34 strings across 4 languages.

**Primary recommendation:** Implement ECO-01 and ECO-02 together (both modify Plugin model and backend), then ECO-03 (theme system only), then ECO-04 (localization infrastructure -- separate from code changes).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ECO-01 | Plugin versioning with auto-update availability check | Plugin model already has `version: String?`. Backend reads `plugin.json` manifest but only extracts `description`. Need to also extract `version` and add a `/plugins/:name/check-update` endpoint that compares local version against GitHub latest release tag. PluginConfigView already has `checkForUpdates()` stub. |
| ECO-02 | Plugin dependency management (detect conflicts, warn on missing deps) | Plugin model needs a `dependencies: [String]?` field. Backend `listPlugins()` reads `plugin.json` but ignores `dependencies` array. Need to parse it, cross-reference against installed plugins, and surface unmet deps. iOS install flow needs pre-install dependency check with warning UI. |
| ECO-03 | MeshGradient theme support verification in theme system | `MeshGradient` is available since iOS 18.0 / macOS 15.0 (confirmed via Context7). No current usage in codebase. ThemeEditorView needs a new "Background Style" section allowing MeshGradient configuration. ThemeSnapshot needs an optional `meshGradientBackground` property. CustomTheme needs a `MeshGradientConfig` token struct. |
| ECO-04 | String Catalog (.xcstrings) migration from .lproj format | 4 `.lproj` directories exist (Base, es, de, ja) with 34 string pairs each (54 lines per file). Xcode has built-in "Migrate to String Catalog" right-click action. No `NSLocalizedString` or `String(localized:)` calls found in Swift code -- strings are used as raw literals. Migration is mechanical: right-click -> Migrate, then delete .lproj directories. |
</phase_requirements>

## Standard Stack

### Core

| Library/API | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| SwiftUI `MeshGradient` | iOS 18+ | Gradient mesh backgrounds for themes | Apple first-party, no dependencies needed |
| GitHub REST API v3 | Current | Check latest release tags for plugin version comparison | Already used via `GitHubService` in backend |
| Xcode String Catalogs | Xcode 15+ | Modern localization format replacing .lproj | Apple recommended, built-in migration tooling |
| `SemanticVersion` comparison | Manual | Compare plugin version strings (semver) | Lightweight -- only need `>` comparison for 2 version strings |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Foundation.ComparisonResult` | Built-in | String-based version comparison | For semver comparison without external deps |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual semver comparison | `swift-semver` SPM package | Adds dependency for trivial comparison; manual is sufficient for `X.Y.Z` strings |
| GitHub Releases API | npm registry / custom registry | GitHub API is already integrated; no need for another registry |
| MeshGradient | ShaderGraph / Metal | Massive overkill; MeshGradient is declarative SwiftUI |

## Architecture Patterns

### ECO-01/02: Plugin Versioning & Dependencies

**Pattern: Manifest-First with Lazy Remote Check**

The backend already reads `plugin.json` manifests from installed plugin directories. Extend this to extract `version` and `dependencies` fields alongside `description`. Version check against GitHub is lazy (user-triggered via "Check for Updates" button), not automatic on every load.

```
Plugin Install Flow (with dependency check):
1. User taps Install
2. POST /plugins/install receives { pluginName, marketplace }
3. Backend clones repo, reads plugin.json
4. Extract dependencies array from manifest
5. Cross-reference against installed plugins list
6. Return Plugin response with `dependencies` and `unmetDependencies` fields
7. iOS shows warning sheet if unmetDependencies is non-empty
8. User confirms or cancels

Plugin Update Check Flow:
1. User taps "Check for Updates" in PluginConfigView
2. GET /plugins/:name/check-update
3. Backend reads local plugin.json version
4. Calls GitHub API: GET /repos/{owner}/{repo}/releases/latest
5. Compares tag_name against local version
6. Returns { currentVersion, latestVersion, updateAvailable }
7. PluginConfigView shows "Update Available" badge + Update button
```

### ECO-03: MeshGradient Theme Integration

**Pattern: Optional Background Layer**

MeshGradient is an optional background style for themes. The ThemeSnapshot gets an optional computed property that produces a `MeshGradient` view when configured. The ThemeEditorView gets a new section for configuring mesh gradient parameters (grid size, control points, colors).

```swift
// MeshGradient as theme background -- simple 3x3 grid
MeshGradient(
    width: 3, height: 3,
    points: [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
    ],
    colors: [
        theme.bgPrimary, theme.accent.opacity(0.3), theme.bgPrimary,
        theme.accentSecondary.opacity(0.2), theme.bgPrimary, theme.accent.opacity(0.2),
        theme.bgPrimary, theme.accentSecondary.opacity(0.3), theme.bgPrimary
    ]
)
.ignoresSafeArea()
```

### ECO-04: String Catalog Migration

**Pattern: In-Place Xcode Migration**

Xcode provides a built-in migration path. Right-click on `Localizable.strings` in the project navigator, select "Migrate to String Catalog". This produces a single `Localizable.xcstrings` file containing all languages. The old `.lproj` directories are removed after migration.

**Key constraint:** The current codebase does NOT use `NSLocalizedString()` or `String(localized:)` calls. All UI text is hardcoded string literals in SwiftUI `Text()` views. String Catalogs work by Xcode automatically extracting string literals from SwiftUI `Text()` views at build time. This means the migration will:
1. Convert existing `.lproj` files to `.xcstrings` format
2. Xcode will auto-detect `Text("string")` literals and add them to the catalog
3. The 34 existing translated strings remain intact

### Anti-Patterns to Avoid

- **Automatic update checking on plugin list load:** This would fire GitHub API requests for every plugin on every list refresh. Use lazy, user-triggered checks only.
- **Blocking install on unmet dependencies:** Show a warning, not a hard block. Some plugins work partially without all dependencies.
- **Animated MeshGradient by default:** Animation is expensive. Offer static MeshGradient first; animation can be a future enhancement.
- **Re-implementing localization extraction:** Do NOT manually create the `.xcstrings` file. Let Xcode's migration tool handle it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Semver comparison | Custom parser with regex | `String.compare(_:options: .numeric)` | Handles X.Y.Z comparison correctly for simple cases |
| String Catalog file format | Manual JSON construction | Xcode "Migrate to String Catalog" tool | The .xcstrings format is complex JSON with state tracking; Xcode generates it perfectly |
| GitHub release version lookup | Custom HTML scraping | GitHub REST API `GET /repos/{owner}/{repo}/releases/latest` | Already have `GitHubService` with authenticated HTTP client |
| MeshGradient point calculation | Manual Bezier math | SwiftUI `MeshGradient` with simple grid points | The API handles all interpolation internally |

**Key insight:** All four requirements leverage existing infrastructure. Plugin model already has `version`. Backend already reads `plugin.json`. GitHub API is already integrated. MeshGradient is a built-in SwiftUI view. String Catalog migration is a one-click Xcode operation.

## Common Pitfalls

### Pitfall 1: GitHub API Rate Limiting on Version Checks
**What goes wrong:** Checking updates for 80+ plugins triggers rate limit (60 req/hour unauthenticated)
**Why it happens:** Each plugin version check = 1 API call to `/repos/{owner}/{repo}/releases/latest`
**How to avoid:** Only check one plugin at a time (user-triggered from detail view). Cache results for 1 hour. Use the existing `GitHubService` which already handles rate limiting.
**Warning signs:** 429 responses, `gitHubError` being set in PluginsViewModel

### Pitfall 2: Plugin Manifest Schema Variance
**What goes wrong:** Different plugins use different manifest formats -- some have `plugin.json`, others have `package.json`, some have `.claude-plugin/plugin.json`
**Why it happens:** No enforced schema for Claude Code plugins
**How to avoid:** Backend already checks 3 manifest paths (lines 286-293 in PluginsController). Extend this pattern. Treat all fields as optional. Use nil-coalescing defaults.
**Warning signs:** Nil version or empty dependencies array when manifest exists

### Pitfall 3: MeshGradient Requires Exact Point Count
**What goes wrong:** `MeshGradient` crashes if `points.count != width * height` or `colors.count != width * height`
**Why it happens:** The API requires exactly `width x height` elements in both arrays
**How to avoid:** Use a fixed 3x3 grid (9 points, 9 colors) for the initial implementation. Validate array sizes before constructing the gradient. Provide sensible defaults.
**Warning signs:** Fatal error at runtime, blank gradient view

### Pitfall 4: String Catalog Migration Breaks Build References
**What goes wrong:** After migration, old `.lproj` file references remain in `project.pbxproj`, causing "file not found" build errors
**Why it happens:** Xcode's migration tool sometimes leaves stale references
**How to avoid:** After migration, do a clean build. If errors appear, remove stale references from the Xcode project navigator. Verify with `xcodebuild` before committing.
**Warning signs:** Build errors referencing `Base.lproj/Localizable.strings` after migration

### Pitfall 5: MeshGradient Not Available on macOS 14
**What goes wrong:** If the macOS deployment target is below 15.0, MeshGradient won't compile
**Why it happens:** MeshGradient requires macOS 15.0+
**How to avoid:** The project targets macOS 14+. Wrap MeshGradient usage in `if #available(macOS 15.0, *)` checks. Since the app is built with Xcode 26.3 and runs on macOS 26.0, this is available at runtime, but the deployment target in `project.yml` may still be macOS 14. Check and guard accordingly.
**Warning signs:** Compilation error on macOS scheme mentioning availability

## Code Examples

### Plugin Version Check Endpoint (Backend)

```swift
// Source: Extends existing PluginsController pattern
// New route: GET /plugins/:name/check-update
@Sendable
func checkUpdate(req: Request) async throws -> APIResponse<PluginUpdateInfo> {
    guard let name = req.parameters.get("name") else {
        throw Abort(.badRequest, reason: "Invalid plugin name")
    }

    // Read local version from installed plugin
    let plugins = try await fileSystem.listPlugins(bypassCache: false)
    guard let plugin = plugins.first(where: { $0.name == name }) else {
        throw Abort(.notFound, reason: "Plugin '\(name)' not found")
    }

    let currentVersion = plugin.version ?? "0.0.0"
    var latestVersion = currentVersion
    var updateAvailable = false

    // Check GitHub for latest release if marketplace is set
    if let marketplace = plugin.marketplace {
        if let release = try? await req.application.githubService.getLatestRelease(repo: marketplace) {
            latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            updateAvailable = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
        }
    }

    return APIResponse(success: true, data: PluginUpdateInfo(
        pluginName: name,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        updateAvailable: updateAvailable
    ))
}
```

### Plugin Dependencies in Model (ILSShared)

```swift
// Add to existing Plugin struct
public var dependencies: [String]?
public var latestVersion: String?
public var updateAvailable: Bool?
```

### MeshGradient Theme Background

```swift
// Source: Apple Developer Documentation - MeshGradient (iOS 18+)
// https://developer.apple.com/documentation/swiftui/meshgradient
struct MeshGradientBackground: View {
    let colors: [Color]

    init(colors: [Color] = []) {
        // Ensure exactly 9 colors for 3x3 grid
        if colors.count == 9 {
            self.colors = colors
        } else {
            self.colors = Array(repeating: Color.clear, count: 9)
        }
    }

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: colors
        )
        .ignoresSafeArea()
    }
}
```

### MeshGradient Config Token (ILSShared)

```swift
// Add to CustomTheme.swift
public struct MeshGradientConfig: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var width: Int       // Grid width (default 3)
    public var height: Int      // Grid height (default 3)
    public var colors: [String] // Hex color strings (width * height count)
    public var points: [[Double]]? // Optional custom control points
    public var animated: Bool   // Whether gradient animates (default false)

    public init(
        enabled: Bool = false,
        width: Int = 3,
        height: Int = 3,
        colors: [String] = [],
        points: [[Double]]? = nil,
        animated: Bool = false
    ) {
        self.enabled = enabled
        self.width = width
        self.height = height
        self.colors = colors
        self.points = points
        self.animated = animated
    }
}
```

### String Catalog Migration (Xcode Steps)

```
1. Open ILSApp.xcodeproj in Xcode
2. In Project Navigator, find Resources/Localizable.strings (Base)
3. Right-click -> "Migrate to String Catalog..."
4. Select all listed .strings files in the migration dialog
5. Click "Migrate"
6. Result: Single Localizable.xcstrings file with all 4 languages
7. Delete the now-empty .lproj directories
8. Clean Build Folder (Shift+Cmd+K)
9. Build to verify (xcodebuild)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.lproj/Localizable.strings` per language | `.xcstrings` String Catalog (single file, all languages) | Xcode 15 (WWDC 2023) | Simpler management, auto-extraction, state tracking |
| `LinearGradient` / `RadialGradient` | `MeshGradient` (2D grid of colored vertices) | iOS 18 (WWDC 2024) | Far richer gradient effects, Bezier control |
| Manual plugin version tracking | Package manifest with semver + registry check | Industry standard | Reliable update detection |

**Deprecated/outdated:**
- `.strings` and `.stringsdict` files: Still functional but Apple recommends migration to `.xcstrings`. Xcode will eventually deprecate the old format.
- `NSLocalizedString()` macro: Still works but `String(localized:)` (Swift 5.7+) and SwiftUI `Text()` auto-extraction are preferred.

## Open Questions

1. **Plugin manifest `dependencies` field format**
   - What we know: Claude Code plugin.json files have a `description` field. The backend already reads it.
   - What's unclear: Whether plugins consistently include a `dependencies` array and what format it uses (npm-style `["plugin-name"]` or `{"name": "version"}`).
   - Recommendation: Support both `[String]` (names only) and `[{"name": String, "version": String?}]` formats. Parse what's available, skip what's missing. Use names-only for dependency resolution (check if named plugin is installed).

2. **MeshGradient deployment target guard**
   - What we know: The iOS app targets iOS 17+, macOS app targets macOS 14+. MeshGradient requires iOS 18+ / macOS 15+.
   - What's unclear: Whether the deployment targets have been bumped since the project started.
   - Recommendation: Check `project.yml` for current deployment targets. If still iOS 17 / macOS 14, wrap MeshGradient in `if #available(iOS 18.0, macOS 15.0, *)` guards. Given Xcode 26.3 and Swift 6.2, runtime availability is guaranteed but compile-time guards may still be needed.

3. **String Catalog -- hardcoded strings in SwiftUI views**
   - What we know: The app uses `Text("literal")` throughout (no `NSLocalizedString`). String Catalogs auto-extract these.
   - What's unclear: How many of the ~150 Swift view files have strings that should be localized vs. strings that are intentionally non-localizable (like technical terms: "MCP", "SSE", "API").
   - Recommendation: Let Xcode extract all strings into the catalog. Mark technical terms as "Don't Translate" in the String Catalog editor. The 34 existing translated strings will carry over from the .lproj files.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: [MeshGradient](https://developer.apple.com/documentation/swiftui/meshgradient) - API reference, initializers, availability (iOS 18.0+)
- Context7 `/websites/developer_apple_swiftui` - MeshGradient initializer signatures, properties, BezierPoint API
- Apple WWDC23: [Discover String Catalogs](https://developer.apple.com/videos/play/wwdc2023/10155/) - String Catalog format and migration
- Apple Developer Documentation: [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)

### Secondary (MEDIUM confidence)
- [How to migrate from Localizable.strings to String Catalogs](https://tanaschita.com/20231106-migration-to-string-catalogs/) - Step-by-step migration guide
- [How to create a mesh gradient (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-mesh-gradient) - Practical examples
- [Animated Mesh Gradient in SwiftUI](https://medium.com/@rishixcode/animated-mesh-gradient-in-swiftui-e1c2e11ed6bf) - Animation techniques
- GitHub REST API: [Get latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release) - For version comparison

### Tertiary (LOW confidence)
- Plugin manifest `dependencies` field format: inferred from common patterns, not verified against Claude Code plugin spec (no official spec found)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs are Apple first-party or already integrated (GitHub API)
- Architecture: HIGH - All patterns extend existing code (Plugin model, PluginsController, ThemeEditor)
- Pitfalls: HIGH - Based on direct codebase analysis and API documentation
- ECO-01 (versioning): HIGH - Plugin.version exists, backend reads manifests, GitHub API integrated
- ECO-02 (dependencies): MEDIUM - Plugin manifest `dependencies` format is assumed, not verified
- ECO-03 (MeshGradient): HIGH - API is well-documented, deployment target supports it
- ECO-04 (String Catalog): HIGH - Xcode has built-in migration, small scope (34 strings, 4 languages)

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable APIs, no expected changes)
