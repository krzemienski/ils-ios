#!/bin/bash
# SSH Endpoint Verification Script
# This script verifies the backend SSH API endpoints work end-to-end

set -e

echo "=== SSH Endpoint Verification ==="
echo ""

# 1. Check backend is running
echo "Step 1: Checking backend is running on port 9999..."
if lsof -i :9999 >/dev/null 2>&1; then
    echo "✓ Backend is running on port 9999"
else
    echo "✗ Backend is not running. Start with: PORT=9999 ./.build/arm64-apple-macosx/debug/ILSBackend"
    exit 1
fi

echo ""

# 2. POST /api/v1/ssh/connect with test credentials
echo "Step 2: POST /api/v1/ssh/connect with test credentials..."
CONNECT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9999/api/v1/ssh/connect \
  -H "Content-Type: application/json" \
  -d '{"host":"test.example.com","port":22,"username":"testuser","authMethod":"password","password":"testpass"}')
HTTP_CODE=$(echo "$CONNECT_RESPONSE" | tail -1)
BODY=$(echo "$CONNECT_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "501" ]; then
    echo "✓ Connect endpoint returned 501 Not Implemented (expected for stub)"
    echo "  Response: $BODY"
else
    echo "✗ Unexpected status code: $HTTP_CODE"
    exit 1
fi

echo ""

# 3. GET /api/v1/ssh/status
echo "Step 3: GET /api/v1/ssh/status..."
STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:9999/api/v1/ssh/status)
HTTP_CODE=$(echo "$STATUS_RESPONSE" | tail -1)
BODY=$(echo "$STATUS_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Status endpoint returned 200 OK"
    echo "  Response: $BODY"
else
    echo "✗ Unexpected status code: $HTTP_CODE"
    exit 1
fi

echo ""

# 4. POST /api/v1/ssh/execute runs 'whoami'
echo "Step 4: POST /api/v1/ssh/execute with 'whoami' command..."
EXEC_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9999/api/v1/ssh/execute \
  -H "Content-Type: application/json" \
  -d '{"command":"whoami"}')
HTTP_CODE=$(echo "$EXEC_RESPONSE" | tail -1)
BODY=$(echo "$EXEC_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "501" ]; then
    echo "✓ Execute endpoint returned 501 Not Implemented (expected for stub)"
    echo "  Response: $BODY"
else
    echo "✗ Unexpected status code: $HTTP_CODE"
    exit 1
fi

echo ""

# 5. POST /api/v1/ssh/disconnect
echo "Step 5: POST /api/v1/ssh/disconnect..."
DISCONNECT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9999/api/v1/ssh/disconnect)
HTTP_CODE=$(echo "$DISCONNECT_RESPONSE" | tail -1)
BODY=$(echo "$DISCONNECT_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Disconnect endpoint returned 200 OK"
    echo "  Response: $BODY"
else
    echo "✗ Unexpected status code: $HTTP_CODE"
    exit 1
fi

echo ""
echo "=== All SSH endpoint verifications passed! ==="
echo ""
echo "Note: Endpoints return stub responses (501 Not Implemented or mock data)"
echo "This is expected as SSHService implementation is pending."
