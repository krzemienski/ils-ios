---
name: audit
description: >
  Run security and quality audit on the ILS iOS/macOS/Vapor codebase. Scans for
  exposed secrets, hardcoded paths, wrong backend binary, git-tracked databases,
  dead code, and build health across all 3 targets. Use when preparing for App
  Store submission, after major refactors, or when asked to check code health.
  Returns a severity-ranked report — does NOT modify any files.
---

# ILS Codebase Audit

## Before You Start

Ask yourself:
- **What triggered this audit?** Pre-submission needs ALL checks. Post-refactor needs build + dead code only.
- **Is the backend running?** If yes, verify it's the CORRECT binary (see Backend Binary below).
- **Are builds currently green?** If not, fix builds first — auditing broken code wastes time.

## Audit Phases

Run phases 1-4 in parallel (independent). Phase 5 depends on all others.

### Phase 1: Security Scan

```bash
bash scripts/headless-audit.sh
```

**Interpreting results — the false positive trap:**

| Finding | Real Issue? | Why |
|---------|-------------|-----|
| `/Users/test/project` in UITest files | NO | Test fixtures use fake paths — ignore `*Tests/` and `*UITests/` matches |
| `/Users/nick/` in Swift source | YES | Hardcoded developer path — must use relative or Bundle-based paths |
| `apiKey` in protocol/enum/case declarations | NO | These are property names, not actual secrets |
| `sk-ant-` or `AKIA` prefixed strings | YES | Real API keys — revoke immediately, clean git history with BFG |
| Backend binary in `.build/` path | DEPENDS | Expected for local dev; FAIL if binary is from `/Users/nick/ils/ILSBackend/` (old project) |

### Phase 1b: Privacy Manifest Check

```bash
# Both iOS and macOS targets MUST have PrivacyInfo.xcprivacy
for target in ILSApp/ILSApp ILSApp/ILSMacApp; do
  if [ -f "$target/PrivacyInfo.xcprivacy" ]; then
    echo "PASS: $target/PrivacyInfo.xcprivacy exists"
  else
    echo "FAIL: $target/PrivacyInfo.xcprivacy MISSING — App Store rejection risk"
  fi
done
```

**Required API declarations** (minimum for ILS):
- `NSPrivacyAccessedAPICategoryUserDefaults` (reason: `CA92.1`)
- `NSPrivacyAccessedAPICategoryFileTimestamp` (reason: `DDA9.1`)
- `NSPrivacyAccessedAPICategorySystemBootTime` (reason: `35F9.1`)

If a manifest is missing, create one matching the existing iOS/macOS template. Missing manifests cause App Store rejection (iOS 17+).

### Phase 2: Build Health

```bash
bash scripts/headless-build.sh all
```

**If a build fails, classify it:**

| Error Type | Action | Severity |
|------------|--------|----------|
| Missing type/module | Check if file was deleted but not removed from project | CRITICAL |
| Duplicate declaration | Two files define same type — one is dead code | HIGH |
| Content protocol conformance | SwiftUI view missing `var body` | CRITICAL |
| SPM resolution failure | Delete `.build/` and `Package.resolved`, retry | MEDIUM |

### Phase 3: Dead Code Detection

```bash
# Files in filesystem but NOT in Xcode project (orphans)
comm -23 \
  <(find ILSApp/ILSApp -name '*.swift' -type f | sort) \
  <(ruby -e 'puts File.read("ILSApp/ILSApp.xcodeproj/project.pbxproj").scan(/[A-Za-z0-9_]+\.swift/).uniq.sort') \
  2>/dev/null || echo "Manual check needed"

# Files in Xcode project but NOT in filesystem (ghosts)
comm -13 \
  <(find ILSApp/ILSApp -name '*.swift' -type f -exec basename {} \; | sort -u) \
  <(ruby -e 'puts File.read("ILSApp/ILSApp.xcodeproj/project.pbxproj").scan(/([A-Za-z0-9_]+\.swift)/).flatten.uniq.sort') \
  2>/dev/null || echo "Manual check needed"
```

### Phase 4: Code Hygiene

```bash
# TODOs/FIXMEs (not a problem, but track count)
grep -rn 'TODO\|FIXME\|HACK\|XXX' ILSApp/ Sources/ --include='*.swift' | wc -l

# Raw print() calls that should use AppLogger
grep -rn 'print(' ILSApp/ILSApp/ --include='*.swift' | grep -v '// ' | grep -v 'AppLogger' | wc -l

# Force unwraps (crash risk)
grep -rn '!' ILSApp/ILSApp/ --include='*.swift' | grep -v '//' | grep -v 'IBOutlet' | grep -v '@objc' | grep -E '\w+!' | head -20
```

### Phase 5: Synthesize Report

**Severity classification (from real ILS audit sessions):**

| Severity | Definition | Examples |
|----------|-----------|---------|
| CRITICAL | App Store rejection or data loss risk | Exposed API key, tracked database, missing encryption declaration |
| HIGH | Production crash or security vulnerability | Force unwrap on optional, missing error handling on network calls |
| MEDIUM | Code quality issue affecting maintenance | Dead code, raw print() calls, hardcoded values |
| LOW | Improvement opportunity | TODO count, missing accessibility labels |

## NEVER

- **NEVER modify files during an audit** — audit is read-only, period
- **NEVER report test fixture paths as security issues** — `/Users/test/` in `*Tests/*.swift` is intentional
- **NEVER report `apiKey` property declarations as exposed secrets** — `var apiKey: String` is a property name
- **NEVER skip the backend binary check** — old binary at `ils/ILSBackend/` returns snake_case data that silently breaks the iOS app
- **NEVER trust `grep` alone for dead code** — a file can be referenced by filename in pbxproj but unused at runtime; check imports too
- **NEVER report build warnings as failures** — warnings are informational, errors are blocking

## Output

Write to `.claude/audit/quick-audit-{date}.md`, not to the conversation.
