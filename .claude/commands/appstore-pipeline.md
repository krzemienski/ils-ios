---
name: appstore-pipeline
description: Run parallel App Store readiness pipeline — spawns simultaneous agents for screenshots, metadata validation, security audit, and build verification
---

# Parallel App Store Readiness Pipeline

Execute a parallel App Store readiness check by spawning independent agents for each validation domain.

## Coordination File

Create `.claude/audit/appstore-status-{date}.json` to track progress:
```json
{
  "date": "YYYY-MM-DD",
  "screenshots_iphone": { "status": "pending" },
  "screenshots_macos": { "status": "pending" },
  "metadata_validation": { "status": "pending" },
  "security_audit": { "status": "pending" },
  "build_verification": { "status": "pending" }
}
```

## Parallel Agents

Launch these 5 agents simultaneously using the Task tool with `run_in_background: true`:

### Agent 1: iPhone Screenshots
- Build and install app on simulator `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Capture screenshots for all required screens: Home, Sessions, Chat, Settings, Browser, System
- Use deep links for navigation (`ils://home`, `ils://sessions`, etc.)
- Save to `AppStoreMetadata/screenshots/iphone_67/`
- If deep link fails, retry 3 times with 5s delays

### Agent 2: macOS Screenshots
- Build ILSMacApp scheme
- Launch app, capture screenshots via `screencapture`
- Save to `AppStoreMetadata/screenshots/macos/`

### Agent 3: Metadata Validation
- Verify all required files exist in `AppStoreMetadata/en-US/`:
  - description.txt (max 4000 chars)
  - keywords.txt (max 100 chars)
  - name.txt (max 30 chars)
  - subtitle.txt (max 30 chars)
- Check character limits
- Verify privacy policy URL returns HTTP 200: `curl -sf https://krzemienski.github.io/ils-ios/privacy`
- Verify support URL returns HTTP 200: `curl -sf https://krzemienski.github.io/ils-ios/support`

### Agent 4: Security Audit
- Run `bash scripts/headless-audit.sh`
- Check Info.plist for required keys: `ITSAppUsesNonExemptEncryption`, `NSLocalNetworkUsageDescription`
- Verify no git-tracked secrets or databases

### Agent 5: Build Verification
- Run `bash scripts/headless-build.sh all`
- Verify all 3 targets (iOS, macOS, Backend) build with 0 errors
- Check for compiler warnings

## Completion

After all agents complete:
1. Update status file with pass/fail per agent
2. Generate summary report at `.claude/audit/appstore-readiness-{date}.md`
3. List any blocking issues that must be fixed before submission
4. List non-blocking warnings that should be addressed

## Rules
- Each agent operates independently — no cross-dependencies
- If an agent encounters a build failure, it attempts to fix it and rebuild before reporting failure
- Screenshot capture uses the dedicated simulator ONLY: `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Deep link UUIDs must be LOWERCASE
