# Stack Research

**Domain:** Functional validation tooling for iOS/iPad SwiftUI app
**Researched:** 2026-02-25
**Confidence:** HIGH (all findings grounded in verified local tool inventory + Apple docs)

---

## Scope: What This File Covers

This document covers ONLY the stack additions/changes required for v3.5 Comprehensive Functional Validation:

1. iPad simulator setup and multi-device screenshot capture
2. Log streaming and crash report collection during validation
3. Evidence organization (numbered screenshots, structured directories)
4. Deep link navigation testing across both iPhone and iPad
5. Dual-agent confirmation workflow tooling

**Everything here describes net-new validation capabilities.** The existing app stack (SwiftUI, Vapor 4, Fluent/SQLite, etc.) is NOT changing. No new SPM packages, no Xcode project modifications, no new Swift source files are needed for validation tooling.

---

## What Already Exists -- Do NOT Re-Add or Reconfigure

| Capability | Already Working | Evidence |
|------------|----------------|----------|
| iPhone 16 Pro Max simulator | UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`, iOS 18.6 | Verified: `xcrun simctl list` |
| iPad Pro 13-inch (M4) simulator | UDID `C074375B-2CB2-4F95-A55C-972F2FF35041`, iOS 18.6, named "iPad Pro 13 ILS" | Verified: `xcrun simctl list -j` |
| idb (Facebook's iOS Development Bridge) | `/Users/nick/Library/Python/3.12/bin/idb` -- screenshot, tap, swipe, describe, log | Verified: `which idb` |
| xcrun simctl | screenshot via `io`, `openurl` for deep links, `install`, `launch`, `terminate`, `spawn log` | Verified: `xcrun simctl help` |
| Auto-build hook | Fires on every `.swift` edit, builds correct target | Configured in `.claude/settings.local.json` |
| Fastlane screenshots lane | Configured for iPhone 16 Pro Max, iPhone 16, iPad Pro 12.9" | `fastlane/Fastfile` |
| ILS-Validator-A | iPhone 16 Pro (`2B0BCA0C`), iOS 18.6 -- pre-created validator sim | Verified: `xcrun simctl list` |
| ILS-Validator-B | iPhone 16 (`A0B383E0`), iOS 18.6 -- pre-created validator sim | Verified: `xcrun simctl list` |
| Quick-5 audit patterns | 7/12 iPhone screens validated with numbered screenshots in `/tmp/cross-milestone-audit/` | `.planning/quick/5-*/5-SUMMARY.md` |
| Deep link handler | `ils://` scheme with 12+ routes (`home`, `sessions`, `browser`, `settings`, `system`, `fleet`, `themes`, etc.) | `ILSAppApp.swift` handleURL |

---

## Recommended Stack: Validation Tooling

### No new software to install. Zero.

Every tool needed for v3.5 is already present on this machine. The validation milestone is about **workflow scripts and evidence discipline**, not new technology.

---

### Core: Screenshot Capture

| Tool | Command Pattern | Use For | Why This One |
|------|----------------|---------|-------------|
| `xcrun simctl io` | `xcrun simctl io <UDID> screenshot <path>.png` | Primary screenshot tool for both iPhone and iPad | Works on any simulator state (booted), device-agnostic, outputs PNG directly, no companion needed |
| `idb screenshot` | `idb screenshot --udid <UDID> <path>.png` | Backup / when idb companion is already connected | Requires companion connection; simctl is simpler for batch capture |

**Use `xcrun simctl io` as primary.** It requires only a booted simulator (no idb companion handshake), works identically for iPhone and iPad, and outputs to any path. idb screenshot adds a companion connection step that can fail silently.

**Status bar cleanup for evidence screenshots:**
```bash
xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```
This gives consistent, professional screenshot evidence (Apple's standard "9:41" time). Run once after boot, persists for the session.

**Confidence:** HIGH -- verified `xcrun simctl io` help and `idb screenshot --help` on this machine.

---

### Core: iPad Simulator

| Item | Value | Notes |
|------|-------|-------|
| Simulator Name | `iPad Pro 13 ILS` | Already created, named for this project |
| UDID | `C074375B-2CB2-4F95-A55C-972F2FF35041` | Verified via `xcrun simctl list -j` |
| Device Type | iPad Pro 13-inch (M4), 8GB | `com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB` |
| Runtime | iOS 18.6 | Same as iPhone simulator -- consistent testing |
| Last Booted | 2026-02-20 | Has been used before; data directory exists (2.2GB) |
| Logical Resolution | 1032 x 1376 points | iPad Pro 13" in portrait (standard) |

**No new iPad simulator needed.** The "iPad Pro 13 ILS" already exists at iOS 18.6 matching the iPhone simulator runtime. Use this one exclusively for iPad validation.

**iPad build destination:**
```bash
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=C074375B-2CB2-4F95-A55C-972F2FF35041' -quiet
```

**iPad-specific validation concerns:**
- `NavigationSplitView` layout (persistent sidebar vs sheet sidebar on iPhone)
- Split-view proportions in landscape
- Multitasking size classes (1/3, 1/2, 2/3 split)
- Toolbar and navigation bar differences from iPhone

**Confidence:** HIGH -- simulator verified present and bootable.

---

### Core: Deep Link Testing

| Tool | Command Pattern | Use For |
|------|----------------|---------|
| `xcrun simctl openurl` | `xcrun simctl openurl <UDID> "ils://home"` | Trigger deep link navigation on any booted simulator |

**All known `ils://` routes to test:**
```
ils://home, ils://sessions, ils://sessions/{uuid}
ils://browser, ils://mcp, ils://skills, ils://plugins
ils://settings, ils://system, ils://fleet, ils://themes
```

**Multi-device deep link testing pattern:**
```bash
# iPhone
xcrun simctl openurl 50523130-57AA-48B0-ABD0-4D59CE455F14 "ils://skills"
xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /tmp/evidence/iphone-skills.png

# iPad (same command, different UDID)
xcrun simctl openurl C074375B-2CB2-4F95-A55C-972F2FF35041 "ils://skills"
xcrun simctl io C074375B-2CB2-4F95-A55C-972F2FF35041 screenshot /tmp/evidence/ipad-skills.png
```

**Known deep link caveat:** `xcrun simctl openurl` on a fresh install may trigger an "Open in ILSApp?" system dialog. The app must be launched at least once first via `xcrun simctl launch <UDID> com.ils.app` before deep links work without prompts.

**Confidence:** HIGH -- `xcrun simctl openurl` verified, deep link routes verified in codebase.

---

### Core: Log Streaming

| Tool | Command Pattern | Use For | Why |
|------|----------------|---------|-----|
| `idb log` | `idb log --udid <UDID> -- --process ILSApp --level info --style json` | Real-time app log streaming during validation | Filters by process name, JSON output for parsing, supports predicate filtering |
| `xcrun simctl spawn` | `xcrun simctl spawn <UDID> log stream --process ILSApp --level info` | Alternative log streaming | No idb companion needed; simpler but less filterable |

**Use `xcrun simctl spawn log stream` as primary** because it avoids idb companion connection overhead and works immediately on any booted simulator.

**Log capture pattern for evidence:**
```bash
# Start log capture in background, filtered to app process
xcrun simctl spawn <UDID> log stream --process ILSApp --level error \
  --style compact > /tmp/evidence/logs/iphone-errors.log 2>&1 &
LOG_PID=$!

# ... run validation steps ...

# Stop capture
kill $LOG_PID
```

**Crash log collection:**
```bash
# Via idb (structured)
idb crash list --udid <UDID>
idb crash show --udid <UDID> <crash_name>

# Via simctl (raw directory)
ls ~/Library/Logs/CoreSimulator/<UDID>/
```

**Confidence:** HIGH -- both `idb log --help` and `xcrun simctl spawn` verified on this machine.

---

### Core: UI Interaction (for navigating to screens)

| Tool | Command Pattern | Use For |
|------|----------------|---------|
| `idb ui swipe` | `idb ui swipe --udid <UDID> 5 500 300 500 --duration 0.3` | Open sidebar (swipe from left edge) |
| `idb ui tap` | `idb ui tap --udid <UDID> <x> <y>` | Tap specific UI elements |
| `idb describe` | `idb describe --udid <UDID> operation:all` | Get accessibility tree with exact coordinates |
| Deep links | `xcrun simctl openurl <UDID> "ils://settings"` | Navigate directly to any screen without tapping |

**Prefer deep links over tap-based navigation for validation.** Deep links are deterministic and device-independent. Tap coordinates differ between iPhone (440x956 points) and iPad (1032x1376 points). Use taps only for interactions that cannot be achieved via deep links (scrolling, context menus, sheet dismissal).

**iPad tap coordinates:** Must be recalculated via `idb describe` on the iPad simulator. iPhone coordinates from MEMORY.md (sidebar y-coords at x=80) will NOT work on iPad due to different layout (persistent sidebar column, not sheet).

**Confidence:** HIGH -- all tools verified present; coordinate caveat documented from prior sessions.

---

### Core: Evidence Organization

No tool needed -- this is a directory convention enforced by validation scripts.

**Recommended evidence structure:**
```
/tmp/v3.5-evidence/
  iphone/
    01-home.png
    02-sidebar.png
    03-sessions.png
    04-chat.png
    05-browser-mcp.png
    06-browser-skills.png
    07-browser-plugins.png
    08-settings-top.png
    09-settings-bottom.png
    10-system-monitor.png
    11-host-profiles.png
    12-themes.png
    13-hooks.png
    deeplinks/
      dl-home.png
      dl-skills.png
      ...
    logs/
      validation-run.log
      errors.log
  ipad/
    01-home.png
    02-sidebar-split.png
    ... (same numbering)
    deeplinks/
    logs/
  confirmation/
    agent-a-verdict.md
    agent-b-verdict.md
    discrepancies.md
```

**Numbering convention:** Two-digit prefix (`01-` through `nn-`), lowercase-hyphenated screen name, `.png` extension. Same numbering for iPhone and iPad enables 1:1 comparison.

**Why `/tmp/`:** Previous milestones used `/tmp/` for evidence (quick-5 used `/tmp/cross-milestone-audit/`, functional validation used `/tmp/audit-evidence/`). Consistent with project convention. Evidence is ephemeral -- the verdicts and summaries go into `.planning/`.

**Confidence:** HIGH -- pattern established in prior milestones.

---

### Dual-Agent Confirmation Workflow

No new tooling. This is a **process pattern**, not a technology requirement.

**How it works:**
1. Agent A performs validation: boots simulators, captures screenshots, writes verdicts
2. Agent B independently reviews the evidence: reads screenshots, reads logs, writes independent verdicts
3. Discrepancies between A and B verdicts trigger re-validation of the specific screen

**Tools Agent B needs (all already available):**
- `Read` tool to view screenshot files (Claude Code is multimodal)
- `Read` tool to parse log files
- `Bash` to verify simulator state if needed
- File write to produce confirmation verdicts

**What NOT to build:** Do not build a custom "validation framework", "test runner", or "evidence collector" application. The tools are `xcrun simctl`, `idb`, shell scripts, and the file system. Wrapping these in a Swift tool would add build complexity and a new maintenance surface for zero capability gain.

**Confidence:** HIGH -- agent confirmation is a workflow pattern, not a technology.

---

## Simulator Configuration Steps

### One-Time iPad Setup (if erase needed)

The iPad Pro 13 ILS simulator already exists. If a fresh start is needed:

```bash
# Erase to clean state (preserves simulator, wipes data)
xcrun simctl erase C074375B-2CB2-4F95-A55C-972F2FF35041

# Boot
xcrun simctl boot C074375B-2CB2-4F95-A55C-972F2FF35041

# Clean status bar for screenshots
xcrun simctl status_bar C074375B-2CB2-4F95-A55C-972F2FF35041 override \
  --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3

# Build and install
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=C074375B-2CB2-4F95-A55C-972F2FF35041' -quiet
xcrun simctl install C074375B-2CB2-4F95-A55C-972F2FF35041 \
  "$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 -type d | sort -t/ -k9 -r | head -1)"

# First launch (required before deep links work without dialog)
xcrun simctl launch C074375B-2CB2-4F95-A55C-972F2FF35041 com.ils.app
```

**CRITICAL: DerivedData stale binary trap.** The project has 40+ `ILSApp-*` directories in DerivedData (documented in quick-5 findings). Always find the NEWEST binary by modification time, never use `find | head -1`. The `sort -t/ -k9 -r | head -1` pattern above handles this.

### Running Both Simulators Simultaneously

Both iPhone and iPad can run concurrently:

```bash
# Boot both
xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14
xcrun simctl boot C074375B-2CB2-4F95-A55C-972F2FF35041

# Build once, install to both (same binary for iPhone and iPad)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 -type d | sort -t/ -k9 -r | head -1)"

xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 "$APP_PATH"
xcrun simctl install C074375B-2CB2-4F95-A55C-972F2FF35041 "$APP_PATH"
```

**Note:** The `-iphonesimulator` SDK builds a universal binary that runs on both iPhone and iPad simulators. No separate iPad build is required.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| XCTest / XCUITest framework | Project mandate: NO test frameworks, NO mocks, NO stubs | `xcrun simctl` + `idb` + shell scripts for all validation |
| Snapshot testing libraries (iOSSnapshotTestCase, swift-snapshot-testing) | These are test framework wrappers -- violates project rules | Direct `xcrun simctl io screenshot` with manual/agent review |
| Fastlane `capture_screenshots` for validation | Requires XCUITest scheme -- only use for App Store marketing screenshots | Direct simctl/idb screenshot capture |
| Custom Swift validation tool / test runner | Adds build target, maintenance burden, compilation time for zero capability over shell tools | Shell scripts calling xcrun/idb directly |
| Appium / Detox / other UI automation frameworks | Heavy, require server processes, designed for CI pipelines not agent-driven validation | Deep links + idb tap/swipe for the few interactions needed |
| New iPad simulator creation | "iPad Pro 13 ILS" already exists at iOS 18.6 | Use existing UDID `C074375B-2CB2-4F95-A55C-972F2FF35041` |
| pytest / any Python test framework for validation scripts | Adds dependency; shell scripts are sufficient and match project patterns | Bash scripts with `set -e` for fail-fast |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| `xcrun simctl io screenshot` | `idb screenshot` | simctl requires no companion; idb adds connection overhead |
| `xcrun simctl spawn log stream` | `idb log` | simctl spawn is simpler; idb log has richer predicates but needs companion |
| `xcrun simctl openurl` for deep links | `idb open` | simctl openurl is the standard; both work equivalently |
| `/tmp/v3.5-evidence/` flat structure | Database-backed evidence tracking | Shell + filesystem is the lightest approach; prior milestones used this successfully |
| Dual-agent review via file sharing | Custom gRPC/WebSocket agent coordination | Agents already share a filesystem; no IPC needed |
| iPad Pro 13-inch (M4) | iPad mini or iPad Air | Pro 13" is the largest iPad; if layout works here, smaller iPads are covered. Also already exists. |
| Status bar override via simctl | No cleanup | 9:41 time + full bars is Apple's standard for screenshots; looks professional |

---

## Device Matrix

| Device | Simulator Name | UDID | Runtime | Logical Resolution | Role |
|--------|---------------|------|---------|-------------------|------|
| iPhone 16 Pro Max | (default) | `50523130-57AA-48B0-ABD0-4D59CE455F14` | iOS 18.6 | 440 x 956 pt | Primary iPhone validation |
| iPad Pro 13" (M4) | iPad Pro 13 ILS | `C074375B-2CB2-4F95-A55C-972F2FF35041` | iOS 18.6 | 1032 x 1376 pt | Primary iPad validation |

**Do NOT use** ILS-Validator-A (`2B0BCA0C`, iPhone 16 Pro) or ILS-Validator-B (`A0B383E0`, iPhone 16) for this milestone. They are for other purposes. Two devices (one iPhone, one iPad) is the right scope.

---

## Version Compatibility

No version changes. All tools are pre-installed.

| Component | Version | v3.5 Impact |
|-----------|---------|-------------|
| Xcode / xcrun simctl | Xcode 16+ (iOS 18.6 runtime) | Screenshot, openurl, boot, install, status_bar, spawn log -- all used |
| idb | Python 3.12 install at `~/.local/bin/idb` | Backup for screenshot, log, crash, describe, tap, swipe |
| Fastlane | Configured in `fastlane/` | NOT used for v3.5 validation (requires XCUITest). Available for App Store screenshots later |
| xcodebuild | Xcode 16+ | Same build commands as development; no new flags needed |

---

## Sources

- Local machine: `xcrun simctl list devices -j` -- full simulator inventory with UDIDs, runtimes, device types: HIGH confidence (direct output)
- Local machine: `xcrun simctl help` -- all subcommands including `io`, `openurl`, `status_bar`, `spawn`: HIGH confidence
- Local machine: `idb --help` -- all subcommands including `screenshot`, `log`, `crash`, `describe`, `ui`: HIGH confidence
- Local machine: `idb screenshot --help` -- confirmed `--udid` flag and `dest_path` positional arg: HIGH confidence
- Local machine: `idb log --help` -- confirmed `--process`, `--level`, `--style`, `--predicate` arguments: HIGH confidence
- Local machine: `idb crash --help` -- confirmed `list`, `show`, `delete` subcommands: HIGH confidence
- Local machine: `xcrun simctl io help` -- confirmed `screenshot`, `recordVideo`, `enumerate` operations: HIGH confidence
- Codebase: `.planning/quick/5-*/5-SUMMARY.md` -- quick-5 audit patterns, DerivedData stale binary discovery: HIGH confidence
- Codebase: `fastlane/Fastfile` -- existing screenshot lane configuration: HIGH confidence
- Codebase: MEMORY.md -- iPhone logical resolution 440x956, sidebar tap coordinates, deep link routes: HIGH confidence
- Apple documentation (training data): iPad Pro 13" logical resolution 1032x1376, `status_bar override` flags: MEDIUM confidence

---

*Stack research for: ILS iOS/macOS v3.5 -- Comprehensive Functional Validation (iOS and iPad)*
*Researched: 2026-02-25*
