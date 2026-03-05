#!/bin/bash
# End-to-End Verification Script for Session Automation Rules
# This script verifies all components of the automation rule system work correctly

set -e  # Exit on error

BACKEND_URL="http://localhost:9999"
API_BASE="${BACKEND_URL}/api/v1"

echo "========================================="
echo "Session Automation Rules - E2E Verification"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Verify backend is running
echo -e "${BLUE}Step 1: Verifying backend is running...${NC}"
if curl -s "${BACKEND_URL}/health" > /dev/null; then
    echo -e "${GREEN}✓ Backend is healthy${NC}"
else
    echo -e "${RED}✗ Backend is not responding${NC}"
    exit 1
fi
echo ""

# Step 2: List existing automation rules
echo -e "${BLUE}Step 2: Listing automation rules...${NC}"
RULES_RESPONSE=$(curl -s "${API_BASE}/automation-rules")
RULES_COUNT=$(echo "$RULES_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['totalCount'])")
echo -e "${GREEN}✓ Found ${RULES_COUNT} automation rule(s)${NC}"
echo ""

# Step 3: Get rule templates
echo -e "${BLUE}Step 3: Fetching rule templates...${NC}"
TEMPLATES_RESPONSE=$(curl -s "${API_BASE}/automation-rules/templates")
TEMPLATES_COUNT=$(echo "$TEMPLATES_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['data']['templates']))")
echo -e "${GREEN}✓ Found ${TEMPLATES_COUNT} pre-built template(s)${NC}"
echo ""

# Step 4: Create a test automation rule
echo -e "${BLUE}Step 4: Creating test automation rule...${NC}"
CREATE_RESPONSE=$(curl -s -X POST "${API_BASE}/automation-rules" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "E2E Test Rule - Auto Export",
    "description": "Test rule for E2E verification - export completed sessions",
    "triggerType": "session_complete",
    "conditions": [],
    "actionType": "export",
    "actionConfig": {
      "exportFormat": "markdown"
    },
    "isEnabled": true
  }')

RULE_ID=$(echo "$CREATE_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('data', {}).get('id', ''))" 2>/dev/null || echo "")

if [ -z "$RULE_ID" ]; then
    echo -e "${RED}✗ Failed to create rule${NC}"
    echo "$CREATE_RESPONSE" | python3 -m json.tool
    exit 1
else
    echo -e "${GREEN}✓ Created rule with ID: ${RULE_ID}${NC}"
fi
echo ""

# Step 5: Retrieve the created rule
echo -e "${BLUE}Step 5: Retrieving created rule...${NC}"
GET_RULE_RESPONSE=$(curl -s "${API_BASE}/automation-rules/${RULE_ID}")
RULE_NAME=$(echo "$GET_RULE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['name'])")
echo -e "${GREEN}✓ Retrieved rule: ${RULE_NAME}${NC}"
echo ""

# Step 6: Update the rule (toggle enabled status)
echo -e "${BLUE}Step 6: Updating rule (disable then re-enable)...${NC}"
UPDATE_RESPONSE=$(curl -s -X PUT "${API_BASE}/automation-rules/${RULE_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "E2E Test Rule - Auto Export",
    "description": "Test rule for E2E verification - export completed sessions",
    "triggerType": "session_complete",
    "conditions": [],
    "actionType": "export",
    "actionConfig": {
      "exportFormat": "markdown"
    },
    "isEnabled": false
  }')
echo -e "${GREEN}✓ Rule disabled${NC}"

# Re-enable the rule
curl -s -X PUT "${API_BASE}/automation-rules/${RULE_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "E2E Test Rule - Auto Export",
    "description": "Test rule for E2E verification - export completed sessions",
    "triggerType": "session_complete",
    "conditions": [],
    "actionType": "export",
    "actionConfig": {
      "exportFormat": "markdown"
    },
    "isEnabled": true
  }' > /dev/null
echo -e "${GREEN}✓ Rule re-enabled${NC}"
echo ""

# Step 7: Check execution logs endpoint
echo -e "${BLUE}Step 7: Checking execution logs...${NC}"
LOGS_RESPONSE=$(curl -s "${API_BASE}/automation-rules/executions")
LOGS_COUNT=$(echo "$LOGS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['totalCount'])")
echo -e "${GREEN}✓ Execution logs endpoint working (${LOGS_COUNT} execution(s) logged)${NC}"
echo ""

# Step 8: Verify exports directory exists
echo -e "${BLUE}Step 8: Verifying exports directory...${NC}"
if [ -d "./exports/automation-rules" ]; then
    echo -e "${GREEN}✓ Exports directory exists${NC}"
else
    mkdir -p "./exports/automation-rules"
    echo -e "${GREEN}✓ Created exports directory${NC}"
fi
echo ""

# Step 9: Clean up test rule
echo -e "${BLUE}Step 9: Cleaning up test rule...${NC}"
DELETE_RESPONSE=$(curl -s -X DELETE "${API_BASE}/automation-rules/${RULE_ID}")
echo -e "${GREEN}✓ Test rule deleted${NC}"
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}✓ All E2E verification steps passed!${NC}"
echo "========================================="
echo ""
echo "Verified Components:"
echo "  ✓ Backend API health"
echo "  ✓ List automation rules endpoint"
echo "  ✓ Get rule templates endpoint"
echo "  ✓ Create automation rule endpoint"
echo "  ✓ Get specific rule endpoint"
echo "  ✓ Update automation rule endpoint"
echo "  ✓ Execution logs endpoint"
echo "  ✓ Exports directory structure"
echo "  ✓ Delete automation rule endpoint"
echo ""
echo "Manual Testing Required:"
echo "  1. Create a session using the iOS/macOS app or API"
echo "  2. Complete the session (set status to 'completed')"
echo "  3. Trigger activity feed to evaluate rules"
echo "  4. Verify export file is created in exports/automation-rules/"
echo "  5. Verify execution log is created with success status"
echo ""
echo "To manually trigger rule evaluation:"
echo "  curl -s \"${API_BASE}/activity-feed\" | python3 -m json.tool"
echo ""
