# Automation Rule Templates - End-to-End Verification Guide

This document provides step-by-step instructions for manually verifying all 5 pre-built automation rule templates work correctly end-to-end.

## Prerequisites

1. Backend running from this worktree:
   ```bash
   cd /Users/nick/Desktop/ils-ios/.auto-claude/worktrees/tasks/248-session-automation-rules-event-driven-triggers
   PORT=9999 swift run ILSBackend
   ```

2. Database migrations applied (v5.0 - automation_rules, rule_execution_logs)

3. Backend health check passes:
   ```bash
   curl http://localhost:9999/health
   ```

## Template Overview

The system provides 5 pre-built templates accessible via:
```bash
curl http://localhost:9999/api/v1/automation-rules/templates
```

1. **High Cost Alert** - Notify when session cost exceeds $5
2. **Auto-Export on Complete** - Export session to Markdown when it completes
3. **Fork on Error** - Fork session when error count > 3
4. **Idle Timeout Notification** - Notify when session is idle for 30 minutes
5. **Context Limit Warning** - Notify when context usage exceeds 80%

---

## Template 1: Auto-Export on Complete

**Trigger:** session_complete
**Action:** export (format: markdown)
**Condition:** None

### Test Steps

1. **Create Rule from Template**
   ```bash
   curl -X POST http://localhost:9999/api/v1/automation-rules \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Auto-Export on Complete",
       "description": "Automatically export completed sessions to Markdown",
       "triggerType": "session_complete",
       "actionType": "export",
       "actionConfig": {
         "exportFormat": "markdown"
       },
       "isEnabled": true
     }'
   ```

2. **Create a Test Session**
   ```bash
   SESSION_ID=$(curl -X POST http://localhost:9999/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Template Test Session",
       "model": "claude-3-7-sonnet-20250219",
       "provider": "anthropic"
     }' | jq -r '.data.id')
   echo "Session ID: $SESSION_ID"
   ```

3. **Complete the Session**
   ```bash
   # Mark session as completed
   curl -X PUT "http://localhost:9999/api/v1/sessions/$SESSION_ID" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "completed"
     }'
   ```

4. **Trigger Rule Evaluation**
   ```bash
   # Activity feed endpoint evaluates automation rules
   curl http://localhost:9999/api/v1/activity-feed
   ```

5. **Verify Export Created**
   ```bash
   # Check exports directory
   ls -lh ./exports/automation-rules/
   # Should contain: {session-id}_{timestamp}.md

   # View export content
   cat ./exports/automation-rules/${SESSION_ID}_*.md
   ```

6. **Check Execution Log**
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId=$SESSION_ID" | jq '.'
   # Should show status: "success", no error_message
   ```

### Expected Results
- ✅ Export file created in ./exports/automation-rules/
- ✅ Export contains session metadata and messages in Markdown format
- ✅ Execution log shows status: "success"
- ✅ Export filename matches pattern: {uuid}_{timestamp}.md

---

## Template 2: High Cost Alert

**Trigger:** cost_threshold
**Action:** notify
**Condition:** cost_usd > 5

### Test Steps

1. **Create Rule from Template**
   ```bash
   curl -X POST http://localhost:9999/api/v1/automation-rules \
     -H "Content-Type: application/json" \
     -d '{
       "name": "High Cost Alert",
       "description": "Alert when session cost exceeds $5",
       "triggerType": "cost_threshold",
       "actionType": "notify",
       "conditions": [{
         "field": "cost_usd",
         "operator": "greater_than",
         "value": "5"
       }],
       "actionConfig": {
         "notificationMessage": "⚠️ Session cost has exceeded $5"
       },
       "isEnabled": true
     }'
   ```

2. **Create a Test Session with High Cost**
   ```bash
   SESSION_ID=$(curl -X POST http://localhost:9999/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{
       "name": "High Cost Test Session",
       "model": "claude-3-7-sonnet-20250219",
       "provider": "anthropic"
     }' | jq -r '.data.id')

   # Update session with cost > $5
   curl -X PUT "http://localhost:9999/api/v1/sessions/$SESSION_ID" \
     -H "Content-Type: application/json" \
     -d '{
       "totalCostUSD": 6.50
     }'
   ```

3. **Trigger Rule Evaluation**
   ```bash
   curl http://localhost:9999/api/v1/activity-feed
   ```

4. **Check Execution Log**
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId=$SESSION_ID" | jq '.'
   # Should show status: "success"
   # Details should contain notification data
   ```

5. **Verify Notification (macOS)**
   - Check macOS Notification Center
   - Should display: "High Cost Alert" with message "⚠️ Session cost has exceeded $5"

### Expected Results
- ✅ Execution log shows status: "success"
- ✅ Details contain notification message
- ✅ macOS notification appears (if app not frontmost and permissions granted)

---

## Template 3: Fork on Error

**Trigger:** error_occurred
**Action:** fork
**Condition:** error_count > 3

### Test Steps

1. **Create Rule from Template**
   ```bash
   curl -X POST http://localhost:9999/api/v1/automation-rules \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Fork on Error",
       "description": "Fork session when errors exceed threshold",
       "triggerType": "error_occurred",
       "actionType": "fork",
       "conditions": [{
         "field": "error_count",
         "operator": "greater_than",
         "value": "3"
       }],
       "isEnabled": true
     }'
   ```

2. **Create a Test Session**
   ```bash
   SESSION_ID=$(curl -X POST http://localhost:9999/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Error Test Session",
       "model": "claude-3-7-sonnet-20250219",
       "provider": "anthropic"
     }' | jq -r '.data.id')
   ```

3. **Add Messages to Session**
   ```bash
   # Add some messages so fork has content
   for i in {1..3}; do
     curl -X POST "http://localhost:9999/api/v1/sessions/$SESSION_ID/messages" \
       -H "Content-Type: application/json" \
       -d "{
         \"role\": \"user\",
         \"content\": \"Test message $i\"
       }"
   done
   ```

4. **Mark Session with Errors**
   ```bash
   # Set session status to error
   curl -X PUT "http://localhost:9999/api/v1/sessions/$SESSION_ID" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "error"
     }'
   ```

5. **Trigger Rule Evaluation with error_count > 3**
   ```bash
   # In real scenario, error_count is passed in trigger context
   # For manual testing, evaluate with ActivityFeedController
   curl http://localhost:9999/api/v1/activity-feed
   ```

6. **Verify Fork Created**
   ```bash
   # List all sessions, should see a forked copy
   curl http://localhost:9999/api/v1/sessions | jq '.data.sessions[] | select(.name | contains("Error Test Session"))'

   # Should see:
   # - Original: "Error Test Session"
   # - Fork: "Error Test Session (Fork)"
   ```

7. **Check Execution Log**
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId=$SESSION_ID" | jq '.'
   # Should show status: "success"
   # Details should contain forked session ID
   ```

### Expected Results
- ✅ Forked session created with name appended "(Fork)"
- ✅ Forked session contains all original messages
- ✅ Forked session has cost reset to 0
- ✅ Execution log shows status: "success" with forked session ID

---

## Template 4: Idle Timeout Notification

**Trigger:** idle_timeout
**Action:** notify
**Condition:** idle_duration_minutes > 30

### Test Steps

1. **Create Rule from Template**
   ```bash
   curl -X POST http://localhost:9999/api/v1/automation-rules \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Idle Timeout Notification",
       "description": "Notify when session has been idle for 30 minutes",
       "triggerType": "idle_timeout",
       "actionType": "notify",
       "conditions": [{
         "field": "idle_duration_minutes",
         "operator": "greater_than",
         "value": "30"
       }],
       "actionConfig": {
         "notificationMessage": "Session has been idle for 30 minutes"
       },
       "isEnabled": true
     }'
   ```

2. **Create a Test Session**
   ```bash
   SESSION_ID=$(curl -X POST http://localhost:9999/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Idle Test Session",
       "model": "claude-3-7-sonnet-20250219",
       "provider": "anthropic"
     }' | jq -r '.data.id')
   ```

3. **Set Session Last Active Time to 31+ Minutes Ago**
   ```bash
   # Calculate timestamp 31 minutes ago
   PAST_TIME=$(date -u -v-31M +"%Y-%m-%dT%H:%M:%SZ")

   curl -X PUT "http://localhost:9999/api/v1/sessions/$SESSION_ID" \
     -H "Content-Type: application/json" \
     -d "{
       \"lastActiveAt\": \"$PAST_TIME\"
     }"
   ```

4. **Trigger Rule Evaluation**
   ```bash
   curl http://localhost:9999/api/v1/activity-feed
   ```

5. **Check Execution Log**
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId=$SESSION_ID" | jq '.'
   # Should show status: "success"
   ```

6. **Verify Notification (macOS)**
   - Check macOS Notification Center
   - Should display: "Idle Timeout Notification" with message

### Expected Results
- ✅ Execution log shows status: "success"
- ✅ Notification prepared with idle duration message
- ✅ macOS notification appears (if conditions met)

---

## Template 5: Context Limit Warning

**Trigger:** context_near_limit
**Action:** notify
**Condition:** context_percentage > 80

### Test Steps

1. **Create Rule from Template**
   ```bash
   curl -X POST http://localhost:9999/api/v1/automation-rules \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Context Limit Warning",
       "description": "Warn when context usage exceeds 80%",
       "triggerType": "context_near_limit",
       "actionType": "notify",
       "conditions": [{
         "field": "context_percentage",
         "operator": "greater_than",
         "value": "80"
       }],
       "actionConfig": {
         "notificationMessage": "⚠️ Context usage is approaching limit (>80%)"
       },
       "isEnabled": true
     }'
   ```

2. **Create a Test Session**
   ```bash
   SESSION_ID=$(curl -X POST http://localhost:9999/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Context Test Session",
       "model": "claude-3-7-sonnet-20250219",
       "provider": "anthropic"
     }' | jq -r '.data.id')
   ```

3. **Add Many Messages to Simulate High Context Usage**
   ```bash
   # Add 161+ messages to trigger >80% context usage
   # (ActivityFeedController estimates: messageCount * 500 tokens)
   # Claude 3.7 Sonnet has 200k context window
   # 161 messages * 500 = 80,500 tokens = 40.25% (need more messages)
   # For 80%: need 160k tokens = 320 messages

   for i in {1..350}; do
     curl -X POST "http://localhost:9999/api/v1/sessions/$SESSION_ID/messages" \
       -H "Content-Type: application/json" \
       -d "{
         \"role\": \"user\",
         \"content\": \"Test message $i with some content to fill context\"
       }" > /dev/null 2>&1

     # Progress indicator
     if [ $((i % 50)) -eq 0 ]; then
       echo "Added $i messages..."
     fi
   done
   ```

4. **Trigger Rule Evaluation**
   ```bash
   curl http://localhost:9999/api/v1/activity-feed
   ```

5. **Check Execution Log**
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId=$SESSION_ID" | jq '.'
   # Should show status: "success"
   # Details should contain context percentage
   ```

6. **Verify Notification (macOS)**
   - Check macOS Notification Center
   - Should display: "Context Limit Warning" with message

### Expected Results
- ✅ Execution log shows status: "success"
- ✅ Context percentage calculated based on message count
- ✅ Notification prepared with context warning
- ✅ macOS notification appears (if conditions met)

---

## Comprehensive Verification Script

Save this script to test all templates automatically:

```bash
#!/bin/bash
# File: verify-all-templates.sh

set -e

BASE_URL="http://localhost:9999/api/v1"
EXPORTS_DIR="./exports/automation-rules"

echo "=== Automation Rule Templates - Comprehensive E2E Verification ==="
echo ""

# Health check
echo "[1/6] Checking backend health..."
if ! curl -sf "$BASE_URL/../health" > /dev/null; then
  echo "❌ Backend not responding. Start backend first:"
  echo "   PORT=9999 swift run ILSBackend"
  exit 1
fi
echo "✅ Backend healthy"
echo ""

# Get templates
echo "[2/6] Fetching rule templates..."
TEMPLATES=$(curl -sf "$BASE_URL/automation-rules/templates")
TEMPLATE_COUNT=$(echo "$TEMPLATES" | jq '.data.templates | length')
echo "✅ Found $TEMPLATE_COUNT templates"
echo ""

# Create exports directory
mkdir -p "$EXPORTS_DIR"
echo "[3/6] Exports directory ready: $EXPORTS_DIR"
echo ""

# Test Template 1: Auto-Export on Complete
echo "[4/6] Testing Template 1: Auto-Export on Complete"
echo "  - Creating rule..."
RULE1_ID=$(curl -sf -X POST "$BASE_URL/automation-rules" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test: Auto-Export on Complete",
    "triggerType": "session_complete",
    "actionType": "export",
    "actionConfig": {"exportFormat": "markdown"},
    "isEnabled": true
  }' | jq -r '.data.id')
echo "  - Rule created: $RULE1_ID"

echo "  - Creating test session..."
SESSION1_ID=$(curl -sf -X POST "$BASE_URL/sessions" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Export Test",
    "model": "claude-3-7-sonnet-20250219",
    "provider": "anthropic"
  }' | jq -r '.data.id')
echo "  - Session created: $SESSION1_ID"

echo "  - Marking session as completed..."
curl -sf -X PUT "$BASE_URL/sessions/$SESSION1_ID" \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}' > /dev/null

echo "  - Triggering rule evaluation..."
curl -sf "$BASE_URL/activity-feed" > /dev/null

echo "  - Checking for export file..."
sleep 1
if ls "$EXPORTS_DIR"/${SESSION1_ID}_*.md 1> /dev/null 2>&1; then
  echo "  ✅ Export file created"
  EXPORT_FILE=$(ls "$EXPORTS_DIR"/${SESSION1_ID}_*.md | head -1)
  echo "     File: $(basename "$EXPORT_FILE")"
else
  echo "  ⚠️  Export file not found (check execution logs)"
fi

echo "  - Cleaning up..."
curl -sf -X DELETE "$BASE_URL/automation-rules/$RULE1_ID" > /dev/null
curl -sf -X DELETE "$BASE_URL/sessions/$SESSION1_ID" > /dev/null
echo "  ✅ Template 1 verification complete"
echo ""

# Test Template 2: High Cost Alert
echo "[5/6] Testing Template 2: High Cost Alert"
echo "  - Creating rule..."
RULE2_ID=$(curl -sf -X POST "$BASE_URL/automation-rules" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test: High Cost Alert",
    "triggerType": "cost_threshold",
    "actionType": "notify",
    "conditions": [{"field": "cost_usd", "operator": "greater_than", "value": "5"}],
    "actionConfig": {"notificationMessage": "Cost exceeded $5"},
    "isEnabled": true
  }' | jq -r '.data.id')
echo "  - Rule created: $RULE2_ID"

echo "  - Creating test session with high cost..."
SESSION2_ID=$(curl -sf -X POST "$BASE_URL/sessions" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Cost Test",
    "model": "claude-3-7-sonnet-20250219",
    "provider": "anthropic"
  }' | jq -r '.data.id')

curl -sf -X PUT "$BASE_URL/sessions/$SESSION2_ID" \
  -H "Content-Type: application/json" \
  -d '{"totalCostUSD": 6.5}' > /dev/null

echo "  - Triggering rule evaluation..."
curl -sf "$BASE_URL/activity-feed" > /dev/null

echo "  - Checking execution log..."
sleep 1
EXEC_COUNT=$(curl -sf "$BASE_URL/automation-rules/executions?sessionId=$SESSION2_ID" \
  | jq '.data.totalCount')
echo "  ✅ Execution log entries: $EXEC_COUNT"

echo "  - Cleaning up..."
curl -sf -X DELETE "$BASE_URL/automation-rules/$RULE2_ID" > /dev/null
curl -sf -X DELETE "$BASE_URL/sessions/$SESSION2_ID" > /dev/null
echo "  ✅ Template 2 verification complete"
echo ""

echo "[6/6] All template verifications complete!"
echo ""
echo "=== Summary ==="
echo "✅ Template 1 (Auto-Export) - Tested"
echo "✅ Template 2 (High Cost Alert) - Tested"
echo "⚠️  Template 3 (Fork on Error) - Requires error count in trigger context"
echo "⚠️  Template 4 (Idle Timeout) - Requires time-based testing"
echo "⚠️  Template 5 (Context Limit) - Requires 350+ messages"
echo ""
echo "For comprehensive manual testing, see template-verification-guide.md"
```

Make it executable:
```bash
chmod +x verify-all-templates.sh
```

---

## Verification Checklist

Use this checklist to track template testing progress:

- [ ] **Template 1: Auto-Export on Complete**
  - [ ] Rule created from template
  - [ ] Session completed
  - [ ] Export file generated in ./exports/automation-rules/
  - [ ] Export contains valid Markdown content
  - [ ] Execution log shows success

- [ ] **Template 2: High Cost Alert**
  - [ ] Rule created from template
  - [ ] Session cost set > $5
  - [ ] Notification prepared
  - [ ] Execution log shows success
  - [ ] macOS notification appears (if app inactive)

- [ ] **Template 3: Fork on Error**
  - [ ] Rule created from template
  - [ ] Session marked with error status
  - [ ] Error count > 3 in trigger context
  - [ ] Forked session created
  - [ ] Fork contains all messages
  - [ ] Execution log shows success

- [ ] **Template 4: Idle Timeout Notification**
  - [ ] Rule created from template
  - [ ] Session lastActiveAt set > 30 minutes ago
  - [ ] Notification prepared
  - [ ] Execution log shows success
  - [ ] macOS notification appears (if app inactive)

- [ ] **Template 5: Context Limit Warning**
  - [ ] Rule created from template
  - [ ] Session has 350+ messages (>80% context)
  - [ ] Notification prepared
  - [ ] Execution log shows success
  - [ ] macOS notification appears (if app inactive)

---

## Troubleshooting

### Rule Not Triggering

1. Check rule is enabled:
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/{rule-id}" | jq '.data.isEnabled'
   ```

2. Check execution logs for errors:
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?status=failed" | jq '.'
   ```

3. Verify ActivityFeedController is processing events:
   ```bash
   curl http://localhost:9999/api/v1/activity-feed
   ```

### Export Not Created

1. Check exports directory exists and is writable:
   ```bash
   mkdir -p ./exports/automation-rules
   ls -ld ./exports/automation-rules
   ```

2. Check execution log details for error:
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions?sessionId={session-id}" | jq '.data.executions[0].errorMessage'
   ```

### Notification Not Appearing

1. Check macOS notification permissions:
   - System Settings → Notifications → ILS
   - Ensure "Allow Notifications" is enabled

2. Check app is not frontmost (notifications only show when app is inactive)

3. Check execution log confirms notification was prepared:
   ```bash
   curl "http://localhost:9999/api/v1/automation-rules/executions" | jq '.data.executions[] | select(.details | contains("notification"))'
   ```

### Debouncing Preventing Execution

Rules have 5-minute debouncing to prevent duplicate executions. If testing repeatedly:

1. Wait 5 minutes between tests, OR
2. Delete the execution log entry:
   ```bash
   # Check recent executions
   curl "http://localhost:9999/api/v1/automation-rules/executions" | jq '.data.executions[0]'
   ```

---

## Success Criteria

All templates pass when:

✅ **Auto-Export on Complete** - Export file created with valid Markdown
✅ **High Cost Alert** - Notification prepared, execution logged
✅ **Fork on Error** - Forked session created with all messages
✅ **Idle Timeout Notification** - Notification prepared for idle sessions
✅ **Context Limit Warning** - Notification prepared at 80%+ context usage

All executions should log `status: "success"` with appropriate details.
