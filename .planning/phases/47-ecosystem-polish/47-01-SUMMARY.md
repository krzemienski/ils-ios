# Summary: Plan 47-01 — Plugin Versioning & Dependency Management

## Status: COMPLETE

## What Was Built
Extended the plugin ecosystem with real version checking and dependency management:

1. **Plugin model extended** — Added `dependencies: [String]?`, `latestVersion: String?`, and `updateAvailable: Bool?` fields to Plugin struct in ILSShared
2. **PluginUpdateInfo DTO** — New response DTO with pluginName, currentVersion, latestVersion, updateAvailable, and unmetDependencies fields
3. **GitHubService.getLatestRelease** — Queries GitHub releases API for latest tag name, used for version comparison
4. **FileSystemService.scanPlugins** — Now extracts dependencies from plugin.json manifest, supporting both `[String]` and `[{name: String}]` formats; also overrides version from manifest
5. **PluginsController check-update endpoint** — `GET /plugins/:name/check-update` compares local version against GitHub latest release, returns unmet dependencies
6. **PluginsViewModel** — Added `checkForUpdate(pluginName:)` and `getUnmetDependencies(for:)` methods
7. **PluginConfigView** — Replaced TODO stub with real API call; shows "Update Available" with version text; added dependenciesSection with installed/missing indicators per dependency

## Requirements Satisfied
- **ECO-01**: Plugin detail view shows current version and indicates when an update is available with an Update button — PASS
- **ECO-02**: Installing a plugin with missing dependencies shows a warning listing unmet dependencies — PASS

## Key Files

### Created
- (none — all modifications to existing files)

### Modified
- `Sources/ILSShared/Models/Plugin.swift` — dependencies, latestVersion, updateAvailable fields
- `Sources/ILSShared/DTOs/ResponseDTOs.swift` — PluginUpdateInfo DTO
- `Sources/ILSBackend/Services/GitHubService.swift` — getLatestRelease method
- `Sources/ILSBackend/Services/FileSystemService.swift` — dependency extraction in scanPlugins
- `Sources/ILSBackend/Controllers/PluginsController.swift` — check-update route and handler
- `Sources/ILSBackend/Extensions/VaporContent+Extensions.swift` — PluginUpdateInfo Content conformance
- `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` — checkForUpdate, getUnmetDependencies
- `ILSApp/ILSApp/Views/Plugins/PluginConfigView.swift` — real update check, dependenciesSection
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift` — environment injection for PluginsViewModel

## Commits
1. `dc9dd83` — feat(47-01): add Plugin dependencies/version fields and PluginUpdateInfo DTO
2. `331f5b0` — feat(47-01): add check-update endpoint, getLatestRelease, dependency extraction
3. `16af4f1` — feat(47-01): wire real update check and dependency UI in PluginConfigView

## Self-Check: PASSED
- [x] Backend builds with zero errors
- [x] iOS builds with zero errors
- [x] macOS builds with zero errors
- [x] Plugin struct has dependencies, latestVersion, updateAvailable fields
- [x] PluginUpdateInfo DTO exists in ResponseDTOs.swift
- [x] GitHubService.getLatestRelease calls GitHub releases API
- [x] PluginsController has GET /plugins/:name/check-update route
- [x] PluginConfigView.checkForUpdates calls real backend endpoint
- [x] PluginConfigView shows Dependencies section with installed/missing status
- [x] PluginsViewModel.getUnmetDependencies returns correct unmet dependency list
