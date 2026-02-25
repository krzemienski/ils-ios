# Domain Pitfalls: Comprehensive Functional Validation (iOS & iPad)

**Domain:** Adding screenshot-evidence functional validation workflows to an existing SwiftUI iOS/iPad/macOS app
**Project:** ILS iOS/macOS -- v3.5 Comprehensive Functional Validation
**Researched:** 2026-02-25
**Confidence:** HIGH -- derived from direct code inspection, project memory of 5 prior milestones, and verified simulator behavior

---

## Critical Pitfalls

Mistakes that produce false PASS verdicts, waste entire validation phases, or require re-running validation from scratch.

---

### Pitfall 1: Stale DerivedData Binary Silently Installed -- Screenshots Validate Wrong Build

**What goes wrong:**
`xcrun simctl install` installs whatever `.app` binary you point it at. With 40+ `ILSApp-*` directories in `~/Library/Developer/Xcode/DerivedData/`, a naive `find ... | head -1` grabs a stale binary from days or weeks ago. The app launches, screens render, screenshots look normal -- but the build does not contain the latest code changes. Every screenshot captured validates the wrong binary. The entire validation session produces false evidence.

**This already happened.** Quick-5 audit (2026-02-25) discovered that deep link fixes were not present because the install script grabbed a stale DerivedData directory. The fix was applied but the wrong binary was installed, making the fix appear to not work.

**Why it happens:**
- DerivedData directories accumulate (40+ found in this project) and are never cleaned automatically
- `find` returns results in filesystem order, not modification time
- The `.app` bundle timestamp is not checked against the latest `xcodebuild` completion time
- Simulator does not warn when installing an older binary over a newer one
- The app UI looks the same across builds unless the specific changed screen is examined

**Consequences:**
- Every screenshot from the session is invalid evidence
- PASS verdicts are false positives -- the fix was never actually validated
- The validation phase must be re-run entirely after discovering the mistake
- If not discovered, the milestone ships with unvalidated claims

**Prevention:**
1. **Always build immediately before install.** Never separate build and install into different phases or sessions.
2. **Use modification-time ordering to find the newest binary:**
   ```bash
   APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 -print0 2>/dev/null | xargs -0 ls -dt | head -1)
   ```
3. **Verify binary timestamp matches build time:**
   ```bash
   stat -f "%m %Sm" "$APP_PATH/ILSApp"  # Must be within seconds of build completion
   ```
4. **Uninstall before install** to prevent cached state from masking binary differences:
   ```bash
   xcrun simctl uninstall $UDID com.ils.app && xcrun simctl install $UDID "$APP_PATH"
   ```
5. **Add a build hash or timestamp to the app's About/Settings screen** so screenshots contain machine-verifiable evidence of which build is running.

**Detection:**
- Screenshot shows old UI state that should have been changed by recent code
- Deep link that was "fixed" does not work in simulator
- Feature that was "added" is not visible

**Phase to address:** Phase 0 (validation infrastructure setup) -- build the install script with these guards before any validation begins.

---

### Pitfall 2: Screenshot Captured Before SwiftUI View Finishes Rendering -- Blank or Partial Content

**What goes wrong:**
`xcrun simctl io $UDID screenshot /tmp/screenshot.png` captures the screen at the exact moment it is called. SwiftUI views rendered via `.task {}` or `onAppear` fetch data asynchronously -- the view shows a loading state (or empty content) for 0.5-3 seconds after navigation. If the screenshot is taken before data loads, it captures a blank screen or a loading spinner, which either:
- Produces a false FAIL (the screen works but was not ready)
- Produces a misleading PASS (the loading state looks like real content at a glance)

This is worse on iPad, where `NavigationSplitView` performs column animations that take 300-500ms to settle, and detail views may render blank until the sidebar selection propagates.

**Why it happens:**
- `xcrun simctl io screenshot` has no "wait for idle" flag
- SwiftUI has no public API to signal "rendering complete"
- Network calls to the backend (localhost:9999) add 100-500ms latency even locally
- iPad `NavigationSplitView` column transitions animate asynchronously
- Deep link navigation triggers multiple `onChange` handlers in sequence, each potentially causing a re-render

**Consequences:**
- Screenshots show loading spinners instead of actual content -- must be re-taken
- Screenshots show partially loaded lists (20 of 50 skills) -- misleading evidence
- iPad screenshots show sidebar-only with blank detail pane -- false FAIL
- Blank screenshots waste time in evidence review and erode trust in the validation process

**Prevention:**
1. **Fixed delay after every navigation action before screenshot:**
   ```bash
   # Navigate via deep link
   xcrun simctl openurl $UDID "ils://skills"
   # Wait for navigation + data load + render
   sleep 3
   # Now capture
   xcrun simctl io $UDID screenshot /tmp/screenshot.png
   ```
2. **Use `idb_describe` to verify content is present before capturing.** Check the accessibility tree for expected elements (e.g., "Search skills..." placeholder text, or a specific skill name).
3. **For iPad:** Add an extra 1-second delay after NavigationSplitView transitions because column animations take longer than stack transitions.
4. **For data-dependent screens** (Home stats, Browser lists, System Monitor), wait for the loading indicator to disappear or for a known data element to appear in the accessibility tree.
5. **Capture two screenshots 2 seconds apart** and compare -- if they differ significantly, the first one was premature.

**Detection:**
- Screenshot shows "Loading..." or a spinner
- Screenshot shows empty list where data should be
- iPad screenshot shows sidebar but blank detail area
- Screenshot differs from what the reviewer sees when they manually open the same screen

**Phase to address:** Phase 0 (validation infrastructure) -- establish timing protocol before any screenshots are captured.

---

### Pitfall 3: iPhone Coordinates Used on iPad -- idb_tap Hits Wrong Element

**What goes wrong:**
The project has well-documented iPhone 16 Pro Max coordinates (440x956 logical points) baked into MEMORY.md and used in prior validation sessions. When validation extends to iPad Pro 13-inch (1032x1376 logical points), reusing iPhone coordinates hits completely wrong screen locations. A tap at iPhone's sidebar item y=198 hits a different element on iPad's always-visible NavigationSplitView sidebar. The hamburger button (x=20, y=50 on iPhone) does not exist on iPad at all -- the sidebar is persistent.

**Why it happens:**
- iPad logical resolution is 2.3x wider than iPhone (1032 vs 440 points)
- iPad uses `NavigationSplitView` (persistent sidebar) while iPhone uses overlay sidebar (sheet)
- Coordinates from prior sessions are copy-pasted without adjusting for device
- `idb_tap` uses logical points, not percentages -- coordinates are device-specific
- The accessibility tree structure differs between iPhone and iPad layouts due to the `isRegularWidth` branch in SidebarRootView

**Consequences:**
- Taps miss intended targets -- buttons not pressed, navigation not triggered
- Taps hit unintended targets -- wrong screen opened, wrong action performed
- Automation scripts designed for iPhone silently fail on iPad
- Screenshots captured after failed taps show unexpected screens -- false evidence

**Prevention:**
1. **Always run `idb_describe` fresh on each device before any tap sequence.** Never reuse coordinates across devices.
   ```bash
   idb describe --udid $IPAD_UDID operation:all 2>/dev/null | head -100
   ```
2. **Maintain separate coordinate maps for iPhone and iPad.** Document them in the validation plan with device UDID labels.
3. **Prefer deep links over taps for navigation** -- `xcrun simctl openurl $UDID "ils://settings"` works identically on both devices.
4. **For iPad-specific interactions** (sidebar selection in NavigationSplitView), the sidebar is always visible -- tap directly on sidebar items without needing an edge swipe first.
5. **Document iPad quirk:** On iPad, the sidebar column is 260-380pt wide (from `navigationSplitViewColumnWidth`), so sidebar item taps need x-coordinates in the 20-300 range, while detail content starts at x=300+.

**Detection:**
- Tap produces no visible change on iPad
- Wrong screen appears after tap sequence
- Edge swipe gesture (used to open iPhone sidebar) does nothing on iPad because sidebar is already persistent

**Phase to address:** Phase 1 (iPhone validation) and Phase 2 (iPad validation) -- establish per-device coordinate discovery as the first step of each device's validation run.

---

### Pitfall 4: iPad NavigationSplitView Layout Not Validated -- Only Detail Pane Checked

**What goes wrong:**
On iPad, the app renders a `NavigationSplitView` with a persistent sidebar column (260-380pt wide) alongside the detail content. Validation that only screenshots the full screen and checks "does the content look right?" misses iPad-specific layout issues:
- Sidebar overlapping detail content due to incorrect `navigationSplitViewColumnWidth`
- Detail content not filling the remaining width (leaving white/black bands)
- Sidebar selection highlight not matching `activeScreen` state
- Column visibility toggling (`columnVisibility: .all` vs `.detailOnly`) not working
- Landscape vs portrait sidebar behavior differences

This is the **number one iPad-specific pitfall** because the iPhone layout (ZStack overlay sidebar) is completely different code from the iPad layout (`NavigationSplitView`). Testing iPhone does not validate iPad layout at all.

**Why it happens:**
- SidebarRootView.body branches on `isRegularWidth` (line 137):
  ```swift
  if isRegularWidth { iPadLayout } else { iPhoneLayout }
  ```
  These are entirely different view hierarchies. iPhone validation exercises `iPhoneLayout` but never touches `iPadLayout`.
- The `iPadLayout` uses `NavigationSplitView(columnVisibility:)` which has documented SwiftUI bugs around column width and visibility
- `SidebarView` receives `isSidebarOpen: .constant(true)` on iPad (line 224), which may suppress open/close animations that should be tested

**Consequences:**
- iPad ships with layout issues invisible on iPhone
- Sidebar column may render too wide or too narrow on specific iPad models
- Column visibility toggle may not work, leaving users unable to hide sidebar for full-screen content
- Evidence screenshots show "content looks correct" but miss structural layout problems

**Prevention:**
1. **iPad validation must explicitly check:**
   - Sidebar visible alongside detail on launch (not overlaying)
   - Sidebar width is proportional (not full-screen or sliver)
   - Detail content fills remaining space without white bands
   - Selecting a sidebar item updates the detail pane
   - Column visibility can be toggled (if exposed in UI)
2. **Take iPad screenshots in both orientations** -- portrait and landscape, because NavigationSplitView column behavior changes
3. **Check iPad mini separately** (744x1133 points) -- it may fall to compact width class in portrait multitasking, triggering the iPhone layout path instead of iPad layout
4. **Verify sidebar selection state** -- after navigating to Settings via deep link, the sidebar should highlight Settings (not Home)

**Detection:**
- iPad screenshot shows sidebar and detail, but sidebar highlight does not match the displayed screen
- iPad landscape shows different sidebar width than portrait
- iPad mini in Split View shows iPhone-style overlay sidebar instead of persistent sidebar

**Phase to address:** Phase 2 (iPad validation) -- this is the primary purpose of the iPad validation phase.

---

### Pitfall 5: Fresh Install Clears UserDefaults -- Validation Starts With Broken State

**What goes wrong:**
`xcrun simctl uninstall` + `xcrun simctl install` (recommended in Pitfall 1 to avoid stale binaries) **also clears all UserDefaults**. This means:
- `serverURL` resets to default `localhost:9999` -- fine if backend is local, but breaks if previously configured to a remote host
- `hasConnectedBefore` resets to `false` -- triggers the onboarding flow instead of the main app
- `activeScreenKey` in `@SceneStorage` resets -- app starts at Home instead of the last screen
- `colorSchemePreference` in `@AppStorage` resets to `"dark"` -- may differ from expected
- `activeHostName` resets to `nil` -- host indicator in sidebar disappears

If validation expects to see a configured app state (sessions loaded, specific host connected), a fresh install produces an unconfigured app that shows onboarding or connection errors.

**Why it happens:**
- `xcrun simctl uninstall` removes the app sandbox including UserDefaults plist
- `@AppStorage` and `@SceneStorage` are backed by UserDefaults/scene state respectively
- `ConnectionManager.init()` reads `UserDefaults.standard.string(forKey: "serverURL")` -- after fresh install this is nil, falling back to building URL from defaults
- Previous milestones documented this: "Fresh install clears UserDefaults (stale Cloudflare tunnel URL)"

**Consequences:**
- First screenshot shows onboarding sheet instead of the expected Home screen
- Validation session wastes time dismissing onboarding and reconfiguring
- If not handled, screenshots of "unconfigured" app are captured as evidence -- false representation
- @SceneStorage restoration of `activeScreenKey` and `lastChatSessionId` is lost

**Prevention:**
1. **After fresh install, always perform a setup sequence before validation:**
   ```bash
   # Launch app
   xcrun simctl launch $UDID com.ils.app
   sleep 3
   # Configure via deep link or verify backend auto-connects
   curl -s http://localhost:9999/health  # Verify backend is up
   sleep 2
   # Now app should auto-connect and show Home
   ```
2. **For validation that requires specific state** (e.g., chat history, host profiles), use the backend's existing data rather than depending on UserDefaults. The app fetches sessions from the API, not from local storage.
3. **Do NOT uninstall before every screenshot** -- only uninstall once at the start of a validation phase to ensure the correct binary, then leave installed for the remainder.
4. **Consider `xcrun simctl install` WITHOUT prior uninstall** -- iOS will upgrade the app in-place, preserving UserDefaults. This is safer for state-dependent validation but risks stale cached views.

**Detection:**
- Screenshot shows ServerSetupSheet / onboarding instead of Home
- No sessions visible despite backend having 22,000+ sessions
- Sidebar shows no host name indicator

**Phase to address:** Phase 0 (validation infrastructure) -- define the install strategy (fresh vs upgrade) and post-install setup sequence.

---

### Pitfall 6: Validating Against Wrong Backend Binary -- Old Backend Returns Different Data Format

**What goes wrong:**
Two backend binaries exist on this machine:
- **OLD:** `/Users/nick/ils/ILSBackend/` -- returns raw Claude Code data (bare arrays, snake_case)
- **CURRENT:** `/Users/nick/Desktop/ils-ios/` -- returns proper `APIResponse` wrappers (camelCase)

If the old backend is running on port 9999 when validation starts, the app connects successfully (port is the same), loads data, and even renders screens -- but with malformed data. Session counts may differ, field names may be wrong, and some views may show "0 items" because JSON decoding partially fails silently (optional fields decode as nil).

**This has happened before.** MEMORY.md documents: "OLD backend returns raw data. ALWAYS use `/Users/nick/Desktop/ils-ios/`"

**Why it happens:**
- Both backends listen on the same port (9999)
- The app does not validate the backend version/identity on connection
- `curl http://localhost:9999/health` returns 200 from either backend
- Previous sessions may have left the old backend running
- `swift run ILSBackend` from the wrong directory is an easy mistake

**Consequences:**
- Screens that depend on `APIResponse.data` wrapper get empty content
- Home screen stats may show wrong numbers (22K sessions vs 41 sessions)
- Chat may fail to stream (different SSE format)
- Screenshots show partially-populated screens that could be misread as PASS or FAIL

**Prevention:**
1. **At the start of every validation session, verify the backend binary path:**
   ```bash
   lsof -i :9999 -P -n | grep LISTEN
   # Output MUST contain "ils-ios" in the path, NOT "ils/ILSBackend"
   ```
2. **Kill any existing backend before starting a new one:**
   ```bash
   lsof -ti :9999 | xargs kill -9 2>/dev/null
   PORT=9999 swift run ILSBackend  # Run from /Users/nick/Desktop/ils-ios/
   ```
3. **Validate response format, not just connectivity:**
   ```bash
   curl -s http://localhost:9999/api/v1/sessions | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Format: {\"APIResponse\" if \"data\" in d else \"RAW\"}, Sessions: {len(d.get(\"data\",[]))}')"
   ```
4. **Include a backend version check in the validation infrastructure script.**

**Detection:**
- Home screen shows surprisingly low session count (41 instead of 22,000+)
- API responses are bare arrays instead of `{"data": [...], "metadata": {...}}`
- `lsof -i :9999` shows binary path containing `ils/ILSBackend` instead of `ils-ios`

**Phase to address:** Phase 0 (validation infrastructure) -- backend verification is the very first step.

---

## Moderate Pitfalls

---

### Pitfall 7: iPad Deep Links Navigate But Sidebar Selection Does Not Update

**What goes wrong:**
On iPhone, deep links set `appState.navigationIntent` which triggers `onChange` in SidebarRootView, updating `activeScreen` and closing the sidebar. On iPad, the sidebar is persistent via `NavigationSplitView` -- when a deep link navigates to a new screen, the detail pane updates correctly, but the sidebar's visual selection indicator may not highlight the correct item because `NavigationSplitView` manages its own selection state separately from `@State activeScreen`.

**Why it happens:**
- `SidebarView` receives `activeScreen: $activeScreen` as a binding
- On iPad, `NavigationSplitView` has its own internal selection tracking for the sidebar column
- When `activeScreen` changes programmatically (via deep link), the `NavigationSplitView` may not sync its internal selection highlight
- This is a known SwiftUI limitation with `NavigationSplitView` -- programmatic changes to the sidebar binding do not always update the visual selection appearance

**How to avoid:**
- After each deep link test on iPad, verify BOTH the detail pane content AND the sidebar highlight
- If sidebar highlight is wrong, this is a real bug to fix (not a test artifact)
- Use `idb_describe` to check the accessibility state of sidebar items (selected vs not selected)

**Warning signs:**
- iPad screenshot shows Settings in the detail pane but Home is highlighted in the sidebar
- Sidebar highlight lags behind by one navigation event

**Phase to address:** Phase 2 (iPad validation) -- check sidebar selection after every deep link navigation.

---

### Pitfall 8: Simulator State Leaks Between Validation Runs -- Cached Screens Show Old Data

**What goes wrong:**
iOS Simulator preserves app state across `xcrun simctl launch` calls (unlike fresh installs). This means:
- `@SceneStorage("activeScreenKey")` restores the last screen from the previous run
- `NSCache`-backed API responses may still be warm
- SSEClient connections from a previous run may interfere with new connections
- In-memory ViewModel state is gone (fresh launch), but UserDefaults/Keychain persists

If validation Phase 1 leaves the app on the Settings screen, Phase 2's first screenshot shows Settings (from SceneStorage restoration) instead of Home. This can either produce a false FAIL ("why is Settings showing instead of Home?") or mask a Home screen bug if the validator does not notice.

**How to avoid:**
- At the start of each validation phase, navigate to a known starting point:
  ```bash
  xcrun simctl openurl $UDID "ils://home"
  sleep 2
  ```
- Document that screenshots numbered 01 are always "initial state after launch and navigation to home"
- If testing fresh-launch behavior specifically, terminate the app first:
  ```bash
  xcrun simctl terminate $UDID com.ils.app
  xcrun simctl launch $UDID com.ils.app
  sleep 3
  ```

**Warning signs:**
- First screenshot shows a screen the validator did not navigate to
- Data counts differ between sequential runs without backend restart

**Phase to address:** Phase 1 and Phase 2 -- define a clean starting state protocol for each phase.

---

### Pitfall 9: iPad Multitasking / Split View Triggers Compact Size Class -- App Switches to iPhone Layout

**What goes wrong:**
iPad in multitasking (Slide Over, 1/3 Split View) downgrades the horizontal size class to `.compact`. SidebarRootView's `isRegularWidth` check (line 119-121) returns `false`, causing the app to render the iPhone overlay-sidebar layout instead of the iPad NavigationSplitView layout. If validation inadvertently activates multitasking (another app slides over, or the simulator window is resized), the screenshots show the iPhone layout on an iPad -- which either:
- Produces a false PASS (iPhone layout works, iPad layout was never tested)
- Produces a confusing FAIL (layout looks wrong for iPad)

**How to avoid:**
- Ensure iPad simulator runs in full-screen mode (not Slide Over or Split View)
- Verify size class before capturing screenshots:
  ```bash
  # Check accessibility tree for NavigationSplitView presence (iPad) vs ZStack (iPhone)
  idb describe --udid $IPAD_UDID operation:all 2>/dev/null | grep -i "split"
  ```
- If deliberately testing multitasking scenarios, document that compact layout is expected
- Consider testing iPad mini in portrait -- its 744pt width is still regular class at full screen, but verify

**Warning signs:**
- iPad screenshot shows hamburger menu button (iPhone-only) instead of persistent sidebar
- iPad screenshot shows overlay sidebar instead of NavigationSplitView column

**Phase to address:** Phase 2 (iPad validation) -- verify full-screen mode before starting.

---

### Pitfall 10: Deep Link UUID Case Sensitivity -- Uppercase UUIDs Fail Silently

**What goes wrong:**
Deep links like `ils://sessions/{uuid}` require **lowercase** UUIDs. Uppercase UUIDs (the default format from `UUID().uuidString` in Swift) fail to match -- the URL handler receives the path, attempts lookup, finds no match, and silently falls through to the default screen (Home). The validation shows Home screen instead of the expected session.

**This is a known project pitfall** documented in CLAUDE.md: "Deep link UUIDs must be LOWERCASE -- uppercase causes failures."

**How to avoid:**
- Always lowercase UUIDs in deep link URLs:
  ```bash
  SESSION_ID=$(echo "A1B2C3D4-E5F6-..." | tr '[:upper:]' '[:lower:]')
  xcrun simctl openurl $UDID "ils://sessions/$SESSION_ID"
  ```
- In automation scripts, pipe UUID through `tr '[:upper:]' '[:lower:]'` or use `${UUID,,}` bash lowercasing
- Verify the deep link handler in `ILSAppApp.swift handleURL()` does case-insensitive UUID comparison (if not, fix it)

**Warning signs:**
- Deep link navigates to Home instead of the expected session/detail screen
- Some deep links work (non-UUID routes like `ils://settings`) but session links fail

**Phase to address:** Phase 1 (deep link testing) -- include both upper and lowercase UUID tests.

---

### Pitfall 11: RalphMobile Reinstalls Itself During Build -- Occupies Simulator

**What goes wrong:**
RalphMobile (a separate app on the same machine) reinstalls itself during its build/install cycle. If a RalphMobile build triggers while ILS validation is running on the same simulator, RalphMobile's install may interfere with the simulator state, or RalphMobile's Xcode build may grab the simulator for its own use.

**This is a known project hazard** documented in MEMORY.md: "RalphMobile reinstalls itself during build/install -- uninstall AFTER each build."

**How to avoid:**
- **Use the dedicated iPhone simulator** (UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`) only for ILS validation
- **Use the dedicated iPad simulator** (UDID: `C074375B-2CB2-4F95-A55C-972F2FF35041` -- "iPad Pro 13 ILS") for iPad validation
- Do not run RalphMobile builds during validation sessions
- If RalphMobile accidentally installs on the ILS simulator, uninstall it:
  ```bash
  xcrun simctl uninstall $UDID com.ralph.mobile  # or whatever its bundle ID is
  ```

**Warning signs:**
- Simulator shows RalphMobile instead of ILS after a build
- Unexpected app appears on simulator home screen
- Build times spike because multiple Xcode builds compete

**Phase to address:** Every phase -- document "do not run other builds during validation" as a session prerequisite.

---

### Pitfall 12: Evidence Screenshots Not Machine-Verifiable -- Rely on Human Visual Inspection

**What goes wrong:**
Screenshots are `.png` files with no metadata about what they are supposed to show. When the dual-agent confirmation step reviews 50+ screenshots, the reviewer must:
1. Open each screenshot
2. Visually identify which screen it shows
3. Compare against expected criteria
4. Render a PASS/FAIL judgment

This is error-prone. The reviewer may conflate screenshots, miss subtle issues (wrong session count, missing badge), or rubber-stamp PASS on screenshots that are actually from a different screen.

**How to avoid:**
1. **Structured naming convention:**
   ```
   {device}-{nn}-{screen}-{state}.png
   iphone-01-home-loaded.png
   iphone-02-sidebar-open.png
   ipad-01-home-splitview.png
   ipad-07-settings-scrolled-bottom.png
   ```
2. **Companion metadata file** for each screenshot:
   ```json
   {"file": "iphone-03-skills.png", "screen": "Browser > Skills", "expected": "50+ skills listed, Active badges visible, search bar present", "deep_link": "ils://skills", "timestamp": "2026-02-25T14:30:00Z"}
   ```
3. **Use `idb_describe` output as machine-verifiable evidence** alongside screenshots. The accessibility tree text can be diffed and checked programmatically:
   ```bash
   idb describe --udid $UDID operation:all > /tmp/evidence/iphone-03-skills-accessibility.txt
   grep -c "Active" /tmp/evidence/iphone-03-skills-accessibility.txt  # Should be > 0
   ```
4. **Capture backend state alongside UI screenshots:**
   ```bash
   curl -s http://localhost:9999/api/v1/skills | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Skills count: {len(d[\"data\"])}')" > /tmp/evidence/iphone-03-skills-backend.txt
   ```

**Warning signs:**
- Reviewer asks "which screen is this?" about an evidence file
- Two screenshots from different devices/screens have similar names
- Reviewer approves a screenshot without noticing the data count is wrong

**Phase to address:** Phase 0 (validation infrastructure) -- establish naming and metadata conventions before any screenshots are captured.

---

## Minor Pitfalls

---

### Pitfall 13: Simulator Clock and Status Bar Clutter Evidence Screenshots

**What goes wrong:**
Simulator status bar shows "9:41 AM" by default but may show different times after prolonged sessions, carrier name "Carrier", battery indicator, etc. These are irrelevant to validation but can confuse reviewers or make screenshots look inconsistent across a validation session.

**How to avoid:**
Override simulator status bar before capturing evidence:
```bash
xcrun simctl status_bar $UDID override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3
```

**Phase to address:** Phase 0 (validation infrastructure) -- add to setup script.

---

### Pitfall 14: iPad Landscape vs Portrait -- Different Sidebar Column Width

**What goes wrong:**
`NavigationSplitView` adjusts sidebar column width based on available space. The `navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)` constraint means:
- Portrait (1032pt width): sidebar ~300pt, detail ~732pt
- Landscape (1376pt width): sidebar ~300-380pt, detail ~996-1076pt

Screenshots taken in only one orientation miss layout issues in the other. A view that fits in 732pt detail width may overflow or look sparse in 996pt detail width.

**How to avoid:**
- Capture key screens in both portrait and landscape on iPad
- At minimum: Home, Settings, Browser (Skills tab), Chat in both orientations
- Rotate simulator:
  ```bash
  # Device > Rotate Left in Simulator, or use Hardware menu
  # Or trigger via simctl (limited support)
  ```

**Phase to address:** Phase 2 (iPad validation) -- include orientation testing for critical screens.

---

### Pitfall 15: Auto-Build Hook Fires During Validation -- No Swift Edits Expected

**What goes wrong:**
The auto-build hook triggers on every `.swift` file edit. During pure validation phases (no code changes), this should never fire. But if a fix is applied mid-validation (the "fix-as-you-go" approach), the hook fires, potentially taking 15-45 seconds and blocking the session. If the fix introduces a build error, the hook surfaces `BUILD FAILED` and the validation must pause for a fix cycle.

**How to avoid:**
- If doing fix-as-you-go, expect build pauses after every fix
- Batch related fixes before rebuilding rather than editing one file at a time
- After a fix cycle: rebuild, reinstall (using Pitfall 1's safe install), re-navigate to the screen, re-capture the screenshot
- Never capture a screenshot between a fix and a rebuild -- the simulator still has the old binary

**Phase to address:** All fix-as-you-go phases -- document the fix-rebuild-reinstall-recapture cycle.

---

### Pitfall 16: idb_tap Cannot Hit SwiftUI Toolbar Buttons -- Known Limitation

**What goes wrong:**
SwiftUI toolbar buttons (hamburger menu, navigation bar items) are not reliably tappable via `idb_tap`. The accessibility tree shows them, but taps at their coordinates often miss. This is documented in MEMORY.md: "idb_tap CANNOT hit SwiftUI toolbar buttons."

**How to avoid:**
- **Open sidebar on iPhone:** Use edge swipe instead:
  ```bash
  idb ui swipe --udid $UDID 5 500 300 500 --duration 0.3
  ```
- **Navigate between screens:** Use deep links:
  ```bash
  xcrun simctl openurl $UDID "ils://settings"
  ```
- **For toolbar actions that have no deep link equivalent** (e.g., chat menu button), use the coordinate approach from MEMORY.md but verify with `idb_describe` first

**Phase to address:** Phase 1 and Phase 2 -- prefer deep links over taps for all navigation.

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Phase 0: Validation Infrastructure | Stale binary install (P1), wrong backend (P6) | Build install script with timestamp verification and backend path check |
| Phase 1: iPhone Validation | Screenshot timing (P2), deep link UUID case (P10), toolbar taps (P16) | 3-second delays, lowercase UUIDs, prefer deep links |
| Phase 2: iPad Validation | Wrong coordinates (P3), NavigationSplitView layout (P4), multitasking size class (P9), sidebar selection (P7) | Fresh `idb_describe`, verify split view, full-screen mode, check both sidebar and detail |
| Phase 3: Deep Link Testing | UUID case (P10), sidebar not updating (P7), fresh install state (P5) | Test both cases, verify sidebar highlight, consistent starting state |
| Phase 4: Fix-as-you-go | Auto-build hook (P15), stale binary after fix (P1), evidence naming (P12) | Full fix-rebuild-install-capture cycle, structured naming |
| Phase 5: Evidence Review | Non-machine-verifiable screenshots (P12), false positives from timing (P2) | Metadata files, accessibility tree dumps, backend state capture |

---

## "Looks Validated But Isn't" Checklist

- [ ] **Binary freshness:** `stat` the installed `.app` binary -- timestamp must match the latest `xcodebuild` completion time
- [ ] **Backend identity:** `lsof -i :9999 -P -n` shows binary path containing `ils-ios/`, NOT `ils/ILSBackend/`
- [ ] **iPad layout type:** Screenshot shows NavigationSplitView (persistent sidebar + detail), NOT overlay sidebar with hamburger button
- [ ] **iPad sidebar highlight:** After deep link navigation, sidebar highlights the correct item (not Home or previous item)
- [ ] **Data loaded:** Screenshots show real data counts (22,000+ sessions, 50+ skills, 15+ MCP servers), not 0 or loading spinners
- [ ] **Both orientations on iPad:** At least Home and Settings captured in both portrait and landscape
- [ ] **Deep link UUIDs lowercase:** Session deep links use lowercase UUIDs
- [ ] **Post-fix screenshots:** After any fix-as-you-go, the screenshot was captured AFTER rebuild + reinstall, not before
- [ ] **Evidence naming:** Every screenshot has a structured name identifying device, sequence number, screen, and state
- [ ] **Accessibility tree evidence:** Key screens have `idb_describe` output alongside visual screenshots for machine verification
- [ ] **UserDefaults state:** Fresh install vs upgrade install decision was intentional, not accidental
- [ ] **Status bar clean:** Simulator status bar overridden for consistent evidence appearance

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Stale binary installed (P1) | HIGH -- re-run entire validation | Build fresh, verify timestamp, reinstall, recapture ALL screenshots |
| Wrong backend (P6) | HIGH -- re-run entire validation | Kill old backend, start correct one, verify response format, recapture all |
| Screenshot timing (P2) | LOW -- recapture specific screenshot | Add delay, verify with idb_describe, recapture |
| Wrong coordinates on iPad (P3) | LOW -- re-run idb_describe | Fresh accessibility tree dump, update coordinate map, retry taps |
| iPad layout not checked (P4) | MEDIUM -- add iPad-specific checks | Run iPad validation phase with explicit split-view checks |
| Fresh install clears state (P5) | LOW -- reconfigure | Launch app, wait for auto-connect, navigate to Home, continue |
| Deep link UUID case (P10) | LOW -- lowercase and retry | Pipe through `tr`, retry deep link |
| Evidence not verifiable (P12) | MEDIUM -- retroactive naming | Rename files, add metadata, re-verify uncertain screenshots |

---

## Sources

- Direct code inspection: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` -- `isRegularWidth` branch at line 137 switches between `iPadLayout` (NavigationSplitView) and `iPhoneLayout` (ZStack overlay); `navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)` at line 230; `columnVisibility` state at line 111
- Direct code inspection: `ILSApp/ILSApp/Services/ConnectionManager.swift` -- `UserDefaults.standard.string(forKey: "serverURL")` read at line 31; `hasConnectedBefore` flag at line 62/68
- Direct code inspection: `ILSApp/ILSApp/ILSAppApp.swift` -- `@AppStorage("colorScheme")` at line 14; URL handler `handleURL()` for deep link routing
- Project memory (MEMORY.md): Stale DerivedData install, idb_tap toolbar limitation, deep link UUID case sensitivity, RalphMobile reinstall, iPhone 16 Pro Max 440x956 logical resolution, fresh install UserDefaults clearing, wrong backend binary
- Quick-5 audit summary (5-SUMMARY.md): 40+ ILSApp-* DerivedData directories found; deep link fix validated against wrong binary; stale install script using `find | head -1`
- Simulator listing: `iPad Pro 13 ILS` (C074375B-2CB2-4F95-A55C-972F2FF35041) confirmed available for iPad validation
- iPad Pro 13-inch M4 logical resolution: 1032x1376 points ([Use Your Loaf](https://useyourloaf.com/blog/ipad-2024-screen-sizes/))
- iPad size class behavior: All iPads full-screen are regular/regular; 1/3 Split View downgrades to compact horizontal ([Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-different-layouts-using-size-classes))
- SwiftUI NavigationSplitView column behavior: Collapses to stack in compact size class ([Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview))
- Screenshot timing: `xcrun simctl io screenshot` has no wait-for-idle; SwiftUI animations can produce partial captures ([simctl reference](https://nshipster.com/simctl/))
- idb accessibility primitives: `idb describe` returns accessibility tree with coordinates; consistent across device types ([idb documentation](https://fbidb.io/docs/accessibility/))
- Animation false positives in UI testing: Elements can exist in accessibility tree before reaching final position ([Flaky UI Tests](https://trinhngocthuyen.com/posts/tech/dealing-with-flaky-ui-tests/))

---
*Pitfalls research for: ILS iOS/macOS -- v3.5 Comprehensive Functional Validation (iOS & iPad)*
*Researched: 2026-02-25*
