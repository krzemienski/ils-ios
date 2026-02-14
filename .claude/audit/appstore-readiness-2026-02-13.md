# App Store Readiness Check — 2026-02-13

## Summary

| Category | PASS | FAIL | SKIP |
|----------|------|------|------|
| Builds | 3/3 | 0 | 0 |
| Security | 3/3 | 0 | 0 |
| Info.plist | 1/2 | 1 | 0 |
| Assets | 2/4 | 2 | 0 |
| Metadata | 1/1 | 0 | 0 |
| URLs | 0/2 | 2 | 0 |
| Git Hygiene | 1/2 | 1 | 0 |
| **Total** | **11** | **6** | **0** |

**Verdict: NOT READY — 6 items require action before submission**

---

## Detailed Results

### 1. Builds

| Check | Result | Details |
|-------|--------|---------|
| iOS Build (ILSApp) | **PASS** | Clean build, exit 0 |
| macOS Build (ILSMacApp) | **PASS** | Clean build, exit 0 (AccentColor asset warning only) |
| Backend Build | **PASS** | Clean build in 2.59s |

### 2. Security Scan

| Check | Result | Details |
|-------|--------|---------|
| API Keys / Secrets | **PASS** | No hardcoded secrets. Matches are model field names (apiKeySource, token params) — false positives |
| Hardcoded Paths | **PASS** | Only `/Users/` in: a comment (FileSystemService:112), test files (UITests). No production paths |
| Git-tracked Databases | **FAIL** | `ils.sqlite` and `ILSApp/.omc/state/jobs.db` are tracked in git |

**Action Required:**
```bash
# Add to .gitignore
echo "*.sqlite" >> .gitignore
echo "*.db" >> .gitignore

# Remove from tracking (preserves local file)
git rm --cached ils.sqlite
git rm --cached ILSApp/.omc/state/jobs.db
```

### 3. Info.plist

| Check | Platform | Result | Details |
|-------|----------|--------|---------|
| CFBundleDisplayName | iOS | **PASS** | "ILS" |
| CFBundleDisplayName | macOS | **PASS** | "ILS" |
| ITSAppUsesNonExemptEncryption | iOS | **PASS** | `false` |
| ITSAppUsesNonExemptEncryption | macOS | **FAIL** | Missing — will trigger export compliance questionnaire every build upload |
| NSLocalNetworkUsageDescription | iOS | **PASS** | Present with descriptive text |
| NSLocalNetworkUsageDescription | macOS | **FAIL** | Missing — required for local network access |
| CFBundleURLSchemes | Both | **PASS** | `ils` scheme registered |

**Action Required:** Add to `ILSApp/ILSMacApp/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
<key>NSLocalNetworkUsageDescription</key>
<string>ILS needs local network access to connect to your ILS Backend server running on your Mac or local network.</string>
```

### 4. App Icons

| Check | Result | Details |
|-------|--------|---------|
| iOS Icon | **PASS** | 1 icon, 1024x1024px |
| macOS Icons | **PASS** | 7 icons including 1024x1024px |

### 5. Screenshots

| Check | Result | Details |
|-------|--------|---------|
| iPhone 6.7" | **PASS** | 6 screenshots, 1320px wide (correct for 6.7") |
| iPad 13" | **FAIL** | 0 screenshots — required for iPad App Store listing |
| macOS | **PARTIAL** | 1 screenshot — need 3-10 for Mac App Store |

**Action Required:**
- Generate iPad screenshots (2064x2752 for 13" iPad Pro)
- Generate additional macOS screenshots (min 3, recommended 5+)

### 6. App Store Metadata

| File | Chars | Limit | Result |
|------|-------|-------|--------|
| name.txt | 3 | 30 | **PASS** ("ILS") |
| subtitle.txt | 27 | 30 | **PASS** |
| keywords.txt | 95 | 100 | **PASS** |
| promotional_text.txt | 134 | 170 | **PASS** |
| description.txt | 1722 | 4000 | **PASS** |
| release_notes.txt | 273 | 4000 | **PASS** |
| review_notes.txt | 1033 | 4000 | **PASS** |

All metadata within character limits.

### 7. Privacy & Support URLs

| URL | Result | Details |
|-----|--------|---------|
| Privacy Policy | **FAIL** | `https://krzemienski.github.io/ils-ios/privacy` returns 404 |
| Support URL | **FAIL** | `https://krzemienski.github.io/ils-ios/support` returns 404 |

**Note:** HTML files exist locally at `docs/privacy/index.html` and `docs/support/index.html`. GitHub Pages is not enabled for this repository.

**Action Required:**
1. Push `docs/` to the `master` branch
2. Enable GitHub Pages: Settings > Pages > Source: Deploy from branch, Branch: master, Folder: /docs
3. Wait for deployment, verify URLs return 200

### 8. .gitignore

| Pattern | Result |
|---------|--------|
| .omc/ | **PRESENT** |
| .env* | **PRESENT** |
| *.log | **PRESENT** |
| .build/ | **PRESENT** |
| DerivedData/ | **PRESENT** |
| xcuserdata/ | **PRESENT** |
| *.sqlite | **MISSING** |
| Pods/ | **MISSING** |

**Action Required:**
```bash
echo "*.sqlite" >> .gitignore
echo "*.db" >> .gitignore
echo "Pods/" >> .gitignore
```

---

## Critical Fix: System Monitor (Fixed This Session)

**Root Cause:** `SystemMetricsService.getNetworkMetrics()` spawned `netstat -ib` subprocess every 2 seconds. Under active Claude Code sessions, subprocess execution hangs indefinitely, blocking the entire metrics pipeline.

**Fix Applied:** Replaced `netstat -ib` subprocess with `getifaddrs()` direct kernel system call. Response time went from **INFINITE TIMEOUT** to **7ms**.

**Files Changed:**
- `Sources/ILSBackend/Services/SystemMetricsService.swift` — replaced `getNetworkMetrics()` implementation

---

## Priority Action Items

### P0 — Blockers (must fix before submission)
1. **macOS Info.plist**: Add `ITSAppUsesNonExemptEncryption` and `NSLocalNetworkUsageDescription`
2. **Privacy/Support URLs**: Enable GitHub Pages or use alternative hosting
3. **Git-tracked databases**: Remove `ils.sqlite` and `.omc/state/jobs.db` from git tracking

### P1 — Required for full listing
4. **iPad screenshots**: Generate 2064x2752 screenshots (required for universal app)
5. **macOS screenshots**: Generate 3+ screenshots for Mac App Store listing

### P2 — Nice to have
6. **`.gitignore`**: Add `*.sqlite`, `*.db`, `Pods/` patterns
