#!/bin/bash
# Headless Security Audit — Non-interactive scan for secrets, paths, and issues
# Usage: bash scripts/headless-audit.sh
set -euo pipefail

PROJECT_DIR="/Users/nick/Desktop/ils-ios"
ISSUES=0

echo "=== ILS Security Audit ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# 1. Hardcoded user paths
echo "--- Hardcoded Paths ---"
PATHS=$(grep -rn '/Users/' "$PROJECT_DIR/Sources/" "$PROJECT_DIR/ILSApp/" --include='*.swift' 2>/dev/null | grep -v '// ' | grep -v 'CLAUDE.md' || true)
if [ -n "$PATHS" ]; then
    echo "FAIL: Hardcoded paths found:"
    echo "$PATHS"
    ISSUES=$((ISSUES + 1))
else
    echo "PASS: No hardcoded paths"
fi
echo ""

# 2. API keys and secrets
echo "--- Secrets Scan ---"
SECRETS=$(grep -rnE '(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36})' "$PROJECT_DIR/Sources/" "$PROJECT_DIR/ILSApp/" --include='*.swift' 2>/dev/null || true)
if [ -n "$SECRETS" ]; then
    echo "FAIL: Potential secrets found:"
    echo "$SECRETS"
    ISSUES=$((ISSUES + 1))
else
    echo "PASS: No exposed secrets"
fi
echo ""

# 3. Git-tracked databases
echo "--- Tracked Databases ---"
cd "$PROJECT_DIR"
DBS=$(git ls-files '*.sqlite' '*.db' '*.sqlite3' 2>/dev/null || true)
if [ -n "$DBS" ]; then
    echo "FAIL: Database files tracked in git:"
    echo "$DBS"
    ISSUES=$((ISSUES + 1))
else
    echo "PASS: No tracked databases"
fi
echo ""

# 4. .env files tracked
echo "--- Environment Files ---"
ENVS=$(git ls-files '.env*' '**/.env*' 2>/dev/null || true)
if [ -n "$ENVS" ]; then
    echo "FAIL: .env files tracked in git:"
    echo "$ENVS"
    ISSUES=$((ISSUES + 1))
else
    echo "PASS: No tracked .env files"
fi
echo ""

# 5. Debug flags in release code
echo "--- Debug Flags ---"
DEBUG=$(grep -rn '#if DEBUG' "$PROJECT_DIR/ILSApp/" --include='*.swift' 2>/dev/null | wc -l | tr -d ' ')
echo "INFO: $DEBUG #if DEBUG blocks found (review for release)"
echo ""

# 6. NSLog / print statements (potential data leaks)
echo "--- Logging Audit ---"
NSLOGS=$(grep -rn 'NSLog\|print(' "$PROJECT_DIR/ILSApp/" --include='*.swift' 2>/dev/null | grep -v '// ' | grep -v 'AppLogger' | wc -l | tr -d ' ')
echo "INFO: $NSLOGS raw print/NSLog calls (should use AppLogger instead)"
echo ""

# 7. .gitignore coverage
echo "--- .gitignore Coverage ---"
GITIGNORE="$PROJECT_DIR/.gitignore"
REQUIRED_PATTERNS=(".build/" ".env" "*.sqlite" "*.log" ".omc/" ".DS_Store")
for pattern in "${REQUIRED_PATTERNS[@]}"; do
    if grep -q "$pattern" "$GITIGNORE" 2>/dev/null; then
        echo "PASS: '$pattern' in .gitignore"
    else
        echo "WARN: '$pattern' NOT in .gitignore"
    fi
done
echo ""

# 8. Backend binary check
echo "--- Backend Binary ---"
BACKEND_PID=$(lsof -i :9999 -P -n 2>/dev/null | grep LISTEN | awk '{print $2}' || true)
if [ -n "$BACKEND_PID" ]; then
    BACKEND_PATH=$(ps -p "$BACKEND_PID" -o command= 2>/dev/null || true)
    if echo "$BACKEND_PATH" | grep -q "ils-ios"; then
        echo "PASS: Backend running from correct binary (ils-ios)"
    else
        echo "FAIL: Backend running from WRONG binary: $BACKEND_PATH"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "INFO: Backend not running on port 9999"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ $ISSUES -eq 0 ]; then
    echo "All security checks PASSED"
    exit 0
else
    echo "$ISSUES security issue(s) found — review and fix before committing"
    exit 1
fi
