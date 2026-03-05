# Worktree Merge Consolidation Plan

## Summary

18 active worktrees exist. Analysis shows 3 categories:
- **7 stale** (no unique work, already merged or empty)
- **4 clean** (diverged recently, small focused diffs)
- **7 noisy** (diverged from old commit `8262f532`, need rebase before merge)

## Phase 1: Cleanup Stale Worktrees

These branches are already merged into master or have zero unique commits:

| # | Branch | Reason | Action |
|---|--------|--------|--------|
| 1 | `auto-claude/187` | No unique commits, at merge-base | Remove worktree + delete branch |
| 2 | `auto-claude/222` | Already merged to master | Delete branch only (no worktree) |
| 3 | `qa-temp-222` | QA temp for already-merged 222 | Remove worktree + delete branch |
| 4 | `auto-claude/229` | No unique commits | Remove worktree + delete branch |
| 5 | `auto-claude/231` | No unique commits (already merged per git log) | Remove worktree + delete branch |
| 6 | `auto-claude/235` | No unique commits | Remove worktree + delete branch |
| 7 | `auto-claude/237` | No unique commits | Remove worktree + delete branch |
| 8 | `audit-fixes` | Already merged to master | Delete branch only |

Risk: **None.** Zero work lost. Verified no unique commits exist.

## Phase 2: Merge Clean Branches (sequential)

These branches diverged from recent master, have clean diffs:

| Order | Branch | Files | Insertions | Feature |
|-------|--------|-------|------------|---------|
| 1 | `auto-claude/241` | 16 | +1,615 | CLI version monitor & update tracker |
| 2 | `auto-claude/249` | 9 | +1,173 | Cache eviction & memory management |
| 3 | `auto-claude/250` | 14 | +761 | Contextual AI prompt suggestions |
| 4 | `auto-claude/248` | 28 | +7,018 | Session automation rules & triggers |

Merge process per branch:
1. `git merge <branch>` on master
2. Build iOS + Backend
3. Fix any build errors
4. Commit, remove worktree, delete branch

## Phase 3: Rebase & Merge Noisy Branches (sequential)

These diverged from old commit `8262f532`. The diff shows ~383 base files + their actual changes. Need cherry-pick or rebase to extract just the feature commits.

| Order | Branch | Feature Commits | Feature |
|-------|--------|----------------|---------|
| 1 | `auto-claude/244` | 3 | Bonjour/mDNS backend auto-discovery |
| 2 | `auto-claude/245` | 3 | API key backend config wizard |
| 3 | `auto-claude/247` | 4 | Claude Code configuration profiles |
| 4 | `auto-claude/252` | 3 | Connection QR code pairing |
| 5 | `auto-claude/236` | 6+ | Backend process monitor |
| 6 | `auto-claude/239` | 6+ | Adaptive information density |
| 7 | `auto-claude/240` | 6+ | Smart paste code detection |
| 8 | `auto-claude/246` | 9+ | Workflow automation builder (largest) |

Strategy: Cherry-pick only the feature commits onto master (NOT rebase, which would replay all old divergent history).

## Phase 4: Build Verification & Functional Audit

After all merges:
1. Clean build iOS + macOS + Backend
2. Launch on simulator `50523130-57AA-48B0-ABD0-4D59CE455F14`
3. Screen-by-screen functional validation
4. Fix any issues found immediately

## Phase 5: Cleanup

1. `git worktree prune`
2. Verify `git worktree list` shows only main
3. Final clean build
