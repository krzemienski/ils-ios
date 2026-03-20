#!/usr/bin/env bash
# =============================================================================
# ILS Backend Security Static Analysis
# Scans source code for security misconfigurations and policy violations.
# Returns exit code 1 on critical findings.
# =============================================================================

set -euo pipefail

# Resolve project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BACKEND_SRC="$PROJECT_ROOT/Sources/ILSBackend"
SHARED_SRC="$PROJECT_ROOT/Sources/ILSShared"
CONFIGURE="$BACKEND_SRC/App/configure.swift"
ROUTES="$BACKEND_SRC/App/routes.swift"
MIDDLEWARE_DIR="$BACKEND_SRC/Middleware"
SERVICES_DIR="$BACKEND_SRC/Services"

CRITICAL=0
WARN=0
PASS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

section() {
    echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
}

pass() {
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

warn() {
    WARN=$((WARN + 1))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

critical() {
    CRITICAL=$((CRITICAL + 1))
    echo -e "  ${RED}✗ CRITICAL:${NC} $1"
}

# =============================================================================
section "1. CORS Configuration Scan"
# =============================================================================

if [ ! -f "$CONFIGURE" ]; then
    critical "configure.swift not found at $CONFIGURE"
else
    # Check for allowedOrigin: .all (Vapor's wildcard CORS)
    if grep -qE '\.all\b' "$CONFIGURE" 2>/dev/null && grep -qE 'allowedOrigin.*\.all' "$CONFIGURE" 2>/dev/null; then
        critical "CORS wildcard '.all' found in configure.swift — use explicit origins"
    else
        pass "No CORS .all wildcard in configure.swift"
    fi

    # Check that wildcard '*' rejection logic is present (SEC-CORS-01)
    if grep -q 'SEC-CORS-01' "$CONFIGURE"; then
        pass "SEC-CORS-01: Wildcard '*' origin rejection logic present"
    else
        critical "SEC-CORS-01: Missing wildcard '*' origin rejection in configure.swift"
    fi

    # Check Vary: Origin header enforcement (SEC-CORS-03)
    if grep -q 'VaryOriginMiddleware' "$CONFIGURE"; then
        pass "SEC-CORS-03: VaryOriginMiddleware registered (cache poisoning prevention)"
    else
        warn "SEC-CORS-03: VaryOriginMiddleware not registered in configure.swift"
    fi
fi

# =============================================================================
section "2. Middleware Existence & Registration"
# =============================================================================

REQUIRED_MIDDLEWARE=(
    "ILSErrorMiddleware"
    "APIKeyMiddleware"
    "RequestValidationMiddleware"
    "RateLimitMiddleware"
    "SecurityPolicyMiddleware"
    "VaryOriginMiddleware"
    "RequestLoggingMiddleware"
    "AdminMiddleware"
)

for mw in "${REQUIRED_MIDDLEWARE[@]}"; do
    mw_file="$MIDDLEWARE_DIR/${mw}.swift"
    if [ ! -f "$mw_file" ]; then
        critical "Middleware file missing: ${mw}.swift"
        continue
    fi

    # Check registration: either in configure.swift (global) or routes.swift (grouped)
    if grep -q "$mw" "$CONFIGURE" 2>/dev/null || grep -q "$mw" "$ROUTES" 2>/dev/null; then
        pass "$mw exists and is registered"
    else
        warn "$mw file exists but not registered in configure.swift or routes.swift"
    fi
done

# =============================================================================
section "3. Hardcoded Secrets / API Keys Scan"
# =============================================================================

# Patterns that indicate hardcoded secrets (excluding comments, test files, env lookups)
SECRET_PATTERNS=(
    'password\s*=\s*"[^"]{4,}'
    'api_key\s*=\s*"[^"]{4,}'
    'apiKey\s*=\s*"[^"]{4,}'
    'secret\s*=\s*"[^"]{8,}'
    'token\s*=\s*"[A-Za-z0-9_\-]{16,}"'
    'Bearer\s+[A-Za-z0-9_\-\.]{20,}'
    'sk-[A-Za-z0-9]{20,}'
    'AKIA[A-Z0-9]{16}'
)

SECRETS_FOUND=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    # Search Swift sources, excluding test files and comments
    matches=$(grep -rnE "$pattern" "$BACKEND_SRC" "$SHARED_SRC" \
        --include="*.swift" \
        2>/dev/null \
        | grep -v '^\s*//' \
        | grep -v 'Environment.get' \
        | grep -v 'ProcessInfo' \
        | grep -v '// SEC-' \
        | grep -v 'placeholder' \
        | grep -v 'example' \
        | grep -v 'Test' \
        | grep -v 'Mock' \
        || true)

    if [ -n "$matches" ]; then
        SECRETS_FOUND=$((SECRETS_FOUND + 1))
        critical "Potential hardcoded secret matching pattern '$pattern':"
        echo "$matches" | head -5 | while IFS= read -r line; do
            echo -e "    ${RED}→${NC} $line"
        done
    fi
done

if [ "$SECRETS_FOUND" -eq 0 ]; then
    pass "No hardcoded secrets or API keys detected in source"
fi

# =============================================================================
section "4. Elevated Endpoint Security Policy Check"
# =============================================================================

if [ ! -f "$ROUTES" ]; then
    critical "routes.swift not found at $ROUTES"
else
    # Elevated controllers that MUST be behind SecurityPolicyMiddleware
    ELEVATED_CONTROLLERS=(
        "SSHController"
        "TerminalController"
        "PermissionsController"
        "AutomationRulesController"
        "AgentQueueController"
    )

    for ctrl in "${ELEVATED_CONTROLLERS[@]}"; do
        if ! grep -q "$ctrl" "$ROUTES" 2>/dev/null; then
            warn "$ctrl not found in routes.swift (may be unregistered)"
            continue
        fi

        # Check the controller is registered on the elevated group (SecurityPolicyMiddleware)
        # The pattern is: elevated.register(collection: ControllerName(...))
        if grep -qE 'elevated\.register\(collection:\s*'"$ctrl" "$ROUTES" 2>/dev/null; then
            pass "$ctrl is behind SecurityPolicyMiddleware"
        else
            critical "$ctrl is NOT behind SecurityPolicyMiddleware — elevated access unprotected"
        fi
    done

    # Admin controllers that MUST be behind AdminMiddleware
    ADMIN_CONTROLLERS=(
        "ConfigController"
        "SystemController"
        "TunnelController"
        "DataErasureController"
        "PairingController"
    )

    for ctrl in "${ADMIN_CONTROLLERS[@]}"; do
        if ! grep -q "$ctrl" "$ROUTES" 2>/dev/null; then
            warn "$ctrl not found in routes.swift"
            continue
        fi

        if grep -qE 'admin\.register\(collection:\s*'"$ctrl" "$ROUTES" 2>/dev/null; then
            pass "$ctrl is behind AdminMiddleware"
        else
            critical "$ctrl is NOT behind AdminMiddleware — admin access unprotected"
        fi
    done
fi

# =============================================================================
section "5. PathSanitizer Usage for File Operations"
# =============================================================================

SANITIZER_FILE="$SERVICES_DIR/PathSanitizer.swift"
if [ ! -f "$SANITIZER_FILE" ]; then
    critical "PathSanitizer.swift not found — file path operations unprotected"
else
    pass "PathSanitizer.swift exists"

    # Check URL-encoded traversal detection (SEC-PATH-01)
    if grep -q 'SEC-PATH-01\|urlEncodedTraversal\|%2e%2e\|%252e' "$SANITIZER_FILE" 2>/dev/null; then
        pass "PathSanitizer includes URL-encoded traversal detection"
    else
        warn "PathSanitizer may lack URL-encoded traversal detection"
    fi
fi

# Scan controllers for direct file path construction without PathSanitizer
CONTROLLERS_DIR="$BACKEND_SRC/Controllers"
if [ -d "$CONTROLLERS_DIR" ]; then
    # Look for controllers that use FileManager or construct paths but don't import/use PathSanitizer
    UNSAFE_PATH_FILES=$(grep -rlE 'FileManager|appendingPathComponent|NSString.*path|URL\(fileURLWithPath' \
        "$CONTROLLERS_DIR" --include="*.swift" 2>/dev/null || true)

    if [ -n "$UNSAFE_PATH_FILES" ]; then
        for file in $UNSAFE_PATH_FILES; do
            basename_file=$(basename "$file")
            if grep -q 'PathSanitizer\|sanitize' "$file" 2>/dev/null; then
                pass "$basename_file uses file paths with PathSanitizer"
            else
                warn "$basename_file performs file operations — verify PathSanitizer usage"
            fi
        done
    else
        pass "No direct file path construction found in controllers"
    fi
fi

# =============================================================================
section "Results Summary"
# =============================================================================

echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASS"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo -e "  ${RED}Critical:${NC} $CRITICAL"
echo ""

if [ "$CRITICAL" -gt 0 ]; then
    echo -e "${RED}══════════════════════════════════════════${NC}"
    echo -e "${RED}  SECURITY CHECK FAILED — $CRITICAL critical finding(s)${NC}"
    echo -e "${RED}══════════════════════════════════════════${NC}"
    exit 1
else
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Security check passed${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    exit 0
fi
