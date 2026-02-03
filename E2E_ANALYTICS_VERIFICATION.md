# End-to-End Analytics Verification Guide

## Overview
This document provides step-by-step instructions for verifying the complete analytics infrastructure from iOS app to backend database.

## Prerequisites
- Backend server running (with migrations applied)
- iOS Simulator with iPhone 15
- Xcode installed

## Part 1: Backend API Verification

### Step 1: Stop Existing Server
```bash
# Find and stop any running backend servers
lsof -ti:8080 | xargs kill -9

# Clean database
rm -f ils.sqlite ils.sqlite-shm ils.sqlite-wal
```

### Step 2: Start Fresh Backend Server
```bash
# Run migrations
swift run ILSBackend migrate --auto-migrate

# Start server
swift run ILSBackend &

# Wait for server to be ready
sleep 5
curl http://localhost:8080/health
# Expected: "OK"
```

### Step 3: Verify Analytics API Endpoints

#### Test Event 1: app_launch
```bash
curl -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "app_launch",
        "eventData": "{\"version\":\"1.0.0\",\"os\":\"iOS 17.0\"}",
        "deviceId": "test-device-001"
    }'
```
**Expected**: HTTP 201 Created with JSON response containing `id` and `createdAt`

#### Test Event 2: project_created
```bash
curl -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "project_created",
        "eventData": "{\"project_name\":\"Test Project\"}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }'
```
**Expected**: HTTP 201 Created

#### Test Event 3: chat_started
```bash
curl -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "chat_started",
        "eventData": "{\"chat_mode\":\"assistant\"}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }'
```
**Expected**: HTTP 201 Created

#### Test Event 4: message_sent
```bash
curl -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "message_sent",
        "eventData": "{\"message_length\":42}",
        "deviceId": "test-device-001",
        "sessionId": "session-001"
    }'
```
**Expected**: HTTP 201 Created

#### Test Event 5: crash
```bash
curl -X POST http://localhost:8080/api/v1/analytics/events \
    -H "Content-Type: application/json" \
    -d '{
        "eventName": "crash",
        "eventData": "{\"type\":\"NSException\",\"reason\":\"Test crash\",\"stack_trace\":\"line1\\nline2\\nline3\"}",
        "deviceId": "test-device-001"
    }'
```
**Expected**: HTTP 201 Created

### Step 4: Verify Database Storage

Use DB Browser for SQLite or the following Swift command to query the database:

```bash
swift run ILSBackend eval "
import Fluent
import ILSBackend

let events = try await AnalyticsEventModel.query(on: app.db).all()
print(\"Total events: \\(events.count)\")
for event in events {
    print(\"- \\(event.eventName): \\(event.deviceId ?? \"no device\")\")
}
"
```

**Expected**: 5 events in database with correct event names and device IDs

## Part 2: iOS App Integration Verification

### Step 1: Build and Launch iOS App

```bash
# Open Xcode project
open ILSApp/ILSApp.xcodeproj

# Or build from command line
xcodebuild -project ILSApp/ILSApp.xcodeproj \
    -scheme ILSApp \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    build
```

### Step 2: Verify Analytics Enabled (Default State)

1. Launch the app in simulator
2. Navigate to **Settings**
3. Scroll to **Privacy** section
4. Verify **Analytics** toggle is **ON** (enabled by default)

### Step 3: Perform User Journey with Analytics Enabled

Execute the following steps in the iOS app:

1. **Launch App**
   - Opens to main screen
   - AnalyticsService should track `app_launch` event

2. **Create Project**
   - Tap "+" to create new project
   - Enter project name: "E2E Test Project"
   - Tap Create
   - AnalyticsService should track `project_created` event

3. **Start Chat**
   - Tap on the newly created project
   - Start a new chat session
   - AnalyticsService should track `chat_started` event

4. **Send Message**
   - Type a message: "Hello, this is a test message"
   - Send the message
   - AnalyticsService should track `message_sent` event

5. **Wait for Flush**
   - Events are batched and sent every 60 seconds
   - Or app going to background triggers flush
   - Press Home button (Cmd+Shift+H) to trigger flush

### Step 4: Verify Events in Backend

Query the backend database to confirm events were received:

```bash
# Check total event count (should be > 4)
# Check for device ID matching your iOS simulator
# Verify event names: app_launch, project_created, chat_started, message_sent
```

**Expected Results**:
- At least 4 new events in database
- All events have same `deviceId` (iOS device identifier)
- Events have correct `eventName` values
- Events with sessions have `sessionId` populated
- `eventData` contains JSON strings with event-specific data

### Step 5: Verify Privacy Controls - Disable Analytics

1. Open **Settings** in iOS app
2. Navigate to **Privacy** section
3. Toggle **Analytics** to **OFF**
4. Exit Settings

### Step 6: Perform User Journey with Analytics Disabled

Repeat the same user journey:

1. Create another project: "Privacy Test Project"
2. Start chat in the new project
3. Send a message
4. Press Home button to ensure flush is attempted

### Step 7: Verify No New Events Captured

Query backend database again:

**Expected Results**:
- Event count should be **SAME** as before (no new events)
- No events with project name "Privacy Test Project"
- Analytics opt-out is properly respected

## Part 3: Crash Reporting Verification

### Step 1: Enable Test Crash Button (If Not Already Added)

The crash button should already be in Settings from subtask-2-3.

### Step 2: Trigger Test Crash

1. Open **Settings**
2. Tap **Test Crash** button
3. App should crash immediately

### Step 3: Restart App

1. Launch app again from Xcode or Simulator
2. CrashReporter checks for pending crash reports on startup
3. If found, sends crash report to analytics backend

### Step 4: Verify Crash Report in Backend

Query for crash events:

**Expected Results**:
- New event with `eventName = "crash"`
- `eventData` contains crash details:
  - `type`: Exception type
  - `name`: Exception name
  - `reason`: Crash reason
  - `stack_trace`: Call stack
  - `timestamp`: When crash occurred
- Stack trace is properly formatted
- No sensitive user data in crash report

## Part 4: Privacy Validation

### Step 1: Verify No PII Collection

Review all analytics events in database and verify:

- ✅ No email addresses
- ✅ No phone numbers
- ✅ No physical addresses
- ✅ No user names (real names)
- ✅ No passwords or credentials
- ✅ Only anonymous device IDs
- ✅ Only aggregate/anonymous usage data

### Step 2: Verify Event Data Sanitization

Check that `eventData` only contains:
- Event type and category
- Anonymized counts/metrics
- App version and OS version
- Generic error types (no sensitive error messages)
- Session IDs and device IDs (anonymous)

## Success Criteria

All of the following must be true:

- [x] Backend analytics API accepts events (HTTP 201)
- [x] Events are persisted to SQLite database
- [x] iOS app tracks key user journeys
- [x] Analytics toggle in Settings works
- [x] Disabling analytics prevents event tracking
- [x] Events are batched and sent periodically
- [x] Crash reports are captured and sent to backend
- [x] No PII is collected in any analytics events
- [x] Device IDs are anonymous (UUID)
- [x] All timestamps are accurate
- [x] Session tracking works correctly

## Troubleshooting

### Server Returns 404 for Analytics Endpoints

**Cause**: Server started before AnalyticsController was added to routes

**Solution**:
```bash
# Stop server
lsof -ti:8080 | xargs kill -9

# Rebuild and restart
swift build
swift run ILSBackend
```

### iOS Events Not Appearing in Database

**Possible Causes**:
1. Analytics disabled in Settings
2. Backend server not running
3. Incorrect backend URL in APIClient
4. Events not flushed yet (wait 60 seconds or background app)

**Solutions**:
- Verify analytics toggle is ON
- Check backend server is running on localhost:8080
- Trigger flush by backgrounding the app

### Crash Reports Not Sent

**Possible Causes**:
1. Crash happened with analytics disabled
2. App didn't restart after crash
3. Network error prevented upload

**Solutions**:
- Ensure analytics is enabled when crash occurs
- Fully restart app after crash
- Check CrashReporter logs in Console.app

## Verification Checklist

- [ ] Backend builds successfully (`swift build`)
- [ ] Migrations run successfully
- [ ] Server starts on port 8080
- [ ] Health endpoint returns "OK"
- [ ] Analytics API accepts all event types
- [ ] Database contains analytics_events table
- [ ] Events are persisted with correct schema
- [ ] iOS app builds successfully
- [ ] iOS app launches in simulator
- [ ] Settings shows Analytics toggle
- [ ] Toggle defaults to enabled (privacy-respecting default)
- [ ] User journey with analytics enabled captures events
- [ ] Events appear in backend database
- [ ] Device ID is consistent across events
- [ ] Session ID links related events
- [ ] Disabling analytics prevents new events
- [ ] Test crash triggers crash report
- [ ] Crash report sent to backend on next launch
- [ ] No PII in any event data
- [ ] All sensitive data sanitized

## Notes

- This verification tests the complete analytics pipeline
- Run this verification after any changes to analytics infrastructure
- Document any failures or unexpected behavior
- Keep backend server running during iOS app testing
- Use Console.app to view detailed logs from iOS app (subsystem: com.ilsapp.analytics)
