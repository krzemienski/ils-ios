---
name: audit-fix-loop
description: Autonomous audit-fix-build-verify loop — reads issue list, fixes each item, builds, verifies, commits if green, rolls back if red
---

# Autonomous Audit Fix Loop

Read an audit issue list and fix each issue autonomously with build verification.

## Input

Expects an issue list file as argument (e.g., `/audit-fix-loop scratch/audit-memory-2026-02-16.md`).

If no file specified, run `/axiom:audit all` first to generate issue lists in `scratch/audit-*.md`.

## Loop Per Issue

For each issue in the list:

### 1. Branch (optional — skip if user says "fix in place")
```bash
git stash  # Save any uncommitted work
```

### 2. Fix
- Read the issue description and affected file(s)
- Apply the minimal targeted fix
- Do NOT restructure the project or change build systems
- If fix requires more than 5 file changes, flag it for human review and skip

### 3. Build
```bash
# iOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5

# macOS (if macOS files were changed)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet 2>&1 | tail -5

# Backend (if backend files were changed)
swift build 2>&1 | tail -5
```

### 4. Verify
- If build succeeds: mark issue as FIXED, continue to next
- If build fails: revert ALL changes for this issue with `git checkout -- <files>`, log the error, move to next

### 5. Batch Commit
After every 5 successful fixes (or at the end), commit:
```bash
git add <fixed-files>
git commit -m "fix: audit batch — <count> issues fixed

<list of issues fixed>"
```

## Constraints

- **Time limit per issue**: 5 minutes max. If not fixed in 5 minutes, skip and log.
- **No scope creep**: Fix the exact issue described. Do not improve surrounding code.
- **No test files**: Do not write unit tests, mocks, or test doubles.
- **Revert on failure**: If a fix breaks the build, revert immediately.
- **Log everything**: Write progress to `scratch/audit-fix-log-{date}.md`

## Output

Generate summary at `scratch/audit-fix-summary-{date}.md`:
```markdown
# Audit Fix Summary — {date}

## Results
- Fixed: X issues
- Skipped (too complex): X issues
- Failed (build broke): X issues
- Total: X issues

## Fixed Issues
1. [file:line] Description — what was changed
2. ...

## Skipped Issues (need human review)
1. [file:line] Description — why it was skipped
2. ...

## Failed Issues
1. [file:line] Description — build error encountered
2. ...
```

## Rules
- One fix at a time, one build at a time
- Minimal changes only — no refactoring beyond the issue
- Always verify build before moving on
- Never spend more than 5 minutes on one issue
