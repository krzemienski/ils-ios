---
phase: 50-backend-api
plan: 02
status: complete
started: 2026-02-27
completed: 2026-02-27
---

## Summary

Audited all backend controllers for `try?` error suppression on mutation paths. Fixed 4 locations where silent error swallowing could cause data loss (config overwrite with empty defaults). Read-only/best-effort paths correctly retain `try?`.

## What Changed

### Task 1: Fix MCPController mutation path error handling
- MCPController restart handler (line ~258): replaced `try?` chain with `do/catch` for file read (500) and `guard/else` for JSON parse (422)
- File-not-exists path still proceeds with empty dict (correct for first-time setup)
- Other `try?` usages left untouched: removeMCPServer (delete-if-exists), log listing (best-effort), log content read (best-effort)

### Task 2: Fix PluginsController mutation path error handling
- `addMarketplace`: replaced `(try? fileSystem.readConfig(scope: .user))?.content ?? ClaudeConfig()` with `do/catch` throwing 500
- `enablePlugin`: same pattern — `do/catch` with 500 on config read failure
- `disablePlugin`: same pattern — `do/catch` with 500 on config read failure
- Other `try?` usages left untouched: marketplace list (display-only, line 79), installed_plugins.json reads (lines 269-270, read-only), manifest reads (lines 295-296, read-only)

## Self-Check: PASSED

- [x] MCPController restart: file read failure → 500, JSON parse failure → 422
- [x] MCPController restart: file-not-exists proceeds normally (empty dict)
- [x] PluginsController addMarketplace: config read failure → 500
- [x] PluginsController enablePlugin: config read failure → 500
- [x] PluginsController disablePlugin: config read failure → 500
- [x] All read-only/best-effort `try?` usages unchanged
- [x] `swift build` passes cleanly
- [x] No new `try?` patterns on mutation paths

## Commits

- `b1c1589` feat(50-02): fix error handling on mutation paths in MCP and Plugins controllers

## Key Files

### Created
- (none — all changes to existing files)

### Modified
- Sources/ILSBackend/Controllers/MCPController.swift — restart handler error propagation
- Sources/ILSBackend/Controllers/PluginsController.swift — addMarketplace, enable, disable error propagation

## Deviations

None. Implementation matches plan exactly.
