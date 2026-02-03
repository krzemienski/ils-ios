#!/bin/bash

# End-to-End Analytics Verification Script
# Tests the complete analytics flow from API to database

set -e

echo "=== End-to-End Analytics Verification ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Track verification status
VERIFICATION_PASSED=true

# Cleanup function
cleanup() {
    if [ ! -z "$SERVER_PID" ]; then
        print_info "Stopping backend server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Step 1: Build backend
print_info "Step 1: Building backend..."
if swift build > /dev/null 2>&1; then
    print_success "Backend build successful"
else
    print_error "Backend build failed"
    VERIFICATION_PASSED=false
    exit 1
fi

# Step 2: Start backend server
print_info "Step 2: Starting backend server..."
rm -f ils.sqlite ils.sqlite-shm ils.sqlite-wal
swift run ILSBackend migrate --auto-migrate --auto-revert > /dev/null 2>&1
swift run ILSBackend > server.log 2>&1 &
SERVER_PID=$!

# Wait for server to be ready
print_info "Waiting for server to start..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        print_success "Server is ready (PID: $SERVER_PID)"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Server failed to start within 30 seconds"
        cat server.log
        VERIFICATION_PASSED=false
        exit 1
    fi
    sleep 1
done

# Step 3: Test analytics API endpoint (analytics enabled)
print_info "Step 3: Testing analytics API with events..."

# Test event 1: app_launch
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "app_launch",
        "eventData": "{\"version\":\"1.0.0\",\"os\":\"iOS 17.0\"}",
        "deviceId": "test-device-001"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ]; then
    print_success "app_launch event created (HTTP 201)"
else
    print_error "app_launch event failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE"
    VERIFICATION_PASSED=false
fi

# Test event 2: project_created
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "project_created",
        "eventData": "{\"project_name\":\"Test Project\"}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ]; then
    print_success "project_created event created (HTTP 201)"
else
    print_error "project_created event failed (HTTP $HTTP_CODE)"
    VERIFICATION_PASSED=false
fi

# Test event 3: chat_started
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "chat_started",
        "eventData": "{\"chat_mode\":\"assistant\"}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ]; then
    print_success "chat_started event created (HTTP 201)"
else
    print_error "chat_started event failed (HTTP $HTTP_CODE)"
    VERIFICATION_PASSED=false
fi

# Test event 4: message_sent
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "message_sent",
        "eventData": "{\"message_length\":42}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ]; then
    print_success "message_sent event created (HTTP 201)"
else
    print_error "message_sent event failed (HTTP $HTTP_CODE)"
    VERIFICATION_PASSED=false
fi

# Test event 5: crash event
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "crash",
        "eventData": "{\"type\":\"NSException\",\"reason\":\"Test crash\"}",
        "deviceId": "test-device-001"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ]; then
    print_success "crash event created (HTTP 201)"
else
    print_error "crash event failed (HTTP $HTTP_CODE)"
    VERIFICATION_PASSED=false
fi

# Step 4: Verify events in database
print_info "Step 4: Verifying events in database..."

# Check SQLite database directly
EVENT_COUNT=$(sqlite3 ils.sqlite "SELECT COUNT(*) FROM analytics_events;" 2>/dev/null || echo "0")
if [ "$EVENT_COUNT" -ge 5 ]; then
    print_success "Found $EVENT_COUNT events in database"
else
    print_error "Expected at least 5 events, found $EVENT_COUNT"
    VERIFICATION_PASSED=false
fi

# Verify each event type exists
EVENT_TYPES=$(sqlite3 ils.sqlite "SELECT DISTINCT event_name FROM analytics_events ORDER BY event_name;" 2>/dev/null)
print_info "Event types in database:"
echo "$EVENT_TYPES" | while read -r event; do
    echo "  - $event"
done

# Check for specific events
for event_name in "app_launch" "project_created" "chat_started" "message_sent" "crash"; do
    COUNT=$(sqlite3 ils.sqlite "SELECT COUNT(*) FROM analytics_events WHERE event_name = '$event_name';" 2>/dev/null || echo "0")
    if [ "$COUNT" -ge 1 ]; then
        print_success "Event '$event_name' found in database"
    else
        print_error "Event '$event_name' NOT found in database"
        VERIFICATION_PASSED=false
    fi
done

# Step 5: Verify device ID tracking
print_info "Step 5: Verifying device ID tracking..."
DEVICE_COUNT=$(sqlite3 ils.sqlite "SELECT COUNT(DISTINCT device_id) FROM analytics_events;" 2>/dev/null || echo "0")
if [ "$DEVICE_COUNT" -eq 1 ]; then
    print_success "All events tracked to single device ID"
else
    print_error "Expected 1 unique device ID, found $DEVICE_COUNT"
    VERIFICATION_PASSED=false
fi

# Step 6: Verify session tracking
print_info "Step 6: Verifying session tracking..."
SESSION_EVENTS=$(sqlite3 ils.sqlite "SELECT COUNT(*) FROM analytics_events WHERE session_id = 'session-001';" 2>/dev/null || echo "0")
if [ "$SESSION_EVENTS" -ge 3 ]; then
    print_success "Found $SESSION_EVENTS events with session ID"
else
    print_error "Expected at least 3 events with session ID, found $SESSION_EVENTS"
    VERIFICATION_PASSED=false
fi

# Step 7: Verify event data structure
print_info "Step 7: Verifying event data structure..."
EVENT_WITH_DATA=$(sqlite3 ils.sqlite "SELECT COUNT(*) FROM analytics_events WHERE event_data IS NOT NULL AND event_data != '';" 2>/dev/null || echo "0")
if [ "$EVENT_WITH_DATA" -ge 5 ]; then
    print_success "All events have event_data populated"
else
    print_error "Some events missing event_data"
    VERIFICATION_PASSED=false
fi

# Step 8: Verify timestamps
print_info "Step 8: Verifying timestamps..."
RECENT_EVENTS=$(sqlite3 ils.sqlite "SELECT COUNT(*) FROM analytics_events WHERE created_at >= datetime('now', '-1 minute');" 2>/dev/null || echo "0")
if [ "$RECENT_EVENTS" -ge 5 ]; then
    print_success "All events have recent timestamps"
else
    print_error "Some events have invalid timestamps"
    VERIFICATION_PASSED=false
fi

# Step 9: Test privacy - no PII collection
print_info "Step 9: Verifying no PII collected..."
PII_CHECK=$(sqlite3 ils.sqlite "SELECT event_data FROM analytics_events;" 2>/dev/null | grep -iE 'email|phone|address|name.*:.*@|password' || echo "")
if [ -z "$PII_CHECK" ]; then
    print_success "No PII detected in event data"
else
    print_error "Potential PII found in event data"
    echo "$PII_CHECK"
    VERIFICATION_PASSED=false
fi

# Summary
echo ""
echo "=== Verification Summary ==="
if [ "$VERIFICATION_PASSED" = true ]; then
    print_success "All verification checks PASSED ✓"
    echo ""
    echo "Backend Analytics API is fully functional!"
    echo ""
    echo "Next steps for complete E2E verification:"
    echo "1. Open ILSApp.xcodeproj in Xcode"
    echo "2. Run the app in simulator with analytics enabled"
    echo "3. Perform user journey: create project → start chat → send message"
    echo "4. Check this database for new events: $PWD/ils.sqlite"
    echo "5. Go to Settings → disable analytics"
    echo "6. Perform same journey again"
    echo "7. Verify no new events are added to database"
    echo ""
    exit 0
else
    print_error "Some verification checks FAILED ✗"
    echo ""
    echo "Review the errors above and check server.log for details"
    exit 1
fi
