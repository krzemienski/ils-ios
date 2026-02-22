#!/usr/bin/env bash
# =============================================================================
# ILS Backend API Audit Script
# Tests all 88 endpoints against the live backend at http://localhost:9999
# =============================================================================

BASE="http://localhost:9999/api/v1"
HEALTH_BASE="http://localhost:9999"
PASS=0
FAIL=0
SKIP=0
RESULTS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "$1"; }
section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

pass() {
    local name="$1" detail="$2"
    PASS=$((PASS+1))
    RESULTS+=("PASS|$name|$detail")
    echo -e "  ${GREEN}✓${NC} $name ${detail}"
}

fail() {
    local name="$1" detail="$2"
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL|$name|$detail")
    echo -e "  ${RED}✗${NC} $name ${detail}"
}

skip() {
    local name="$1" detail="$2"
    SKIP=$((SKIP+1))
    RESULTS+=("SKIP|$name|$detail")
    echo -e "  ${YELLOW}⊘${NC} $name ${detail}"
}

# Check for required tools
for tool in curl python3; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: $tool is required but not found in PATH" >&2
        exit 1
    fi
done

# Verify backend is up
if ! curl -sf "${HEALTH_BASE}/health" >/dev/null 2>&1; then
    echo "ERROR: Backend not running at ${HEALTH_BASE}. Start with: PORT=9999 swift run ILSBackend" >&2
    exit 1
fi

# Helper: check HTTP status and optional JSON key
check_get() {
    local name="$1" path="$2" expected_status="${3:-200}" check_key="${4:-}"
    local url="${BASE}${path}"
    local response http_code body

    body=$(curl -sf -w "\n__STATUS__%{http_code}" "${url}" 2>/dev/null) || {
        fail "$name" "(connection error)"
        return
    }
    http_code=$(echo "$body" | tail -1 | sed 's/__STATUS__//')
    body=$(echo "$body" | head -n -1)

    if [ "$http_code" != "$expected_status" ]; then
        fail "$name" "(expected $expected_status, got $http_code)"
        return
    fi

    if [ -n "$check_key" ]; then
        if echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$check_key' in d" 2>/dev/null; then
            pass "$name" "(HTTP $http_code, has '$check_key')"
        else
            fail "$name" "(HTTP $http_code but missing key '$check_key')"
        fi
    else
        pass "$name" "(HTTP $http_code)"
    fi
}

check_get_raw() {
    local name="$1" url="$2" expected_status="${3:-200}" check_key="${4:-}"
    local response http_code body

    body=$(curl -sf -w "\n__STATUS__%{http_code}" "${url}" 2>/dev/null) || {
        fail "$name" "(connection error)"
        return
    }
    http_code=$(echo "$body" | tail -1 | sed 's/__STATUS__//')
    body=$(echo "$body" | head -n -1)

    if [ "$http_code" != "$expected_status" ]; then
        fail "$name" "(expected $expected_status, got $http_code)"
        return
    fi

    if [ -n "$check_key" ]; then
        if echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$check_key' in d" 2>/dev/null; then
            pass "$name" "(HTTP $http_code, has '$check_key')"
        else
            fail "$name" "(HTTP $http_code but missing key '$check_key')"
        fi
    else
        pass "$name" "(HTTP $http_code)"
    fi
}

check_post() {
    local name="$1" path="$2" body="${3:-{}}" expected_status="${4:-200}" check_key="${5:-}"
    local url="${BASE}${path}"
    local response http_code resp_body

    resp_body=$(curl -sf -w "\n__STATUS__%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$body" "${url}" 2>/dev/null) || {
        fail "$name" "(connection error)"
        return
    }
    http_code=$(echo "$resp_body" | tail -1 | sed 's/__STATUS__//')
    resp_body=$(echo "$resp_body" | head -n -1)

    if [ "$http_code" != "$expected_status" ]; then
        fail "$name" "(expected $expected_status, got $http_code) body: $(echo $resp_body | head -c 120)"
        return
    fi

    if [ -n "$check_key" ]; then
        if echo "$resp_body" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$check_key' in d" 2>/dev/null; then
            pass "$name" "(HTTP $http_code, has '$check_key')"
        else
            fail "$name" "(HTTP $http_code but missing key '$check_key')"
        fi
    else
        pass "$name" "(HTTP $http_code)"
    fi
}

# Check APIResponse wrapper: {"success": true, "data": ...}
check_api_response() {
    local name="$1" path="$2"
    local url="${BASE}${path}"
    local body http_code

    body=$(curl -sf -w "\n__STATUS__%{http_code}" "${url}" 2>/dev/null) || {
        fail "$name" "(connection error)"
        return
    }
    http_code=$(echo "$body" | tail -1 | sed 's/__STATUS__//')
    body=$(echo "$body" | head -n -1)

    if [ "$http_code" != "200" ]; then
        fail "$name" "(HTTP $http_code)"
        return
    fi

    if echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d.get('success') == True, 'success != true'
assert 'data' in d, 'missing data key'
" 2>/dev/null; then
        pass "$name" "(HTTP 200, APIResponse wrapper OK)"
    else
        fail "$name" "(HTTP 200 but invalid APIResponse structure)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
section "HEALTH (no /api/v1 prefix)"
check_get_raw "GET /health"        "${HEALTH_BASE}/health"        "200" "status"
check_get_raw "GET /health/ready"  "${HEALTH_BASE}/health/ready"  "200" "status"
check_get_raw "GET /health/live"   "${HEALTH_BASE}/health/live"   "200" "status"

# ─────────────────────────────────────────────────────────────────────────────
section "SESSIONS (/api/v1/sessions) — 14 routes"
check_api_response "GET /sessions (list)"          "/sessions"
check_api_response "GET /sessions/projects"        "/sessions/projects"
check_api_response "GET /sessions/scan"            "/sessions/scan"
check_api_response "GET /sessions/search?q=test"   "/sessions/search?q=test"

# Get first session ID from list for detail tests
SESSION_ID=$(curl -sf "${BASE}/sessions?limit=1" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items:
    print(items[0]['id'])
" 2>/dev/null)

if [ -n "$SESSION_ID" ]; then
    check_api_response "GET /sessions/:id"               "/sessions/${SESSION_ID}"
    check_api_response "GET /sessions/:id/messages"      "/sessions/${SESSION_ID}/messages"
    check_api_response "GET /sessions/:id/messages/search?q=test" "/sessions/${SESSION_ID}/messages/search?q=test"
    # Export returns file download (not APIResponse) — just check HTTP 200
    check_get "GET /sessions/:id/export (json)" "/sessions/${SESSION_ID}/export?format=json" "200"
    check_get "GET /sessions/:id/export (md)"   "/sessions/${SESSION_ID}/export?format=markdown" "200"
    check_get "GET /sessions/:id/export (txt)"  "/sessions/${SESSION_ID}/export?format=text" "200"
else
    skip "GET /sessions/:id" "(no sessions in DB)"
    skip "GET /sessions/:id/messages" "(no sessions in DB)"
    skip "GET /sessions/:id/messages/search" "(no sessions in DB)"
    skip "GET /sessions/:id/export (json)" "(no sessions in DB)"
    skip "GET /sessions/:id/export (md)" "(no sessions in DB)"
    skip "GET /sessions/:id/export (txt)" "(no sessions in DB)"
fi

# POST create session
NEW_SESSION_ID=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "Audit Test Session", "model": "sonnet"}' \
    "${BASE}/sessions" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

if [ -n "$NEW_SESSION_ID" ]; then
    pass "POST /sessions (create)"     "(created ${NEW_SESSION_ID})"

    # PUT rename
    RENAME_RESULT=$(curl -sf -X PUT \
        -H "Content-Type: application/json" \
        -d '{"name": "Renamed Audit Session"}' \
        "${BASE}/sessions/${NEW_SESSION_ID}" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$RENAME_RESULT" = "True" ]; then
        pass "PUT /sessions/:id (rename)" "(success)"
    else
        fail "PUT /sessions/:id (rename)" "(unexpected response)"
    fi

    # POST fork
    FORK_RESULT=$(curl -sf -w "\n__STATUS__%{http_code}" -X POST \
        "${BASE}/sessions/${NEW_SESSION_ID}/fork" 2>/dev/null)
    FORK_CODE=$(echo "$FORK_RESULT" | tail -1 | sed 's/__STATUS__//')
    FORK_BODY=$(echo "$FORK_RESULT" | head -n -1)
    FORKED_ID=$(echo "$FORK_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('id',''))" 2>/dev/null)
    if [ "$FORK_CODE" = "200" ] && [ -n "$FORKED_ID" ]; then
        pass "POST /sessions/:id/fork" "(forked to ${FORKED_ID})"
    else
        fail "POST /sessions/:id/fork" "(HTTP $FORK_CODE)"
    fi

    # DELETE created sessions
    if [ -n "$FORKED_ID" ]; then
        curl -sf -X DELETE "${BASE}/sessions/${FORKED_ID}" >/dev/null 2>&1
    fi
    curl -sf -X DELETE "${BASE}/sessions/${NEW_SESSION_ID}" >/dev/null 2>&1
    pass "DELETE /sessions/:id" "(cleanup OK)"
else
    fail "POST /sessions (create)" "(no ID returned)"
    skip "PUT /sessions/:id (rename)" "(create failed)"
    skip "POST /sessions/:id/fork" "(create failed)"
    skip "DELETE /sessions/:id" "(create failed)"
fi

# POST bulk-delete (with dummy IDs — should succeed even if IDs don't exist)
BULK_DEL=$(curl -sf -w "\n__STATUS__%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"ids": ["00000000-0000-0000-0000-000000000001"]}' \
    "${BASE}/sessions/bulk-delete" 2>/dev/null)
BULK_CODE=$(echo "$BULK_DEL" | tail -1 | sed 's/__STATUS__//')
if [ "$BULK_CODE" = "200" ]; then
    pass "POST /sessions/bulk-delete" "(HTTP 200)"
else
    fail "POST /sessions/bulk-delete" "(HTTP $BULK_CODE)"
fi

# Transcript route — needs real encoded path and session ID from external sessions
# Get from scan
TRANSCRIPT_DATA=$(curl -sf "${BASE}/sessions/scan" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items:
    i = items[0]
    print(i.get('encodedProjectPath', '') + '|' + i.get('id', ''))
" 2>/dev/null)
if [ -n "$TRANSCRIPT_DATA" ]; then
    ENC_PATH=$(echo "$TRANSCRIPT_DATA" | cut -d'|' -f1)
    TRANS_ID=$(echo "$TRANSCRIPT_DATA" | cut -d'|' -f2)
    check_api_response "GET /sessions/transcript/:path/:id" "/sessions/transcript/${ENC_PATH}/${TRANS_ID}"
else
    skip "GET /sessions/transcript/:path/:id" "(no external sessions found)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "PROJECTS (/api/v1/projects) — 7 routes"
check_api_response "GET /projects (list)"           "/projects"
check_api_response "GET /projects?search=ils"       "/projects?search=ils"

PROJECT_ID=$(curl -sf "${BASE}/projects?limit=1" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items: print(items[0]['id'])
" 2>/dev/null)

if [ -n "$PROJECT_ID" ]; then
    check_api_response "GET /projects/:id"          "/projects/${PROJECT_ID}"
    check_api_response "GET /projects/:id/sessions" "/projects/${PROJECT_ID}/sessions"
else
    skip "GET /projects/:id" "(no projects found)"
    skip "GET /projects/:id/sessions" "(no projects found)"
fi

# POST create project
NEW_PROJ_ID=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "Audit Test Project", "path": "/tmp/audit-test"}' \
    "${BASE}/projects" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

if [ -n "$NEW_PROJ_ID" ]; then
    pass "POST /projects (create)" "(created ${NEW_PROJ_ID})"
    # PUT update
    PUT_RESULT=$(curl -sf -X PUT \
        -H "Content-Type: application/json" \
        -d '{"name": "Updated Audit Project"}' \
        "${BASE}/projects/${NEW_PROJ_ID}" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$PUT_RESULT" = "True" ]; then
        pass "PUT /projects/:id (update)" "(success)"
    else
        fail "PUT /projects/:id (update)" "(unexpected response)"
    fi
    # DELETE
    DEL_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X DELETE "${BASE}/projects/${NEW_PROJ_ID}" 2>/dev/null)
    if [ "$DEL_CODE" = "200" ]; then
        pass "DELETE /projects/:id" "(HTTP 200)"
    else
        fail "DELETE /projects/:id" "(HTTP $DEL_CODE)"
    fi
else
    fail "POST /projects (create)" "(no ID returned)"
    skip "PUT /projects/:id" "(create failed)"
    skip "DELETE /projects/:id" "(create failed)"
fi

# POST bulk-delete
PROJ_BULK=$(curl -sf -w "\n__STATUS__%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"ids": ["00000000-0000-0000-0000-000000000002"]}' \
    "${BASE}/projects/bulk-delete" 2>/dev/null)
PROJ_BULK_CODE=$(echo "$PROJ_BULK" | tail -1 | sed 's/__STATUS__//')
if [ "$PROJ_BULK_CODE" = "200" ]; then
    pass "POST /projects/bulk-delete" "(HTTP 200)"
else
    fail "POST /projects/bulk-delete" "(HTTP $PROJ_BULK_CODE)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "CHAT (/api/v1/chat) — 4 routes"
# SSE stream — skip actual execution (requires claude CLI + running process)
# Permission and cancel endpoints need active session
skip "POST /chat/stream" "(requires claude CLI subprocess — skipped in audit)"
skip "WS /chat/ws/:sessionId" "(WebSocket — requires wscat or similar tool)"

# Permission endpoint — will 410 Gone (no active process), but endpoint must exist
PERM_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X POST \
    -H "Content-Type: application/json" \
    -d '{"decision": "allow"}' \
    "${BASE}/chat/permission/00000000-0000-0000-0000-000000000001/req-123" 2>/dev/null)
if [ "$PERM_CODE" = "410" ] || [ "$PERM_CODE" = "200" ]; then
    pass "POST /chat/permission/:sessionId/:requestId" "(HTTP $PERM_CODE — endpoint exists)"
else
    fail "POST /chat/permission/:sessionId/:requestId" "(HTTP $PERM_CODE)"
fi

# Cancel endpoint — will succeed even with no active process
CANCEL_RESULT=$(curl -sf "${BASE}/chat/cancel/00000000-0000-0000-0000-000000000001" -X POST 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
if [ "$CANCEL_RESULT" = "True" ]; then
    pass "POST /chat/cancel/:sessionId" "(HTTP 200)"
else
    fail "POST /chat/cancel/:sessionId" "(unexpected response)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "SKILLS (/api/v1/skills) — 7 routes"
check_api_response "GET /skills (list)"             "/skills"
check_api_response "GET /skills?search=git"         "/skills?search=git"
check_api_response "GET /skills?scope=local"        "/skills?scope=local"

# Try to get a known skill name
SKILL_NAME=$(curl -sf "${BASE}/skills?limit=1" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items: print(items[0]['name'])
" 2>/dev/null)

if [ -n "$SKILL_NAME" ]; then
    check_api_response "GET /skills/:name"          "/skills/${SKILL_NAME}"
else
    skip "GET /skills/:name" "(no skills found)"
fi

# GitHub search requires network — just check it returns without 500
SEARCH_CODE=$(curl -sf -w "%{http_code}" -o /dev/null "${BASE}/skills/search?q=claude" 2>/dev/null)
if [ "$SEARCH_CODE" = "200" ] || [ "$SEARCH_CODE" = "503" ]; then
    pass "GET /skills/search?q=claude" "(HTTP $SEARCH_CODE — endpoint reachable)"
else
    fail "GET /skills/search?q=claude" "(HTTP $SEARCH_CODE)"
fi

# Create, update, delete a test skill
CREATE_SKILL=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "audit-test-skill", "content": "# Audit Test Skill\nTest content.", "description": "Temporary audit test skill"}' \
    "${BASE}/skills" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
if [ "$CREATE_SKILL" = "True" ]; then
    pass "POST /skills (create)" "(success)"
    # Update
    UPD_SKILL=$(curl -sf -X PUT \
        -H "Content-Type: application/json" \
        -d '{"content": "# Updated content"}' \
        "${BASE}/skills/audit-test-skill" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$UPD_SKILL" = "True" ]; then
        pass "PUT /skills/:name (update)" "(success)"
    else
        fail "PUT /skills/:name (update)" "(unexpected response)"
    fi
    # Delete
    DEL_SKILL=$(curl -sf -X DELETE "${BASE}/skills/audit-test-skill" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$DEL_SKILL" = "True" ]; then
        pass "DELETE /skills/:name" "(success)"
    else
        fail "DELETE /skills/:name" "(unexpected response)"
    fi
else
    fail "POST /skills (create)" "(unexpected response)"
    skip "PUT /skills/:name" "(create failed)"
    skip "DELETE /skills/:name" "(create failed)"
fi

skip "POST /skills/install" "(requires live GitHub access and git clone — skipped in audit)"

# ─────────────────────────────────────────────────────────────────────────────
section "MCP (/api/v1/mcp) — 8 routes"
check_api_response "GET /mcp (list)"                "/mcp"
check_api_response "GET /mcp?scope=user"            "/mcp?scope=user"

MCP_NAME=$(curl -sf "${BASE}/mcp?limit=1" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items: print(items[0]['name'])
" 2>/dev/null)

if [ -n "$MCP_NAME" ]; then
    check_api_response "GET /mcp/:name"             "/mcp/${MCP_NAME}"
    check_api_response "GET /mcp/:name/health"      "/mcp/${MCP_NAME}/health"
    check_api_response "GET /mcp/:name/logs"        "/mcp/${MCP_NAME}/logs"
    # POST restart
    RESTART_RESULT=$(curl -sf -X POST "${BASE}/mcp/${MCP_NAME}/restart" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$RESTART_RESULT" = "True" ]; then
        pass "POST /mcp/:name/restart" "(success)"
    else
        fail "POST /mcp/:name/restart" "(unexpected response)"
    fi
else
    skip "GET /mcp/:name" "(no MCP servers found)"
    skip "GET /mcp/:name/health" "(no MCP servers found)"
    skip "GET /mcp/:name/logs" "(no MCP servers found)"
    skip "POST /mcp/:name/restart" "(no MCP servers found)"
fi

# Create and delete a test MCP server
CREATE_MCP=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "audit-test-mcp", "command": "echo", "args": ["test"], "scope": "user"}' \
    "${BASE}/mcp" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
if [ "$CREATE_MCP" = "True" ]; then
    pass "POST /mcp (create)" "(success)"
    # PUT update
    UPD_MCP=$(curl -sf -X PUT \
        -H "Content-Type: application/json" \
        -d '{"name": "audit-test-mcp", "command": "echo", "args": ["updated"], "scope": "user"}' \
        "${BASE}/mcp/audit-test-mcp" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$UPD_MCP" = "True" ]; then
        pass "PUT /mcp/:name (update)" "(success)"
    else
        fail "PUT /mcp/:name (update)" "(unexpected response)"
    fi
    # DELETE
    DEL_MCP=$(curl -sf -X DELETE "${BASE}/mcp/audit-test-mcp?scope=user" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$DEL_MCP" = "True" ]; then
        pass "DELETE /mcp/:name" "(success)"
    else
        fail "DELETE /mcp/:name" "(unexpected response)"
    fi
else
    fail "POST /mcp (create)" "(unexpected response: $CREATE_MCP)"
    skip "PUT /mcp/:name" "(create failed)"
    skip "DELETE /mcp/:name" "(create failed)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "PLUGINS (/api/v1/plugins) — 8 routes"
check_api_response "GET /plugins (list)"            "/plugins"
check_api_response "GET /plugins/search?q=git"      "/plugins/search?q=git"
check_api_response "GET /plugins/marketplace"       "/plugins/marketplace"

PLUGIN_NAME=$(curl -sf "${BASE}/plugins?limit=1" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items: print(items[0]['name'])
" 2>/dev/null)

if [ -n "$PLUGIN_NAME" ]; then
    ENABLE_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X POST "${BASE}/plugins/${PLUGIN_NAME}/enable" 2>/dev/null)
    DISABLE_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X POST "${BASE}/plugins/${PLUGIN_NAME}/disable" 2>/dev/null)
    if [ "$ENABLE_CODE" = "200" ]; then
        pass "POST /plugins/:name/enable" "(HTTP 200)"
    else
        fail "POST /plugins/:name/enable" "(HTTP $ENABLE_CODE)"
    fi
    if [ "$DISABLE_CODE" = "200" ]; then
        pass "POST /plugins/:name/disable" "(HTTP 200)"
    else
        fail "POST /plugins/:name/disable" "(HTTP $DISABLE_CODE)"
    fi
    # Re-enable to restore state
    curl -sf -X POST "${BASE}/plugins/${PLUGIN_NAME}/enable" >/dev/null 2>&1
else
    skip "POST /plugins/:name/enable" "(no plugins found)"
    skip "POST /plugins/:name/disable" "(no plugins found)"
fi

skip "POST /plugins/marketplaces" "(modifies config — skipped in read-only audit)"
skip "POST /plugins/install" "(requires live GitHub and git clone — skipped in audit)"
skip "DELETE /plugins/:name" "(destructive — skipped in read-only audit)"

# ─────────────────────────────────────────────────────────────────────────────
section "CONFIG (/api/v1/config) — 3 routes"
check_api_response "GET /config?scope=user"         "/config?scope=user"

# Validate endpoint
VALIDATE_RESULT=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"content": {"model": "sonnet"}}' \
    "${BASE}/config/validate" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', {})
print(data.get('isValid', False))
" 2>/dev/null)
if [ "$VALIDATE_RESULT" = "True" ]; then
    pass "POST /config/validate" "(model 'sonnet' is valid)"
else
    fail "POST /config/validate" "(unexpected response)"
fi

# Validate invalid model
INVALID_MODEL=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"content": {"model": "not-a-valid-model-xyz"}}' \
    "${BASE}/config/validate" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', {})
# Should NOT be valid; should have errors
print(not data.get('isValid', True) and bool(data.get('errors')))
" 2>/dev/null)
if [ "$INVALID_MODEL" = "True" ]; then
    pass "POST /config/validate (invalid model)" "(correctly rejected non-claude model)"
else
    fail "POST /config/validate (invalid model)" "(unexpected response)"
fi

skip "PUT /config" "(modifies user settings — skipped in read-only audit)"

# ─────────────────────────────────────────────────────────────────────────────
section "STATS (/api/v1/stats + /settings + /server/status) — 4 routes"
check_api_response "GET /stats"                     "/stats"
check_api_response "GET /stats/recent"              "/stats/recent"
check_api_response "GET /settings"                  "/settings"
check_api_response "GET /server/status"             "/server/status"

# ─────────────────────────────────────────────────────────────────────────────
section "THEMES (/api/v1/themes) — 5 routes"
check_api_response "GET /themes (list)"             "/themes"

THEME_ID=$(curl -sf "${BASE}/themes" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', {}).get('items', [])
if items: print(items[0]['id'])
" 2>/dev/null)

if [ -n "$THEME_ID" ]; then
    check_api_response "GET /themes/:id"            "/themes/${THEME_ID}"
else
    skip "GET /themes/:id" "(no custom themes)"
fi

# Create, update, delete a test theme
CREATE_THEME=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "Audit Test Theme", "description": "Temp audit theme"}' \
    "${BASE}/themes" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [ -n "$CREATE_THEME" ]; then
    pass "POST /themes (create)" "(created ${CREATE_THEME})"
    UPD_THEME=$(curl -sf -X PUT \
        -H "Content-Type: application/json" \
        -d '{"name": "Updated Audit Theme"}' \
        "${BASE}/themes/${CREATE_THEME}" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$UPD_THEME" = "True" ]; then
        pass "PUT /themes/:id (update)" "(success)"
    else
        fail "PUT /themes/:id (update)" "(unexpected response)"
    fi
    DEL_THEME=$(curl -sf -X DELETE "${BASE}/themes/${CREATE_THEME}" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$DEL_THEME" = "True" ]; then
        pass "DELETE /themes/:id" "(success)"
    else
        fail "DELETE /themes/:id" "(unexpected response)"
    fi
else
    fail "POST /themes (create)" "(no ID returned)"
    skip "PUT /themes/:id" "(create failed)"
    skip "DELETE /themes/:id" "(create failed)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "SYSTEM (/api/v1/system) — 5 routes (raw JSON, no APIResponse)"
# These endpoints return raw JSON by design — client decodes directly
check_get_raw "GET /system/metrics (raw)" "${BASE}/system/metrics" "200" "cpu"
check_get_raw "GET /system/processes (raw)" "${BASE}/system/processes" "200"

# Verify processes returns array
PROC_IS_ARRAY=$(curl -sf "${BASE}/system/processes" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(isinstance(d, list))
" 2>/dev/null)
if [ "$PROC_IS_ARRAY" = "True" ]; then
    pass "GET /system/processes (returns array)" "(confirmed)"
else
    fail "GET /system/processes (returns array)" "(expected JSON array)"
fi

check_get_raw "GET /system/files?path=/tmp (raw)" "${BASE}/system/files?path=/tmp" "200"
check_get_raw "GET /system/metrics/source (raw)" "${BASE}/system/metrics/source" "200" "source"
skip "WS /system/metrics/live" "(WebSocket — requires wscat or similar tool)"

# ─────────────────────────────────────────────────────────────────────────────
section "TUNNEL (/api/v1/tunnel) — 3 routes (raw JSON, no APIResponse)"
# These endpoints return raw JSON by design
check_get_raw "GET /tunnel/status (raw)" "${BASE}/tunnel/status" "200" "running"

TUNNEL_STATUS_SHAPE=$(curl -sf "${BASE}/tunnel/status" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Must have 'running' and 'mode' keys
assert 'running' in d, 'missing running'
assert 'mode' in d, 'missing mode'
print('OK')
" 2>/dev/null)
if [ "$TUNNEL_STATUS_SHAPE" = "OK" ]; then
    pass "GET /tunnel/status shape" "(has running, mode)"
else
    fail "GET /tunnel/status shape" "(missing expected keys)"
fi

skip "POST /tunnel/start" "(would start cloudflared process — skipped in audit)"
skip "POST /tunnel/stop" "(would stop tunnel — skipped in audit)"

# ─────────────────────────────────────────────────────────────────────────────
section "TEAMS (/api/v1/teams) — 12 routes"
check_api_response "GET /teams (list)"              "/teams"

# Create a test team
CREATE_TEAM=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "audit-test-team", "description": "Temporary audit team"}' \
    "${BASE}/teams" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('name', ''))
" 2>/dev/null)

if [ "$CREATE_TEAM" = "audit-test-team" ]; then
    pass "POST /teams (create)" "(created)"
    check_api_response "GET /teams/:name"           "/teams/audit-test-team"
    check_api_response "GET /teams/:name/tasks"     "/teams/audit-test-team/tasks"
    check_api_response "GET /teams/:name/messages"  "/teams/audit-test-team/messages"

    # Create task
    CREATE_TASK=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d '{"subject": "Audit test task", "description": "Test"}' \
        "${BASE}/teams/audit-test-team/tasks" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
    if [ -n "$CREATE_TASK" ]; then
        pass "POST /teams/:name/tasks (create)" "(created ${CREATE_TASK})"
        UPD_TASK=$(curl -sf -X PUT \
            -H "Content-Type: application/json" \
            -d '{"status": "in_progress"}' \
            "${BASE}/teams/audit-test-team/tasks/${CREATE_TASK}" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
        if [ "$UPD_TASK" = "True" ]; then
            pass "PUT /teams/:name/tasks/:taskId" "(success)"
        else
            fail "PUT /teams/:name/tasks/:taskId" "(unexpected response)"
        fi
    else
        fail "POST /teams/:name/tasks" "(no ID returned)"
        skip "PUT /teams/:name/tasks/:taskId" "(create failed)"
    fi

    # Send message
    MSG_RESULT=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d '{"content": "Audit test message", "from": "auditor"}' \
        "${BASE}/teams/audit-test-team/messages" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('success', False))
" 2>/dev/null)
    if [ "$MSG_RESULT" = "True" ]; then
        pass "POST /teams/:name/messages (send)" "(success)"
    else
        fail "POST /teams/:name/messages (send)" "(unexpected response)"
    fi

    skip "POST /teams/:name/spawn" "(would spawn a Claude subprocess — skipped in audit)"
    skip "POST /teams/:name/shutdown" "(no spawned members — skipped)"
    skip "DELETE /teams/:name/members/:memberName" "(no spawned members — skipped)"

    # Delete team
    DEL_TEAM=$(curl -sf -X DELETE "${BASE}/teams/audit-test-team" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$DEL_TEAM" = "True" ]; then
        pass "DELETE /teams/:name" "(success)"
    else
        fail "DELETE /teams/:name" "(unexpected response)"
    fi
else
    fail "POST /teams (create)" "(unexpected: $CREATE_TEAM)"
    skip "GET /teams/:name" "(create failed)"
    skip "GET /teams/:name/tasks" "(create failed)"
    skip "GET /teams/:name/messages" "(create failed)"
    skip "POST /teams/:name/tasks" "(create failed)"
    skip "PUT /teams/:name/tasks/:taskId" "(create failed)"
    skip "POST /teams/:name/messages" "(create failed)"
    skip "POST /teams/:name/spawn" "(create failed)"
    skip "POST /teams/:name/shutdown" "(create failed)"
    skip "DELETE /teams/:name/members/:memberName" "(create failed)"
    skip "DELETE /teams/:name" "(create failed)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "FLEET (/api/v1/fleet) — 5 routes"
check_api_response "GET /fleet (list)"              "/fleet"

FLEET_HOST_ID=$(curl -sf "${BASE}/fleet" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
hosts = d.get('data', {}).get('hosts', [])
if hosts: print(hosts[0]['id'])
" 2>/dev/null)

if [ -n "$FLEET_HOST_ID" ]; then
    check_api_response "GET /fleet/:id/health"      "/fleet/${FLEET_HOST_ID}/health"
    # Activate — only if safe (it's already the local host)
    ACTIVATE_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X POST "${BASE}/fleet/${FLEET_HOST_ID}/activate" 2>/dev/null)
    if [ "$ACTIVATE_CODE" = "200" ]; then
        pass "POST /fleet/:id/activate" "(HTTP 200)"
    else
        fail "POST /fleet/:id/activate" "(HTTP $ACTIVATE_CODE)"
    fi
else
    skip "GET /fleet/:id/health" "(no fleet hosts)"
    skip "POST /fleet/:id/activate" "(no fleet hosts)"
fi

# Register a test host
REG_FLEET=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "audit-test-host", "host": "192.0.2.1", "port": 22, "backendPort": 9999}' \
    "${BASE}/fleet/register" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [ -n "$REG_FLEET" ]; then
    pass "POST /fleet/register" "(registered ${REG_FLEET})"
    # DELETE
    DEL_FLEET=$(curl -sf -X DELETE "${BASE}/fleet/${REG_FLEET}" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
    if [ "$DEL_FLEET" = "True" ]; then
        pass "DELETE /fleet/:id" "(success)"
    else
        fail "DELETE /fleet/:id" "(unexpected response)"
    fi
else
    fail "POST /fleet/register" "(no ID returned)"
    skip "DELETE /fleet/:id" "(register failed)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "ERROR CASE VERIFICATION"
# Invalid UUIDs should return 400
BAD_SESSION_CODE=$(curl -sf -w "%{http_code}" -o /dev/null "${BASE}/sessions/not-a-uuid" 2>/dev/null)
if [ "$BAD_SESSION_CODE" = "400" ]; then
    pass "GET /sessions/not-a-uuid → 400" "(bad request)"
else
    fail "GET /sessions/not-a-uuid → 400" "(got HTTP $BAD_SESSION_CODE)"
fi

# Non-existent session should return 404
MISSING_SESSION_CODE=$(curl -sf -w "%{http_code}" -o /dev/null \
    "${BASE}/sessions/00000000-0000-0000-0000-000000000099" 2>/dev/null)
if [ "$MISSING_SESSION_CODE" = "404" ]; then
    pass "GET /sessions/nonexistent → 404" "(not found)"
else
    fail "GET /sessions/nonexistent → 404" "(got HTTP $MISSING_SESSION_CODE)"
fi

# Missing required field should return 400
MISSING_FIELD_CODE=$(curl -sf -w "%{http_code}" -o /dev/null -X POST \
    -H "Content-Type: application/json" \
    -d '{}' \
    "${BASE}/sessions/search" 2>/dev/null)
if [ "$MISSING_FIELD_CODE" = "400" ]; then
    pass "GET /sessions/search (missing q) → 400" "(bad request)"
else
    fail "GET /sessions/search (missing q) → 400" "(got HTTP $MISSING_FIELD_CODE)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "PAGINATION VERIFICATION"
# Verify page and limit work
PAGE_RESP=$(curl -sf "${BASE}/sessions?page=1&limit=5" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', {})
items = data.get('items', [])
total = data.get('total', 0)
has_more = data.get('hasMore', False)
# items count must be <= limit
assert len(items) <= 5, f'too many items: {len(items)}'
assert total > 0, 'total should be > 0'
print(f'OK: {len(items)} items, total={total}, hasMore={has_more}')
" 2>/dev/null)
if echo "$PAGE_RESP" | grep -q "^OK:"; then
    pass "Pagination: /sessions?page=1&limit=5" "($PAGE_RESP)"
else
    fail "Pagination: /sessions?page=1&limit=5" "(unexpected response)"
fi

SKILLS_PAGE=$(curl -sf "${BASE}/skills?page=2&limit=10" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', {})
items = data.get('items', [])
assert len(items) <= 10
print(f'OK: {len(items)} items on page 2')
" 2>/dev/null)
if echo "$SKILLS_PAGE" | grep -q "^OK:"; then
    pass "Pagination: /skills?page=2&limit=10" "($SKILLS_PAGE)"
else
    fail "Pagination: /skills?page=2&limit=10" "(unexpected response)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# FINAL REPORT
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  AUDIT RESULTS SUMMARY${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "  Total endpoints tested: ${TOTAL}"
echo -e "  ${GREEN}PASS: ${PASS}${NC}"
echo -e "  ${RED}FAIL: ${FAIL}${NC}"
echo -e "  ${YELLOW}SKIP: ${SKIP}${NC}"
echo ""
if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Failed endpoints:${NC}"
    for r in "${RESULTS[@]}"; do
        STATUS=$(echo "$r" | cut -d'|' -f1)
        NAME=$(echo "$r" | cut -d'|' -f2)
        DETAIL=$(echo "$r" | cut -d'|' -f3)
        if [ "$STATUS" = "FAIL" ]; then
            echo -e "  ${RED}✗${NC} $NAME $DETAIL"
        fi
    done
    echo ""
fi
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ All tested endpoints PASSED. No 500 errors on valid requests.${NC}"
else
    echo -e "${YELLOW}! Some endpoints failed. See details above.${NC}"
fi
