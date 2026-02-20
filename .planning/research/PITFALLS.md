# Domain Pitfalls

**Domain:** Native iOS/macOS client for Claude Code -- comprehensive audit
**Researched:** 2026-02-19

## Critical Pitfalls

Mistakes that cause audit failures, rework, or major issues.

### Pitfall 1: Evidence Discipline Failure (MOST IMPORTANT)

**What goes wrong:** Agent claims screenshots PASS without actually reading them with the Read tool. File existence is NOT evidence of PASS. A screenshot may show a crash, wrong data, broken layout, or loading spinner.
**Why it happens:** Agents optimize for speed and assume "screenshot captured = screenshot correct."
**Consequences:** False PASS verdicts. Previous sessions scored 1.5-3.1/5.0 on reflexion specifically because of this.
**Prevention:** After EVERY `xcrun simctl io screenshot`, immediately use `Read` tool to visually inspect the screenshot. Check against PASS criteria. If ANY criterion fails, the screenshot is FAIL.
**Detection:** Audit report with PASS verdicts but no evidence of Read tool invocations on the screenshots.

### Pitfall 2: Wrong Backend Binary

**What goes wrong:** Running the OLD backend at `/Users/nick/ils/ILSBackend/` instead of the current one at `/Users/nick/Desktop/ils-ios/`.
**Why it happens:** Multiple ILS directories exist on the machine. Tab completion or cached shell history sends to wrong path.
**Consequences:** Old backend returns raw Claude Code data (bare arrays, snake_case) instead of proper `APIResponse` wrappers (camelCase). App displays no data or crashes on decode.
**Prevention:** ALWAYS verify with `lsof -i :9999 -P -n` -- binary path MUST contain `ils-ios`, NOT `ils/ILSBackend`.
**Detection:** curl responses that lack `{success: true, data: {...}}` wrapper.

### Pitfall 3: Simulator UDID Mismatch

**What goes wrong:** Using the wrong simulator UDID, which belongs to another AI session.
**Why it happens:** Multiple simulators exist. Agents pick the first one or use a different device.
**Consequences:** Interferes with other active sessions. Screenshots may show wrong app or wrong state.
**Prevention:** ALWAYS use UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max, iOS 18.6). NEVER use any other simulator.
**Detection:** Screenshots showing wrong device dimensions or unexpected app state.

### Pitfall 4: Scope Creep During Audit

**What goes wrong:** Finding a bug during visual audit leads to architectural refactoring, which leads to new bugs, which leads to more refactoring. The audit never completes.
**Why it happens:** Engineers naturally want to fix everything they find.
**Consequences:** Audit takes 10x longer. New bugs introduced by "fixes." Original evidence invalidated.
**Prevention:** Follow the plan's guardrails: "No architecture redesign -- targeted fixes only." Fix the specific issue, rebuild, re-verify. Do NOT expand the fix scope.
**Detection:** Git diff showing 50+ changed files when the audit plan expected 0-5 changes per phase.

### Pitfall 5: MCP Env Var Leakage

**What goes wrong:** MCP endpoint returns raw API keys/tokens in the `env` field instead of masked values.
**Why it happens:** `maskSensitiveEnv()` in `MCPController.swift` may not cover all code paths, or a new endpoint bypasses masking.
**Consequences:** Security vulnerability. API keys exposed to the iOS app and potentially cached/logged.
**Prevention:** Phase 6 specifically verifies that ALL env values are `***masked***`. Run the Python script to check every env value across all MCP servers.
**Detection:** `curl /api/v1/mcp | grep -v 'masked'` returns non-empty results for env values.

## Moderate Pitfalls

### Pitfall 6: Deep Link Confirmation Dialogs

**What goes wrong:** `xcrun simctl openurl "$UDID" "ils://browser"` shows a system dialog "Open in ILSApp?" that blocks automation.
**Why it happens:** iOS shows confirmation for custom URL schemes.
**Prevention:** Use `idb_tap` to confirm the dialog, or navigate via sidebar swipe + tap instead.

### Pitfall 7: DerivedData Staleness

**What goes wrong:** Installed app binary does not match latest code changes. Screenshots show old behavior.
**Why it happens:** `xcodebuild` incremental build succeeds but DerivedData has stale artifacts.
**Prevention:** After any code change, verify binary timestamp with `stat` on the `.app` bundle in DerivedData. If stale: `rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*`.
**Detection:** Screenshot shows old UI after a code change was supposed to fix something.

### Pitfall 8: Backend Port Conflict

**What goes wrong:** Port 9999 is already in use by a previous backend instance or another service.
**Why it happens:** Previous `swift run ILSBackend` was not killed, or the process became a zombie.
**Prevention:** Before starting backend: `lsof -i :9999 -P -n` and kill any existing process. After starting: verify with `curl -sf http://localhost:9999/health`.
**Detection:** Backend startup fails with "Address already in use" or the wrong binary responds.

### Pitfall 9: Cross-Platform Parity Miss

**What goes wrong:** Fix an iOS bug but forget to apply the same fix to macOS (or vice versa).
**Why it happens:** iOS and macOS share `ILSShared` models but have separate view layers.
**Prevention:** After EVERY iOS fix, check if the same file/pattern exists in `ILSMacApp/`. Build both targets.
**Detection:** macOS build fails after iOS-only changes, or macOS screenshots show bugs fixed on iOS.

### Pitfall 10: `import Crypto` vs `import CryptoKit`

**What goes wrong:** Using `import Crypto` in a Vapor context imports a DIFFERENT SHA256 implementation than expected.
**Why it happens:** Vapor depends on `swift-crypto` which provides `Crypto` module. `CryptoKit` is Apple's framework.
**Prevention:** Always use `import CryptoKit` for deterministic hashing in the iOS/macOS app.
**Detection:** Hash values differ between platforms or between builds.

## Minor Pitfalls

### Pitfall 11: Video Recording Kill Signal

**What goes wrong:** Using `kill -9` on `xcrun simctl io recordVideo` corrupts the video file.
**Prevention:** Use `kill -SIGINT` (or `kill -2`) and `wait` for graceful shutdown.

### Pitfall 12: Status Bar Override Persistence

**What goes wrong:** Status bar override ("9:41", full battery) persists across screenshots when not intended, or is cleared prematurely.
**Prevention:** Set override at start of screenshot session, clear at end: `xcrun simctl status_bar "$UDID" clear`.

### Pitfall 13: macOS Screenshot CGWindowID

**What goes wrong:** Using AppleScript `get id of window 1` returns an AX identifier, NOT a CGWindowID. `screencapture -l` requires CGWindowID.
**Prevention:** Use Quartz Python bindings: `CGWindowListCopyWindowInfo` to get `kCGWindowNumber`. Or fallback to `screencapture -x` (full screen).

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Phase 0 (Build) | DerivedData staleness | Clear DerivedData if any build behaves strangely |
| Phase 1 (Screenshots) | Deep link dialogs | Use idb_tap to dismiss, or navigate via sidebar |
| Phase 2 (AddMCPServerView) | Already done -- minimal risk | Verify file exists and BrowserView integrates it |
| Phase 3 (Mandates) | Evidence discipline | Read EVERY screenshot with Read tool before PASS |
| Phase 4 (Visual) | 28 screenshots = fatigue | Do NOT skip Read tool on any screenshot |
| Phase 5 (Functional) | Backend offline during test | Verify backend health before each interaction test |
| Phase 6 (Backend) | Env var leakage | Run masking verification script on EVERY MCP response |
| Phase 7 (Integration) | Data count mismatch | Compare exact numbers between curl and screenshot |
| Phase 8 (Bug Hunt) | Scope creep | Fix only the specific issue found, not the architecture |
| Phase 9 (Report) | Missing evidence files | Verify every referenced file exists before submitting |

## Historical Lessons (From Project Memory)

| Session | What Went Wrong | Lesson |
|---------|----------------|--------|
| Multiple sessions | Agents claimed PASS without reading screenshots | VERIFY step is MANDATORY |
| 2026-02-08 | Wrong backend binary at `/Users/nick/ils/` | ALWAYS check `lsof -i :9999` |
| 2026-02-17 | Reflexion score 1.5/5.0 | Validation protocols are NON-NEGOTIABLE |
| 2026-02-07 | 6 plans created over 10 days, incomplete validation | Plans without execution = wasted effort |
| Multiple | iOS fix not applied to macOS | Cross-platform check after EVERY fix |
| Multiple | `process.terminationStatus` crash | Always `waitUntilExit()` before accessing |
| 2026-02-17 | `CLAUDECODE=1` env var blocks subprocess | Strip `CLAUDE_CODE_*` env vars before spawning |

## Sources

- `CLAUDE.md` -- Common pitfalls section (from real sessions)
- `memory/MEMORY.md` -- Lessons learned across all sessions
- `.omc/plans/ils-comprehensive-audit-remediation.md` -- Risk mitigations per phase
- `.claude/skills/ils-ios-project/references/audit-backlog.md` -- Anti-patterns from auditors
