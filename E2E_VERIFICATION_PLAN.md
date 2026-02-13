# End-to-End Verification Plan for macOS App

## Prerequisites

✅ Backend server running on port 9999
✅ ILSMacApp target created in Xcode
✅ macOS app builds successfully
✅ Database has test data (sessions, projects)

## Verification Steps

### 1. Backend Server Setup

```bash
# Terminal 1: Start backend
cd /Users/nick/Desktop/ils-ios
PORT=9999 swift run ILSBackend
```

Expected output:
```
[ NOTICE ] Server starting on http://127.0.0.1:9999
```

Verify backend health:
```bash
curl http://localhost:9999/api/v1/health
```

Expected: `{"status":"ok","version":"1.0.0"}`

### 2. Launch macOS App

```bash
# Option A: From Xcode
# Press Cmd+R to run ILSMacApp scheme

# Option B: From terminal
cd /Users/nick/Desktop/ils-ios/ILSApp
xcodebuild -project ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug/ILSMacApp.app
```

**Expected Result**: macOS app window opens showing sidebar and main content

**Success Criteria**:
- ✅ App launches without crashes
- ✅ Window appears with proper layout
- ✅ Sidebar visible on left side
- ✅ Main content area visible

### 3. Verify Connection Indicator

**Location**: Top of sidebar or main content area

**Steps**:
1. Observe connection status indicator
2. Check it shows "Connected" or green status

**Expected Result**: Connection indicator shows "Connected" with green color

**Success Criteria**:
- ✅ Connection status visible
- ✅ Shows "Connected" state
- ✅ Backend communication established

**Troubleshooting**:
- If "Disconnected": Check backend is running on port 9999
- If error: Check backend logs for connection errors
- If timeout: Verify firewall allows localhost:9999

### 4. Navigate to Sessions

**Steps**:
1. Click "Sessions" in sidebar (or press Cmd+2)
2. Observe sessions list loads

**Expected Result**:
- Sessions list appears showing available sessions
- Sessions grouped by project
- Search bar visible at top

**Success Criteria**:
- ✅ Sessions list loads without errors
- ✅ At least one session visible (or empty state shown)
- ✅ Project grouping works
- ✅ Session metadata visible (name, date, project)

### 5. Create New Session

**Steps**:
1. Click "New Session" button (or press Cmd+N)
2. New session dialog appears
3. Enter session name: "E2E Test Session"
4. Select project (if available) or leave default
5. Click "Create"

**Expected Result**:
- New session created in database
- App navigates to chat view for new session
- Chat view shows empty message history

**Success Criteria**:
- ✅ New session dialog opens
- ✅ Can enter session name
- ✅ Can select project
- ✅ Session creates successfully
- ✅ Navigates to chat view automatically

### 6. Send Message and Verify Streaming Response

**Steps**:
1. In chat view input field, type: "What is 2+2?"
2. Click Send button (or press Cmd+Return)
3. Observe streaming indicator appears
4. Watch message appear in chat history
5. Observe AI response streams in

**Expected Result**:
- Message appears in chat immediately
- Streaming indicator shows (●●● animation)
- AI response appears gradually (streaming)
- Response completes and indicator disappears

**Success Criteria**:
- ✅ Input field accepts text
- ✅ Send button works (or Cmd+Return)
- ✅ User message appears in chat
- ✅ Streaming indicator visible during response
- ✅ AI response streams in character by character
- ✅ Response completes successfully
- ✅ Stop button available during streaming
- ✅ Input field re-enabled after completion

**Troubleshooting**:
- If no response: Check backend logs for Claude API errors
- If immediate error: May be Claude API rate limit or API key issue
- If timeout: Expected for AI service busy (shows timeout message)

### 7. Open Session in New Window (Cmd+N)

**Steps**:
1. With a session selected in sessions list
2. Press Cmd+N (or right-click → "Open in New Window")
3. Observe new window opens

**Expected Result**:
- New window opens showing selected session
- Original window remains open
- New window has full chat interface
- Both windows independent

**Success Criteria**:
- ✅ Cmd+N keyboard shortcut works
- ✅ New window opens
- ✅ Shows correct session content
- ✅ Can interact with chat in new window
- ✅ Original window still functional
- ✅ Windows can be managed independently

### 8. Test Keyboard Shortcuts for Navigation

**Shortcuts to test**:
- Cmd+1: Show Dashboard
- Cmd+2: Show Sessions
- Cmd+3: Show Projects
- Cmd+4: Show System
- Cmd+5: Show Browser
- Cmd+6: Show Settings (or Cmd+7)

**Steps**:
1. Press each keyboard shortcut
2. Verify correct view appears

**Expected Result**: Each shortcut navigates to correct section

**Success Criteria**:
- ✅ Cmd+1 → Dashboard view
- ✅ Cmd+2 → Sessions list
- ✅ Cmd+3 → Projects list
- ✅ Cmd+4 → System monitor
- ✅ Cmd+5 → Browser view
- ✅ Cmd+6/7 → Settings view

### 9. Test Menu Bar Actions

#### File Menu

**Steps**:
1. Click "File" in menu bar
2. Verify menu items:
   - New Session (Cmd+N)
   - Open Session (Cmd+O)
   - Close Window (Cmd+W)
   - Save (Cmd+S)

**Success Criteria**:
- ✅ File menu exists
- ✅ All menu items present
- ✅ Keyboard shortcuts shown
- ✅ "New Session" creates session
- ✅ "Close Window" closes window (Cmd+W)

#### Edit Menu

**Steps**:
1. Click "Edit" in menu bar
2. Verify standard edit items:
   - Undo (Cmd+Z)
   - Redo (Cmd+Shift+Z)
   - Cut (Cmd+X)
   - Copy (Cmd+C)
   - Paste (Cmd+V)
   - Select All (Cmd+A)

**Success Criteria**:
- ✅ Edit menu exists
- ✅ All standard shortcuts present
- ✅ Work in text fields (test in chat input)

#### View Menu

**Steps**:
1. Click "View" in menu bar
2. Verify navigation items:
   - Toggle Sidebar (Cmd+Ctrl+S)
   - Show Dashboard (Cmd+1)
   - Show Sessions (Cmd+2)
   - Show Projects (Cmd+3)
   - Show System (Cmd+4)
   - Show Browser (Cmd+5)
   - Show Settings (Cmd+6/7)

**Success Criteria**:
- ✅ View menu exists
- ✅ All navigation items present
- ✅ Toggle Sidebar works (Cmd+Ctrl+S)
- ✅ Navigation shortcuts work

#### Window Menu

**Steps**:
1. Click "Window" in menu bar
2. Verify window management items:
   - Minimize (Cmd+M)
   - Zoom
   - Bring All to Front
   - [List of open windows]

**Success Criteria**:
- ✅ Window menu exists
- ✅ Minimize works (Cmd+M)
- ✅ Zoom works (maximize window)
- ✅ Open windows listed automatically

### 10. Resize Sidebar and Verify Persistence

**Steps**:
1. Note current sidebar width
2. Drag sidebar divider to resize (make narrower)
3. Resize again (make wider)
4. Quit app completely (Cmd+Q)
5. Relaunch app
6. Check if sidebar width matches last setting

**Expected Result**: Sidebar width persists across app launches

**Success Criteria**:
- ✅ Sidebar divider is draggable
- ✅ Sidebar resizes smoothly
- ✅ Has minimum width constraint (~150pt)
- ✅ Has maximum width constraint (~400pt)
- ✅ Width persists after quit and relaunch

### 11. Verify Window State Restoration

**Steps**:
1. Move main window to different screen position
2. Resize main window (make smaller/larger)
3. Open a session in new window
4. Move and resize the session window
5. Note positions and sizes of all windows
6. Quit app completely (Cmd+Q)
7. Relaunch app
8. Check window positions and sizes

**Expected Result**: All window positions and sizes restored

**Success Criteria**:
- ✅ Main window position restored
- ✅ Main window size restored
- ✅ Session windows reopened (optional, depending on implementation)
- ✅ Session window positions restored (if reopened)

### 12. Additional Features to Verify

#### Touch Bar (if applicable)

**Requirements**: MacBook with Touch Bar hardware

**Steps**:
1. Open chat view
2. Observe Touch Bar
3. Verify buttons appear:
   - Send button
   - Command palette
   - Session info
   - New session

**Success Criteria**:
- ✅ Touch Bar shows custom controls
- ✅ All buttons functional
- ✅ Touch Bar updates with view context

#### Native Notifications

**Steps**:
1. Start a streaming response in chat
2. Switch to another app (make macOS app not frontmost)
3. Wait for response to complete
4. Observe notification

**Expected Result**: macOS notification appears with message preview

**Success Criteria**:
- ✅ Notification permission requested on first launch
- ✅ Notification appears when app in background
- ✅ Notification shows session name and message preview
- ✅ Clicking notification brings app to front
- ✅ No notification when app is frontmost

## Verification Checklist

Copy this checklist and mark items as you verify:

### Core Functionality
- [ ] Backend server running
- [ ] macOS app launches successfully
- [ ] Connection indicator shows "Connected"
- [ ] Sessions list loads
- [ ] Can create new session
- [ ] Can send message
- [ ] Streaming response works
- [ ] Stop button works during streaming

### Multi-Window Support
- [ ] Can open session in new window (Cmd+N)
- [ ] Can open session via context menu
- [ ] Multiple windows work independently
- [ ] Window management works (minimize, zoom, close)

### Navigation
- [ ] Sidebar navigation works (clicks)
- [ ] Cmd+1 through Cmd+6/7 keyboard shortcuts work
- [ ] View menu navigation works

### Menu Bar
- [ ] File menu complete with all actions
- [ ] Edit menu complete with standard shortcuts
- [ ] View menu complete with navigation
- [ ] Window menu complete with window management

### Keyboard Shortcuts
- [ ] Cmd+N: New session / New window
- [ ] Cmd+O: Open session
- [ ] Cmd+W: Close window
- [ ] Cmd+S: Save/export
- [ ] Cmd+K: Command palette
- [ ] Cmd+Return: Send message
- [ ] Cmd+/: Focus search
- [ ] Cmd+Ctrl+S: Toggle sidebar
- [ ] Standard edit shortcuts work

### Polish Features
- [ ] Sidebar resizable with constraints
- [ ] Sidebar width persists
- [ ] Window positions persist
- [ ] Window sizes persist
- [ ] Touch Bar controls (if hardware available)
- [ ] Native notifications work

### Error Handling
- [ ] Handles backend disconnect gracefully
- [ ] Shows error messages for failed operations
- [ ] Recovers from streaming errors
- [ ] Timeout handling works (30s backend timeout)

## Success Criteria

**Pass**: All core functionality items ✅ + 80% of other items ✅
**Fail**: Any core functionality fails OR <60% of other items pass

## Known Limitations

1. **Claude API timeout**: Backend times out after 30s if Claude API is slow (expected)
2. **Touch Bar**: Requires physical MacBook with Touch Bar hardware
3. **Notifications**: Requires user permission on first launch

## Troubleshooting

### App won't launch
- Clean build folder: Product → Clean Build Folder
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*`
- Rebuild: `xcodebuild -project ILSApp.xcodeproj -scheme ILSMacApp build`

### Connection fails
- Check backend running: `lsof -i :9999`
- Check backend health: `curl http://localhost:9999/api/v1/health`
- Verify port 9999 not blocked by firewall

### Streaming doesn't work
- Check backend logs for errors
- Verify Claude API key configured (if needed)
- Try simpler message: "Hello"

### Keyboard shortcuts don't work
- Ensure app is frontmost
- Check for conflicts with system shortcuts
- Try clicking menu items instead (shortcuts shown in menus)

## Reporting Results

After completing verification, report results in this format:

```
## E2E Verification Results

Date: [DATE]
Tester: [NAME]
Build: [BUILD NUMBER/COMMIT HASH]

### Summary
- Total items tested: X
- Passed: X (XX%)
- Failed: X (XX%)
- Not applicable: X

### Failed Items
1. [Item description]: [Reason for failure]
2. ...

### Notes
- [Any additional observations]
- [Performance issues noted]
- [UI/UX feedback]
```

## Next Steps After Verification

1. If PASS: Mark subtask 6-1 as complete
2. If FAIL: Document issues, fix, and re-test
3. Proceed to subtask 6-2 (UI tests creation)
4. Proceed to subtask 6-3 (documentation update) if needed
