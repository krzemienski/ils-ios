---
name: audit-fix-loop
description: >
  Autonomous fix loop for Axiom audit results in the ILS iOS/macOS/Vapor codebase.
  Reads issue lists from scratch/audit-*.md, classifies each by type (performance,
  accessibility, concurrency, energy, codable, architecture), applies the correct fix
  strategy, builds, verifies, reverts on failure, and commits in batches. Use after
  running /axiom:audit to fix identified issues. Handles Swift-specific cascade errors,
  ILSShared cross-target dependencies, and theme system changes.
---

# Audit Fix Loop

## Before You Start

Ask yourself:
- **Are builds currently green?** Run `bash scripts/headless-build.sh all` first. Never fix audit issues on a broken build.
- **How many issues?** <10: fix in place. 10-30: batch by type. >30: split into parallel workstreams (use Team).
- **Any ILSShared changes?** If audit issues touch `Sources/ILSShared/`, those must be fixed FIRST — both iOS and macOS depend on them.

## Fix Strategy by Issue Type

This is the core decision tree. Each issue type requires different thinking:

| Issue Type | Strategy | Watch Out For | Example Fix |
|------------|----------|---------------|-------------|
| **Performance** (Set lookups, detached I/O) | Replace `Array.contains` with `Set` lookup; move file I/O to `Task.detached(priority:)` | Check ALL callers of changed API; `Task.detached` loses actor context | `static let keywords: Set<String> = ["a", "b"]` |
| **Accessibility** (fonts, labels, hints) | Replace `.system(size: X)` with semantic font (`.caption`, `.body`); add `accessibilityHint`; use `@ScaledMetric` for spacing | Test at BOTH default AND extra-extra-large Dynamic Type; `.custom()` fonts need `relativeTo:` | `.font(.caption2)` instead of `.font(.system(size: 10))` |
| **Concurrency** (Task.detached, actor) | Replace `Task.detached` with plain `Task` (inherits actor context); add `@MainActor` where needed | `Task.detached` is almost NEVER what you want — it loses Sendable context; plain `Task` inherits correctly | `Task { await vm.load() }` not `Task.detached { await vm.load() }` |
| **Energy** (timers, polling, animation) | Add `Timer.tolerance`, store timer reference for cleanup, add `scenePhase` pause/resume | MUST invalidate timers in `deinit` or `.onDisappear`; forgetting creates immortal timers | `timer.tolerance = interval * 0.1` |
| **Codable** (JSONSerialization) | Create private `Codable` struct, replace `JSONSerialization` with `JSONDecoder`/`JSONEncoder` | Ensure `CodingKeys` match actual JSON field names; test with real API response | `struct Response: Codable { let items: [Item] }` |
| **Architecture** (try?, encapsulation) | Replace `try?` with `do/catch` + `AppLogger.shared.error()`; add `private(set)` to published vars | `try?` silently swallows errors — the catch block MUST log something useful | `do { try ... } catch { AppLogger.shared.error("\(error)", category: "net") }` |
| **Storage** (file locations, backup) | Move temp files to Caches, user data to Application Support; add `isExcludedFromBackup` | Never store temp/cache data in Documents (bloats iCloud backup); file protection `.complete` breaks on simulator | `url.resourceValues.isExcludedFromBackup = true` |

## The Fix Loop

For each issue:

### 1. Classify
Read the issue. Identify its type from the table above. If unclear, read the affected file first.

### 2. Check Dependencies
Before touching any file, ask:
- **Is this in ILSShared?** → Must build BOTH iOS and macOS after fix
- **Does this function have callers?** → Grep for the function name across the project
- **Is this a protocol method?** → All conforming types must be updated together

### 3. Apply Fix
Use the strategy from the decision tree. Minimal changes only.

### 4. Build
```bash
# Always build the target that owns the file
# ILSApp/**  → xcodebuild -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5
# ILSMacApp/** → xcodebuild -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5
# Sources/**  → swift build 2>&1 | tail -5
# ILSShared/** → build ALL THREE targets
```

### 5. Verify or Revert
- **Build succeeds**: Log as FIXED, continue
- **Build fails**: `git checkout -- <changed-files>`, log the error with exact compiler message, move to next
- **Cascade error** (fixing one thing breaks 5 others): STOP. This issue needs a coordinated multi-file fix — flag for human review

### 6. Batch Commit
After every 5 successful fixes (or at the end):
```bash
git add <fixed-files>
git commit -m "fix: audit batch — N issues (type: performance/accessibility/etc)"
```

## NEVER

- **NEVER change a function from sync to async without updating ALL callers** — the PollingManager refactor required updating 6 callers across ILSAppApp.swift AND ILSMacApp.swift; missing one = build failure
- **NEVER add `as! Type` to fix a type error** — masks the real problem, crashes at runtime
- **NEVER use `Task.detached` to "move work off main thread"** — it loses actor context and Sendable safety; use plain `Task` which inherits correctly
- **NEVER replace `try?` with `try!`** — that's worse; use `do/catch` with `AppLogger.shared.error()`
- **NEVER fix ILSShared files without building BOTH iOS and macOS** — they share the module and WILL break the other target
- **NEVER batch more than 5 fixes before building** — Swift cascade errors make root cause diagnosis impossible beyond 5 changes
- **NEVER trust the audit report blindly** — SyntaxHighlighter was flagged for "Array.contains" but already used `Set<String>` for all 17 grammar classes; always READ the file before fixing
- **NEVER fix a @State/@Binding issue by changing the default value** — changing `activeScreen` default crashes the app because @EnvironmentObject isn't ready during @State init

## Constraints

- **5 minutes max per issue** — skip and log if not resolved
- **No test files** — validate through real builds, not mocks
- **No scope creep** — fix the exact issue, don't improve surrounding code
- **Log everything** to `scratch/audit-fix-log-{date}.md`

## Output

Write to `scratch/audit-fix-summary-{date}.md`:
```markdown
# Audit Fix Summary — {date}

| Metric | Count |
|--------|-------|
| Fixed | X |
| Skipped (too complex) | X |
| Failed (build broke) | X |
| False positive (already correct) | X |

## Fixed (by type)
| # | File:Line | Type | What Changed |
|---|-----------|------|-------------|

## Skipped (needs human review)
| # | File:Line | Why |
|---|-----------|-----|

## Failed (build errors)
| # | File:Line | Compiler Error |
|---|-----------|----------------|
```
