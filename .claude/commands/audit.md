---
name: audit
description: Run comprehensive code audit on ILS iOS/macOS codebase — security scan, build verification, and code quality checks without restructuring the project
---

# Quick Audit

Run a focused security and quality audit. Do NOT restructure the project — only report findings.

## Steps

1. **Security Scan** — Run `bash scripts/headless-audit.sh` and capture output
2. **Build Verification** — Run `bash scripts/headless-build.sh all` and capture output
3. **Hardcoded Values** — Grep for hardcoded IPs, ports (except 9999), and debug flags:
   ```bash
   grep -rn 'http://[0-9]' Sources/ ILSApp/ --include='*.swift' | grep -v 'localhost\|127.0.0.1'
   ```
4. **Dead Code** — Check for files not referenced by the Xcode project:
   ```bash
   # List Swift files not in project.pbxproj
   for f in $(find ILSApp/ILSApp -name '*.swift' -type f); do
     basename "$f" | xargs -I{} grep -L {} ILSApp/ILSApp.xcodeproj/project.pbxproj >/dev/null 2>&1 && echo "ORPHAN: $f"
   done
   ```
5. **TODO/FIXME/HACK Count** — `grep -rn 'TODO\|FIXME\|HACK\|XXX' ILSApp/ Sources/ --include='*.swift' | wc -l`

## Output

Summarize as a checklist:
- [ ] Security: X issues
- [ ] Builds: iOS/macOS/Backend pass/fail
- [ ] Hardcoded values: X found
- [ ] Dead code: X orphan files
- [ ] TODOs: X items

## Rules
- Do NOT modify any files
- Do NOT propose architecture changes
- Do NOT create test files
- Stay within the audit — report findings only
